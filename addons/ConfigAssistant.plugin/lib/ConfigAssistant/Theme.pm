package ConfigAssistant::Theme;

use strict;
use MT;
use base qw( MT::Object );

use MT::Util
  qw( dirify );

__PACKAGE__->install_properties({
    column_defs => {
        'id'         => 'integer not null auto_increment',
        'plugin_sig' => 'string(999)',
        'ts_id'      => 'string(999)',
        'ts_label'   => 'string(999)',
        'ts_desc'    => 'text',
    },
    indexes => {
        plugin_sig => 1,
        ts_id      => 1,
    },
    datasource  => 'theme',
    primary_key => 'id',
});

sub _theme_label {
    # Grab the theme label. If no template set label is supplied then use
    # the parent plugin's name plus the template set ID.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{label}
        ? $obj->{registry}->{'template_sets'}->{$set}->{label}
        : eval {$obj->name.': '} . $set;
}

sub _theme_thumbnail_url {
    # Build the theme thumbnail URL. If no thumb is supplied, grab the
    # "default" thumbnail.
    my ($set, $obj) = @_;
    my $app = MT->instance;
    return $obj->{registry}->{'template_sets'}->{$set}->{thumbnail}
        ? $app->config('StaticWebPath').'support/plugins/'
            .$obj->key.'/'.$obj->{registry}->{'template_sets'}->{$set}->{thumbnail}
        : $app->config('StaticWebPath').'support/plugins/'
            .'ConfigAssistant/images/default_theme_thumb-small.png';
}

sub _theme_preview_url {
    # Build the theme thumbnail URL. If no thumb is supplied, grab the
    # "default" thumbnail.
    my ($set, $obj) = @_;
    my $app = MT->instance;
    return $obj->{registry}->{'template_sets'}->{$set}->{preview}
        ? $app->config('StaticWebPath').'support/plugins/'
            .$obj->key.'/'.$obj->{registry}->{'template_sets'}->{$set}->{preview}
        : $app->config('StaticWebPath').'support/plugins/'
            .'ConfigAssistant/images/default_theme_thumb-large.png';
}

sub _theme_description {
    # Grab the description. If no template set description is supplied
    # then use the parent plugin's description.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{description}
        ? $obj->{registry}->{'template_sets'}->{$set}->{description}
        : eval {$obj->description};
}

sub _theme_author_name {
    # Grab the author name. If no template set author name, then use
    # the parent plugin's author name.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{author_name}
        ? $obj->{registry}->{'template_sets'}->{$set}->{author_name}
        : eval {$obj->author_name};
}

sub _theme_author_link {
    # Grab the author name. If no template set author link, then use
    # the parent plugin's author link.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{author_link}
        ? $obj->{registry}->{'template_sets'}->{$set}->{author_link}
        : eval {$obj->author_link};
}

sub _theme_paypal_email {
    # Grab the paypal donation email address. If no template set paypal
    # email address, then it might have been set at the plugin level.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{paypal_email}
        ? $obj->{registry}->{'template_sets'}->{$set}->{paypal_email}
        : eval {$obj->paypal_email};
}

sub _theme_version {
    # Grab the version number. If no template set version, then use
    # the parent plugin's version.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{version}
        ? $obj->{registry}->{'template_sets'}->{$set}->{version}
        : eval {$obj->version};
}

sub _theme_link {
    # Grab the theme link URL. If no template set theme link, then use
    # the parent plugin's plugin_link.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{theme_link}
        ? $obj->{registry}->{'template_sets'}->{$set}->{theme_link}
        : eval {$obj->plugin_link};
}

sub _theme_docs {
    # Grab the theme doc URL. If no template set theme doc, then use
    # the parent plugin's doc_link.
    my ($set, $obj) = @_;
    return $obj->{registry}->{'template_sets'}->{$set}->{doc_link}
        ? $obj->{registry}->{'template_sets'}->{$set}->{doc_link}
        : eval {$obj->doc_link};
}

sub theme_dashboard {
    my $app    = shift;
    my $ts     = $app->blog->template_set;
    use ConfigAssistant::Plugin;
    my $plugin = ConfigAssistant::Plugin::find_theme_plugin($ts);

    my $param = {};
    # Build the theme dashboard links
    $param->{theme_label}       = _theme_label($ts, $plugin);
    $param->{theme_description} = _theme_description($ts, $plugin);
    $param->{theme_author_name} = _theme_author_name($ts, $plugin);
    $param->{theme_author_link} = _theme_author_link($ts, $plugin);
    $param->{theme_link}        = _theme_link($ts, $plugin);
    $param->{theme_doc_link}    = _theme_docs($ts, $plugin);
    $param->{theme_version}     = _theme_version($ts, $plugin);
    $param->{paypal_email}      = _theme_paypal_email($ts, $plugin);
    # Grab an up-to-date thumbnail to show what the site looks like.
    $param->{theme_thumb_url}   = _theme_thumbnail($ts, $plugin);

    # Are the templates linked? We use this to show/hide the Edit/View
    # Templates links.
    use MT::Template;
    my $linked = MT::Template->load(
                        { blog_id     => $app->blog->id,
                          linked_file => '*', });
    if ($linked) {
        # These templates *are* linked.
        $param->{linked_theme} = 1;
    }
    else {
        # These templates are *not* linked. Because they are not linked,
        # it's possible the user has edited them. Return a message saying
        # that. We can figure out which templates are edited by comparing
        # the created_on and modified_on dates.
        # So, first grab templates in the current blog that are not 
        # backups and that have had modifications made (modified_on col).
        my $iter = MT::Template->load_iter(
                        { blog_id    => $app->blog->id,
                          type => {not_like => 'backup'},
                          modified_on => {not_null => 1}, });
        while ( my $tmpl = $iter->() ) { 
            if ($tmpl->modified_on > $tmpl->created_on) {
                $param->{templates_modified} = 1;
                # Once a single modified template has been found there's
                # no reason to search anymore.
                last;
            }
        }
    }
    # Are there any Theme Options for this blog?
    $param->{theme_options} = $plugin->{registry}->{'template_sets'}->{$ts}->{options}
                                ? 1 : 0;
    # Are there any Widget Sets for this blog?
    $param->{widget_sets} = $plugin->{registry}->{'template_sets'}->{$ts}->{templates}->{widgetset}
                                ? 1 : 0;
    # Is the Custom CSS plugin installed? Is it used in this blog? If so, we
    # should link to it.
    my $plugin_custom_css = MT->component('CustomCSS');
    if ( $plugin_custom_css ) {
        require CustomCSS::Plugin;
        eval {
            $param->{custom_css} = CustomCSS::Plugin::uses_custom_css();
        }
    }
    # Now, if there are any configurable options for this theme, we want to expose them.
    # So check the previous variables to see if there is anything to show.
    $param->{customizable_theme} = ( $param->{theme_options} || 
                                     $param->{widget_sets} ||
                                     $param->{custom_css} ) ? 1 : 0;
    $param->{new_theme} = $app->param('new_theme');
    return $app->load_tmpl('theme_dashboard.mtml', $param);
}

sub select_theme {
    # The user probably wants to apply a new theme; we start by browsing the
    # available themes.
    # Save themes to the theme table, so that we can build a listing screen from them.
    _theme_check();

    my $app = shift;
    # Terms may be supplied if the user is searching.
    my $search_terms = $app->param('search');
    # Unset the search parameter to that the $app->listing won't try to build
    # a search result.
    $app->param('search', '');
    my @terms;
    if ($search_terms) {
        # Create an array of the search terms. "Like" lets us do the actual
        # search portion, while the "=> -or =>" lets us match any field.
        @terms = ({ts_label =>{like => '%'.$search_terms.'%'}} 
                    => -or => 
                  {ts_desc => {like => '%'.$search_terms.'%'}}
                    => -or => 
                  {ts_id => {like => '%'.$search_terms.'%'}}
                    => -or => 
                  {plugin_sig => {like => '%'.$search_terms.'%'}});
    }
    else {
        # Terms needs to be filled with something, otherwise it throws an 
        # error. Apparently, *if* an array is used for terms, MT expects 
        # there to be something in it, so undef'ing the @terms doesn't
        # help. This should match anything.
        @terms = ( { ts_label => {like => "%%"}} );
    }

    # Set the number of items to appear on the theme grid. 6 fit, so that's
    # what it's set to here. However, if unset, it defaults to 25!
    my $list_pref = $app->list_pref('theme') if $app->can('list_pref');
    $list_pref->{rows} = 6;

    my $plugin = MT->component('ConfigAssistant');
    my $tmpl = $plugin->load_tmpl('theme_select.mtml');
    return $app->listing({
        type     => 'theme',
        template => $tmpl,
        terms    => \@terms,
        params   => {
            search  => $search_terms,
            blog_id => $app->param('blog_id'),
        },
        code => sub {
            my ($theme, $row) = @_;
            # Use the plugin sig to grab the plugin.
            my $plugin = $MT::Plugins{$theme->plugin_sig}->{object};
            if (!$plugin) {
                # This plugin couldn't be loaded! That must mean the theme has 
                # been uninstalled, so remove the entry in the table.
                $theme->remove;
                $theme->save;
                next;
            }
            $row->{id}            = $theme->ts_id;
            $row->{label}         = _theme_label($theme->ts_id, $plugin);
            $row->{thumbnail_url} = _theme_thumbnail_url($theme->ts_id, $plugin);
            $row->{preview_url}   = _theme_preview_url($theme->ts_id, $plugin);
            $row->{description}   = _theme_description($theme->ts_id, $plugin);
            $row->{author_name}   = _theme_author_name($theme->ts_id, $plugin);
            $row->{version}       = _theme_version($theme->ts_id, $plugin);
            $row->{theme_link}    = _theme_link($theme->ts_id, $plugin);
            $row->{theme_docs}    = _theme_docs($theme->ts_id, $plugin);
            $row->{plugin_sig}     = $theme->plugin_sig;
            
            return $row;
        },
    });
}

sub setup_theme {
    my $app = shift;

    my $ts_id      = $app->param('theme_id');
    my $plugin_sig = $app->param('plugin_sig');
    my $blog_id    = $app->param('blog_id');

    # As you may guess, this applies the template set to the current blog.
    my $result = _apply_theme($ts_id);

    my $param = {};
    $param->{ts_id}     = $ts_id;
    $param->{plugin_sig} = $plugin_sig;
    $param->{blog_id}   = $blog_id;

    my @loop;

    my $plugin = $MT::Plugins{$plugin_sig}->{object};

    # Find the template set and grab the options associated with it, so that
    # we can determine if there are any "required" fields to make the user
    # set up. If there are, we want them to look good (including being sorted)
    # into alphabeticized fieldsets and to be ordered correctly with in each
    # fieldset, just like on the Theme Options page.
    my $ts = $plugin->{registry}->{'template_sets'}->{$ts_id};
    # This is for any required fields that the user may not have filled in.
    my @missing_required;
    if (my $optnames = $ts->{options}) {
        my $types = $app->registry('config_types');
        my $fieldsets = $ts->{options}->{fieldsets};

        $fieldsets->{__global} = {
            label => sub { "Global Options"; }
        };

        require MT::Template::Context;
        my $ctx = MT::Template::Context->new();

        # This is a localized stash for field HTML
        my $fields;

        my $cfg_obj = $plugin->get_config_hash('blog:'.$app->blog->id);

        foreach my $optname (
            sort {
                ( $optnames->{$a}->{order} || 999 ) <=> ( $optnames->{$b}->{order} || 999 )
            } keys %{$optnames}
          )
        {
            # Don't bother to look at the fieldsets.
            next if $optname eq 'fieldsets';

            my $field = $ts->{options}->{$optname};
            if ($field->{required} == 1) {
                if ( my $cond = $field->{condition} ) {
                    if ( !ref($cond) ) {
                        $cond = $field->{condition} = $app->handler_to_coderef($cond);
                    }
                    next unless $cond->();
                }

                my $field_id = $ts_id . '_' . $optname;
                if ( $types->{ $field->{'type'} } ) {
                    my $value;
                    my $value = delete $cfg_obj->{$field_id};
                    my $out;
                    $field->{fieldset} = '__global' unless defined $field->{fieldset};
                    my $show_label =
                        defined $field->{show_label} ? $field->{show_label} : 1;
                    my $label = $field->{label} ne '' ? &{$field->{label}} : '';
                    # If there is no value for this required field (whether a 
                    # "default" value or a user-supplied value), we need to 
                    # complain and make the user fill it in. But, only complain
                    # if the user has tried to save already! We don't want to be
                    # annoying.
                    if ( !$value && $app->param('saved') ) {
                        # There is no value for this field, and it's a required
                        # field, so we need to tell the user to fix it!
                        push @missing_required, { label => $label };
                    }
                    $out .=
                        '  <div id="field-'
                        . $field_id
                        . '" class="field field-left-label pkg field-type-'
                        . $field->{type} . '">' . "\n";
                    $out .= "    <div class=\"field-header\">\n";
                    $out .=
                        "      <label for=\"$field_id\">"
                        . $label
                        . "</label>\n"
                            if $show_label;
                    $out .= "    </div>\n";
                    $out .= "    <div class=\"field-content\">\n";
                    my $hdlr =
                        MT->handler_to_coderef( $types->{ $field->{'type'} }->{handler} );
                    $out .= $hdlr->( $app, $ctx, $field_id, $field, $value );

                    if ( $field->{hint} ) {
                        $out .=
                          "      <div class=\"hint\">" . $field->{hint} . "</div>\n";
                    }
                    $out .= "    </div>\n";
                    $out .= "  </div>\n";
                    my $fs = $field->{fieldset};
                    push @{ $fields->{$fs} }, $out;
                }
                else {
                    MT->log(
                        {
                            message => 'Unknown config type encountered: '
                              . $field->{'type'}
                        }
                    );
                }
            }
        }
        my $count = 0;
        my $html;
        foreach my $set (
            sort {
                ( $fieldsets->{$a}->{order} || 999 )
                  <=> ( $fieldsets->{$b}->{order} || 999 )
            } keys %$fieldsets
          )
        {   
            next unless $fields->{$set} || $fieldsets->{$set}->{template};
            my $label     = $fieldsets->{$set}->{label};
            my $innerhtml = '';
            if ( my $tmpl = $fieldsets->{$set}->{template} ) {
                my $txt = $plugin->load_tmpl($tmpl);
                my $filter =
                    $fieldsets->{$set}->{format}
                  ? $fieldsets->{$set}->{format}
                  : '__default__';
                $txt = MT->apply_text_filters( $txt->text(), [$filter] );
                $innerhtml = $txt;
                $html .= $txt;
            }
            else {
                $html .= "<fieldset>";
                $html .= "<h3>" . $label . "</h3>";
                foreach ( @{ $fields->{$set} } ) {
                    $innerhtml .= $_;
                }
                $html .= $innerhtml;
                $html .= "</fieldset>";
            }
            push @loop,
              {
                '__first__' => ( $count++ == 0 ),
                id          => dirify($label),
                label       => $label,
                content     => $innerhtml,
              };
        }
        my @leftovers;
        foreach my $field_id ( keys %$cfg_obj ) {
            push @leftovers,
              {
                name  => $field_id,
                value => $cfg_obj->{$field_id},
              };
        }
    }

    $param->{ts_label}         = $ts->{label};
    $param->{fields_loop}      = \@loop;
    $param->{saved}            = $app->param('saved');
    $param->{missing_required} = \@missing_required;
    # Not "to home," but "Theme Options home"
    $param->{to_home_url} = $app->uri.'?__mode=theme_dashboard'
                                ."&blog_id=$blog_id&new_theme=1";
    # If there are *no* missing required fields, and the options *have*
    # been saved, that means we've completed everything that needs to be
    # done for the theme setup. So, *don't* return the fields_loop 
    # contents, and the "Theme Applied" completion message will show.
    if ( !$missing_required[0] && $app->param('saved') ) {
        $param->{fields_loop} = '';
    }
    $app->load_tmpl('theme_setup.mtml', $param);
}

sub update_menus {
    my $app = MT->instance;
    # We only want to remove the Templates menu at the blog-level. We don't
    # know for sure what templates are at the system-level, so just blanket
    # denying access is probably not best.
    my $blog_id = $app->param('blog_id');
    if ($blog_id) {
        # Any linked templates?
        use MT::Template;
        my $linked_tmpl = MT::Template->load(
                        { blog_id     => $blog_id,
                          linked_file => '*', });
        # If there are linked templates, then remove the Templates menu.
        if ($linked_tmpl) {
            my $core = MT->component('Core');
            delete $core->{registry}->{applications}->{cms}->{menus}->{'design:template'};
        }
    }
    # Now just add the Theme Options menu item.
    return {
        'design:theme_dashboard' => {
            label => 'Theme Dashboard',
            order => 1,
            mode  => 'theme_dashboard',
            view  => 'blog',
            permission => 'edit_templates',
        },
        'design:theme_options' => {
            label => 'Theme Options',
            order => '10',
            mode  => 'theme_options',
            view  => 'blog',
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
        }
    };
}

sub update_page_actions {
    # Override the blog-level "Refresh Blog Templates" page action, causing
    # a popup to start the theme selection process. We want to keep the
    # Refresh Blog Templates link because it's familiar at this point.
    return {
        'list_templates' => {
            refresh_all_blog_templates => {
                label     => "Refresh Blog Templates",
                dialog    => 'select_theme',
                condition => sub {
                    MT->app->blog,;
                },
                order => 1000,
            },
        }
    };
}

sub template_set_change {
    my ($cb, $param) = @_;
    my $blog_id = $param->{blog}->id;
    
    # Link the templates to the theme.
    use MT::Template;
    # Grab all of the templates except the Widget Sets, because the user
    # should be able to edit (drag-drop) those all the time.
    my $iter = MT::Template->load_iter({ blog_id => $blog_id });
    while ( my $tmpl = $iter->() ) {
        if ($tmpl->type ne 'widgetset') {
            $tmpl->linked_file('*');
        }
        else {
            # Just in case Widget Sets were previously linked,
            # now forcefully unlink!
            $tmpl->linked_file(undef);
        }
        $tmpl->save;
    }
}

sub _theme_thumbnail {
    # We want a custom thumbnail to display on the Theme Options About tab.
    my $app = MT->instance;
    my ($ts, $plugin) = @_;
    
    # Craft the destination path and URL.
    use File::Spec;
    my $dest_path = File::Spec->catfile( 
        $app->config('StaticFilePath'), 'support', 'plugins', 'ConfigAssistant', 
            'theme_thumbs', $app->blog->id.'.jpg' 
    );
    my $dest_url = $app->static_path.'support/plugins/ConfigAssistant/theme_thumbs/'.$app->blog->id.'.jpg';

    # Check if the thumbnail is cached (exists) and is less than 1 day old. 
    # If it's older, we want a new thumb to be created.
    if ( (-e $dest_path) && (-M $dest_path <= 1) ) {
        # We've found a cached image! No need to grab a new screenshot; just 
        # use the existing one.
        return '<img src="'.$dest_url.'" width="300" height="240" title="'
            .$app->blog->name.' on '.$app->blog->site_url.'" />';
    }
    else {
        # No screenshot was found, or it's too old--so create one.
        # First, create the destination directory, if necessary.
        my $dir = File::Spec->catfile( 
            $app->config('StaticFilePath'), 'support', 'plugins', 'ConfigAssistant', 
                'theme_thumbs' 
        );
        if (!-d $dir) {
            my $fmgr = MT::FileMgr->new('Local')
                or return MT::FileMgr->errstr;
            $fmgr->mkpath($dir)
                or return MT::FileMgr->errstr;
        }
        # Now build and cache the thumbnail URL
        # This is done with thumbalizr.com, a free online screenshot service.
        # Their API is completely http based, so this is all we need to do to
        # get an image from them.
        my $thumb_url = 'http://api.thumbalizr.com/?url='.$app->blog->site_url.'&width=300';
        use LWP::Simple;
        my $http_response = LWP::Simple::getstore($thumb_url, $dest_path);
        if ($http_response == 200) {
            # success!
            return '<img src="'.$dest_url.'" width="300" height="240" title="'
                .$app->blog->name.' on '.$app->blog->site_url.'" />';
        }
    }
}

sub paypal_donate {
    # Donating through PayPal requires a pop-up dialog so that we can break 
    # out of MT and the normal button handling. (That is, clicking a PayPal
    # button on Theme Options causes MT to try to save Theme Options, not 
    # launch the PayPal link. Creating a dialog breaks out of that
    # requirement.)
    my $app = MT->instance;
    my $param = {};
    $param->{theme_label}  = $app->param('theme_label');
    $param->{paypal_email} = $app->param('paypal_email');
    return $app->load_tmpl( 'paypal_donate.mtml', $param );
}

sub edit_templates {
    # Pop up the warning dialog about what it really means to "edit templates."
    my $app = shift;
    my $param->{blog_id} = $app->param('blog_id');
    return $app->load_tmpl( 'edit_templates.mtml', $param );
}

sub unlink_templates {
    # Unlink all templates.
    my $app = shift;
    my $blog_id = $app->param('blog_id');
    use MT::Template;
    my $iter = MT::Template->load_iter({ blog_id     => $blog_id,
                                         linked_file => '*', });
    while ( my $tmpl = $iter->() ) {
        $tmpl->linked_file(undef);
        $tmpl->linked_file_mtime(undef);
        $tmpl->linked_file_size(undef);
        $tmpl->save;
    }
    my $return_url = $app->uri.'?__mode=theme_dashboard&blog_id='.$blog_id
        .'&unlinked=1';
    my $param = { return_url => $return_url };
    return $app->load_tmpl( 'templates_unlinked.mtml', $param );
}

sub _apply_theme {
    my ($ts) = @_;
    my $app = MT->instance;

    # First, apply the theme.
    $app->param('template_set', $ts);
    $app->param('blog_id', $app->blog->id);
    
    return _refresh_all_templates($app);
}

sub _refresh_all_templates {
    # This is basically lifted right from MT::CMS::Template, with some
    # necessary changes to work with CA.
    my ($app) = @_;

    # refresh templates dialog uses a 'backup' field
    my $backup = 1;

    my $template_set = $app->param('template_set');
    my $refresh_type = 'clean';

    my $t = time;

    my @id;
    if ($app->param('blog_id')) {
        @id = ( scalar $app->param('blog_id') );
    }
    else {
        @id = $app->param('id');
        if (! @id) {
            # refresh global templates
            @id = ( 0 );
        }
    }

    require MT::Template;
    require MT::DefaultTemplates;
    require MT::Blog;
    require MT::Permission;
    require MT::Util;

    my $user = $app->user;
    my @blogs_not_refreshed;
    my $can_refresh_system = $user->is_superuser() ? 1 : 0;
    BLOG: for my $blog_id (@id) {
        my $blog;
        if ($blog_id) {
            $blog = MT::Blog->load($blog_id);
            next BLOG unless $blog;
        }

        if (!$can_refresh_system) {  # system refreshers can refresh all blogs
            my $perms = MT::Permission->load(
                { blog_id => $blog_id, author_id => $user->id } );
            my $can_refresh_blog = !$perms                       ? 0
                                 : $perms->can_edit_templates()  ? 1
                                 : $perms->can_administer_blog() ? 1
                                 :                                 0
                                 ;
            if (!$can_refresh_blog) {
                push @blogs_not_refreshed, $blog->id;
                next BLOG;
            }
        }

        my $tmpl_list;

        if ($refresh_type eq 'clean') {
            # the user wants to back up all templates and
            # install the new ones

            my @ts = MT::Util::offset_time_list( $t, $blog_id );
            my $ts = sprintf "%04d-%02d-%02d %02d:%02d:%02d",
                $ts[5] + 1900, $ts[4] + 1, @ts[ 3, 2, 1, 0 ];

            # Backup/delete all the existing templates.
            my $tmpl_iter = MT::Template->load_iter({
                blog_id => $blog_id,
                type => { not => 'backup' },
            });
            while (my $tmpl = $tmpl_iter->()) {
                if ($backup) {
                    # zap all template maps
                    require MT::TemplateMap;
                    MT::TemplateMap->remove({
                        template_id => $tmpl->id,
                    });
                    $tmpl->name( $tmpl->name
                            . ' (Backup from '
                            . $ts . ') '
                            . $tmpl->type );
                    $tmpl->type('backup');
                    $tmpl->identifier(undef);
                    $tmpl->rebuild_me(0);
                    $tmpl->linked_file(undef);
                    $tmpl->outfile('');
                    $tmpl->save;
                } else {
                    $tmpl->remove;
                }
            }

            if ($blog_id) {
                # Create the default templates and mappings for the selected
                # set here, instead of below.
                $blog->create_default_templates( $template_set ||
                    $blog->template_set || 'mt_blog' );

                if ($template_set) {
                    $blog->template_set( $template_set );
                    $blog->save;
                    $app->run_callbacks( 'blog_template_set_change', { blog => $blog } );
                }

                next BLOG;
            }
        }
    }
    if (@blogs_not_refreshed) {
        # Failed!
        return 0;
    }
    # Success!
    return 1;
}

sub xfrm_disable_tmpl_link {
    # If templates are linked, we don't want users to be able to simply unlink
    # them, because that "breaks the seal" and lets them modify the template,
    # so upgrades are no longer easy. 
    my ($cb, $app, $tmpl) = @_;
    use MT::Template;
    my $linked = MT::Template->load(
                        { blog_id     => $app->blog->id,
                          linked_file => '*', });
    if ($linked) {
        my $old = 'name="linked_file"';
        my $new = 'name="linked_file" disabled="disabled"';
        $$tmpl =~ s/$old/$new/mgi;
        
        $old = 'name="outfile"';
        $new = 'name="outfile" disabled="disabled"';
        $$tmpl =~ s/$old/$new/mgi;

        $old = 'name="identifier"';
        $new = 'name="identifier" disabled="disabled"';
        $$tmpl =~ s/$old/$new/mgi;
    }
}

sub _theme_check {
    # We need to store templates in the DB so that we can do the
    # $app->listing thing to build the page.
    
    # Look through all the plugins and find the template sets.
    for my $sig ( keys %MT::Plugins ) {
        my $plugin = $MT::Plugins{$sig};
        my $obj    = $MT::Plugins{$sig}{object};
        my $r      = $obj->{registry};
        my @sets   = keys %{ $r->{'template_sets'} };
        foreach my $set (@sets) {
            # Has this theme already been saved?
            my $theme = ConfigAssistant::Theme->load({
                    ts_id      => $set,
                    plugin_sig => $sig,
                });
            if (!$theme) {
                # Not saved, so save it.
                $theme = ConfigAssistant::Theme->new();
                $theme->plugin_sig( $sig );
                $theme->ts_id( $set );
                $theme->ts_label( _theme_label($set, $obj) );
                $theme->ts_desc(  _theme_description($set, $obj) );
                $theme->save;
            }
        }
    }
    # Should we delete any themes from the db?
    my $iter = ConfigAssistant::Theme->load_iter({},{sort_by => 'ts_id',});
    while (my $theme = $iter->()) {
        # Use the plugin sig to grab the plugin.
        my $plugin = $MT::Plugins{$theme->plugin_sig}->{object};
        if (!$plugin) {
            # This plugin couldn't be loaded! That must mean the theme has 
            # been uninstalled, so remove the entry in the table.
            $theme->remove;
            $theme->save;
            next;
        }
        else {
            if (!$plugin->{registry}->{'template_sets'}->{$theme->ts_id}) {
                # This template set couldn't be loaded! That must mean the theme
                # has been uninstalled, so remove the entry in the table.
                $theme->remove;
                $theme->save;
                next;
            }
        }
    }
}

1;

__END__
