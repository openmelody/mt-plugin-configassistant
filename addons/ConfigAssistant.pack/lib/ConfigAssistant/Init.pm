package ConfigAssistant::Init;

use strict;
use ConfigAssistant::Util qw( find_theme_plugin find_option_plugin );
use File::Spec;
use Sub::Install;

# use MT::Log::Log4perl qw( l4mtdump ); use Log::Log4perl qw( :resurrect );
our $logger;

sub plugin {
    return MT->component('ConfigAssistant');
}

sub init_app {
    my $plugin = shift;
    my ($app) = @_;
    return if $app->id eq 'wizard';

    # Disable the AutoPrefs plugin if it's installed. (AutoPrefs has been
    # merged with Config Assistant, so is not needed anymore.)
    my $switch = MT->config('PluginSwitch') || {};
    unless ( ( $switch->{'AutoPrefs'} || '' ) eq '0' ) {
        $switch->{'AutoPrefs'} = 0;
        MT->config( 'PluginSwitch', $switch, 1 );
        MT->config->save_config();
    }

    init_options($app);
    my $r = $plugin->registry;
    $r->{tags} = sub { load_tags( $app, $plugin ) };

    # Static files only get copied during an upgrade.
    if ( $app->id eq 'upgrade' ) {

        # Because no schema version is set, the upgrade process doesn't run
        # during the plugin's initial install. But, we need it to so that
        # static files will get copied. Check if PluginschemaVersion has been
        # set for Config Assistant. If not, set it. That way, when the upgrade
        # runs it sees it and will run the upgrade_function.
        # If this isn't the upgrade screen, just quit.
        my $cfg = MT->config('PluginSchemaVersion');

        # $cfg->{$plugin->id} = '0.1';  ### UNCOMMENT TO TEST UPGRADE ###
        if ( ( $cfg->{ $plugin->id } || '' ) eq '' ) {

            # There is no schema version set. Set one!
            $cfg->{ $plugin->id } = '0.1';
        }
    }

    require Sub::Install;

    # TODO - This should not have to reinstall a subroutine. It should invoke
    #        a callback.
    Sub::Install::reinstall_sub( {
                                   code => \&needs_upgrade,
                                   into => 'MT::Component',
                                   as   => 'needs_upgrade'
                                 }
    );
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
            if ( $r->{'template_sets'}->{$set}->{'options'} ) {
                foreach my $opt (
                        keys %{ $r->{'template_sets'}->{$set}->{'options'} } )
                {
                    next if ( $opt eq 'fieldsets' );
                    my $option
                      = $r->{'template_sets'}->{$set}->{'options'}->{$opt};

                    # To avoid option names that may collide with other 
                    # options in other template sets settings are derived 
                    # by combining the name of the template set and the 
                    # option's key.
                    my $optname = $set . '_' . $opt;
                    if ( _option_exists( $sig, $optname ) ) {

                        # do nothing
                    }
                    else {

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
                        if ( ref $obj->{'registry'}->{'settings'} eq 'ARRAY' )
                        {
                            push @{ $obj->{'registry'}->{'settings'} },
                              [ $optname, { scope => 'blog', %$option, } ];
                        }
                        else
                        { # (ref $obj->{'registry'}->{'settings'} eq 'HASH') {
                            $obj->{'registry'}->{'settings'}->{$optname}
                              = { scope => 'blog', %$option, };
                        }
                    }
                } ## end foreach my $opt ( keys %{ $r...})
            } ## end if ( $r->{'template_sets'...})
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

            if ( _option_exists( $sig, $opt ) ) {

                # do nothing
            }
            else {
                if ( ref $obj->{'registry'}->{'settings'} eq 'ARRAY' ) {
                    push @{ $obj->{'registry'}->{'settings'} },
                      [ $opt, { %$option, } ];
                }
                else {    # (ref $obj->{'registry'}->{'settings'} eq 'HASH') {
                    $obj->{'registry'}->{'settings'}->{$opt} = { %$option, };
                }
            }
        } ## end foreach my $opt (@options)
    } ## end for my $sig ( keys %MT::Plugins)
} ## end sub init_options

sub _option_exists {
    my ( $sig, $opt ) = @_;
    my $obj = $MT::Plugins{$sig}{object};
    if ( ref $obj->{'registry'}->{'settings'} eq 'ARRAY' ) {
        my @settings = $obj->{'registry'}->{'settings'}->{$opt};
        foreach (@settings) {
            return 1 if $opt eq $_[0];
        }
        return 0;
    }
    elsif ( ref $obj->{'registry'}->{'settings'} eq 'HASH' ) {
        return $obj->{'registry'}->{'settings'}->{$opt} ? 1 : 0;
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
            if ( $obj->registry( 'template_sets', $set, 'options' ) ) {
                foreach my $opt (
                    keys %{ $obj->registry( 'template_sets', $set, 'options' )
                    } )
                {
                    my $option
                      = $obj->registry( 'template_sets', $set, 'options',
                                        $opt );

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
                            $_[0]->stash( 'field', $bset . '_' . $opt );
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
                            $_[0]->stash( 'field', $bset . '_' . $opt );
                            $_[0]->stash( 'plugin_ns',
                                          find_theme_plugin($bset)->id );
                            $_[0]->stash( 'scope', 'blog' );
                            runner( '_hdlr_field_value',
                                    'ConfigAssistant::Plugin', @_ );
                        };
                        if ( $option->{'type'} eq 'checkbox' ) {
                            $tags->{block}->{ $tag . 'Loop' } = sub {
                                my $blog = $_[0]->stash('blog');
                                my $bset = $blog->template_set;
                                $_[0]->stash( 'field', $bset . '_' . $opt );
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
                                $_[0]->stash( 'field', $bset . '_' . $opt );
                                $_[0]->stash( 'plugin_ns',
                                              find_theme_plugin($bset)->id );
                                $_[0]->stash( 'scope', 'blog' );
                                ###l4p $logger->debug('Contains: ', l4mtdump({ bset => $bset, opt => $opt, plugin_ns => $_[0]->stash('plugin_ns'), tag => $tag}));

                                runner( '_hdlr_field_array_contains',
                                        'ConfigAssistant::Plugin', @_ );
                            };


                        } ## end if ( $option->{'type'}...)
                        elsif ( $option->{'type'} eq 'file' ) {
                            $tags->{block}->{ $tag . 'Asset' } = sub {
                                my $blog = $_[0]->stash('blog');
                                my $bset = $blog->template_set;
                                $_[0]->stash( 'field', $bset . '_' . $opt );
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
                                $_[0]->stash( 'field', $bset . '_' . $opt );
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
                        elsif (    $option->{'type'} eq 'category_list'
                                or $option->{'type'} eq 'folder_list' )
                        {
                            my $t = $option->{'type'};
                            my $tag_type
                              = $t eq 'category_list'
                              ? 'Categories'
                              : 'Folders';
                            my $obj_class
                              = substr( $t, 0, index( $t, '_list' ) );
                            $tags->{block}->{ $tag . $tag_type } = sub {
                                $_[0]->stash( 'obj_class', $obj_class );
                                my $blog = $_[0]->stash('blog');
                                my $bset = $blog->template_set;
                                $_[0]->stash( 'field', $bset . '_' . $opt );
                                $_[0]->stash( 'plugin_ns',
                                              find_theme_plugin($bset)->id );
                                $_[0]->stash( 'scope', 'blog' );
                                runner( '_hdlr_field_category_list',
                                        'ConfigAssistant::Plugin', @_ );
                            };
                        } ## end elsif ( $option->{'type'}...)
                    } ## end elsif ( $tag ne '' )
                } ## end foreach my $opt ( keys %{ $obj...})
            } ## end if ( $obj->registry( 'template_sets'...))
        } ## end foreach my $set (@sets)

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
                    $_[0]->stash( 'field',     $opt );
                    $_[0]->stash( 'plugin_ns', find_option_plugin($opt)->id );
                    $_[0]->stash( 'scope',     lc( $option->{scope} ) );
                    runner( '_hdlr_field_cond', 'ConfigAssistant::Plugin',
                            @_ );
                };
            }
            elsif ( $tag ne '' ) {
                $tags->{function}->{$tag} = sub {
                    $_[0]->stash( 'field',     $opt );
                    $_[0]->stash( 'plugin_ns', find_option_plugin($opt)->id );
                    $_[0]->stash( 'scope',     lc( $option->{scope} ) );
                    runner( '_hdlr_field_value', 'ConfigAssistant::Plugin',
                            @_ );
                };
                if ( $option->{'type'} eq 'checkbox' ) {
                    $tags->{block}->{ $tag . 'Loop' } = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'field', $bset . '_' . $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', 'blog' );
                        runner( '_hdlr_field_array_loop',
                                'ConfigAssistant::Plugin', @_ );
                    };
                    $tags->{block}->{ $tag . 'Contains' } = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'field', $bset . '_' . $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', 'blog' );
                        runner( '_hdlr_field_array_contains',
                                'ConfigAssistant::Plugin', @_ );
                    };

                } ## end if ( $option->{'type'}...)
                elsif ( $option->{'type'} eq 'file' ) {
                    $tags->{block}->{ $tag . 'Asset' } = sub {
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'field', $bset . '_' . $opt );
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
                        $_[0]->stash( 'field', $bset . '_' . $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', 'blog' );
                        runner( '_hdlr_field_link_group',
                                'ConfigAssistant::Plugin', @_ );
                    };

                }
                elsif (    $option->{'type'} eq 'category_list'
                        or $option->{'type'} eq 'folder_list' )
                {
                    my $t = $option->{'type'};
                    my $tag_type
                      = $t eq 'category_list' ? 'Categories' : 'Folders';
                    my $obj_class = substr( $t, 0, index( $t, '_list' ) );
                    $tags->{block}->{ $tag . $tag_type } = sub {
                        $_[0]->stash( 'obj_class', $obj_class );
                        my $blog = $_[0]->stash('blog');
                        my $bset = $blog->template_set;
                        $_[0]->stash( 'field', $bset . '_' . $opt );
                        $_[0]->stash( 'plugin_ns',
                                      find_theme_plugin($bset)->id );
                        $_[0]->stash( 'scope', 'blog' );
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
                $_[0]->stash( 'field',     $tag );
                $_[0]->stash( 'plugin_ns', $obj->id );
                $_[0]->stash( 'scope',     'system' );
                $_[0]->stash( 'default',   $dir );
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
                $_[0]->stash( 'field',     $tag );
                $_[0]->stash( 'plugin_ns', $obj->id );
                $_[0]->stash( 'scope',     'system' );
                $_[0]->stash( 'default',   $url );
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
            view       => 'blog',
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
    my $c = shift;
    if ( $c->schema_version ) {
        my $sv = $c->schema_version;

        # Don't return 0 here, because we also need to check static_version.
        #return 0 unless defined $sv;
        my $key     = 'PluginSchemaVersion';
        my $id      = $c->id;
        my $ver     = MT->config($key);
        my $cfg_ver = $ver->{$id} if $ver;
        if ( ( !defined $cfg_ver ) || ( $cfg_ver < $sv ) ) {
            return 1;
        }
    }
    if ( $c->{'registry'}->{'static_version'} ) {
        my $sv      = $c->{'registry'}->{'static_version'};
        my $key     = 'PluginStaticVersion';
        my $id      = $c->id;
        my $ver     = MT->config($key);
        my $cfg_ver = $ver->{$id} if $ver;
        if ( ( !defined $cfg_ver ) || ( $cfg_ver < $sv ) ) {
            return 1;
        }
    }
    0;
} ## end sub needs_upgrade

1;

