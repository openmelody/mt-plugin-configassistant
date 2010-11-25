package ConfigAssistant::Util;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK
  = qw( find_theme_plugin   find_template_def   find_option_def
        find_option_plugin  process_file_upload 
        plugin_static_web_path plugin_static_file_path
        ERROR SUCCESS OVERWRITE NO_UPLOAD );

use MT::Util qw( encode_url );

sub ERROR ()     {0}
sub SUCCESS ()   {1}
sub OVERWRITE () {2}
sub NO_UPLOAD () {3}

sub plugin_static_web_path {
    my ($plugin) = @_;
    my $url = MT->instance->static_path;
    $url .= '/' unless $url =~ m!/$!;
    $url .= 'support/plugins/' . $plugin->id . '/';
    return $url;
}

sub plugin_static_file_path {
    my ($plugin) = @_;
    return File::Spec->catdir( MT->instance->static_file_path,
                               'support', 'plugins', $plugin->id );

}

sub process_file_upload {
    my $app = shift;
    my ( $param_name, $scope, $extra_path, %upload_param ) = @_;

    if ( my $perms = $app->permissions ) {
        return {
                 status  => ERROR(),
                 message => $app->translate("Permission denied."),
          }
          unless $perms->can_upload;
    }

    $app->validate_magic()
      or return {
                  status  => ERROR(),
                  message => $app->translate("Failed to validate magic.")
      };

    my $q = $app->can('query') ? $app->query : $app->param;
    my ( $fh, $info ) = $app->upload_info($param_name);

    return { status => NO_UPLOAD() } unless $fh;

    my $mimetype;
    if ($info) {
        $mimetype = $info->{'Content-Type'};
    }
    my $has_overwrite = $q->param('overwrite_yes')
      || $q->param('overwrite_no');
    my %param = (
                  middle_path => $q->param('middle_path'),
                  site_path   => $q->param('site_path'),
                  extra_path  => $q->param('extra_path'),
                  upload_mode => $app->mode,
    );
    return {
             status  => ERROR(),
             message => $app->translate("Please select a file to upload."),
      }
      if !$fh && !$has_overwrite;

    my $basename = $q->param($param_name) || $q->param('fname');
    $basename =~ s!\\!/!g;    ## Change backslashes to forward slashes
    $basename =~ s!^.*/!!;    ## Get rid of full directory paths
    if ( $basename =~ m!\.\.|\0|\|! ) {
        return {
                 status => ERROR(),
                 message =>
                   $app->translate( "Invalid filename '[_1]'", $basename ),
        };
    }

    # TODO: implement better abstraction for required type
    if ( my $asset_type = $upload_param{'require_type'} ) {
        my $asset_pkg = MT->model('asset')->handler_for_file($basename);
        my %settings_for = (
            audio => {
                  class => 'MT::Asset::Audio',
                  error =>
                    $app->translate("Please select an audio file to upload."),
            },
            image => {
                class => 'MT::Asset::Image',
                error => $app->translate("Please select an image to upload."),
            },
            video => {
                 class => 'MT::Asset::Video',
                 error => $app->translate("Please select a video to upload."),
            },
        );
        if ( my $settings = $settings_for{$asset_type} ) {
            return { status => ERROR(), message => $settings->{error} }
              if !$asset_pkg->isa( $settings->{class} );
        }
    } ## end if ( my $asset_type = ...)

    my (
         $blog_id,       $blog,     $fmgr,           $local_file,
         $asset_file,    $base_url, $asset_base_url, $relative_url,
         $relative_path, $format,   $root_path
    );

    if ( lc($scope) eq 'blog' ) {
        return {
               status => ERROR(),
               message =>
                 $app->translate(
                   "Unable to upload to blog site path without blog context.")
          }
          unless ( $app->blog );
        $root_path = $app->blog->site_path;
        $base_url  = $app->blog->site_url;
        $fmgr      = $app->blog->file_mgr;
        $blog_id   = $app->blog
          ->id;    # the resulting asset will be added to this context
        $format = '%r';

    }
    elsif ( lc($scope) eq 'archive' ) {
        return {
            status => ERROR(),
            message =>
              $app->translate(
                "Unable to upload to blog archive path without blog context.")
          }
          unless ( $app->blog );
        $root_path = $app->blog->archive_path;
        $base_url  = $app->blog->archive_url;
        $fmgr      = $app->blog->file_mgr;
        $blog_id   = $app->blog
          ->id;    # the resulting asset will be added to this context
        $format = '%a';

    }
    elsif ( lc($scope) eq 'support' ) {
        require MT::FileMgr;
        $root_path = File::Spec->catdir( $app->static_file_path, 'support' );
        $base_url  = $app->static_path . '/support';
        $fmgr      = MT::FileMgr->new('Local');
        $blog_id = 0;    # the resulting asset will be added to this context
        $format = File::Spec->catfile( '%s', 'support' );

    }
    else {

        # This is not supported. Error? Default to something?
    }

    unless ( $fmgr->exists($root_path) ) {
        $fmgr->mkpath($root_path);
        unless ( $fmgr->exists($root_path) ) {
            return {
                  status => ERROR(),
                  message =>
                    $app->translate(
                      "Could not create upload path '[_1]': [_2]", $root_path,
                      $fmgr->errstr
                    )
            };
        }
    }

    $extra_path ||= '';
    if ( $extra_path =~ m!\.\.|\0|\|! ) {
        return {
                 status => ERROR(),
                 message =>
                   $app->translate( "Invalid extra path '[_1]'", $extra_path )
        };
    }

    # Process tokens into an actual path
    $extra_path = format_path($extra_path);

    if ( $extra_path =~ m!^/! ) {
        return {
                 status => ERROR(),
                 message =>
                   $app->translate(
                                  "Extra path must be a relative path '[_1]'",
                                  $extra_path
                   )
        };
    }

    my $path = File::Spec->catdir( $root_path, $extra_path );
    ## Untaint. We already checked for security holes in $relative_path.
    ($path) = $path =~ /(.+)/s;

    ## Build out the directory structure if it doesn't exist. DirUmask
    ## determines the permissions of the new directories.
    unless ( $fmgr->exists($path) ) {
        $fmgr->mkpath($path)
          or return {
                     status => ERROR(),
                     message =>
                       $app->translate(
                                        "Can't make path '[_1]': [_2]", $path,
                                        $fmgr->errstr
                       )
          };
    }

    # The relative path/URL will be relative to the base path/url respectively
    $relative_url = File::Spec->catfile( $extra_path, encode_url($basename) );
    $relative_path
      = $extra_path
      ? File::Spec->catfile( $extra_path, $basename )
      : $basename;

    $asset_file = File::Spec->catfile( $format, $relative_path );
    $local_file = File::Spec->catfile( $path,   $basename );

    ## Untaint. We already tested $basename and $relative_path for security
    ## issues above, and we have to assume that we can trust the user's
    ## Local Archive Path setting. So we should be safe.
    ($local_file) = $local_file =~ /(.+)/s;

    # Extricated from code base:
    # Handling file collissions and overwriting
    # Avoid problem by adding random file name?

    require MT::Image;
    my ( $w, $h, $id, $write_file )
      = MT::Image->check_upload(
                                 Fh     => $fh,
                                 Fmgr   => $fmgr,
                                 Local  => $local_file,
                                 Max    => $upload_param{max_size},
                                 MaxDim => $upload_param{max_image_dimension}
      );

    return { status => ERROR(), message => MT::Image->errstr }
      unless $write_file;

    ## File does not exist, or else we have confirmed that we can overwrite.
    my $umask = oct $app->config('UploadUmask');
    my $old   = umask($umask);
    defined( my $bytes = $write_file->() )
      or return {
                  status => ERROR(),
                  message =>
                    $app->translate(
                                     "Error writing upload to '[_1]': [_2]",
                                     $local_file, $fmgr->errstr
                    )
      };
    umask($old);

    ## Close up the filehandle.
    close $fh;

    ## We'll use $relative_path as the filename and as the url passed
    ## in to the templates. So, we want to replace all of the '\' characters
    ## with '/' characters so that it won't look like backslashed characters.
    ## Also, get rid of a slash at the front, if present.
    $relative_path =~ s!\\!/!g;
    $relative_path =~ s!^/!!;
    $relative_url  =~ s!\\!/!g;
    $relative_url  =~ s!^/!!;

    my $url = $base_url;
    $url .= '/' unless $url =~ m!/$!;
    $url .= $relative_url;

    my $asset_url = $format . '/' . $relative_url;

    require File::Basename;
    my $local_basename = File::Basename::basename($local_file);
    my $ext
      = ( File::Basename::fileparse( $local_file, qr/[A-Za-z0-9]+$/ ) )[2];

    my $asset_pkg = MT->model('asset')->handler_for_file($local_basename);
    my $is_image
      = defined($w) && defined($h) && $asset_pkg->isa('MT::Asset::Image');
    my $asset
      = $asset_pkg->load( { file_path => $asset_file, blog_id => $blog_id } );
    if ( !$asset ) {
        $asset = $asset_pkg->new();
        $asset->file_path($asset_file);
        $asset->file_name($local_basename);
        $asset->file_ext($ext);
        $asset->blog_id($blog_id);
        $asset->created_by( $app->user->id );
    }
    else {
        $asset->modified_by( $app->user->id );
    }
    my $original = $asset->clone;
    $asset->url($asset_url);
    $asset->mime_type($mimetype) if $mimetype;

    # TODO - Abstract into a callback for more programmatically populated fields
    if ($is_image) {
        $asset->image_width($w);
        $asset->image_height($h);
    }
    $asset->save;
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    if ($is_image) {
        $app->run_callbacks(
                             'cms_upload_file.' . $asset->class,
                             File  => $local_file,
                             file  => $local_file,
                             Url   => $url,
                             url   => $url,
                             Size  => $bytes,
                             size  => $bytes,
                             Asset => $asset,
                             asset => $asset,
                             Type  => 'image',
                             type  => 'image',
                             Blog  => $blog,
                             blog  => $blog
        );
        $app->run_callbacks(
                             'cms_upload_image',
                             File       => $local_file,
                             file       => $local_file,
                             Url        => $url,
                             url        => $url,
                             Size       => $bytes,
                             size       => $bytes,
                             Asset      => $asset,
                             asset      => $asset,
                             Height     => $h,
                             height     => $h,
                             Width      => $w,
                             width      => $w,
                             Type       => 'image',
                             type       => 'image',
                             ImageType  => $id,
                             image_type => $id,
                             Blog       => $blog,
                             blog       => $blog
        );
    } ## end if ($is_image)
    else {
        $app->run_callbacks(
                             'cms_upload_file.' . $asset->class,
                             File  => $local_file,
                             file  => $local_file,
                             Url   => $url,
                             url   => $url,
                             Size  => $bytes,
                             size  => $bytes,
                             Asset => $asset,
                             asset => $asset,
                             Type  => 'file',
                             type  => 'file',
                             Blog  => $blog,
                             blog  => $blog
        );
    }

    return {
          status => SUCCESS(),
          asset => { id => $asset->id, url => $asset->url, object => $asset },
          bytes => $bytes
    };
} ## end sub process_file_upload

# Reserved:
# %s - mt-static/support
# %r - blog site root
# %a - blog archive root
# Implemented:
# %{#}e - entroy - random n byte string
# TODO:
# %b - current blog_id in context or 0
sub format_path {
    my ($path) = @_;
    if ( $path =~ /\%({\d+})?e/ ) {
        my $len = $1;
        $len ||= '8';
        my $str = generate_random_string($len);
        $path =~ s/\%({\d*})?e/$str/g;
    }
    return $path;
}

sub generate_random_string {
    my $length_of_randomstring = shift;

    # the random string to generate

    my @chars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '_' );
    my $random_string;
    foreach ( 1 .. $length_of_randomstring ) {

        # rand @chars will generate a random
        # number between 0 and scalar @chars
        $random_string .= $chars[ rand @chars ];
    }
    return $random_string;
}

sub find_template_def {
    my ( $id, $set ) = @_;
    my $r = MT->registry('template_sets');
    foreach
      my $type (qw(widget_sets widget index module individual system archive))
    {
        if ( $r->{$set}->{'templates'}->{$type} ) {
            my $def = $r->{$set}->{'templates'}->{$type}->{$id};
            if ($def) {
                $def->{type} = $type;
                return $def;
            }
        }
    }
    return undef;
}

sub find_option_def {
    my ( $app, $id ) = @_;
    my $opt;

    # First, search the current template set's theme options
    if ( $app->blog ) {
        my $set = $app->blog->template_set;
        $id =~ s/^($set)_//;
        my $r = MT->registry('template_sets');
        if ( $r->{$set}->{'options'} ) {
            foreach ( keys %{ $r->{$set}->{'options'} } ) {
                $opt = $r->{$set}->{'options'}->{$id} if ( $id eq $_ );
            }
        }
    }

    # Next, if a theme option was not found, search plugin options
    unless ($opt) {
        my $r = MT->registry('options');
        if ($r) {
            foreach ( keys %{$r} ) {
                $opt = $r->{$id} if ( $id eq $_ );
            }
        }
    }
    return $opt;
} ## end sub find_option_def

sub find_theme_plugin {
    my ($set) = @_;
    for my $sig ( keys %MT::Plugins ) {
        my $plugin = $MT::Plugins{$sig};
        my $obj    = $MT::Plugins{$sig}{object};
        my $r      = $obj->{registry};
        my @sets   = keys %{ $r->{'template_sets'} };
        foreach (@sets) {
            return $obj if ( $set eq $_ );
        }
    }
    return undef;
}

sub find_option_plugin {
    my ($opt_name) = @_;
    for my $sig ( keys %MT::Plugins ) {
        my $plugin = $MT::Plugins{$sig};
        my $obj    = $MT::Plugins{$sig}{object};
        my $r      = $obj->{registry};
        my @opts   = keys %{ $r->{'options'} };
        foreach (@opts) {
            return $obj if ( $opt_name eq $_ );
        }
    }
    return undef;
}

1;
