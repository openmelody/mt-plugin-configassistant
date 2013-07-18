package ConfigAssistant::Plugin;

use strict;
use warnings;
use Carp qw( croak );
use MT::Util
  qw( relative_date      offset_time    offset_time_list    epoch2ts
      ts2epoch format_ts encode_html    decode_html         dirify );
use ConfigAssistant::Util
  qw( find_theme_plugin     find_template_def   find_option_def
      find_option_plugin    process_file_upload 
      plugin_static_web_path plugin_static_file_path );
use JSON;
# use MT::Log::Log4perl qw( l4mtdump ); use Log::Log4perl qw( :resurrect );
our $logger;

sub tag_plugin_static_web_path {
    my ( $ctx, $args, $cond ) = @_;
    my $sig = $args->{'component'};
    my $obj = MT->component($sig);
    if ( !$obj ) {
        return
          $ctx->error(
            MT->translate(
                  "The plugin you specified '[_2]' in '[_1]' "
                . "could not be found.",
                $ctx->stash('tag'),
                $sig
            )
          );
    }
    elsif ( $obj->registry('static_version') ) {
        return plugin_static_web_path($obj);
    }
    else {

        # TODO - perhaps this should default to: mt-static/plugins/$sig?
        return
          $ctx->error(
            MT->translate(
                  "The plugin you specified '[_2]' in '[_1]' has not"
                . "registered a static directory. Please use "
                . "<mt:StaticWebPath> instead.",
                $ctx->stash('tag'),
                $sig
            )
          );
    }
} ## end sub tag_plugin_static_web_path

sub tag_plugin_static_file_path {
    my ( $ctx, $args, $cond ) = @_;
    my $sig = $args->{'component'};
    my $obj = MT->component($sig);
    if ( !$obj ) {
        return
          $ctx->error(
            MT->translate(
                 "The plugin you specified '[_2]' in '[_1]' "
                . "could not be found.",
                $ctx->stash('tag'),
                $sig
            )
          );
    }
    elsif ( $obj->registry('static_version') ) {
        return plugin_static_file_path($obj);
    }
    else {
        return
          $ctx->error(
            MT->translate(
                  "The plugin you specified in '[_1]' has not "
                . "registered a static directory. Please use "
                . "<mt:StaticFilePath> instead.",
                $_[0]->stash('tag')
            )
          );
    }
} ## end sub tag_plugin_static_file_path

sub theme_options {
    my $app     = shift;
    my ($param) = @_;
    my $q       = $app->can('query') ? $app->query : $app->param;
    my $blog    = $app->blog;
    
    # No blog was found, so this must be the system level. Just go to the
    # System Dashboard.
    if (!$blog) {
        return $app->redirect( $app->mt_uri . '?__mode=dashboard&blog_id=0' );
    }

    $param ||= {};

    my $ts     = $blog->template_set;
    my $plugin = find_theme_plugin($ts);
    my $cfg    = $app->registry('template_sets')->{$ts}->{options};

    # If there are no Theme Options in the selected blog, we need to redirect
    # the user. (They could have gotten here by jumping from a blog with Theme
    # Options to a blog without Theme Options.)
    if ( !$cfg ) {

        # If the Theme Manager plugin is installed, redirect to the Theme
        # Dashboard. Otherwise, just redirect to the Blog Dashboard.
        my $redirect;
        my $plugin_tm = MT->component('ThemeManager');
        if ($plugin_tm) {
            $redirect
              = $app->mt_uri . '?__mode=theme_dashboard&blog_id=' . $blog->id;
        }
        else {
            $redirect
              = $app->mt_uri . '?__mode=dashboard&blog_id=' . $blog->id;
        }
        return $app->redirect($redirect);
    }

    my $result = _build_options_screen({
        cfg          => $cfg,
        blog         => $blog,
        plugin       => $plugin,
        options_type => 'theme',
    });

    $param->{html}             = $result->{html};
    $param->{fieldsets}        = $result->{loop};
    $param->{leftovers}        = $result->{leftovers};
    $param->{missing_required} = $result->{missing_required};

    $param->{blog_id}          = $blog->id;
    $param->{plugin_sig}       = $plugin->{plugin_sig};
    $param->{saved}            = $q->param('saved');
    return $app->load_tmpl( 'theme_options.mtml', $param );
} ## end sub theme_options

# Code for this method taken from MT::CMS::Plugin
sub save_config {
    my $app        = shift;
    my $q          = $app->can('query') ? $app->query : $app->param;
    my $plugin_sig = $q->param('plugin_sig');
    my $profile    = $MT::Plugins{$plugin_sig};
    my $blog_id    = $q->param('blog_id');
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();

    # this should not break out anymore, except for theme settings
    #return unless $blog_id; # this works in blog-context, no sys. plugin cfg
    $app->blog( MT->model('blog')->load($blog_id) ) if $blog_id;

    $app->validate_magic or return;
    return $app->errtrans("Permission denied.")
      unless $app->user->can_manage_plugins
          or (     $blog_id
               and $app->user->permissions($blog_id)->can_edit_templates );

    my $param;
    my @params = $q->param;
    foreach (@params) {
        next
          if $_ =~ m/^(__mode|return_args|plugin_sig|magic_token|blog_id)$/;
        my @vals = $q->param($_);
        if ( $#vals > 0 ) {

            # TODO - should this join items together?
            $param->{$_} = \@vals;
        }
        else {
            $param->{$_} = $vals[0];
        }
    }
    if ( $profile && $profile->{object} ) {
        my $plugin = $profile->{object};
        $plugin->error(undef);
        my $scope = $blog_id ? 'blog:' . $blog_id : 'system';

        #        $plugin->save_config( \%param, $scope );

        # BEGIN - contents of MT::Plugin->save_config
        my $pdata = $plugin->get_config_obj($scope);
        $scope =~ s/:.*//;
        my $data = $pdata->data() || {};

        my $repub_queue;
        my $plugin_changed = 0;

        my @vars = $plugin->config_vars($scope);
        foreach my $var (@vars) {
            my $opt = find_option_def( $app, $var );
            ###l4p $logger->debug( '$opt and var: ',
            ###l4p                 l4mtdump( { opt => $opt, var => $var } ) );

            # TODO - this should be pluggable. Field types should register a pre_save handler
            #        or something
            if ( $opt->{type} eq 'checkbox' ) {
                if ( ref( $param->{$var} ) ne 'ARRAY' && $opt->{'values'} ) {
                    $param->{$var} = [ $param->{$var} ]
                      ;    # Could this be a leak or be weakened?
                }
            }
            if ( $opt->{type} eq 'file' ) {
                my $scope = $opt->{scope} || 'support';
                my $result = process_file_upload( $app, $var, $scope,
                                                  $opt->{destination} );
                if ( $result->{status} == ConfigAssistant::Util::ERROR() ) {
                    return $app->error(
                              "Error uploading file: " . $result->{message} );
                } elsif ( $result->{status} == ConfigAssistant::Util::NO_UPLOAD ) {
                    if ($param->{$var.'-clear'} && $data->{$var}) {
                        my $old = MT->model('asset')->load( $data->{$var} );
                        $old->remove if $old;
                        $param->{$var} = undef;
                    }
                    else {
                        
                        # The user hasn't changed the file--keep it.
                        $param->{$var} = $data->{$var};
                    }
                } else {
                    if ( $data->{$var} ) {
                        my $old = MT->model('asset')->load( $data->{$var} );
                        $old->remove if $old;
                    }
                    $param->{$var} = $result->{asset}->{id};
                }
            }
            my $old = $data->{$var};
            my $new = $param->{$var};
            my $has_changed 
              = ( defined $new and !defined $old )
              || ( defined $old && !defined $new )
              || ( defined $new and $old ne $new );
            ###l4p $logger->debug('$has_changed: '.$has_changed);

            # If the field data has changed, and if the field uses the 
            # "republish" key, we want to republish the specified templates.
            # Add the specified templates to $repub_queue so that they can
            # be republished later.
            if ( $has_changed && $opt && $opt->{'republish'} ) {
                foreach ( split( ',', $opt->{'republish'} ) ) {
                    $repub_queue->{$_} = 1;
                }
            }
            $data->{$var} = $new ? $new : undef;
            if ($has_changed) {
                $opt->{'basename'} = $var;
                #MT->log("Triggering: " . 'options_change.option.' . $var );
                $app->run_callbacks( 'options_change.option.' . $var,
                                     $app, $opt, $old, $new );
                $app->run_callbacks( 'options_change.option.*',
                                     $app, $opt, $old, $new );
                $plugin_changed = 1;
            }
        } ## end foreach my $var (@vars)
        if ($plugin_changed) {

            #MT->log("Triggering: ".'options_change.plugin.' . $plugin->id );
            $app->run_callbacks( 'options_change.plugin.' . $plugin->id,
                                 $app, $plugin );
        }

        # Set the data and save it. This must be done before trying to
        # republish because the new selections the user made are not available
        # until the data is saved.
        $pdata->data($data);
        MT->request( 'plugin_config.' . $plugin->id, undef );
        $pdata->save() or die $pdata->errstr;

        # Index templates that have been flagged should be republished.
        use MT::WeblogPublisher;
        foreach ( keys %$repub_queue ) {
            _republish_template({
                tmpl_identifier => $_,
                blog_id         => $blog_id,
                app             => $app,
            });
        }

        # END - contents of MT::Plugin->save_config

        if ( $plugin->errstr ) {
            return $app->error(
                         "Error saving plugin settings: " . $plugin->errstr );
        }
    } ## end if ( $profile && $profile...)

    $app->add_return_arg( saved => $profile->{object}->id );
    $app->call_return;
} ## end sub save_config

# When saving Theme Options, a template may have been flagged to be
# republished. If the specified template identifier refers to an index
# template, republish it. If the identifier refers to an archive template
# (Entry, Page, Category, etc) then we should republish the most recent item
# in that archive.
sub _republish_template {
    my ($arg_ref) = @_;
    my $tmpl_identifier = $arg_ref->{tmpl_identifier};
    my $blog_id         = $arg_ref->{blog_id};
    my $app             = $arg_ref->{app};

    my $tmpl = MT->model('template')->load({
        blog_id    => $blog_id,
        identifier => $_,
    });

    if (!$tmpl) {
        MT->log({
            blog_id => $blog_id,
            level   => MT->model('log')->WARNING(),
            message => "Config Assistant could not find a template with "
                . "the identifier $tmpl_identifier.",
        });
        return;
    }

    # Different template types are handled differently. Save the $result of
    # publishing so that the Activity Log can be updated about the status.
    my $result;
    # This is an index template; just force republish it.
    if ($tmpl->type eq 'index') {
        $result = $app->rebuild_indexes(
            BlogID   => $blog_id,
            Template => $tmpl,
            Force    => 1,
        );
    }
    # Rebuild an archive template.
    elsif ($tmpl->type eq 'archive') {
        # Use the template to look up the template map to determine exactly
        # what kind of archive this is.
        my $tmpl_map = MT->model('templatemap')->load({
            template_id => $tmpl->id,
        });
        if (!$tmpl_map) {
            MT->log({
                blog_id => $blog_id,
                level   => MT->model('log')->WARNING(),
                message => "Config Assistant could not find a template map "
                    . "configured to use the template $tmpl_identifier.",
            });
            return;
        }

        # The template map exists so go ahead and republish. The `Limit` key
        # is used to only republish the most recent entry/page. For a
        # well-built site this should be enough: republishing the most recent
        # entry should trigger MultiBlog or a cached/included module to be
        # refreshed.
        $result = $app->rebuild(
            BlogID      => $blog_id,
            ArchiveType => $tmpl_map->archive_type,
            Limit       => 1, # Only limits entries.
            NoIndexes   => 1,
        );
    }

    # Report on the success/failure of the template republishing.
    my ($message, $level);
    if ($result) {
        $level   = MT->model('log')->INFO();
        $message = "Config Assistant is republishing " . $tmpl->type
            . " template " . $tmpl->name . '.';
    }
    else {
        $level   = MT->model('log')->ERROR;
        $message = "Config Assistant could not republish " . $tmpl->type
            . " template " . $tmpl->name . '.';
    }
    MT->log({
        blog_id => $blog_id,
        level   => $level,
        message => $message,
    });
}

sub _hdlr_field_value {
    my $plugin = shift;
    my ( $ctx, $args ) = @_;
    my $field = $ctx->stash('config_type') or return _no_field($ctx);
    my $value = _get_field_value($ctx);
    return $args->{default}
      if ( $args->{default} && ( !$value || $value eq '' ) );

    # If any MT templating is in the field, process it.
    my $builder = $ctx->stash('builder');
    my $tokens = $builder->compile( $ctx, $value );
    return $ctx->error( $builder->errstr ) unless defined $tokens;
    my $out = $builder->build( $ctx, $tokens );
    return $ctx->error( $builder->errstr ) unless defined $out;
    return $out;
}

sub _hdlr_field_asset {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field = $ctx->stash('config_type') or return _no_field($ctx);
    my $value = _get_field_value($ctx);
    return if !$value || $value eq '';
    my $asset = MT->model('asset')->load($value);
    my $out;
    if ($asset) {
        local $ctx->{'__stash'}->{'asset'} = $asset;
        defined( $out = $ctx->slurp( $args, $cond ) ) or return;
        return $out;
    }
    else {
        require MT::Template::ContextHandlers;
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }
}

# The block tag handler for the Entry or Page field type.
sub _hdlr_field_entry_loop {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field = $ctx->stash('config_type') or return _no_field($ctx);
    my $value  = _get_field_value($ctx);
    unless ( $value ) {
        require MT::Template::ContextHandlers;
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }

    # The value contains both active and inactive entries. We want the
    # active ones, because the inactive ones aren't supposed to get 
    # published. The format is, for example: `active:1,2,5;inactive:3,4,6`
    ( my $active_ids = $value ) =~ s{active:([^;]+).*}{$1};
    my @ids                     =  split( ',', $active_ids );

    my $out   = '';
    my $count = 0;
    my $lastn = $args->{'lastn'} || 0;
    my $vars  = $ctx->{__stash}{vars};
    foreach my $id (@ids) {
        $count++;
        my $entry = MT->model('entry')->load($id);
        local $ctx->{'__stash'}->{'entry'} = $entry;
        local $vars->{'__first__'}         = ( $count == 1 );
        local $vars->{'__last__'}
            = ( $lastn == $count || $count == scalar @ids );
        defined( $out .= $ctx->slurp( $args, $cond ) ) or return;
        last if ( $lastn == $count );
    }
    return $out;
} ## end sub _hdlr_field_array_loop

# The function tag handler for the Entry or Page field type. This overrides
# the default _hdlr_field_value method's results.
sub _hdlr_field_value_entry {
    my $plugin = shift;
    my ( $ctx, $args ) = @_;
    my $field = $ctx->stash('config_type') or return _no_field($ctx);
    my $value = _get_field_value($ctx);
    return $args->{default}
      if ( $args->{default} && ( !$value || $value eq '' ) );

    # The value contains both active and inactive entries. We only want the
    # active ones, because the inactive ones aren't supposed to get published.
    # The format is, for example: `active:1,2,5;inactive:3,4,6`
    my ($active_ids,$inactive_ids) = split(';', $value);
    if ($active_ids) {
        $active_ids =~ s/active://; # Strip the leading identifier
        $value = $active_ids;
    }

    return $value;
}


sub _hdlr_field_array_loop {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field  = $ctx->stash('config_type') or return _no_field($ctx);
    my $values = _get_field_value($ctx);
    my $out    = '';
    my $count  = 0;
    if ( @$values > 0 ) {
        my $vars = $ctx->{__stash}{vars};
        foreach (@$values) {
            local $vars->{'value'}     = $_;
            local $vars->{'__first__'} = ( $count++ == 0 );
            local $vars->{'__last__'}  = ( $count == @$values );
            defined( $out .= $ctx->slurp( $args, $cond ) ) or return;
        }
        return $out;
    }
    else {
        require MT::Template::ContextHandlers;
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }
} ## end sub _hdlr_field_array_loop

sub _hdlr_field_array_contains {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $field = $ctx->stash('config_type') or return _no_field($ctx);
    my $value = $args->{'value'};
    my $array = _get_field_value($ctx);
    ###l4p require Carp; (ref $array eq 'ARRAY') or $logger->warn('_get_field_value did not return an array reference: '.($array||'')." ".Carp::longmess());
    return $ctx->slurp( $args, $cond )
        if grep { defined($_) && $_ eq $value } @$array;

    require MT::Template::ContextHandlers;
    return MT::Template::Context::_hdlr_pass_tokens_else(@_);
}

sub _hdlr_field_category_list {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field = $ctx->stash('config_type') or return _no_field($ctx);
    my $value = _get_field_value($ctx);
    my @ids = ref($value) eq 'ARRAY' ? @$value : ($value);
    my $class = $ctx->stash('obj_class');

    my @categories = MT->model($class)->load( { id => \@ids } );
    my $out        = '';
    my $vars       = $ctx->{__stash}{vars};
    my $glue       = $args->{glue};
    for ( my $index = 0; $index <= $#categories; $index++ ) {

        local $vars->{__first__} = $index == 0;
        local $vars->{__last__}  = $index == $#categories;
        local $vars->{__odd__}   = $index % 2 == 1;
        local $vars->{__even__}  = $index % 2 == 0;
        local $vars->{__index__} = $index;
        local $vars->{__size__}  = scalar(@categories);

        $ctx->stash( 'category', $categories[$index] );
        $out .= $ctx->slurp( $args, $cond )
          . ( $glue && $index < $#categories ? $glue : '' );
    }
    return $out;
} ## end sub _hdlr_field_category_list

sub _hdlr_field_datetime {
    my $plugin = shift;
    my ($ctx, $args, $cond) = @_;
    my $field = $ctx->stash('config_type') or return _no_field($ctx);
    my $value = _get_field_value($ctx);

    my @pieces = split(/[\s]/, $value);
    my @date = split('/', $pieces[0]);
    $pieces[1] =~ s/\://g;
    $value = sprintf('%s%s%s%s%s%s', $date[2], $date[0], $date[1], $pieces[1]); 

    $args->{ts} = $value;
    my $processed_value = MT::Template::Context::_hdlr_date($ctx, $args);
    return $processed_value;
}

sub _get_field_value {
    my ($ctx) = @_;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $plugin_ns = $ctx->stash('plugin_ns');
    my $scope     = $ctx->stash('scope') || 'blog';
    my $field     = $ctx->stash('config_type');
 
    my $plugin    = MT->component($plugin_ns);        # is this necessary?
    my $value;
    my $blog = $ctx->stash('blog');
    if ( !$blog ) {
        my $blog_id = $ctx->var('blog_id');
        $blog = MT->model('blog')->load($blog_id);
    }
    if ( $blog && $blog->id && $scope eq 'blog' ) {
        $value = $plugin->get_config_value( $field, 'blog:' . $blog->id )
            || '';
    }
    else {
        $value = $plugin->get_config_value($field) || '';
    }
    ###l4p $logger->debug('$value: ', l4mtdump($value));
    return $value;
} ## end sub _get_field_value

sub _hdlr_field_link_group {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field = $ctx->stash('config_type') or return _no_field($ctx);
    my $value = _get_field_value($ctx);
    $value = '"[]"' if ( !$value || $value eq '' );
    eval "\$value = \"$value\"";
    if ($@) { $value = '[]'; }
    my $list = JSON::from_json($value);

    if ( @$list > 0 ) {
        my $out   = '';
        my $vars  = $ctx->{__stash}{vars};
        my $count = 0;
        foreach (@$list) {
            local $vars->{'link_label'} = $_->{'label'};
            local $vars->{'link_url'}   = $_->{'url'};
            local $vars->{'__first__'}  = ( $count++ == 0 );
            local $vars->{'__last__'}   = ( $count == @$list );
            defined( $out .= $ctx->slurp( $args, $cond ) ) or return;
        }
        return $out;
    }
    else {
        require MT::Template::ContextHandlers;
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }
} ## end sub _hdlr_field_link_group

sub _hdlr_field_text_group {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field = $ctx->stash('config_type') or return _no_field($ctx);
    my $value = _get_field_value($ctx);
    $value = '"[]"' if ( !$value || $value eq '' );
    eval "\$value = \"$value\"";
    if ($@) { $value = '[]'; }
    my $list = JSON::from_json($value);

    if ( @$list > 0 ) {
        my $out   = '';
        my $vars  = $ctx->{__stash}{vars};
        my $count = 0;
        foreach (@$list) {
            local $vars->{'label'} = $_->{'label'};
            local $vars->{'__first__'}  = ( $count++ == 0 );
            local $vars->{'__last__'}   = ( $count == @$list );
            defined( $out .= $ctx->slurp( $args, $cond ) ) or return;
        }
        return $out;
    }
    else {
        require MT::Template::ContextHandlers;
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }
} ## end sub _hdlr_field_text_group

sub _hdlr_field_cond {
    my $plugin = shift;
    my ( $ctx, $args ) = @_;
    my $plugin_ns = $ctx->stash('plugin_ns');
    my $scope     = $ctx->stash('scope') || 'blog';
    my $field     = $ctx->stash('config_type') or return _no_field($ctx);

    my $blog = $ctx->stash('blog');
    if ( !$blog ) {
        my $blog_id = $ctx->var('blog_id');
        $blog = MT->model('blog')->load($blog_id);
    }
    $plugin = MT->component($plugin_ns);    # load the theme plugin
    my $value;
    if ( $blog && $blog->id && $scope eq 'blog' ) {
        $value = $plugin->get_config_value( $field, 'blog:' . $blog->id );
    }
    else {
        $value = $plugin->get_config_value($field);
    }
    if ($value) {
        return $ctx->_hdlr_pass_tokens(@_);
    }
    else {
        return $ctx->_hdlr_pass_tokens_else(@_);
    }
} ## end sub _hdlr_field_cond

sub _no_field {
    return
      $_[0]->error(
        MT->translate(
            "You used an '[_1]' tag outside of the context of the correct content; ",
            $_[0]->stash('tag')
        )
      );
}

sub plugin_options {
    my $plugin = shift;
    my ( $param, $scope ) = @_;

    my $app = MT->app;
    my $blog;
    if ( $scope =~ /blog:(\d+)/ ) {
        $blog = MT->model('blog')->load($1);
    }

    $param = {};

    my $html = '';
    my $cfg  = $plugin->registry('options');
    my $seen;

    my $result = _build_options_screen({
        cfg          => $cfg,
        blog         => $blog,
        plugin       => $plugin,
        options_type => 'plugin',
    });

    $param->{html}             = $result->{html};
    $param->{fieldsets}        = $result->{loop};
    $param->{leftovers}        = $result->{leftovers};
    $param->{missing_required} = $result->{missing_required};

    $param->{blog_id}     = $blog->id if $blog;
    $param->{magic_token} = $app->current_magic;
    $param->{plugin_sig}  = $plugin->{plugin_sig};

    return MT->component('ConfigAssistant')
      ->load_tmpl( 'plugin_options.mtml', $param );
} ## end sub plugin_options


# The Theme Options and Plugin Options screen both display fields in the same
# format.
sub _build_options_screen {
    my ($arg_ref) = @_;
    my $cfg          = $arg_ref->{cfg};
    my $blog         = $arg_ref->{blog};
    my $plugin       = $arg_ref->{plugin};
    my $options_type = $arg_ref->{options_type};
    my $app = MT->instance;

    my $types     = $app->registry('config_types');
    my $fieldsets = $cfg->{fieldsets};
    $fieldsets->{__global} = {
        label => sub { "Global Options"; }
    };

    # Get any saved field settings.
    my $cfg_obj = {};
    if ( $options_type eq 'plugin') {
        # Plugin Options can be for either the blog or system level, so
        # determine current scope.
        my $scope = $blog
            ? 'blog:' . $blog->id
            : 'system';
        $cfg_obj = $plugin->get_config_hash($scope);
    }
    # Theme Options
    else { 
        $cfg_obj = eval { $plugin->get_config_hash('blog:' . $blog->id) };
    }

    require MT::Template::Context;
    my $ctx = MT::Template::Context->new();

    # this is a localized stash for field HTML
    my $fields;
    my @missing_required;

    foreach my $optname (
        sort {
            ( $cfg->{$a}->{order} || 999 ) <=> ( $cfg->{$b}->{order} || 999 )
        } keys %{$cfg}
      )
    {
        next if $optname eq 'fieldsets' || $optname eq 'plugin';

        my $field = $cfg->{$optname};
        if ( my $cond = $field->{condition} ) {
            if ( !ref($cond) ) {
                $cond = $field->{condition} = $app->handler_to_coderef($cond);
            }
            next unless $cond->();
        }
        if ( !$field->{'type'} ) {
            $app->log( {
                   blog_id => $blog->id,
                   level   => MT::Log::WARNING(),
                   message =>
                     "Skipping option '$optname' in "
                     . $options_type eq 'plugin'
                         ? 'plugin settings '
                         : 'template set "' . $blog->template_set . '" '
                     . "because it did not declare a type."
                }
            );
            next;
        }

        my $field_id;
        if ( $options_type eq 'plugin' ) {
            $field_id = $optname;
        }
        else {
            $field_id = $blog->template_set . '_' . $optname;
        }

        # The separator "type" is handled specially here because it's not
        # really a "config type" -- it isn't editable and no data is saved
        # or retrieved. It just displays a separator and some info.
        if ( $field->{'type'} eq 'separator' ) {

            my $out;
            my $show_label
              = defined $field->{show_label} ? $field->{show_label} : 1;
            my $label = $field->{label} && ($field->{label} ne '')
                ? &{ $field->{label} } : '';
            $out
              .= '  <div id="field-'
              . $field_id
              . '" class="field field-top-label pkg field-type-'
              . $field->{type} . '">' . "\n";
            $out .= "    <div class=\"field-header\">\n";
            $out .= "        <h3>$label</h3>\n" if $show_label;
            $out .= "    </div>\n";
            $out .= "    <div class=\"field-content\">\n";

            if ( $field->{hint} ) {
                my $hint = MT->product_version =~ /^4/
                    ? $field->{hint}
                    : &{ $field->{hint} }; # MT5+
                $out .= "       <div>$hint</div>\n";
            }
            $out .= "    </div>\n";
            $out .= "  </div>\n";
            $field->{fieldset} = '__global' unless defined $field->{fieldset};
            my $fs = $field->{fieldset};
            push @{ $fields->{$fs} }, $out;
        } ## end if ( $field->{'type'} ...)

        elsif ( $types->{ $field->{'type'} } ) {
            my $value = delete $cfg_obj->{$field_id};
            my $out;
            $field->{fieldset} = '__global' unless defined $field->{fieldset};
            my $show_label
                = defined $field->{show_label} ? &{ $field->{show_label} } : 1;
            my $label = $field->{label} ne '' ? &{ $field->{label} } : '';
            my $required = $field->{required} ? 'required' : '';
            if ($required) {
                # There is no value for this field, and it's a required field,
                # so we need to tell the user to fix it!
                if ( !$value ) {
                    push @missing_required, { label => $label };
                }

                # Append the required flag.
                $label .= ' <span class="required-flag">*</span>';
            }

            $out
                .= "  <div id=\"field-$field_id\" class=\"field"
                . ( $show_label == 1 ? " field-left-label" : "" )
                . ' pkg field-type-'
                . $field->{type} . ' '
                . $required . '">' . "\n";
            $out .= "    <div class=\"field-header\">\n";
            $out .= "      <label for=\"$field_id\">$label</label>\n"
                if $show_label;
            $out .= "    </div>\n";
            $out .= "    <div class=\"field-content\">\n";
            my $hdlr = MT->handler_to_coderef(
                                    $types->{ $field->{'type'} }->{handler} );
            $out .= $hdlr->( $app, $ctx, $field_id, $field, $value );

            if ( $field->{hint} ) {
                my $hint = MT->product_version =~ /^4/
                    ? $field->{hint}
                    : &{ $field->{hint} }; # MT5+
                $out .= "      <div class=\"hint\">$hint</div>\n";
            }
            $out .= "    </div>\n";
            $out .= "  </div>\n";
            my $fs = $field->{fieldset};
            push @{ $fields->{$fs} }, $out;
        } ## end elsif ( $types->{ $field->...})
    } ## end foreach my $optname ( sort ...)

    my @loop;
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
        my $label     = &{ $fieldsets->{$set}->{label} };
        my $hint      = $fieldsets->{$set}->{hint};
        my $innerhtml = '';
        if ( my $tmpl = $fieldsets->{$set}->{template} ) {
            my $txt = $plugin->load_tmpl($tmpl);
            my $filter
              = $fieldsets->{$set}->{format}
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
            hint        => $hint,
            content     => $innerhtml,
          };
    } ## end foreach my $set ( sort { ( ...)})
    my @leftovers;
    foreach my $field_id ( keys %$cfg_obj ) {
        push @leftovers,
          { name => $field_id, value => $cfg_obj->{$field_id}, };
    }

    # Return the built options screen -- ready for either the Theme Options or
    # Plugin Options display.
    return {
        html             => $html,
        loop             => \@loop,
        leftovers        => \@leftovers,
        missing_required => \@missing_required,
    };
}

sub list_entry_mini {
    my $app = shift;
    my $q = $app->can('query') ? $app->query : $app->param;

    my $blog_id  = $q->param('blog_id') || 0;
    my $obj_type = $q->param('class')   || 'entry';
    my $pkg      = $app->model($obj_type)
      or return "Invalid request: unknown class $obj_type";

    my $terms;
    $terms->{class} = $obj_type;
    $terms->{blog_id} = $blog_id if $blog_id;
    $terms->{status} = 2 if $obj_type eq 'entry' || $obj_type eq 'page';

    my %args = ( sort => 'authored_on', direction => 'descend', );

    my $plugin = MT->component('ConfigAssistant')
      or die "OMG NO COMPONENT!?!";

    my $tmpl = $plugin->load_tmpl('entry_list.mtml');
    $tmpl->param('entry_class_labelp', $pkg->class_label_plural);
    $tmpl->param('entry_class_label', $pkg->class_label);
    $tmpl->param('obj_type', $obj_type);
    return $app->listing( {
           type     => $obj_type,
           template => $tmpl,
           params   => {
               panel_searchable => 1,
               edit_blog_id     => $blog_id,
               edit_field       => $q->param('edit_field'),
               search           => $q->param('search'),
               blog_id          => $blog_id,
               class            => $obj_type,
           },
           code => sub {
               my ( $obj, $row ) = @_;
               $row->{ 'status_' . lc MT::Entry::status_text( $obj->status ) }
                 = 1;
               $row->{entry_permalink} = $obj->permalink
                 if $obj->status == MT->model('entry')->RELEASE();
               if ( my $ts = $obj->authored_on ) {
                   my $date_format = MT::App::CMS->LISTING_DATE_FORMAT();
                   my $datetime_format
                     = MT::App::CMS->LISTING_DATETIME_FORMAT();
                   $row->{created_on_formatted}
                     = format_ts( $date_format, $ts, $obj->blog,
                        $app->user ? $app->user->preferred_language : undef );
                   $row->{created_on_time_formatted}
                     = format_ts( $datetime_format, $ts, $obj->blog,
                        $app->user ? $app->user->preferred_language : undef );
                   $row->{created_on_relative}
                     = relative_date( $ts, time, $obj->blog );
                   my $author = MT->model('author')->load( $obj->author_id );
                   $row->{author_name} = $author ? $author->nickname : '';
               }
               return $row;
           },
           terms => $terms,
           args  => \%args,
        }
    );
} ## end sub list_entry_mini

sub select_entry {
    my $app = shift;
    my $q = $app->can('query') ? $app->query : $app->param;

    my $class = $q->param('class') || 'entry';
    my $obj_id = $q->param('id') or return $app->errtrans('No id');
    my $obj = MT->model($class)->load($obj_id)
      or return $app->errtrans( 'No entry #[_1]', $obj_id );
    my $edit_field = $q->param('edit_field')
      or return $app->errtrans('No edit_field');

    my $plugin = MT->component('ConfigAssistant')
      or die "OMG NO COMPONENT!?!";
    my $tmpl = $plugin->load_tmpl(
                                   'select_entry.mtml',
                                   {
                                      entry_class     => $class,
                                      entry_id        => $obj->id,
                                      entry_title     => $obj->title,
                                      entry_permalink => $obj->permalink,
                                      entry_blog_id   => $obj->blog_id,
                                      edit_field      => $edit_field,
                                   }
    );
    return $tmpl;
} ## end sub select_entry

sub list_entry_or_page {
    my $app      = shift;
    my $blog_ids = $app->param('blog_ids');
    my $type     = 'entry';
    my $pkg      = $app->model($type) or return "Invalid request.";

    my %terms = (
        status => MT->model('entry')->RELEASE(),
        class  => '*',
    );

    my @blog_ids;
    if ( $blog_ids == 'all' ) {

        # @blog_ids should stay empty so all blogs are loaded.
    }
    else {

        # Turn this into an array so that all specified blogs can be loaded.
        @blog_ids = split( /,/, $blog_ids );
        $terms{blog_id} = [@blog_ids];
    }

    my %args = (
        sort      => 'authored_on',
        direction => 'descend',
    );

    my $plugin = MT->component('ConfigAssistant')
      or die "OMG NO COMPONENT!?!";
    my $tmpl   = $plugin->load_tmpl('entry_list.mtml');
    $tmpl->param( 'type', $type );

    return $app->listing(
        {   type     => 'entry',
            template => $tmpl,
            params   => {
                panel_searchable => 1,
                edit_blog_id     => $blog_ids,
                edit_field       => $app->param('edit_field'),
                search           => $app->param('search'),
                blog_id          => $blog_ids,
            },
            code => sub {
                my ( $obj, $row ) = @_;
                $row->{ 'status_'
                        . lc MT::Entry::status_text( $obj->status ) } = 1;
                $row->{entry_permalink} = $obj->permalink
                    if $obj->status == MT::Entry->RELEASE();
                if ( my $ts = $obj->authored_on ) {
                    my $date_format = MT::App::CMS->LISTING_DATE_FORMAT();
                    my $datetime_format
                        = MT::App::CMS->LISTING_DATETIME_FORMAT();
                    $row->{created_on_formatted}
                        = format_ts( $date_format, $ts, $obj->blog,
                        $app->user ? $app->user->preferred_language : undef );
                    $row->{created_on_time_formatted}
                        = format_ts( $datetime_format, $ts, $obj->blog,
                        $app->user ? $app->user->preferred_language : undef );
                    $row->{created_on_relative}
                        = relative_date( $ts, time, $obj->blog );
                    $row->{kind} = ucfirst( $obj->class );
                    my $author = MT->model('author')->load( $obj->author_id );
                    $row->{author_name} = $author ? $author->nickname : '';
                }
                return $row;
            },
            terms => \%terms,
            args  => \%args,
        }
    );
}

sub select_entry_or_page {
    my $app = shift;

    my $edit_field = $app->param('edit_field')
        or return $app->errtrans('No edit_field');

    my $obj_id = $app->param('id')
        or return $app->errtrans('No id');

    my $obj = MT->model('entry')->load($obj_id)
        or return $app->errtrans( 'No entry or page #[_1]', $obj_id );

    my $plugin = MT->component('ConfigAssistant')
        or die "OMG NO COMPONENT!?!";
    my $tmpl   = $plugin->load_tmpl(
        'select_entry.mtml',
        {
            entry_id        => $obj->id,
            entry_title     => $obj->title,
            entry_class     => lc($obj->class_label),
            entry_permalink => $obj->permalink,
            entry_blog_id   => $obj->blog_id,
            edit_field      => $edit_field,
        }
    );
    return $tmpl;
}


sub xfrm_cfg_plugin_param {
    my ( $cb, $app, $param, $tmpl ) = @_;
    foreach ( @{ $param->{plugin_loop} } ) {
        my $sig     = $_->{'plugin_sig'};
        my $plugin  = $MT::Plugins{$sig}{'object'};
        my $r       = $plugin->{'registry'};
        my @options = keys %{ $r->{'options'} };
        if ( $#options > -1 ) {
            $_->{'uses_configassistant'} = 1;
        }
    }
}

sub xfrm_cfg_plugin {
    my ( $cb, $app, $tmpl ) = @_;
    my $slug1 = <<END_TMPL;

<form enctype="multipart/form-data" method="post" action="<mt:var name="script_url">" id="plugin-<mt:var name="plugin_id">-form">
<mt:unless name="uses_configassistant">
  <input type="hidden" name="__mode" value="save_plugin_config" />
<mt:if name="blog_id">
  <input type="hidden" name="blog_id" value="<mt:var name="blog_id">" />
</mt:if>
  <input type="hidden" name="return_args" value="<mt:var name="return_args" escape="html">" />
  <input type="hidden" name="plugin_sig" value="<mt:var name="plugin_sig" escape="html">" />
  <input type="hidden" name="magic_token" value="<mt:var name="magic_token">" />
</mt:unless>
  <fieldset>
    <mt:var name="plugin_config_html">
  </fieldset>
<mt:unless name="uses_configassistant">
  <div class="actions-bar settings-actions-bar">
    <div class="actions-bar-inner pkg actions">
      <button
        mt:mode="save_plugin_config"
        type="submit"
        class="save action primary button primary-button"><__trans phrase="Save Changes"></button>
<mt:if name="plugin_settings_id">
      <button
        onclick="resetPlugin(getByID('plugin-<mt:var name="plugin_id">-form')); return false"
        class="action button"
        type="submit"><__trans phrase="Reset to Defaults"></button>
</mt:if>
    </div>
  </div>
</mt:unless>
</form>

END_TMPL

    my $slug2 = <<END_TMPL;
<mt:setvarblock name="html_head" append="1">
  <link rel="stylesheet" href="<mt:PluginStaticWebPath component="configassistant">css/app.css" type="text/css" />
  <link rel="stylesheet" href="<mt:PluginStaticWebPath component="configassistant">colorpicker/css/colorpicker.css" type="text/css" />
  <mt:If tag="Version" lt="5">
    <mt:Unless tag="ProductName" eq="Melody">
  <script src="<mt:StaticWebPath>jquery/jquery.js" type="text/javascript"></script>
    </mt:Unless>
  </mt:If>
  <script src="<mt:PluginStaticWebPath component="configassistant">js/options.js" type="text/javascript"></script>
  <script src="<mt:PluginStaticWebPath component="configassistant">colorpicker/js/colorpicker.js" type="text/javascript"></script>
</mt:setvarblock>
END_TMPL

# MT 4/5
#  <form method="post" action="<mt:var name="script_url">" id="plugin-<mt:var name="plugin_id">-form">
# Melody
#  <form method="post" action="<$mt:var name="script_url"$>" id="plugin-<$mt:var name="plugin_id" dirify="1"$>-form">
    $$tmpl
      =~ s{(<form method="post" action="<\$?mt:var name="script_url"\$?>" id="plugin-<\$?mt:var name="plugin_id"( dirify="1"\$?)?>-form">.*</form>)}{$slug1}msg;
    $$tmpl =~ s{^}{$slug2};
} ## end sub xfrm_cfg_plugin

sub tag_config_form {
    my ( $ctx, $args, $cond ) = @_;
    return
      "<p>Our sincerest apologies. This plugin uses a Config Assistant syntax which is no longer supported. Please notify the developer of the plugin.</p>";
}

1;

__END__

