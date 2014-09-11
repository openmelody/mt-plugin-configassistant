package ConfigAssistant::ConfigTypes;

use strict;
use warnings;
use Carp qw( croak );

use ConfigAssistant::Util qw( fix_support_directories );

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

    my $blog_id = $app->blog ? $app->blog->id : '0';

    # Show the author display name, if a valid author has been saved already.
    my $author_display_name = '';
    if ($value) {
        $author_display_name = MT->model('author')->exist($value)
            ? MT->model('author')->load($value)->nickname
            : ''; # No author found
    }

    # If the author display name was set above, then create a remove button.
    my $remove_button = '';
    if ($author_display_name ne '') {
        $remove_button = '<img class="remove" '
            . 'src="' . $app->static_path . 'images/status_icons/close.gif" '
            . 'width="9" height="9" '
            . 'alt="Remove ' . $author_display_name . '" '
            . 'title="Remove ' . $author_display_name . '" />';
    }

    # If any roles were defined, supply them so that only valid authors can
    # be selected from the popup. Check for both keys "roles" and "role"
    # because it's easy to forget the "s"--I did it several times testing!
    my $valid_roles = $field->{roles} || $field->{role} || '';

    # The all_authors key will be true if all authors should appear in the
    # pop-up, regardless of blog association.
    my $all_authors = $field->{all_authors} || '';
    # If this is used as a Plugin Option at the system level, all authors are
    # also valid because there is no blog restriction.
    $all_authors = 1 if !$app->blog;

    my $button = '';
    if (MT->product_version =~ /^4/) {
        $button = "onclick=\"return openDialog(this.form, 'ca_select_author', "
            . "'blog_id=${blog_id}&all_authors=$all_authors&idfield=$field_id"
            . "&namefield=${field_id}_display_name')\"";
    }
    else {
        $button = "onclick=\"return jQuery.fn.mtDialog.open('" . $app->app_uri
            . "?__mode=ca_select_author&blog_id=${blog_id}&idfield=$field_id')\"";
    }

    my $out = <<HTML;
<script type="text/javascript">
    // Build the query string for the openDialog popup.
    var query_string = ''
        + 'blog_id=${blog_id}'
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
    <a
        class="button"
        $button
        >Choose Author
    </a>
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
    my $q     = $app->can('query') ? $app->query : $app->param;
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

    # Build the terms for the join used to find all of the users to display in
    # the popup.
    my $join_terms = {};
    if ( !$q->param('all_authors') && $q->param('blog_id') ) {
        $join_terms->{blog_id} = $q->param('blog_id');
    }

    # Load authors with permission on this blog
    my $author_roles = $q->param('roles');
    if ($author_roles) {
        my @roles = map { $_->id } MT->model('role')->load({ 
            name => [ split(/\s*,\s*/, $author_roles) ]
        });
        return unless @roles;

        $join_terms->{role_id} = \@roles;

        require MT::Association;
        $args->{join} = MT::Association->join_on(
            'author_id',
            $join_terms,
            { unique => 1, }
        );
    }

    # Roles have not been specified, so just grab any user with adequate
    # permission to post.
    else {
        $join_terms->{permissions} = { like => '%post%', };

        require MT::Permission;
        $args->{join} = MT::Permission->join_on(
            'author_id',
            $join_terms,
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
                panel_title       => $cur_author || '',
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
            },
        }
    );
}

# The `blogs` config type allows you to select a blog from the system.
sub type_blogs {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $class = $field->{class} || 'blog';
    my $out;

    my @blogs = MT->model('blog')->load(
        { class => , $class, },
        { sort => 'name', }
    );

    $out .= "      <select name=\"$field_id\">\n";
    $out
      .= "        <option value=\"0\" "
      . ( $value && 0 == $value ? " selected" : "" )
      . ">None Selected</option>\n";
    foreach (@blogs) {
        $out
          .= "        <option value=\""
          . $_->id . "\" "
          . ( $value && $value == $_->id ? " selected" : "" ) . ">"
          . $_->name
          . "</option>\n";
    }
    $out .= "      </select>\n";
    return $out;
} ## end sub type_blogs

# The `category` config type allows you to select a category from the blog.
# This field can be configured to show parent and child categories or parents
# only, as well as a single- or multiple-select list.
sub type_category {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;

    # If the saved value is an array of items, that means it's a multiple-
    # select list. If it's a single value, just push it into an array to work
    # with.
    $value = 0 unless defined $value;
    my @values = ref $value eq 'ARRAY' ? @$value : ($value);

    # If this is a multiple-select category list, it needs to be formatted as
    # such.
    my $multiple = ( $field->{multiple} )
        ? ' style="height: 100px;" multiple="true"'
        : '';

    my $terms = {};
    $terms->{blog_id} = $app->blog->id;

    # By default, show parent and child categories. Only exclude child
    # categories if explicitly set to do so (`show_children: 0`).
    if ( defined( $field->{show_children} ) && $field->{show_children} == 0 ) {
        $terms->{parent} = 0;
    }

    my $obj_class = 'category'
        unless $ctx->stash('object_class') eq 'folder';

    my @cats = MT->model($obj_class)->load(
        $terms,
        {
            sort      => 'label',
            direction => 'ascend',
        }
    );

    my $out = "<select name=\"$field_id\"$multiple>\n";
    # Add a "None Selected" option so categories can be de-selected.
    $out .= '    <option value="0" '
        . ((grep /^0$/, @values) ? ' selected' : '')
        . ">None Selected</option>\n";

    foreach my $cat (@cats) {
        my $cat_id = $cat->id;
        $out
            .= '    <option value="' . $cat->id . '"'
            . ((grep /^$cat_id$/, @values) ? ' selected' : '') . '>'
            . $cat->label
            . "</option>\n";
    }

    $out .= "</select>\n";
    return $out;
} ## end sub type_category

# Deprecated.
# The `category_list` config type is basically a multi-select category field.
sub type_category_list {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;

    # Set some default for how the old `category_list` field type is supposed
    # to work.
    $field->{multiple}      = 1;
    $field->{show_children} = ($field->{show_children}) ? 1 : 0;

    # Now just pass it to the standard `category` config type.
    type_category($app, $ctx, $field_id, $field, $value);
} ## end sub type_category_list

# The `checkbox` config type allows you to add a checkbox option.
sub type_checkbox {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;

    # If a previously saved value doesn't exist then be sure to set it as an
    # empty string.
    $value = '' if !$value;

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
    jQuery(function(jQuery) {
        jQuery('#%s').datetimepicker({
            dateFormat: 'yy-mm-dd',
            dayNamesMin: ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
            monthNames: ['- 01','- 02','- 03','- 04','- 05','- 06','- 07','- 08','- 09','- 10','- 11','- 12'],
            showMonthAfterYear: true,
            prevText: '&lt;',
            nextText: '&gt;',
            ampm: false,
            showSecond: true,
            timeFormat: 'hh:mm:ss', controlType: 'select'
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
    $ctx->stash('object_class',       'entry');
    $ctx->stash('object_class_label', 'Entry');
    return _type_object( $app, @_ );
}

# the `entry_or_page` config type allows you select an Entry or Page from the
# current blog or the system.
sub type_entry_or_page {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $ctx->stash('object_class',       'entry_or_page');
    $ctx->stash('object_class_label', 'Entry or Page');
    return _type_object( $app, @_ );
}

# This function is used by several of the config types: `entry_or_page`,
# `entry`, and `page`.
sub _type_object {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $blog_id     = $field->{all_blogs} ? 0 : $app->blog->id;
    my $obj_class   = $ctx->stash('object_class') || '';
    my $list_method = 'ca_config_' . $obj_class;
    my $out;
    my $obj;

    my $active   = '';
    my $inactive = '';

    my $label = $ctx->stash('object_class_label');
    $ctx->var( 'entry_class_label', $label);

    # If `multiple` is true, then the field should allow for many
    # Pages/Entries to be selected.
    my $multiple = $field->{multiple} ? 'multiple' : '';

    # If `inactive_area` is true, then a special inactive area should be
    # available to store (but not publish) entries.
    my $inactive_area = ($field->{inactive_area}) ? 1 : 0;

    # Add the sortable fields only if their can be multiple Entries/Pages, or
    # if the Inactive Area can be used.
    my $js = '';
    my $sortable = '';
    if ($multiple || $inactive_area) {
        # If the field allows multiple objects, or if it allows the inactive
        # area to be used, it's sortable.
        $sortable = ' sortable';
        # Add the JS to make things work.
        $js = <<JS;
    <script type="text/javascript">
        jQuery(document).ready(function() {
            jQuery('ul#${field_id}_preview, ul#${field_id}_inactive').sortable({
                revert: true,
                connectWith: '.${field_id}_sortable',
                stop: function(event, ui) {
                    var active   = new Array();
                    var inactive = new Array();

                    jQuery('ul#${field_id}_preview li').each(function(index,value){
                        var id = jQuery(this).attr('id');
                        id = id.replace('obj-','');
                        active.push(id);
                    });

                    jQuery('ul#${field_id}_inactive li').each(function(index,value){
                        var id = jQuery(this).attr('id');
                        id = id.replace('obj-','');
                        inactive.push(id);
                    });

                    jQuery('#$field_id').val( 'active:' + active.join(',') + ';inactive:' + inactive.join(',') );
                }
            }).disableSelection();
        });
    </script>
JS
    }

    # The $value is an array of object IDs. Only if $value exists should we
    # try to load the objects. Otherwise, the most recent entry/page is loaded
    # and the $obj_name is incorrectly populated with the most recent object
    # title. This way, $obj_name is blank if there is no $value, which is
    # clearer to the user.
    if ($value) {
        my ($active_ids,$inactive_ids) = split(';', $value);

        if ($active_ids) {
            $active_ids  =~ s/active://; # Strip the leading identifier
            my @active_ids = split(',', $active_ids);
            foreach my $id (@active_ids) {
                my $obj = MT->model('entry')->load($id)
                    or next;

                # Build the list item HTML.
                $active .= _entry_list_item({
                    object   => $obj,
                    sortable => $sortable,
                    field_id => $field_id,
                    app      => $app,
                });
            }
        }

        if ($inactive_ids) {
            $inactive_ids  =~ s/inactive://; # Strip the leading identifier
            my @inactive_ids = split(',', $inactive_ids);
            foreach my $id (@inactive_ids) {
                my $obj = MT->model('entry')->load($id)
                    or next;

                # Build the list item HTML.
                $inactive .= _entry_list_item({
                    object   => $obj,
                    sortable => $sortable,
                    field_id => $field_id,
                    app      => $app,
                });
            }
        }
    }
    else {
        $value = ''; # To suppress a warning.
    }

    my $inactive_area_html = '';
    if ($inactive_area) {
        $inactive_area_html = <<INACTIVE_AREA;
        <div class="inactive-container">
            <p>$label inactive area</p>
            <ul id="${field_id}_inactive" class="${field_id}_sortable">
$inactive
            </ul>
        </div>
INACTIVE_AREA
    }

    my $button = '';
    if (MT->product_version =~ /^4/) {
        $button = "onclick=\"return openDialog(this.form, '$list_method', "
            . "'blog_id=$blog_id&edit_field=$field_id&class=$obj_class')\"";
    }
    else {
        $button = "onclick=\"return jQuery.fn.mtDialog.open('" 
            . $app->app_uri . "?__mode=$list_method&blog_id=$blog_id"
            . "&edit_field=$field_id&class=$obj_class')\"";
    }

    $out .= <<EOH;
$js
    <div class="pkg">
        <input name="$field_id"
            id="$field_id"
            class="hidden"
            type="hidden"
            value="$value" />

        <a type="submit"
            $button
            class="button">
            Choose $label
        </a>

        <div class="active-container">
            <ul id="${field_id}_preview"
                class="preview $multiple ${field_id}_sortable">
$active
            </ul>
        </div>
$inactive_area_html
    </div>
EOH

    return $out;
}

# Build the list item HTML used for the Entry or Page field type.
sub _entry_list_item {
    my ($arg_ref) = @_;
    my $obj      = $arg_ref->{object};
    my $sortable = $arg_ref->{sortable};
    my $field_id = $arg_ref->{field_id};
    my $app      = $arg_ref->{app};

    my $static_path = $app->static_path;
    my $mt_uri      = $app->mt_uri;

    my $obj_name = ( $obj ? $obj->title : '' ) || '';
    my $class_label = $obj->class_label;

    my $html .= "\t\t\t\t" 
        . '<li id="obj-' . $obj->id 
        . '" class="obj-type obj-type-' . $obj->class . $sortable
        . '"><span class="obj-title">' . $obj_name 
        . '</span>' . "\n\t\t\t\t\t"
        # Edit button
        . '<a href="'. $mt_uri . '?__mode=view&amp;_type='
        . lc($class_label) . '&amp;id=' . $obj->id . '&amp;blog_id='
        . $obj->blog_id . '" target="_blank"'
        . ' title="Edit in a new window.">'
        . '<img src="' . $static_path 
        . 'images/status_icons/draft.gif" width="9" height="9"'
        . ' alt="Edit" />'
        . '</a> ' . "\n\t\t\t\t\t"
        # View button
        . '<a href="' . $obj->permalink . '" target="_blank"'
        . ' title="View in a new window.">'
        . '<img src="' . $static_path
        . 'images/status_icons/view.gif" width="13" height="9"'
        . ' alt="View" />'
        . '</a> ' . "\n\t\t\t\t\t"
        # The remove button
        . '<a href="javascript:void(0);" onclick="removeCustomFieldEntry(\'' 
        . "$field_id','" . $obj->id 
        . '\')" title="Remove this ' . $class_label . '"><img src="'
        . $static_path . 'images/status_icons/close.gif" '
        . ' width="9" height="9" alt="Remove" /></a>' . "\n\t\t\t\t"
        # Close the list item.
        . "</li>\n";

    return $html;
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
            # Fix support directories (likely a problem when moving from MT4 to 5.)
            ($asset) = fix_support_directories( $asset );

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

# Deprecated.
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
          . $_->{'url'} . '" target="_blank">'
          . $_->{'label'}
          . '</a> <img class="edit" src="' . $static
          . 'images/status_icons/draft.gif" alt="Edit" title="Edit" /> '
          . '<img class="remove" src="' . $static
          . 'images/status_icons/close.gif" alt="Remove" title="Remove" />'
          . '</li>'
          . "\n";
    }
    $html
      .= "          <li class=\"last\">"
      . "<span class=\"button add-link\">Add Link</span>"
      . "</li>\n"
      . "    </ul>\n"
      . "</div>\n"
      . "<input type=\"hidden\" id=\"$field_id\" name=\"$field_id\" value=\""
      . encode_html( $value, 1
      )    # The additional "1" will escape HTML entities properly
      . "\" />\n<script type=\"text/javascript\">
  jQuery('#'+'$field_id-link-group').parents('form').submit( function (){
    var struct = Array();
    jQuery(this).find('#'+'$field_id-link-group ul li a.link').each( function(i, e) {
      var u = jQuery(this).attr('href');
      var l = jQuery(this).html();
      struct.push( { 'url': u, 'label': l } );
    });
    var json = struct.toJSON().escapeJS();
    jQuery('#'+'$field_id').val( json );
  });
  jQuery('#'+'$field_id-link-group ul li span.add-link').click( handle_edit_click );
  jQuery('#'+'$field_id-link-group ul li img.remove').click( handle_delete_click );
  jQuery('#'+'$field_id-link-group ul li img.edit').click( handle_edit_click );
</script>\n";
    return $html;
} ## end sub type_link_group

# The `page` config type is analagous to the `entry` config type: it will let
# you choose a Page from a blog or system.
sub type_page {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    $ctx->stash('object_class',       'page');
    $ctx->stash('object_class_label', 'Page');
    return _type_object( $app, @_ );
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

    $out .= "      <ul class=\"full full-width\">\n";
    foreach my $option (@values) {

        # $el_id ("element ID") is used as a unique identifier so that the
        # label can be clickable to select the radio button.
        my $el_id = $field_id . '_' . dirify($option);
        $out
          .= "        <li><input type=\"radio\" name=\"$field_id\""
          . " id=\"$el_id\" value=\"$option\""
          . ( $value && $value eq $option ? " checked=\"checked\"" : "" )
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

    my $out .= "      <select name=\"$field_id\" class=\"full\">\n";

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
          .= '        <li><span class="content">'
          . $_->{'label'}
          . '</span>'
          . '<img class="edit" src="' . $static
          . 'images/status_icons/draft.gif" alt="Edit" title="Edit" /> '
          . '<img class="remove" src="' . $static
          . 'images/status_icons/close.gif" alt="Remove" title="Remove" />'
          . "</li>\n";
    }
    $html
      .= "          <li class=\"last\">"
      . "<span class=\"button add-item\">Add Item</span>"
      . "</li>\n"
      . "    </ul>\n"
      . "</div>\n"
      . "<input type=\"hidden\" id=\"$field_id\" name=\"$field_id\" value=\""
      . encode_html( $value, 1
      )    # The additional "1" will escape HTML entities properly
      . "\" />\n<script type=\"text/javascript\">
  jQuery('#'+'$field_id-text-group').parents('form').submit( function (){
    var struct = Array();
    jQuery(this).find('#'+'$field_id-text-group ul li span.content').each( function(i, e) {
      var l = jQuery(this).html();
      struct.push( { 'label': l } );
    });
    var json = struct.toJSON().escapeJS();
    jQuery('#'+'$field_id').val( json );
  });
  jQuery('#'+'$field_id-text-group ul li span.add-item').click( text_handle_edit_click );
  jQuery('#'+'$field_id-text-group ul li img.remove').click( text_handle_delete_click );
  jQuery('#'+'$field_id-text-group ul li img.edit, #' + '$field_id-text-group ul li span.content').click( text_handle_edit_click );
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
      . "\" class=\"text full full-width\" />\n";
}

# The `textarea` config type produced a form textarea for you to enter text.
# The number of rows can be specified with the `rows` key.
sub type_textarea {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $rows = $field->{rows} || '';
    my $rows_class = 'low';
    if ( $rows && $rows > 4 && $rows < 11 ) {
        $rows_class = 'high';
    }
    elsif ( $rows && $rows > 11 ) {
        $rows_class = 'highest';
    }
    
    my $out;
    $out = "      <textarea name=\"$field_id\" class=\"text full $rows_class full-width\" rows=\""
      . $rows . "\">";

    # The additional "1" below will escape HTML entities properly
    $out .= encode_html( $value, 1 );
    $out .= "</textarea>\n";
    return $out;
}

1;

__END__
