package ConfigAssistant::Static;

use strict;

use MT;
use MT::FileMgr;
use File::Spec;

sub manual_run {
    # The manual run is something that the admin may need to use if they
    # haven't correctly set permissions on the support folder.
    my $app = shift;
    my (@messages, $message);
    
    # We need to look at all plugins and decide if they have registry
    # entries, and therefore static entries.
    for my $sig ( keys %MT::Plugins ) {
        my $plugin   = $MT::Plugins{$sig}{object};
        my $registry = $plugin->{registry};

        # Do *not* check schema versions, because we want the static copy
        # to run for all plugins.
        if ( $registry->{'static'} ) {
            push @messages, 'Copying static files for <strong>'.$plugin->name.'</strong>...';
            push @messages, _traverse_hash(
                $registry->{'static'}, 
                $plugin->key, 
            );
        }
    }
    my $message = join('<br />', @messages);
    
    $app->build_page('copy_static_files.mtml', { status => $message, });
}

sub upgrade {
    my $self = shift;
    my $app  = MT->instance;
    
    # We need to look at all plugins and decide if they have registry
    # entries, and therefore static entries.
    for my $sig ( keys %MT::Plugins ) {
        my $plugin   = $MT::Plugins{$sig}{object};
        my $registry = $plugin->{registry};

        # Grab the plugin schema version, and check if it's newer than the
        # version currently installed. If it is, then we want to install
        # the static files.
        my $saved_version = MT->config('PluginSchemaVersion')->{$plugin->id} || '0';
        if ($plugin->schema_version > $saved_version) {
            # Are there any static folders?
            if ( $registry->{'static'} ) {
                $self->progress('Copying static files for <strong>'.$plugin->name.'</strong> to mt-static/support/plugins/...');
                # Create the plugin's directory.
                my $message = _make_dir($plugin->key);
                $self->progress($message);
                my @messages = _traverse_hash($registry->{'static'}, $plugin->key);
                $message = join('<br />', @messages);
                $self->progress($message);
            }
        }
    }
    # Always return true so that the upgrade can continue.
    1;
}

sub _traverse_hash {
    my $registry   = shift;
    my $plugin_key = shift;
    my $dir        = shift;
    my (@messages, $message);
    my $app = MT->instance;

    # Is this a hash? If so, these are directories to be created.
    if (ref($registry) eq 'HASH') {
        while ( my ($folder, $reg) = each (%$registry) ) {
            # Create the specified directory
            my $dir = File::Spec->catfile($dir, $folder);
            my $dir_w_plugin = File::Spec->catfile($plugin_key, $dir);
            $message = _make_dir($dir_w_plugin);
            push @messages, $message;
            # Now investigate the next level of the registry, to see if 
            # another directory is needed, or if there are files to copy.
            my @result = _traverse_hash($registry->{$folder}, $plugin_key, $dir);
            push @messages, @result;
        }
    }
    # An array means these are files to be copied.
    elsif (ref($registry) eq 'ARRAY') {
        foreach my $static (@$registry) {
            my $src = File::Spec->catfile($app->mt_dir, 'plugins', 
                        $plugin_key, 'static', $dir, $static);
            unless (-e $src) {
                # Can't find the source files. Check the addons/ folder.
                $src = File::Spec->catfile($app->mt_dir, 'addons', 
                            $plugin_key.".plugin", 'static', $dir, $static);
            }
            my $dest = File::Spec->catfile($app->config('StaticFilePath'), 
                        'support', 'plugins', $plugin_key, $dir, $static);
            $message = _write_file($src, $dest);
            push @messages, $message;
        }
    }
    return @messages;
}

sub _make_dir {
    # Create the required directory.
    my $dir = shift;
    my $fmgr = MT::FileMgr->new('Local')
        or return MT::FileMgr->errstr;

    my $app = MT->instance;
    my $dir = File::Spec->catfile($app->config('StaticFilePath'), 'support', 'plugins', $dir);
    if ( $fmgr->mkpath($dir) ) {
        # Success!
        my $app = MT->instance;
        my $static_file_path = $app->config('StaticFilePath');
        $dir =~ s!$static_file_path/support/plugins/(.*)!$1!;
        return "Created folder $dir/.";
    }
    else {
        return '<span style="color: #990000;">'.$fmgr->errstr.'</span>';
    }
    return;
}

sub _write_file {
    # Actually copy the file from plugins/static/ to the mt-static/support/plugins/ area.
    my ($src, $dest) = @_;
    my $fmgr = MT::FileMgr->new('Local')
        or return MT::FileMgr->errstr;

    # Grab the file specified.
    my $src_data = $fmgr->get_data($src)
        or return '<span style="color: #990000;">'.$fmgr->errstr.'</span>';
    # Write the file to its new home, but only if some data was read.
    if ($src_data) {
        my $bytes = $fmgr->put_data($src_data, $dest)
            or return '<span style="color: #990000;">'.$fmgr->errstr.'</span>';
        # Only provide a "copied" message if the file was successfully written.
        if ($bytes) {
            my $app = MT->instance;
            my $static_file_path = $app->config('StaticFilePath');
            $dest =~ s!$static_file_path/support/plugins/(.*)!$1!;
            return "Copied $dest.";
        }
    }
    return;
}

1;

__END__
