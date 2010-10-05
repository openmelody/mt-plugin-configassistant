package ConfigAssistant::Prefs;

use strict;

sub apply {
    my $app = shift;
    my ($param) = @_;

    $app->validate_magic or return;

    my $q    = $app->{query};
    my $blog = MT->model('blog')->load( $q->param('blog_id') );
    my $pid  = $q->param('pref_id');

    _apply_prefs( $blog, $pid );

    return $app->redirect(
        $app->uri(
            'mode' => 'ca_prefs_chooser',
            'args' => {
                'prefs_applied' => 1,
                'blog_id'       => $app->param('blog_id'),
                'return_args'   => $app->return_args,
                'magic_token'   => $app->param('magic_token')
            }
        )
    );
}

sub chooser {
    my $app     = shift;
    my ($param) = @_;
    my $q       = $app->{query};
    my $blog    = MT->model('blog')->load( $q->param('blog_id') );

    $param ||= {};

    my $prefs = MT->registry('blog_preferences');
    my @data;
    foreach my $pid ( keys %$prefs ) {
        my $pref = $prefs->{$pid};
        push @data,
          {
            id          => $pid,
            name        => &{ $pref->{'label'} },
            description => $pref->{'description'},
            order       => $pref->{'order'} || 10,
            selected    => $blog->selected_config eq $pid
          };
    }
    @data = sort { $a->{order} <=> $b->{order} } @data;
    $param->{prefs}         = \@data;
    $param->{blog_id}       = $app->param('blog_id');
    $param->{return_args}   = $app->return_args;
    $param->{magic_token}   = $app->param('magic_token');
    $param->{prefs_applied} = $app->param('prefs_applied') ? 1 : 0;

    return $app->load_tmpl( 'prefs_chooser.mtml', $param )
}

sub on_template_set_change {
    my ( $cb, $param ) = @_;
    my $blog = $param->{blog} or return;

    my $ts = $blog->template_set;
    return undef unless $ts;

    my $pref_id = MT->registry('template_sets')->{$ts}->{blog_preferences};
    return undef unless $pref_id;

    _apply_prefs( $blog, $pref_id );
}

sub _apply_prefs {
    my ( $blog, $pid ) = @_;

    my $label = &{ MT->registry('blog_preferences')->{$pid}->{label} };

    # Set plugin preferences.
    my $plugins = MT->registry('blog_preferences', $pid, 'plugin_data');
    foreach my $plugin_id ( keys %$plugins ) {
        my $plugin = MT->component($plugin_id);
        next if !$plugin;
        MT->log(
            {
                blog_id => $blog->id,
                message => "Config Assistant is configuring "
                  . $plugin->name . " preferences for "
                  . $blog->name . ".",
                level => MT::Log::INFO(),
            }
        );

        my $scope = "blog:" . $blog->id;
        my $pdata = $plugin->get_config_obj($scope);
        my $data  = $pdata->data() || {};
        my $datas =
            MT->registry('blog_preferences', $pid, 'plugin_data', $plugin_id);
        foreach my $key ( keys %$datas ) {
            $data->{$key} = $datas->{$key};
        }
        $pdata->data($data);
        MT->request( 'plugin_config.' . $plugin->id, undef );
        $pdata->save() or die $pdata->errstr;
    }

    # Set blog preferences
    my $prefs = MT->registry('blog_preferences', $pid, 'preferences');

    MT->log(
        {
            blog_id => $blog->id,
            message => "Config Assistant is configuring "
              . $blog->name
              . " with $label preferences.",
            level => MT::Log::INFO(),
        }
    );
    
    foreach my $col ( keys %$prefs ) {
        my $value = $prefs->{$col};
        if ( $blog->has_column($col) ) {
            # TODO Validate input
            $blog->$col($value);
        }
        else {
            MT->log(
                {
                    blog_id => $blog->id,
                    message => "Config Assistant tried to set a blog "
                        . "preference $col that does not exist.",
                    level => MT::Log::WARNING(),
                }
            );
        }
    }
    $blog->meta( 'selected_config', $pid );
    $blog->save;
}

1;
