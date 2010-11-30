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
    my $types     = $app->registry('config_types');
    my $fieldsets = $cfg->{fieldsets};
    my $scope     = 'blog:' . $app->blog->id;

    my $cfg_obj = eval { $plugin->get_config_hash($scope) };

    require MT::Template::Context;
    my $ctx = MT::Template::Context->new();

    $fieldsets->{__global} = {
                               label => sub { "Global Options"; }
    };

    # this is a localized stash for field HTML
    my $fields;
    my @missing_required;

    foreach my $optname (
        sort {
            ( $cfg->{$a}->{order} || 999 ) <=> ( $cfg->{$b}->{order} || 999 )
        } keys %{$cfg}
      )
    {
        next if $optname eq 'fieldsets';
        my $field = $cfg->{$optname};
        if ( my $cond = $field->{condition} ) {
            if ( !ref($cond) ) {
                $cond = $field->{condition} = $app->handler_to_coderef($cond);
            }
            next unless $cond->();
        }
        if ( !$field->{'type'} ) {
            MT->log( {
                   message =>
                     "Option '$optname' in template set '$ts' did not declare a type. Skipping"
                }
            );
            next;
        }


        my $field_id = $ts . '_' . $optname;

        if ( $field->{'type'} eq 'separator' ) {

            # The separator "type" is handled specially here because it's not
            # really a "config type"-- it isn't editable and no data is saved
            # or retrieved. It just displays a separator and some info.
            my $out;
            my $show_label
              = defined $field->{show_label} ? $field->{show_label} : 1;
            my $label = $field->{label} ne '' ? &{ $field->{label} } : '';
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
                $out .= "       <div>" . $field->{hint} . "</div>\n";
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
                if ( !$value ) {

                    # There is no value for this field, and it's a required
                    # field, so we need to tell the user to fix it!
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
                $out
                  .= "      <div class=\"hint\">"
                  . $field->{hint}
                  . "</div>\n";
            }
            $out .= "    </div>\n";
            $out .= "  </div>\n";
            my $fs = $field->{fieldset};
            push @{ $fields->{$fs} }, $out;
        } ## end elsif ( $types->{ $field->...})
        else {
            MT->log( {
                       message => 'Unknown config type encountered: '
                         . $field->{'type'}
                     }
            );
        }
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


    $param->{html}             = $html;
    $param->{fieldsets}        = \@loop;
    $param->{leftovers}        = \@leftovers;
    $param->{blog_id}          = $blog->id;
    $param->{plugin_sig}       = $plugin->{plugin_sig};
    $param->{saved}            = $q->param('saved');
    $param->{missing_required} = \@missing_required;
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
               and $app->user->permissions($blog_id)->can_administer_blog );

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
                my $result = process_file_upload( $app, $var, 'support',
                                                  $opt->{destination} );
                if ( $result->{status} == ConfigAssistant::Util::ERROR() ) {
                    return $app->error(
                              "Error uploading file: " . $result->{message} );
                }
                next
                  if (
                      $result->{status} == ConfigAssistant::Util::NO_UPLOAD );
                if ( $data->{$var} ) {
                    my $old = MT->model('asset')->load( $data->{$var} );
                    $old->remove if $old;
                }
                $param->{$var} = $result->{asset}->{id};
            }
            my $old = $data->{$var};
            my $new = $param->{$var};
            my $has_changed 
              = ( defined $new and !defined $old )
              || ( defined $old && !defined $new )
              || ( defined $new and $old ne $new );
            ###l4p $logger->debug('$has_changed: '.$has_changed);

            if ( $has_changed && $opt && $opt->{'republish'} ) {
                foreach ( split( ',', $opt->{'republish'} ) ) {
                    $repub_queue->{$_} = 1;
                }
            }
            $data->{$var} = $new ? $new : undef;
            if ($has_changed) {

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
        foreach ( keys %$repub_queue ) {
            my $tmpl = MT->model('template')
              ->load( { blog_id => $blog_id, identifier => $_, } );
            next unless $tmpl;
            MT->log( {
                   blog_id => $blog_id,
                   message => "Config Assistant: Republishing " . $tmpl->name
                 }
            );
            $app->rebuild_indexes(
                                   Blog     => $app->blog,
                                   Template => $tmpl,
                                   Force    => 1,
            );
        }
        $pdata->data($data);
        MT->request( 'plugin_config.' . $plugin->id, undef );
        $pdata->save() or die $pdata->errstr;

        # END - contents of MT::Plugin->save_config

        if ( $plugin->errstr ) {
            return $app->error(
                         "Error saving plugin settings: " . $plugin->errstr );
        }
    } ## end if ( $profile && $profile...)

    $app->add_return_arg( saved => 1 );
    $app->call_return;
} ## end sub save_config

sub type_text {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    return "      <input type=\"text\" name=\"$field_id\" value=\""
      . encode_html( $value, 1
      )    # The additional "1" will escape HTML entities properly
      . "\" class=\"full-width\" />\n";
}

sub type_file {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $html = "";
    if ($value) {
        my $asset = MT->model('asset')->load($value);
        if ($asset) {
            $html
              .= "<p>"
              . ( $asset->label ? $asset->label : $asset->file_name )
              . " <a target=\"_new\" href=\""
              . $asset->url
              . "\">view</a></p>";
        }
        else {
            $html .= "<p>File not found.</p>";
        }
    }
    $html
      .= "      <input type=\"file\" name=\"$field_id\" class=\"full-width\" />\n";
    return $html;
} ## end sub type_file

sub type_colorpicker {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    return
      "      <div id=\"$field_id-colorpicker\" class=\"colorpicker-container\"><div style=\"background-color: $value\"></div></div><input type=\"hidden\" id=\"$field_id\" name=\"$field_id\" value=\""
      . encode_html( $value, 1
      )    # The additional "1" will escape HTML entities properly
      . "\" />\n<script type=\"text/javascript\">\$('#'+'$field_id-colorpicker').ColorPicker({
        color: '$value',
        onShow: function (colpkr) {
            \$(colpkr).fadeIn(500);
            return false;
        },
        onHide: function (colpkr) {
            \$(colpkr).fadeOut(500);
            return false;
        },
        onChange: function (hsb, hex, rgb) {
            \$('#'+'$field_id-colorpicker div').css('backgroundColor', '#' + hex);
            \$('#'+'$field_id').val('#' + hex).trigger('change');
        }
    });</script>\n";
} ## end sub type_colorpicker

sub type_link_group {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $static = $app->static_path;
    $value = '"[]"' if ( !$value || $value eq '' );
    eval "\$value = $value";
    if ($@) { $value = '"[]"'; }
    my $list;
    eval { $list = JSON::from_json($value) };
    if ($@) { $list = []; }
    my $html;
    $html
      = "      <div id=\"$field_id-link-group\" class=\"link-group-container pkg\">"
      . "<ul>";

    foreach (@$list) {
        $html
          .= '<li class="pkg"><a class="link" href="'
          . $_->{'url'} . '">'
          . $_->{'label'}
          . '</a> <a class="remove" href="javascript:void(0);"><img src="'
          . $static
          . '/images/icon_close.png" /></a> <a class="edit" href="javascript:void(0);">edit</a></li>';
    }
    $html
      .= "<li class=\"last\"><button class=\"add-link\">Add Link</button></li>"
      . "</ul>"
      . "</div>"
      . "<input type=\"hidden\" id=\"$field_id\" name=\"$field_id\" value=\""
      . encode_html( $value, 1
      )    # The additional "1" will escape HTML entities properly
      . "\" />\n<script type=\"text/javascript\">\n";
    $html
      .= "  \$('#'+'$field_id-link-group button.add-link').click( handle_edit_click );\n";
    $html
      .= "  \$('#'+'$field_id-link-group').parents('form').submit( function (){
    var struct = Array();
    \$(this).find('#'+'$field_id-link-group ul li button').trigger('click');
    \$(this).find('#'+'$field_id-link-group ul li a.link').each( function(i, e) {
      var u = \$(this).attr('href');
      var l = \$(this).html();
      struct.push( { 'url': u, 'label': l } );
    });
    var json = \$.toJSON(struct);
    \$('#'+'$field_id').val( json );
  });
  \$('#'+'$field_id-link-group ul li a.remove').click( handle_delete_click );
  \$('#'+'$field_id-link-group ul li a.edit').click( handle_edit_click );
</script>\n";
    return $html;
} ## end sub type_link_group

sub type_textarea {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $rows = $field->{rows} || '';
    my $out;
    $out = "      <textarea name=\"$field_id\" class=\"full-width\" rows=\""
      . $rows . "\">";

    # The additional "1" below will escape HTML entities properly
    $out .= encode_html( $value, 1 );
    $out .= "</textarea>\n";
    return $out;
}

sub type_page {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $ctx->stash( 'object_class', 'page' );
    return type_entry( $app, @_ );
}

sub type_entry {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my $obj_class = $ctx->stash('object_class') || 'entry';
    my $obj       = MT->model($obj_class)->load($value);
    my $obj_name  = ( $obj ? $obj->title : '' ) || '';
    my $blog_id   = $field->{all_blogs} ? 0 : $app->blog->id;
    unless ( $ctx->var('entry_chooser_js') ) {
        $out .= <<EOH;
    <script type="text/javascript">
        function insertCustomFieldEntry(html, val, id) {
            \$('#'+id).val(val);
            try {
                \$('#'+id+'_preview').html(html);
            } catch(e) {
                log.error(e);
            };
        }
    </script>
EOH
        $ctx->var( 'entry_chooser_js', 1 );
    }
    my $label = MT->model($obj_class)->class_label;
    $out .= <<EOH;
<div class="pkg">
  <input name="$field_id" id="$field_id" class="hidden" type="hidden" value="$value" />
  <button type="submit"
          onclick="return openDialog(this.form, 'ca_config_entry', 'blog_id=$blog_id&edit_field=$field_id&status=2&class=$obj_class')">Choose $label</button>
  <div id="${field_id}_preview" class="preview">
    $obj_name
  </div>
</div>
EOH
    return $out;
} ## end sub type_entry

sub type_tagged_entry {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my $lastn = $field->{lastn} || 10;
    my $tag = $field->{tag};

    my ( %terms, %args );
    $terms{blog_id} = $app->blog->id unless $field->{blog_id} eq 'all';
    $args{lastn} = $lastn;
    my @filters;
    my $class = 'MT::Entry';
    if ( my $tag_arg = $field->{tag_filter} ) {
        require MT::Tag;
        require MT::ObjectTag;

        my $terms;
        if ( $tag_arg !~ m/\b(AND|OR|NOT)\b|\(|\)/i ) {
            my @tags = MT::Tag->split( ',', $tag_arg );
            $terms = { name => \@tags };
            $tag_arg = join " or ", @tags;
        }
        my $tags = [
                MT::Tag->load(
                    $terms,
                    {
                      binary => { name => 1 },
                      join   => [
                          'MT::ObjectTag', 'tag_id',
                          { %terms, object_datasource => $class->datasource }
                      ]
                    }
                )
        ];
        require MT::Template::Context;
        my $ctx = MT::Template::Context->new;
        my $cexpr = $ctx->compile_tag_filter( $tag_arg, $tags );
        if ($cexpr) {
            my @tag_ids
              = map { $_->id, ( $_->n8d_id ? ( $_->n8d_id ) : () ) } @$tags;
            my $preloader = sub {
                my ($entry_id) = @_;
                my $cterms = {
                               tag_id            => \@tag_ids,
                               object_id         => $entry_id,
                               object_datasource => $class->datasource,
                               %terms,
                };
                my $cargs
                  = { %args, fetchonly => ['tag_id'], no_triggers => 1, };
                my @ot_ids = MT::ObjectTag->load( $cterms, $cargs )
                  if @tag_ids;
                my %map;
                $map{ $_->tag_id } = 1 for @ot_ids;
                \%map;
            };
            push @filters, sub { $cexpr->( $preloader->( $_[0]->id ) ) };
        } ## end if ($cexpr)
    } ## end if ( my $tag_arg = $field...)

    my @entries;
    my $iter = MT->model('entry')->load_iter( \%terms, \%args );
    my $i    = 0;
    my $j    = 0;
    my $n    = $field->{lastn};
  ENTRY: while ( my $e = $iter->() ) {
        for (@filters) {
            next ENTRY unless $_->($e);
        }
        push @entries, $e;
        $i++;
        last if $n && $i >= $n;
    }
    $out .= "      <select name=\"$field_id\">\n";
    $out
      .= '        <option value=""'
      . ( !$value || $value eq "" ? " selected" : "" )
      . ">None selected</option>\n";
    my $has_selected = 0;
    foreach (@entries) {
        $has_selected = 1 if $value eq $_->id;
        $out
          .= '        <option value="'
          . $_->id . '"'
          . ( $value eq $_->id ? " selected" : "" ) . ">"
          . $_->title
          . ( $field->{blog_id} eq 'all' ? " (" . $_->blog->name . ")" : "" )
          . "</option>\n";
    }
    if ( $value && !$has_selected ) {
        my $e = MT->model('entry')->load($value);
        if ($e) {
            $out
              .= '        <option value="'
              . $e->id
              . '" selected>'
              . $e->title
              . ( $field->{blog_id} eq 'all'
                  ? " (" . $e->blog->name . ")"
                  : "" )
              . "</option>\n";
        }
    }
    $out .= "      </select>\n";
    return $out;
} ## end sub type_tagged_entry

sub type_radio {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my @values = split( ",", $field->{values} );
    $out .= "      <ul>\n";
    foreach (@values) {

        # $el_id ("element ID") is used as a unique identifier so that the
        # label can be clickable to select the radio button.
        my $el_id = $field_id . '_' . $_;
        $out
          .= "        <li><input type=\"radio\" name=\"$field_id\""
          . " id=\"$el_id\" value=\"$_\""
          . ( $value eq $_ ? " checked=\"checked\"" : "" )
          . " class=\"rb\" />"

          # Add a space between the input field and the label so that the
          # label text isn't bumped up right next to the radio button.
          . " <label for=\"$el_id\">$_</label>" . "</li>\n";
    }
    $out .= "      </ul>\n";
    return $out;
} ## end sub type_radio

sub type_radio_image {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my $static = $app->static_path;
    $out .= "      <ul class=\"pkg\">\n";
    while ( $field->{values} =~ /\"([^\"]*)\":\"([^\"]*)\",?/g ) {
        my ( $url, $label ) = ( $1, $2 );
        my $base;
        if ( $url =~ /^http/ ) {
            $base = '';
        }
        else {
            $base = $static;
        }
        $out
          .= "        <li><input type=\"radio\" name=\"$field_id\" value=\"$label\""
          . ( $value eq $label ? " checked=\"checked\"" : "" )
          . " class=\"rb\" />"
          . "<img src=\""
          . $base
          . $url
          . "\" /><br />$label"
          . "</li>\n";
    }
    $out .= "      </ul>\n";
    return $out;
} ## end sub type_radio_image

sub type_select {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my @values = split( ",", $field->{values} );
    $out .= "      <select name=\"$field_id\">\n";
    foreach my $label (@values) {
        my $v;
        if ( $label =~ /\"([^\"]+)\":\"([^\"]+)\"/ ) {
            $label = $1;
            $v     = $2;
        }
        else {
            $v = $label;
        }
        $out
          .= "        <option value=\"$v\""
          . ( $value eq $label ? " selected" : "" )
          . ">$label</option>\n";
    }
    $out .= "      </select>\n";
    return $out;
} ## end sub type_select

sub type_blogs {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my @blogs = MT->model('blog')->load( {}, { sort => 'name' } );
    $out .= "      <select name=\"$field_id\">\n";
    $out
      .= "        <option value=\"0\" "
      . ( 0 == $value ? " selected" : "" )
      . ">None Selected</option>\n";
    foreach (@blogs) {
        $out
          .= "        <option value=\""
          . $_->id . "\" "
          . ( $value == $_->id ? " selected" : "" ) . ">"
          . $_->name
          . "</option>\n";
    }
    $out .= "      </select>\n";
    return $out;
} ## end sub type_blogs

sub in_array {
    my ( $arr, $search_for ) = @_;
    foreach my $value (@$arr) {
        return 1 if $value eq $search_for;
    }
    return 0;
}


sub type_checkbox {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    if ( $field->{values} ) {
        my $delimiter = $field->{delimiter} || ',';
        my @values = split( $delimiter, $field->{values} );
        $out .= "      <ul>\n";
        foreach (@values) {
            my $checked = 0;
            if ( ref($value) eq 'ARRAY' ) {
                $checked = in_array( $value, $_ );
            }
            else {
                $checked = $value eq $_;
            }

            # $el_id ("element ID") is used as a unique identifier so that the
            # label can be clickable to select the radio button.
            my $el_id = $field_id . '_' . $_;
            $out
              .= "        <li><input type=\"checkbox\" name=\"$field_id\" "
              . "id=\"$el_id\" value=\"$_\""
              . ( $checked ? " checked=\"checked\"" : "" )
              . " class=\"rb\" />"

              # Add a space between the input field and the label so that the
              # label text isn't bumped up right next to the radio button.
              . " <label for=\"$el_id\">$_</label>" . "</li>\n";
        } ## end foreach (@values)
        $out .= "      </ul>\n";
    } ## end if ( $field->{values} )
    else {
        $out
          .= "      <input type=\"checkbox\" name=\"$field_id\" value=\"1\" "
          . ( $value ? "checked " : "" ) . "/>\n";
    }
    return $out;
} ## end sub type_checkbox

sub type_category {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $value = defined($value) ? $value : 0;
    my $out;
    my $obj_class = $ctx->stash('object_class') || 'category';
    my @cats = MT->model($obj_class)
      ->load( { blog_id => $app->blog->id }, { sort => 'label' } );
    $out .= "      <select name=\"$field_id\">\n";
    $out
      .= "        <option value=\"0\" "
      . ( 0 == $value ? " selected" : "" )
      . ">None Selected</option>\n";

    foreach (@cats) {
        $out
          .= "        <option value=\""
          . $_->id . "\" "
          . ( $value == $_->id ? " selected" : "" ) . ">"
          . $_->label
          . "</option>\n";
    }
    $out .= "      </select>\n";
    return $out;
} ## end sub type_category

sub type_folder_list {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $ctx->stash( 'object_class', 'folder' );
    return type_category_list( $app, @_ );
}

sub type_category_list {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $value = 0 unless defined $value;
    my @values = ref $value eq 'ARRAY' ? @$value : ($value);
    my $out;
    my $obj_class = $ctx->stash('object_class') || 'category';

    my $params = {};
    $params->{blog_id} = $app->blog->id;
    $params->{parent} = 0 unless $ctx->stash('show_children');

    my @cats = MT->model($obj_class)->load( $params, { sort => 'label' } );
    $out
      .= "      <select style=\"width: 300px;height:100px\" name=\"$field_id\" multiple=\"true\">\n";
    foreach my $cat (@cats) {
        my $found = 0;
        foreach (@values) {
            if ( $cat->id == $_ ) {
                $found = 1;
            }
        }
        $out
          .= "        <option value=\""
          . $cat->id . "\" "
          . ( $found ? " selected" : "" ) . ">"
          . $cat->label
          . "</option>\n";
    }
    $out .= "      </select>\n";
    return $out;
} ## end sub type_category_list

sub type_folder {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $ctx->stash( 'object_class', 'folder' );
    return type_category( $app, @_ );
}


sub _hdlr_field_value {
    my $plugin = shift;
    my ( $ctx, $args ) = @_;
    my $field = $ctx->stash('field') or return _no_field($ctx);
    my $value = _get_field_value($ctx);
    return $args->{default}
      if ( $args->{default} && ( !$value || $value eq '' ) );
    return $value;
}

sub _hdlr_field_asset {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field = $ctx->stash('field') or return _no_field($ctx);
    my $value = _get_field_value($ctx);
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

sub _hdlr_field_array_loop {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field  = $ctx->stash('field') or return _no_field($ctx);
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
    my $field = $ctx->stash('field') or return _no_field($ctx);
    my $value = $args->{'value'};
    my $array = _get_field_value($ctx);
    use Carp;
    ###l4p (ref $array eq 'ARRAY') or $logger->warn('_get_field_value did not return an array reference: '.($array||'')." ".Carp::longmess());
    foreach (@$array) {

        #MT->log("Does array contain $value? (currently checking $_)");
        if ( $_ eq $value ) {
            return $ctx->slurp( $args, $cond );
        }
    }
    require MT::Template::ContextHandlers;
    return MT::Template::Context::_hdlr_pass_tokens_else(@_);
}

sub _hdlr_field_category_list {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field = $ctx->stash('field') or return _no_field($ctx);
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

sub _get_field_value {
    my ($ctx) = @_;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $plugin_ns = $ctx->stash('plugin_ns');
    my $scope     = $ctx->stash('scope') || 'blog';
    my $field     = $ctx->stash('field');
    my $plugin    = MT->component($plugin_ns);        # is this necessary?
    my $value;
    my $blog = $ctx->stash('blog');
    if ( !$blog ) {
        my $blog_id = $ctx->var('blog_id');
        $blog = MT->model('blog')->load($blog_id);
    }
    if ( $blog && $blog->id && $scope eq 'blog' ) {
        $value = $plugin->get_config_value( $field, 'blog:' . $blog->id );
    }
    else {
        $value = $plugin->get_config_value($field);
    }
    ###l4p $logger->debug('$value: ', l4mtdump($value||''));
    return $value;
} ## end sub _get_field_value

sub _hdlr_field_link_group {
    my $plugin = shift;
    my ( $ctx, $args, $cond ) = @_;
    my $field = $ctx->stash('field') or return _no_field($ctx);
    my $value = _get_field_value($ctx);
    $value = '"[]"' if ( !$value || $value eq '' );
    eval "\$value = $value";
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

sub _hdlr_field_cond {
    my $plugin = shift;
    my ( $ctx, $args ) = @_;
    my $plugin_ns = $ctx->stash('plugin_ns');
    my $scope     = $ctx->stash('scope') || 'blog';
    my $field     = $ctx->stash('field') or return _no_field($ctx);

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

    my $types     = $app->registry('config_types');
    my $fieldsets = $cfg->{fieldsets};
    my $cfg_obj   = $plugin->get_config_hash($scope);

    require MT::Template::Context;
    my $ctx = MT::Template::Context->new();

    $fieldsets->{__global} = {
                               label => sub { "Global Options"; }
    };

    # this is a localized stash for field HTML
    my $fields;

    foreach my $optname (
        sort {
            ( $cfg->{$a}->{order} || 999 ) <=> ( $cfg->{$b}->{order} || 999 )
        } keys %{$cfg}
      )
    {
        next if $optname eq 'fieldsets';
        my $field = $cfg->{$optname};

        next
          if (    ( $field->{scope} eq 'blog' && $scope !~ /^blog:/ )
               || ( $field->{scope} eq 'system' && $scope ne 'system' ) );

        if ( my $cond = $field->{condition} ) {
            if ( !ref($cond) ) {
                $cond = $field->{condition} = $app->handler_to_coderef($cond);
            }
            next unless $cond->();
        }

        my $field_id = $optname;

        if ( $field->{'type'} eq 'separator' ) {

            # The separator "type" is handled specially here because it's not
            # really a "config type"-- it isn't editable and no data is saved
            # or retrieved. It just displays a separator and some info.
            my $out;
            my $show_label
              = defined $field->{show_label} ? %{ $field->{show_label} } : 1;
            my $label = $field->{label} ne '' ? &{ $field->{label} } : '';

            $out
              .= '  <div id="field-'
              . $field_id
              . '" class="field field-top-label pkg field-type-'
              . $field->{type} . '">' . "\n";
            $out .= "   <div class=\"field-header\">\n";
            $out .= "       <h3>$label</h3>\n" if $show_label;
            $out .= "   </div>\n";
            $out .= "   <div class=\"field-content\">\n";
            if ( $field->{hint} ) {
                $out .= "       <div>" . $field->{hint} . "</div>\n";
            }
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
              = defined $field->{show_label} ? %{ $field->{show_label} } : 1;
            my $label = $field->{label} ne '' ? &{ $field->{label} } : '';

            $out
              .= "  <div id=\"field-$field_id\" class=\"field"
              . ( $show_label == 1 ? " field-left-label" : "" )
              . ' pkg field-type-'
              . $field->{type} . '">' . "\n";
            $out .= "    <div class=\"field-header\">\n";
            $out .= "      <label for=\"$field_id\">$label</label>\n"
              if $show_label;
            $out .= "    </div>\n";
            $out .= "    <div class=\"field-content\">\n";
            my $hdlr = MT->handler_to_coderef(
                                    $types->{ $field->{'type'} }->{handler} );
            $out .= $hdlr->( $app, $ctx, $field_id, $field, $value );

            if ( $field->{hint} ) {
                $out
                  .= "      <div class=\"hint\">"
                  . $field->{hint}
                  . "</div>\n";
            }
            $out .= "    </div>\n";
            $out .= "  </div>\n";

            my $fs = $field->{fieldset};
            push @{ $fields->{$fs} }, $out;
        } ## end elsif ( $types->{ $field->...})
        else {
            MT->log( {
                       message => 'Unknown config type encountered: '
                         . $field->{'type'}
                     }
            );
        }
    } ## end foreach my $optname ( sort ...)
    my @loop;
    my $count = 0;
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
    $param->{html}        = $html;
    $param->{fieldsets}   = \@loop;
    $param->{leftovers}   = \@leftovers;
    $param->{blog_id}     = $blog->id if $blog;
    $param->{magic_token} = $app->current_magic;
    $param->{plugin_sig}  = $plugin->{plugin_sig};

    return MT->component('ConfigAssistant')
      ->load_tmpl( 'plugin_options.mtml', $param );
} ## end sub plugin_options

sub entry_search_api_prep {
    my $app = MT->instance;
    my ( $terms, $args, $blog_id ) = @_;
    my $q = $app->can('query') ? $app->query : $app->param;

    $terms->{blog_id} = $blog_id            if $blog_id;
    $terms->{status}  = $q->param('status') if ( $q->param('status') );

    my $search_api = $app->registry("search_apis");
    my $api        = $search_api->{entry};
    my $date_col   = $api->{date_column} || 'created_on';
    $args->{sort}      = $date_col;
    $args->{direction} = 'descend';
}

#sub entry_search_api_prep {
#    my $app = MT->instance;
#    my ( $terms, $args, $blog_id ) = @_;
#    $terms->{status} = $app->param('status') if ( $app->param('status') );
#}

sub list_entry_mini {
    my $app = shift;
    my $q = $app->can('query') ? $app->query : $app->param;

    my $blog_id  = $q->param('blog_id') || 0;
    my $obj_type = $q->param('class')   || 'entry';
    my $pkg      = $app->model($obj_type)
      or return "Invalid request: unknown class $obj_type";

    my $terms;
    $terms->{blog_id} = $blog_id if $blog_id;
    $terms->{status} = 2;

    my %args = ( sort => 'authored_on', direction => 'descend', );

    my $plugin = MT->component('ConfigAssistant')
      or die "OMG NO COMPONENT!?!";
    my $tmpl = $plugin->load_tmpl('entry_list.mtml');
    $tmpl->param( 'obj_type', $obj_type );
    return $app->listing( {
           type     => $obj_type,
           template => $tmpl,
           params   => {
                       panel_searchable => 1,
                       edit_blog_id     => $blog_id,
                       edit_field       => $q->param('edit_field'),
                       search           => $q->param('search'),
                       blog_id          => $blog_id,
           },
           code => sub {
               my ( $obj, $row ) = @_;
               $row->{ 'status_' . lc MT::Entry::status_text( $obj->status ) }
                 = 1;
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
               }
               return $row;
           },
           terms => $terms,
           args  => \%args,
           limit => 10,
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
                                      class_type  => $class,
                                      class_label => $obj->class_label,
                                      entry_id    => $obj->id,
                                      entry_title => $obj->title,
                                      edit_field  => $edit_field,
                                   }
    );
    return $tmpl;
} ## end sub select_entry

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
        class="primary-button"><__trans phrase="Save Changes"></button>
<mt:if name="plugin_settings_id">
      <button
        onclick="resetPlugin(getByID('plugin-<mt:var name="plugin_id">-form')); return false"
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
  <script src="<mt:StaticWebPath>jquery/jquery.js" type="text/javascript"></script>
  <script src="<mt:PluginStaticWebPath component="configassistant">js/options.js" type="text/javascript"></script>
</mt:setvarblock>
END_TMPL

# MT 4.34
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

