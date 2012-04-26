package ConfigAssistant::ConfigTypes;

use strict;
use warnings;
use Carp qw( croak );

use MT::Util qw ( encode_html dirify );
# use MT::Util
#   qw( relative_date      offset_time    offset_time_list    epoch2ts
#       ts2epoch format_ts encode_html    decode_html         dirify );
# use ConfigAssistant::Util
#   qw( find_theme_plugin     find_template_def   find_option_def
#       find_option_plugin    process_file_upload 
#       plugin_static_web_path plugin_static_file_path );
#use JSON;
# use MT::Log::Log4perl qw( l4mtdump ); use Log::Log4perl qw( :resurrect );
our $logger;

# The `author` config type allows you to select an author from the system.
sub type_author {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $value ||= ''; # Define $value if no saved/default.
    my $blog_id = $app->blog->id;

    # Show the author display name, if a valid author has been saved already.
    my $author_display_name = '';
    if ($value) {
        $author_display_name = MT->model('author')->load($value)
            ? MT->model('author')->load($value)->nickname
            : ''; # No author found
    }

    # If the author display name was set above, then create a remove button.
    my $remove_button = '';
    if ($author_display_name ne '') {
        $remove_button = '<a href="javascript:void(0);" '
            . 'onclick="removeAuthor(\'' . $field_id . '\')" '
            . 'id="' . $field_id . '_remove_button" '
            . 'class="remove-item-button">'
            . '    <img src="' . $app->static_path . 'images/status_icons/close.gif" '
            . '        width="9" height="9" '
            . '        alt="Remove ' . $author_display_name . '" '
            . '        title="Remove ' . $author_display_name . '" />'
            . '</a>';
    }

    # If any roles were defined, supply them so that only valid authors can
    # be selected from the popup. Check for both keys "roles" and "role"
    # because it's easy to forget the "s"--I did it several times testing!
    my $valid_roles = $field->{roles} || $field->{role} || '';

    # The all_authors key will be true if all authors should appear in the
    # pop-up, regardless of blog association.
    my $all_authors = $field->{all_authors};

    my $out = <<HTML;
<script type="text/javascript">
    // Build the query string for the openDialog popup.
    var query_string = ''
        + 'blog_id=$blog_id'
        + '&all_authors=$all_authors'
        + '&idfield=$field_id'
        + '&namefield=${field_id}_display_name';

    if ( jQuery('#'+'${field_id}_display_name').text() ) {
        query_string += '&cur_author_display_name' 
            + jQuery('#'+'${field_id}_display_name').text();
    }

    var roles = '$valid_roles';
    if (roles) {
        query_string += '&roles=' + roles;
    }
</script>
<div class="pkg">
    <input name="$field_id" id="$field_id" class="hidden" type="hidden" value="$value" />
    <button 
        type="submit"
        onclick="return openDialog(this.form, 'ca_select_author', query_string)">
        Choose Author
    </button>
    <div id="${field_id}_display_name" class="preview">
        $author_display_name
    </div>
    $remove_button
</div>
HTML

    return $out;
}

# The author config type uses a popup dialog to select an author. This is that
# popup dialog.
sub select_author {
    my $app   = shift;
    my $q     = $app->query;
    my $param = {};

    # If an author has already been selected, show their display name. This is
    # just helpful to see who I picked.
    my $cur_author = $q->param('cur_author_display_name')
        ? $app->translate("Current author: ") 
            . $q->param('cur_author_display_name')
        : '';

    # Create the arguments for the listing screen based on whether roles have
    # been specified to filter on.
    my $args = {};
    $args->{sort} = 'name';

    # Load authors with permission on this blog
    my $author_roles = $q->param('roles');
    if ($author_roles) {
        my @roles = map { $_->id } MT->model('role')->load({ 
            name => [ split(/\s*,\s*/, $author_roles) ]
        });
        return unless @roles;

        require MT::Association;
        $args->{join} = MT::Association->join_on(
            'author_id', 
            {
                role_id => \@roles,
                blog_id => $app->param('all_authors') 
                    ? {like => '%'} # Grab authors in any blog
                    : $app->param('blog_id'), 
            },
            { unique => 1, }
        );
    }

    # Roles have not been specified, so just grab any user with adequate
    # permission to post.
    else {
        require MT::Permission;
        $args->{join} = MT::Permission->join_on(
            'author_id', 
            {
                blog_id => $app->param('all_authors') 
                    ? {like => '%'} # Grab authors in any blog
                    : $app->param('blog_id'), 
                permissions => { like => '%post%', } 
            },
            { unique => 1, }
        );
    }

    my $hasher = sub {
        my ( $obj, $row ) = @_;
        $row->{label}       = $row->{name};
        $row->{description} = $row->{nickname};
    };

    # MT::CMS::User::dialog_select_author mostly does what is needed, so that
    # served as the starting point. We're supplying an argument list to 
    # augment it.
    $app->listing(
        {
            type  => 'author',
            terms => {
                type   => MT::Author::AUTHOR(),
                status => MT::Author::ACTIVE(),
            },
            args     => $args,
            code     => $hasher,
            template => 'select_author.mtml',
            params   => {
                dialog_title =>
                  $app->translate("Select an author"),
                items_prompt =>
                  $app->translate("Selected author"),
                search_prompt => $app->translate(
                    "Type a username to filter the choices below."),
                panel_title       => $cur_author,
                panel_label       => $app->translate("Author Username"),
                panel_description => $app->translate("Author Display Name"),
                panel_type        => 'author',
                panel_multi       => defined $app->param('multi')
                ? $app->param('multi')
                : 0,
                panel_searchable => 1,
                panel_first      => 1,
                panel_last       => 1,
                list_noncron     => 1,
                idfield          => $app->param('idfield'),
                namefield        => $app->param('namefield'),
            },
        }
    );
}

# The `blogs` config type allows you to select a blog from the system.
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

# The `category` config type allows you to select a category from the blog.
sub type_category {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $value = defined($value) ? $value : '';
    my $out;
    my $obj_class = $ctx->stash('object_class') || 'category';
    my @cats = MT->model($obj_class)
      ->load( { blog_id => $app->blog->id }, { sort => 'label' } );
    $out .= "      <select name=\"$field_id\">\n";
    $out
      .= "        <option value=\"0\" "
      . ( $value eq '' ? " selected" : "" )
      . ">None Selected</option>\n";

    foreach (@cats) {
        $out
          .= "        <option value=\""
          . $_->id . "\" "
          . ( $value eq $_->id ? " selected" : "" ) . ">"
          . $_->label
          . "</option>\n";
    }
    $out .= "      </select>\n";
    return $out;
} ## end sub type_category

# The `category_list` config type allows you to select several categories from
# the blog using a multi-select list.
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

# The `checkbox` config type allows you to add a checkbox option.
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

# Used with the `checkbox` config type.
sub in_array {
    my ( $arr, $search_for ) = @_;
    foreach my $value (@$arr) {
        return 1 if $value eq $search_for;
    }
    return 0;
}

# The `colorpicker` config type allows you to select a color from a jQuery
# clickable interface. The hex value is saved.
sub type_colorpicker {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    return
      "      <div id=\"$field_id-colorpicker\" class=\"colorpicker-container\"><div style=\"background-color: $value\"></div></div><input type=\"hidden\" id=\"$field_id\" name=\"$field_id\" value=\""
      . encode_html( $value, 1
      )    # The additional "1" will escape HTML entities properly
      . "\" />\n<script type=\"text/javascript\">jQuery('#'+'$field_id-colorpicker').ColorPicker({
        color: '$value',
        onShow: function (colpkr) {
            jQuery(colpkr).fadeIn(500);
            return false;
        },
        onHide: function (colpkr) {
            jQuery(colpkr).fadeOut(500);
            return false;
        },
        onChange: function (hsb, hex, rgb) {
            jQuery('#'+'$field_id-colorpicker div').css('backgroundColor', '#' + hex);
            jQuery('#'+'$field_id').val('#' + hex).trigger('change');
        }
    });</script>\n";
} ## end sub type_colorpicker

# The `datetime` config type allows you to select a date and time stamp.
sub type_datetime {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $value = 0 unless defined $value;
    my @values = ref $value eq 'ARRAY' ? @$value : ($value);
    my $out;

    my $js = <<JS;
<script type="text/javascript">
    jQuery(function(\$) {
        \$('#%s').datetimepicker({
            ampm: false,
            showSecond: true,
            timeFormat: 'hh:mm:ss'
        });
    });
</script>
JS

    $out = sprintf('<input type="text" name="%s" id="%s" class="ca-datetime" value="%s"/>',
                $field_id, $field_id, $value);
    $out .= sprintf($js, $field_id);

    return $out;
} ## end sub type_datetime

# The `entry` config type allows you select an Entry from a blog.
sub type_entry {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my $obj_class = $ctx->stash('object_class') || 'entry';
    my $obj;
    my $obj_name = ''; # A default value to alleviate warnings.
    my $obj_id   = ''; # Same!
    my $obj_blog_id = '';

    # The $value is the object ID. Only if $value exists should we try to 
    # load the object. Otherwise, the most recent entry/page is loaded
    # and the $obj_name is incorrectly populated with the most recent object
    # title. This way, $obj_name is blank if there is no $value, which is
    # clearer to the user.
    if ($value) {
        $obj         = MT->model($obj_class)->load($value);
        $obj_name    = ( $obj ? $obj->title : '' ) || '';
        $obj_id      = ( $obj ? $obj->id : 0 ) || '';
        $obj_blog_id = $obj->blog_id;
    }
    else {
        $value = '';
    }

    my $blog_id   = $field->{all_blogs} ? 0 : $app->blog->id;
    unless ( $ctx->var('entry_chooser_js') ) {
        $out .= <<EOH;
    <script type="text/javascript">
        function removeCustomFieldEntry(el_id, val) {
            var orig = \$('#'+el_id).val();
            var newval = '';
            var ids = orig.split(',');
            for (var i = 0; i < ids.length; i++) {
                if (ids[i] != val) {
                    if (newval != '') newval += ',';
                    newval += ids[i];
                }
            }
            \$('#'+el_id).val(newval);
            \$('#'+el_id+'_preview').remove();
        }
        function insertCustomFieldEntry(title, obj_class, entry_id, blog_id, el_id) {
            jQuery('#'+el_id).val(entry_id);
            try {
                jQuery('#'+el_id+'_preview').html(
                    title 
                    + ' (<a href="?__mode=edit&_type=entry' 
                    + '&blog_id=' + blog_id + '&id=' + entry_id 
                    + '">edit ' + obj_class + '</a>)'
                );
            } catch(e) {
                log.error(e);
            };
        }
    </script>
EOH
        $ctx->var( 'entry_chooser_js', 1 );
    }
    my $class = MT->model($obj_class);
    my $label = $class->class_label;
    my $label_lc = lc($label);
    $ctx->var( 'entry_class_label', $label );
    $ctx->var( 'entry_class_labelp', $class->class_label_plural );

    my $edit_link = $value
        ? "(<a href=\"?__mode=edit&_type=$label_lc&blog_id=$obj_blog_id"
            . "&id=$obj_id\">edit $label_lc</a>) "
            . '<a href="javascript:void(0);" onclick="removeCustomFieldEntry(\'' 
            . $field_id . '\',' . $obj_id 
            . ')"><img src="' . $app->static_path
            . 'images/status_icons/close.gif" width="9" height="9" alt="Remove ' 
            . $label_lc . '" title="Remove ' . $label_lc . '" /></a>'
        : '';

    $out .= <<EOH;
<div class="pkg">
  <input name="$field_id" id="$field_id" class="hidden" type="hidden" value="$value" />
  <button type="submit"
          onclick="return openDialog(this.form, 'ca_config_entry', 'blog_id=$blog_id&edit_field=$field_id&status=2&class=$obj_class')">Choose $label</button>
  <div id="${field_id}_preview" class="preview">
    $obj_name
    $edit_link
  </div>
</div>
EOH
    $ctx->stash('object_class','');
    return $out;
} ## end sub type_entry

# the `entry_or_page` config type allows you select an Entry or Page from the
# current blog or the system.
sub type_entry_or_page {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my $obj;
    my $obj_class = 'entry';
    my $blog_id = $field->{all_blogs} ? 0 : $app->blog->id;
    my $preview = '';
    my $static_path = $app->static_path;

    unless ( $ctx->var('entry_chooser_js') ) {
        $out .= <<EOH;
        <script type="text/javascript">
            function removeCustomFieldEntry(id, val) {
                var orig = \$('#'+id).val();
                var newval = '';
                var ids = orig.split(',');
                for (var i = 0; i < ids.length; i++) {
                    if (ids[i] != val) {
                        if (newval != '') newval += ',';
                        newval += ids[i];
                    }
                }
                \$('#'+id).val(newval);
                \$('#'+id+'_preview #obj-'+val).remove();
            }
            function insertCustomFieldEntry(title, obj_class, entry_id, blog_id, el_id) {

                var orig = \$('#'+el_id).val();
                var is_mult = \$('#'+el_id+'_preview').hasClass('multiple');
                var newval;
                if (is_mult) { 
                    new_entry_id = orig ? orig + ',' + entry_id : entry_id;
                } else {
                    new_entry_id = entry_id;
                }
                \$('#'+el_id).val( new_entry_id );

                try {
                    var html = '<li id="obj-' + entry_id 
                        + '" class="obj-type obj-type-' + obj_class 
                        + '"><span class="obj-title">' + title 
                        + '</span> <a href="javascript:void(0);" onclick="removeCustomFieldEntry(' 
                        + el_id + ',' + entry_id + ')"><img src="${static_path}images/status_icons/close.gif" width="9" height="9" alt="Remove ' + obj_class + '" title="Remove ' + obj_class + '" /></a></li>';

                    if ( is_mult ) {
                      \$('#'+el_id+'_preview').append(html);
                    } else {
                      \$('#'+el_id+'_preview').html(html);
                    }
                } catch(e) {
                    log.error(e);
                };
            }
        </script>
EOH
        $ctx->var( 'entry_chooser_js', 1 );
    }

    # The $value is the object ID. Only if $value exists should we try to
    # load the object. Otherwise, the most recent entry/page is loaded
    # and the $obj_name is incorrectly populated with the most recent object
    # title. This way, $obj_name is blank if there is no $value, which is
    # clearer to the user.
    if ($value) {
        my @ids = split(',',$value);
        foreach my $id (@ids) {
            my $obj = MT->model('entry')->load($id)
                or next;
            my $obj_name = ( $obj ? $obj->title : '' ) || '';
            my $class_label = $obj->class_label;

            $preview .= '<li id="obj-' . $obj->id 
                . '" class="obj-type obj-type-' . $obj->class 
                . '"><span class="obj-title">' . $obj_name 
                . '</span> <a href="javascript:void(0);" onclick="removeCustomFieldEntry(\'' 
                . $field_id . '\',' . $obj->id 
                . ')"><img src="' . $static_path
                . 'images/status_icons/close.gif" width="9" height="9" alt="Remove ' 
                . $class_label . '" title="Remove ' . $class_label . '" /></a></li>';
        }
    }
    else {
        $value = ''; # To suppress a warning.
    }

    my $label = 'Entry or Page';
    $ctx->var( 'entry_class_label', $label );
    my $multiple = '';
    if ($field->{multiple}) { $multiple = 'multiple'; }
    $out .= <<EOH;
    <div class="pkg">
      <input name="$field_id" id="$field_id" class="hidden" type="hidden" value="$value" />
      <button type="submit"
              onclick="return openDialog(this.form, 'ca_config_entry_or_page', 'blog_id=$blog_id&edit_field=$field_id')">Choose $label</button>
      <ul id="${field_id}_preview" class="preview $multiple">
        $preview
      </ul>
    </div>
EOH

    return $out;
}

# The `file` config type allows you to select a file to upload, which is
# turned into an asset.
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
              . "\">view</a> | <a href=\"javascript:void(0)\" class=\"remove\">remove</a></p>\n";
        }
        else {
            $html .= "<p>Selected asset could not be found. <a href=\"javascript:void(0)\" class=\"remove\">reset</a></p>\n";
        }
    }
    $html .= "      <input type=\"file\" name=\"$field_id\" class=\"full-width\" />\n" .
             "      <input type=\"hidden\" name=\"$field_id-clear\" value=\"0\" class=\"clear-file\" />\n";

    $html .= "<script type=\"text/javascript\">\n";
    $html .= "  jQuery('#field-".$field_id." a.remove').click( handle_remove_file );\n";
    $html .= "</script>\n";

    return $html;
} ## end sub type_file

# The `folder` config type is analagous to the `category` config type; it lets
# you select a Folder in the blog or system.
sub type_folder {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $ctx->stash( 'object_class', 'folder' );
    return type_category( $app, @_ );
}

# The `folder_list` config type is analagous to the `category_list` config
# type; it lets you make a multiple selection of Folders in the blog or
# system.
sub type_folder_list {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $ctx->stash( 'object_class', 'folder' );
    return type_category_list( $app, @_ );
}

# The `link-group` config type allows you to build a link list by specifying
# a URL and link title.
sub type_link_group {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $static = $app->static_path;
    $value = '"[]"' if ( !$value || $value eq '' );
    eval "\$value = \"$value\"";
    if ($@) { $value = '"[]"'; }
    my $list;
    eval { $list = JSON::from_json($value) };
    if ($@) { $list = []; }
    my $html;
    $html
      = "<div id=\"$field_id-link-group\" class=\"link-group-container pkg\">\n"
      . "    <ul>\n";

    foreach (@$list) {
        $html
          .= '        <li><a class="link" href="'
          . $_->{'url'} . '">'
          . $_->{'label'}
          . '</a> <a class="remove" href="javascript:void(0);"><img src="'
          . $static
          . '/images/icon_close.png" alt="remove" title="remove" /></a> '
          . '<a class="edit" href="javascript:void(0);">edit</a></li>' . "\n";
    }
    $html
      .= "          <li class=\"last\">"
      . "<a href=\"javascript:void(0);\" class=\"add-link\">Add Link</a>"
      . "</li>\n"
      . "    </ul>\n"
      . "</div>\n"
      . "<input type=\"hidden\" id=\"$field_id\" name=\"$field_id\" value=\""
      . encode_html( $value, 1
      )    # The additional "1" will escape HTML entities properly
      . "\" />\n<script type=\"text/javascript\">
  jQuery('#'+'$field_id-link-group').parents('form').submit( function (){
    var struct = Array();
    jQuery(this).find('#'+'$field_id-link-group ul li button').trigger('click');
    jQuery(this).find('#'+'$field_id-link-group ul li a.link').each( function(i, e) {
      var u = jQuery(this).attr('href');
      var l = jQuery(this).html();
      struct.push( { 'url': u, 'label': l } );
    });
    var json = struct.toJSON().escapeJS();
    jQuery('#'+'$field_id').val( json );
  });
  jQuery('#'+'$field_id-link-group ul li a.add-link').click( handle_edit_click );
  jQuery('#'+'$field_id-link-group ul li a.remove').click( handle_delete_click );
  jQuery('#'+'$field_id-link-group ul li a.edit').click( handle_edit_click );
</script>\n";
    return $html;
} ## end sub type_link_group

# The `page` config type is analagous to the `entry` config type: it will let
# you choose a Page from a blog or system.
sub type_page {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $ctx->stash( 'object_class', 'page' );
    return type_entry( $app, @_ );
}

# The `radio` config type creates radio buttons of options for you to choose
# from.
sub type_radio {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;

    # Use the delimiter specified for the field, or fall back to the comma.
    # Split the values with the delimiter, but cut out any white space on 
    # either side of the value.
    my $delimiter = $field->{delimiter} || ',';
    my @values = split( /\s*$delimiter\s*/, $field->{values} );

    $out .= "      <ul>\n";
    foreach my $option (@values) {

        # $el_id ("element ID") is used as a unique identifier so that the
        # label can be clickable to select the radio button.
        my $el_id = $field_id . '_' . dirify($option);
        $out
          .= "        <li><input type=\"radio\" name=\"$field_id\""
          . " id=\"$el_id\" value=\"$option\""
          . ( $value eq $option ? " checked=\"checked\"" : "" )
          . " class=\"rb\" />"

          # Add a space between the input field and the label so that the
          # label text isn't bumped up right next to the radio button.
          . " <label for=\"$el_id\">$option</label>" . "</li>\n";
    }
    $out .= "      </ul>\n";
    return $out;
} ## end sub type_radio

# The `radio-image` config type creates radio buttons but uses images as the
# display item instead of text.
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

# The `select` config type creates a drop down select window for you to choose
# an option from.
sub type_select {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $value ||= '';

    # Use the delimiter specified for the field, or fall back to the comma.
    # Split the values with the delimiter, but cut out any white space on 
    # either side of the value.
    my $delimiter = $field->{delimiter} || ',';
    my @values = split( /\s*$delimiter\s*/, $field->{values} );

    my $out .= "      <select name=\"$field_id\">\n";

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

# The `tagged-entry` config type allows you to select from a filtered list of
# entries. The filter is a tag, also set in the theme's options.
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

# The `text-group` config type produces a list of text labels.
sub type_text_group {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $static = $app->static_path;
    $value = '"[]"' if ( !$value || $value eq '' );
    eval "\$value = \"$value\"";
    if ($@) { $value = '"[]"'; }
    my $list;
    eval { $list = JSON::from_json($value) };
    if ($@) { $list = []; }
    my $html;
    $html
      = "<div id=\"$field_id-text-group\" class=\"text-group-container pkg\">\n"
      . "    <ul>\n";

    foreach (@$list) {
        $html
          .= '        <li><span class="text">'
          . $_->{'label'}
          . '</span> <a class="remove" href="javascript:void(0);"><img src="'
          . $static
          . '/images/icon_close.png" alt="remove" title="remove" /></a> '
          . '<a class="edit" href="javascript:void(0);">edit</a></li>' . "\n";
    }
    $html
      .= "          <li class=\"last\">"
      . "<a href=\"javascript:void(0);\" class=\"add-item\">Add Item</a>"
      . "</li>\n"
      . "    </ul>\n"
      . "</div>\n"
      . "<input type=\"hidden\" id=\"$field_id\" name=\"$field_id\" value=\""
      . encode_html( $value, 1
      )    # The additional "1" will escape HTML entities properly
      . "\" />\n<script type=\"text/javascript\">
  jQuery('#'+'$field_id-text-group').parents('form').submit( function (){
    var struct = Array();
    jQuery(this).find('#'+'$field_id-text-group ul li button').trigger('click');
    jQuery(this).find('#'+'$field_id-text-group ul li span.text').each( function(i, e) {
      var l = jQuery(this).html();
      struct.push( { 'label': l } );
    });
    var json = struct.toJSON().escapeJS();
    jQuery('#'+'$field_id').val( json );
  });
  jQuery('#'+'$field_id-text-group ul li a.add-item').click( text_handle_edit_click );
  jQuery('#'+'$field_id-text-group ul li a.remove').click( text_handle_delete_click );
  jQuery('#'+'$field_id-text-group ul li a.edit').click( text_handle_edit_click );
</script>\n";
    return $html;
} ## end sub type_text_group

# The `text` config type creates a simple text input field.
sub type_text {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    return "      <input type=\"text\" name=\"$field_id\" value=\""
      . encode_html( $value, 1
      )    # The additional "1" will escape HTML entities properly
      . "\" class=\"full-width\" />\n";
}

# The `textarea` config type produced a form textarea for you to enter text.
# The number of rows can be specified with the `rows` key.
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

1;

__END__
