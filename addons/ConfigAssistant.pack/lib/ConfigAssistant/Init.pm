package ConfigAssistant::Init;

use strict;
use ConfigAssistant::Util qw( find_theme_plugin find_option_plugin );
use File::Spec;
use Sub::Install;
use MT::Theme;
use version 0.77;
use Scalar::Util qw( reftype );

# use MT::Log::Log4perl qw( l4mtdump ); use Log::Log4perl qw( :resurrect );
our $logger;

sub plugin {
    return MT->component('ConfigAssistant');
}

sub init_app {
    my $plugin = shift;
    my ($app)  = @_;
    my $cfg    = $app->config;
    return if $app->id eq 'wizard';

    # Disable the AutoPrefs plugin if it's still installed. (AutoPrefs has
    # been merged with Config Assistant, so is not needed anymore.)
    my $switch = $cfg->PluginSwitch || {};
    $switch->{'AutoPrefs/config.yaml'} = $switch->{'AutoPrefs'} = 0;
    $cfg->PluginSwitch( $switch );

    # FIXME This needs some commentary...
    init_options($app);

    # FIXME This looks fishy... Pretty sure we shouldn't be accessing the registry as a hash but instead $plugin->registry('tags', sub { ... })
    my $r = $plugin->registry->{tags} = sub { load_tags( $app, $plugin ) };

    # Static files only get copied during an upgrade.
    if ( $app->id eq 'upgrade' ) {
        # Because no schema version is set, the upgrade process does nothing
        # during the plugin's initial install.  So, in order to copy static
        # files on first run, we set an initial schema version which triggers
        # the framework.
        my $schemas                 = $cfg->PluginSchemaVersion || {};
        $schemas->{ $plugin->id } ||= '0.1';
        # $schemas->{$plugin->id}   = '0.1';  ## UNCOMMENT TO TEST UPGRADE ##
        $cfg->PluginSchemaVersion( $schemas );
    }

    # TODO - This should not have to reinstall a subroutine. It should invoke
    #        a callback.
    require Sub::Install;
    Sub::Install::reinstall_sub( {
                                   code => \&needs_upgrade,
                                   into => 'MT::Component',
                                   as   => 'needs_upgrade'
                                 }
    );

    # Template sets should work as blog or website-level themes. The modified
    # function allows a template set to work as either.
    my $result = Sub::Install::reinstall_sub({
        code => \&load_pseudo_theme_from_template_set,
        into => 'MT::Theme',
        as   => '_load_pseudo_theme_from_template_set'
    });

    return 1;
} ## end sub init_app

sub init_options {

    #    my $callback = shift;
    my $app = shift;

    # For each plugin, convert options into settings
    my $has_blog_settings = 0;
    my $has_sys_settings  = 0;

    # For the static_version check, to determine if an upgrade is needed.
    my @plugins;
    for my $sig ( keys %MT::Plugins ) {
        my $plugin = $MT::Plugins{$sig};
        my $obj    = $MT::Plugins{$sig}{object};
        my $r      = $obj->{registry};
        my @sets   = keys %{ $r->{'template_sets'} };
        foreach my $set (@sets) {
            my $options = $r->{'template_sets'}->{$set}->{'options'} || {};
            foreach my $opt ( keys %$options ) {
                next if ( $opt eq 'fieldsets' );
                my $option = $options->{$opt};

                # To avoid option names that may collide with other
                # options in other template sets settings are derived
                # by combining the name of the template set and the
                # option's key.
                my $optname = $set . '_' . $opt;
                unless ( _option_exists( $sig, $optname ) ) {
                    # if ( my $default = $option->{default} ) {
                    #     if (   !ref($default)
                    #         && (   $default =~ /^\s*sub/
                    #             || $default =~ /^\$/)) {
                    #         $default
                    #           = $app->handler_to_coderef($default);
                    #         $option->{default} = sub {
                    #               return $default->(MT->instance) };
                    #     }
                    # }

                    my $settings         = $obj->{registry}->{settings} ||= {};
                    my $settings_reftype = reftype($settings) || '';

                    if ( 'ARRAY' eq $settings_reftype ) {
                        push( @$settings,
                            [ $optname, { scope => 'blog', %$option, } ]
                        );
                    }
                    else
                    { # (ref $obj->{'registry'}->{'settings'} eq 'HASH') {
                            $settings->{$optname}
                              = { scope => 'blog', %$option, };
                    }
                }
            } ## end foreach my $opt ( keys %{ $r...})
        }    # end foreach (@sets)

        # Now register settings for each plugin option and a plugin_config_form
        my @options = keys %{ $r->{'options'} };
        foreach my $opt (@options) {
            next if ( $opt eq 'fieldsets' );
            my $option = $r->{'options'}->{$opt};
            $option->{scope} ||= '';
            if ( $option->{scope} eq 'system' ) {
                require ConfigAssistant::Plugin;
                $obj->{'registry'}->{'system_config_template'}
                  = \&ConfigAssistant::Plugin::plugin_options;
            }
            if ( $option->{scope} eq 'blog' ) {
                require ConfigAssistant::Plugin;
                $obj->{'registry'}->{'blog_config_template'}
                  = \&ConfigAssistant::Plugin::plugin_options;
            }

            unless ( _option_exists( $sig, $opt ) ) {
                my $settings         = $obj->{registry}->{settings} ||= {};
                my $settings_reftype = reftype($settings) || '';
                if ( 'ARRAY' eq $settings_reftype ) {
                    push( @$settings, [ $opt, { %$option, } ]);
                }
                else {    # (ref $obj->{'registry'}->{'settings'} eq 'HASH') {
                    $settings->{$opt} = { %$option };
                }
            }
        } ## end foreach my $opt (@options)
    } ## end for my $sig ( keys %MT::Plugins)
} ## end sub init_options

sub _option_exists {
    my ( $sig, $opt ) = @_;
    my $obj = $MT::Plugins{$sig}{object};

    my $settings         = $obj->{registry}->{settings} ||= {};
    my $settings_reftype = reftype($settings) || '';

    if ( 'ARRAY' eq $settings_reftype ) {
        my @settings = $obj->{'registry'}->{'settings'}->{$opt}; # FIXME This looks wrong
        foreach (@settings) {
            return 1 if $opt eq $_[0];
        }
        return 0;
    }
    elsif ( 'HASH' eq $settings_reftype ) {
        return $settings->{$opt} ? 1 : 0;
    }
    return 0;
}

sub load_tags {
    my $app  = shift;
    my $tags = {};

    # First load tags that correspond with Plugin Settings
    # TODO: this struct needs to be abstracted out to be similar to template set options
    my $cfg = $app->registry('plugin_config');
    foreach my $plugin_id ( keys %$cfg ) {
        my $plugin_cfg = $cfg->{$plugin_id};
        my $p          = delete $cfg->{$plugin_id}->{'plugin'};
        foreach my $key ( keys %$plugin_cfg ) {
            MT->log( {
                   message => $p->name
                     . " is using a Config Assistant syntax that is no "
                     . "longer supported. plugin_config needs to be "
                     . "updated to 'options'. Please consult documentation.",
                   class    => 'system',
                   category => 'plugin',
                   level    => MT::Log::ERROR(),
                }
            );
        }
    }

    # Now register template tags for each of the template set options.
    for my $sig ( keys %MT::Plugins ) {
        my $plugin = $MT::Plugins{$sig};
        my $obj    = $MT::Plugins{$sig}{object};
        my $r      = $obj->{registry};

        # First initialize all the tags associated with themes
        my @sets = keys %{ $r->{'template_sets'} };
        foreach my $set (@sets) {
            my $options = $obj->registry('template_sets', $set, 'options') || {};
            foreach my $opt ( keys %$options ) {
                my $option = $options->{$opt};

                # If the option does not define a tag name,
                # then there is no need to register one
                next if ( !defined( $option->{tag} ) );
                my $tag = $option->{tag};

                # TODO - there is the remote possibility that a template
                # set will attempt to register a duplicate tag. This
                # case needs to be handled properly. Or does it? Note:
                # the tag handler takes into consideration the blog_id,
                # the template set id and the option/setting name.
                if ( $tag =~ s/\?$// ) {
                    $tags->{block}->{$tag} = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'config_type', $bset . '_' . $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', 'blog' );
                        runner( '_hdlr_field_cond',
                                'ConfigAssistant::Plugin', @_ );
                    };
                }
                elsif ( $tag ne '' ) {
                    $tags->{function}->{$tag} = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'config_type', $bset . '_' . $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', 'blog' );
                        runner( '_hdlr_field_value',
                                'ConfigAssistant::Plugin', @_ );
                    };
                    # Field type: `entry` or `page` or `entry_or_page`
                    if (
                        $option->{'type'} eq 'entry'
                        || $option->{'type'} eq 'page'
                        || $option->{'type'} eq 'entry_or_page'
                    ) {
                        $tags->{block}->{ $tag . 'Entries' } = sub {
                            my $blog = $_[0]->stash('blog');
                            my $bset = $blog->template_set;
                            $_[0]->stash( 'config_type', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            runner( '_hdlr_field_entry_loop',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                        # Redefine the function tag so that only the
                        # active entries are returned.
                        $tags->{function}->{$tag} = sub {
                            my $blog = $_[0]->stash('blog');
                            my $bset = $blog->template_set;
                            $_[0]->stash( 'config_type', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            runner( '_hdlr_field_value_entry',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                    } ## end
                    elsif ( $option->{'type'} eq 'checkbox' ) {
                        $tags->{block}->{ $tag . 'Loop' } = sub {
                            my $blog = $_[0]->stash('blog');
                            my $bset = $blog->template_set;
                            $_[0]->stash( 'config_type', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            runner( '_hdlr_field_array_loop',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                        $tags->{block}->{ $tag . 'Contains' } = sub {
                            ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
                            my $blog = $_[0]->stash('blog');
                            my $bset = $blog->template_set;
                            $_[0]->stash( 'config_type', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            ###l4p $logger->debug('Contains: ', l4mtdump({ bset => $bset, opt => $opt, plugin_ns => $_[0]->stash('plugin_ns'), tag => $tag}));

                            runner( '_hdlr_field_array_contains',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                    } ## end if ( $option->{'type'}...)
                    elsif (
                        $option->{'type'} eq 'file'
                        || $option->{'type'} eq 'asset'
                    ) {
                        $tags->{block}->{ $tag . 'Asset' } = sub {
                            my $blog = $_[0]->stash('blog');
                            my $bset = $blog->template_set;
                            $_[0]->stash( 'config_type', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            runner( '_hdlr_field_asset',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                    }
                    elsif ( $option->{'type'} eq 'link-group' ) {
                        $tags->{block}->{ $tag . 'Links' } = sub {
                            my $blog = $_[0]->stash('blog');
                            my $bset = $blog->template_set;
                            $_[0]->stash( 'config_type', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            $_[0]->stash(
                                       'show_children',
                                       (
                                         defined $option->{show_children}
                                         ? $option->{show_children}
                                         : 1
                                       )
                            );
                            runner( '_hdlr_field_link_group',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                    } ## end elsif ( $option->{'type'}...)
                    elsif ( $option->{'type'} eq 'text-group' ) {
                        $tags->{block}->{ $tag . 'Items' } = sub {
                            my $blog = $_[0]->stash('blog');
                            my $bset = $blog->template_set;
                            $_[0]->stash( 'config_type', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            runner( '_hdlr_field_text_group',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                    } ## end elsif ( $option->{'type'}...)
                    elsif ( $option->{'type'} eq 'datetime' ) {
                        $tags->{function}->{ $tag } = sub {
                            my $blog = $_[0]->stash('blog');
                            my $bset = $blog->template_set;
                            $_[0]->stash( 'config_type', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            $_[0]->stash( 'format', $option->{format} );
                            runner( '_hdlr_field_datetime',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                    } ## end elsif ( $option->{'type'}...)
                    elsif (    $option->{'type'} eq 'category'
                            or $option->{'type'} eq 'folder'
                            # deprecated options
                            or $option->{'type'} eq 'category_list'
                            or $option->{'type'} eq 'folder_list' )
                    {
                        my $obj_class = $option->{'type'} =~ /category/
                            ? 'category' : 'folder';
                        my $tag_type = $obj_class eq 'category'
                            ? 'Categories' : 'Folders';
                        $tags->{block}->{ $tag . $tag_type } = sub {
                            $_[0]->stash( 'obj_class', $obj_class );
                            my $blog = $_[0]->stash('blog');
                            my $bset = $blog->template_set;
                            $_[0]->stash( 'config_type', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            $_[0]->stash(
                                       'show_children',
                                       (
                                         defined $option->{show_children}
                                         ? $option->{show_children}
                                         : 1
                                       ));
                            runner( '_hdlr_field_category_list',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                    } ## end elsif ( $option->{'type'}...)
                } ## end elsif ( $tag ne '' )
            } ## end foreach my $opt ( keys %{ $obj...})
        } ## end foreach my $set (@sets)

        # Create tags for system- and blog-level Plugin Options.
        my @options = keys %{ $r->{'options'} };
        foreach my $opt (@options) {
            my $option = $r->{'options'}->{$opt};

            # If the option does not define a tag name,
            # then there is no need to register one
            next if ( !defined( $option->{tag} ) );
            my $tag = $option->{tag};

            # TODO - there is the remote possibility that a template set
            # will attempt to register a duplicate tag. This case needs to be
            # handled properly. Or does it?
            # Note: the tag handler takes into consideration the blog_id, the
            # template set id and the option/setting name.
            if ( $tag =~ s/\?$// ) {
                $tags->{block}->{$tag} = sub {
                    $_[0]->stash( 'config_type', $opt );
                    $_[0]->stash( 'plugin_ns',   find_option_plugin($opt)->id );
                    $_[0]->stash( 'scope',       lc( $option->{scope} ) );
                    runner( '_hdlr_field_cond', 'ConfigAssistant::Plugin',
                            @_ );
                };
            }
            elsif ( $tag ne '' ) {
                $tags->{function}->{$tag} = sub {
                    $_[0]->stash( 'config_type',     $opt );
                    $_[0]->stash( 'plugin_ns', find_option_plugin($opt)->id );
                    $_[0]->stash( 'scope',     lc( $option->{scope} ) );
                    runner( '_hdlr_field_value', 'ConfigAssistant::Plugin',
                            @_ );
                };
                if ( $option->{'type'} eq 'checkbox' ) {
                    $tags->{block}->{ $tag . 'Loop' } = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'config_type', $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', lc( $option->{scope} ) );
                        runner( '_hdlr_field_array_loop',
                                'ConfigAssistant::Plugin', @_ );
                    };
                    $tags->{block}->{ $tag . 'Contains' } = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'config_type', $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', lc( $option->{scope} ) );
                        runner( '_hdlr_field_array_contains',
                                'ConfigAssistant::Plugin', @_ );
                    };

                } ## end if ( $option->{'type'}...)
                elsif ( $option->{'type'} eq 'file' ) {
                    $tags->{block}->{ $tag . 'Asset' } = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'config_type', $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', lc( $option->{scope} ) );
                        runner( '_hdlr_field_asset',
                                'ConfigAssistant::Plugin', @_ );
                    };

                }
                elsif ( $option->{'type'} eq 'link-group' ) {
                    $tags->{block}->{ $tag . 'Links' } = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'config_type', $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', lc( $option->{scope} ) );
                        runner( '_hdlr_field_link_group',
                                'ConfigAssistant::Plugin', @_ );
                    };

                }
                elsif ( $option->{'type'} eq 'datetime' ) {
                    $tags->{function}->{ $tag } = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'config_type', $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', lc( $option->{scope} ) );
                        $_[0]->stash( 'format', $option->{format} );
                        runner( '_hdlr_field_datetime',
                                'ConfigAssistant::Plugin', @_ );
                    };
                } ## end elsif ( $option->{'type'}...)

                elsif (    $option->{'type'} eq 'category'
                        or $option->{'type'} eq 'folder'
                        # deprecated options
                        or $option->{'type'} eq 'category_list'
                        or $option->{'type'} eq 'folder_list' )
                {
                    my $obj_class = $option->{'type'} =~ /category/
                        ? 'category' : 'folder';
                    my $tag_type = $obj_class eq 'category'
                        ? 'Categories' : 'Folders';
                    $tags->{block}->{ $tag . $tag_type } = sub {
                        $_[0]->stash( 'obj_class', $obj_class );
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'config_type', $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', lc( $option->{scope} ) );
                        runner( '_hdlr_field_category_list',
                                'ConfigAssistant::Plugin', @_ );
                    };
                }
            } ## end elsif ( $tag ne '' )
        } ## end foreach my $opt (@options)

        # Create plugin-specific tags to the static content
        if ( $r && $r->{'static_version'} ) {

            # Create the plugin-specific static file path tag, such as "ConfigAssistantStaticFilePath."
            my $tag;
            $tag = $obj->id . 'StaticFilePath';
            my $dir = $obj->path;
            $tags->{function}->{$tag} = sub {
                MT->log(
                    "The usage of the tag '$tag' has been deprecated. Please use mt:PluginStaticFilePath instead"
                );
                $_[0]->stash( 'config_type', $tag );
                $_[0]->stash( 'plugin_ns',   $obj->id );
                $_[0]->stash( 'scope',       'system' );
                $_[0]->stash( 'default',     $dir );
            };

            # Create the plugin-specific static web path tag, such as "ConfigAssistantStaticWebPath."
            $tag = $obj->id . 'StaticWebPath';
            my $url = $app->static_path;
            $url .= '/' unless $url =~ m!/$!;
            $url .= 'support/plugins/' . $obj->id . '/';
            $tags->{function}->{$tag} = sub {
                MT->log(
                    "The usage of the tag '$tag' has been deprecated. Please use mt:PluginStaticWebPath instead"
                );
                $_[0]->stash( 'config_type', $tag );
                $_[0]->stash( 'plugin_ns',   $obj->id );
                $_[0]->stash( 'scope',       'system' );
                $_[0]->stash( 'default',     $url );
            };
        } ## end if ( $r && $r->{'static_version'...})
    } ## end for my $sig ( keys %MT::Plugins)

    $tags->{function}{'PluginConfigForm'}
      = '$ConfigAssistant::ConfigAssistant::Plugin::tag_config_form';
    $tags->{function}{'PluginStaticWebPath'}
      = '$ConfigAssistant::ConfigAssistant::Plugin::tag_plugin_static_web_path';
    $tags->{function}{'PluginStaticFilePath'}
      = '$ConfigAssistant::ConfigAssistant::Plugin::tag_plugin_static_file_path';

    return $tags;
} ## end sub load_tags

sub update_menus {

    # Now just add the Theme Options menu item to the top of the Design menu.
    return {
        'design:theme_options' => {
            label      => 'Theme Options',
            order      => '10',
            mode       => 'theme_options',
            view       => [ 'blog', 'website' ],
            permission => 'edit_templates',
            condition  => sub {
                my $blog = MT->instance->blog;
                return 0 if !$blog;
                my $ts = MT->instance->blog->template_set;
                return 0 if !$ts;
                my $app = MT::App->instance;
                return 1 if $app->registry('template_sets')->{$ts}->{options};
                return 0;
            },
        },
        'prefs:ca_prefs' => {
                              label      => 'Chooser',
                              order      => 1,
                              mode       => 'ca_prefs_chooser',
                              view       => 'blog',
                              permission => 'administer',
        }
    };
} ## end sub update_menus

sub runner {
    my $method = shift;
    my $class  = shift;
    eval "require $class;";
    if ($@) { die $@; $@ = undef; return 1; }
    my $method_ref = $class->can($method);
    my $plugin     = MT->component("ConfigAssistant");
    return $method_ref->( $plugin, @_ ) if $method_ref;
    die $plugin->translate( "Failed to find [_1]::[_2]", $class, $method );
}

sub needs_upgrade {

    # We need to override MT::Component::needs_upgrade because that only
    # checks for schema_version, because now we also want to check for
    # static_version.
    my $c  = shift;
    my $id = $c->id;

    my %versions = (
        PluginSchemaVersion => ($c->schema_version || '0.0.0'),
        PluginStaticVersion => ($c->{'registry'}->{'static_version'} || '0.0.0'),
    );

    foreach my $key ( keys %versions ) {
        if ( defined( my $currver = $versions{$key} )) {
            my $lastvercfg = MT->config($key);
            my $lastver    = $lastvercfg->{$id} if 'HASH' eq ref $lastvercfg;
            return 1 if version->parse( $currver ) > version->parse( $lastver // '0.0.0' );
        }
    }

    return 0;
} ## end sub needs_upgrade

# This is a copy of MT::Theme::_load_pseudo_theme_from_template_set with only
# one change: $props->{class} is set to `both` instead of `blog`, which means
# the template set can work as both a blog theme and a website theme.
sub load_pseudo_theme_from_template_set {
    my $pkg = shift;
    my ($id) = @_;
    $id =~ s/^theme_//;
    my $sets = MT->registry("template_sets")
        or return;
    my $set = $sets->{$id}
        or return;
    my $plugin = $set->{plugin} || undef;
    my $label
        = $set->{label}
        || ( $plugin && $plugin->registry('name') )
        || $id;
    my $props = {
        id          => "theme_$id",
        type        => 'template_set',
        author_name => $plugin ? $plugin->registry('author_name') : '',
        author_link => $plugin ? $plugin->registry('author_link') : '',
        version     => $plugin ? $plugin->registry('version') : '',
        __plugin    => $plugin,

        # A template set theme is valid for both blog and website-level themes.
        # class       => 'blog',
        class       => 'both',

        path        => $plugin ? $plugin->path : '',
        base_css    => $set->{base_css},
        elements    => {
            template_set => {
                component => 'core',
                importer  => 'template_set',
                name      => 'template set',
                data      => $id,
            },
        },
    };
    my $reg = {
        id          => "theme_$id",
        version     => $plugin ? $plugin->registry('version') : '',
        l10n_class  => $plugin ? $plugin->registry('l10n_class') : 'MT::L10N',
        label       => sub { MT->translate( '[_1]', $label ) },
        description => $set->{description},
        class       => 'blog',
    };
    my $class = $pkg->new($props);
    $class->registry($reg);
    return $class;
}

1;
