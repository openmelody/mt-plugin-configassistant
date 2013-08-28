// Utility Functions

// `link-group` config type
function handle_edit_click() {
    var p = jQuery(this).parent();
    var link = p.find('a.link');
    if (link.length > 0) {
        p.replaceWith( render_link_form( link.html(), link.attr('href') ) );
    } else {
        p.before( render_link_form( '','' ) );
        p.hide();
    }
    p.parent().find('input.label').focus();
    return false;
};

function render_link(label,url) {
    var dom = '<li class="pkg"><a class="link" href="'+url+'" target="_blank">'
        + label + '</a> '
        + '<img class="edit" src="' + StaticURI
        + 'images/status_icons/draft.gif" alt="Edit" title="Edit" /> '
        + '<img class="remove" src="' + StaticURI
        + 'images/status_icons/close.gif" alt="Remove" title="Remove" /></li>';
    var e = jQuery(dom);
    e.find('img.edit').click( handle_edit_click );
    e.find('img.remove').click( handle_delete_click );
    return e;
};

function handle_save_click() {
    var label = jQuery(this).parent().find('input[class=label]').val();
    var url = jQuery(this).parent().find('input[class=url]').val();
    if (!label && !url) { return false; }
    jQuery(this).parents('ul').find('li.last').show();
    jQuery(this).parent().replaceWith( render_link(label,url) );
    return false;
};

function handle_delete_click() {
    jQuery(this).parent().remove(); return false;
};

function render_link_form(label,url) {
    var dom = '<li><label class="link-text">'
        + 'Label: <input type="text" class="label" value="'
        + (typeof label != 'undefined' ? label : '')
        + '" /></label>'
        + '<label class="link-url">URL: <input type="text" class="url" value="'
        + (typeof url != 'undefined' ? url : '')
        + '" /></label> <span class="button">Save</span></li>';
    var e = jQuery(dom);
    e.find('span.button').click( handle_save_click );
    e.find('input.url').focus( function() {
        jQuery(this).bind('keypress', function(event) {
            if (event.keyCode == 13) {
                event.stopPropagation();
                e.find('span.button').trigger('click');
                return false;
            }
    });
    }).blur( function() {
        jQuery(this).unbind('keypress');
    });
    return e;
};

// `file` config type
function handle_remove_file() {
    jQuery(this).parents('.field-content').find('.clear-file').val(1);
    jQuery(this).parent().remove(); return false;
};

// `text-group` config type
function text_handle_edit_click() {
    var p = jQuery(this).parent();
    var text = p.find('span.content');
    if (text.length > 0) {
        p.replaceWith( render_text_form( text.html() ) );
    } else {
        p.before( render_text_form( '' ) );
        p.hide();
    }
    p.parent().find('input.label').focus();
    return false;
};

function render_text(label) {
    var dom = '<li class="pkg"><span class="content">' + label + '</span> '
        + '<img class="edit" src="' + StaticURI
        + 'images/status_icons/draft.gif" alt="Edit" title="Edit" /> '
        + '<img class="remove" src="' + StaticURI
        + 'images/status_icons/close.gif" alt="Remove" title="Remove" /></li>';
    var e = jQuery(dom);
    e.find('img.edit, span.content').click( text_handle_edit_click );
    e.find('img.remove').click( text_handle_delete_click );
    return e;
};

function text_handle_save_click() {
    var label = jQuery(this).parent().find('input[class=label]').val();
    if (!label) { return false; }
    jQuery(this).parents('ul').find('li.last').show();
    jQuery(this).parent().html( render_text(label) );
    return false;
};

function text_handle_delete_click() {
    jQuery(this).parent().remove(); return false;
};

function render_text_form(label,url) {
    var dom = '<li><label class="link-text">Label: '
        + '<input type="text" class="label" value="'
        + (typeof label != 'undefined' ? label : '')
        + '" /></label> <span class="button">Save</></li>';
    var e = jQuery(dom);
    e.find('span.button').click( text_handle_save_click ); 
    e.find('input.label').focus( function() {
        jQuery(this).bind('keypress', function(event) {
            if (event.keyCode == 13) {
                event.stopPropagation();
                e.find('span.button').trigger('click');
                return false;
            }
    });
    }).blur( function() {
        jQuery(this).unbind('keypress');
    });
    return e;
};

// Author config type
function removeAuthor(field_id) {
    jQuery('#' + field_id).val('');
    jQuery('#' + field_id + '_display_name').html('');
    jQuery('#field-' + field_id + ' a.remove-item-button').hide();
}


// Entry or Page config types
// Removing an item (particularly when using the "multiple" option) requires
// some careful handling. The data is stored in the format
// "active:1,2,12;inactive:4,5,6" so we need to be careful when removing item
// "2," for example and not turning "12" into "1." So, turn the object IDs into
// an array to properly remove any ID.
function removeCustomFieldEntry(el_id, obj_id) {
    // Strip the object ID off of the element.
    var obj_ids = jQuery('#'+el_id).val();

    // The ID of this object is saved to a hidden field to track all active
    // and inactive objects in use.
    var split_result = obj_ids.split(';');
    var i = 0;

    // Process "active:1,2,3" and "inactive:4,5,6" which are the only elements
    // in the `split_result` array.
    while ( split_result[i] ) {
        // Strip the leader prefix and the IDs.
        var item   = split_result[i].split(':');
        var prefix = item[0];
        var id_str = item[1] || '';

        // The IDs are a string. Split them into an array to be able to remove
        // any specific element.
        var ids = id_str.split(',');
        // Search the array of IDs for the ID to remove.
        var index = jQuery.inArray( obj_id, ids );
        // Remove the item.
        ids.splice( index, 1 );
        // Rebuild the array item.
        split_result[i] = prefix + ':' + ids.join(',');

        // Increment to work with the next item in the `split_result` array.
        i++;
    }

    // Reconstruct the "active" and "inactive" pieces.
    var obj_ids = split_result.join(';');
    jQuery('#'+el_id).val( obj_ids );
    // Remove the list item that shows the object.
    jQuery('#field-'+el_id+' li#obj-'+obj_id).remove();
}

function insertCustomFieldEntry(obj_name, obj_class, obj_id, obj_permalink, blog_id, el_id) {
    var obj_ids = jQuery('#'+el_id).val();
    var is_mult = jQuery('#'+el_id+'_preview').hasClass('multiple');

    // Check if the field is sortable (allows multiple objects, or has the
    // inactive area) and make the new object work the same way.
    var sortable = '';

    if ( jQuery('#'+el_id+'_inactive').length ) {
        sortable = ' sortable';
    }

    // The ID of this object is saved to a hidden field to track all active
    // and inactive objects in use. We need to consider if any other objects
    // use this field yet, and also whether multiple objects are allowed.
    var split_result = obj_ids.split(';');
    var active       = split_result[0];
    var inactive     = split_result[1] || '';

    if (is_mult) {
        // Multiple objects area allowed in this field. If the `active`
        // keyword was not used yet, add it.
        if (active) {
            active += ',' + obj_id;
        }
        else {
            active = 'active:' + obj_id;
        }
        // If multiple objects are allowed, this is sortable.
        sortable = ' sortable';
    } else {
        // Only one object is allowed to be active.
        active = 'active:' + obj_id;
    }

    obj_ids = active + ';' + inactive;
    jQuery('#'+el_id).val( obj_ids );

    try {
        // Build the list item.
        var html = '<li id="obj-' + obj_id
            + '" class="obj-type obj-type-' + obj_class + sortable
            + '"><span class="obj-title">' + obj_name
            + '</span>'
            // Edit button
            + '<a href="'+ CMSScriptURI + '?__mode=view&amp;_type='
            + obj_class + '&amp;id=' + obj_id + '&amp;blog_id='
            + blog_id + '" target="_blank"'
            + ' title="Edit in a new window.">'
            + '<img src="' + StaticURI
            + 'images/status_icons/draft.gif" width="9" height="9"'
            + ' alt="Edit" />'
            + '</a> '
            // View button
            + '<a href="' + obj_permalink + '" target="_blank"'
            + ' title="View in a new window.">'
            + '<img src="' + StaticURI
            + 'images/status_icons/view.gif" width="13" height="9"'
            + ' alt="View" />'
            + '</a> '
            // The remove button
            + '<a href="javascript:void(0);" onclick="removeCustomFieldEntry(\'' 
            + el_id + "'," + obj_id
            + ')" title="Remove this ' + obj_class + '"><img src="'
            + StaticURI + 'images/status_icons/close.gif" '
            + ' width="9" height="9" alt="Remove" /></a>'
            // Close the list item.
            + '</li>';

        if ( is_mult ) {
          jQuery('#'+el_id+'_preview').append(html);
        } else {
          jQuery('#'+el_id+'_preview').html(html);
        }
    } catch(e) {
        log.error(e);
    };
}

// The Asset custom field type uses this function to insert the asset.
function insertSelectedAsset(obj_title, obj_id, obj_permalink, field, blog_id) {
    // This is just a standard Selected Entries or Selected Pages insert.
    // Create a list item populated with title, edit, view, and remove links.
    var div = createObjectListing(
        obj_title,
        obj_id,
        'asset',
        obj_permalink,
        blog_id
    );

    // Insert the list item with the button, preview, etc into the field area.
    jQuery('#preview_'+field).html(div);
    jQuery('input#'+field).val( obj_id );
}

// Create an object listing for an entry or page. This is used for Selected
// Entry, Selected Page, and Reciprocal Objects.
function createObjectListing(obj_title, obj_id, obj_class, obj_permalink, blog_id) {
    var $preview = jQuery('<span/>')
        .addClass('obj-title')
        .text(obj_title);
    // Edit link.
    var $edit = jQuery('<a/>')
        .attr('href', CMSScriptURI+'?__mode=view&_type='+obj_class+'&id='+obj_id+'&blog_id='+blog_id)
        .addClass('edit')
        .attr('style', 'padding-left: 3px;')
        .attr('target', '_blank')
        .attr('title', 'Edit in a new window')
        .html('<img src="'+StaticURI+'images/status_icons/draft.gif" width="9" height="9" alt="Edit" />');
    // View link.
    var $view = jQuery('<a/>')
        .attr('href', obj_permalink)
        .addClass('view')
        .attr('style', 'padding-left: 3px;')
        .attr('target', '_blank')
        .attr('title', 'View in a new window')
        .html('<img src="'+StaticURI+'images/status_icons/view.gif" width="13" height="9" alt="View" />');
    // Delete button.
    var $remove = jQuery('<img/>')
        .addClass('remove')
        .attr('style', 'padding-left: 3px;')
        .attr('title', 'Remove selected entry')
        .attr('alt', 'Remove selected entry')
        .attr('src', StaticURI+'images/status_icons/close.gif')
        .attr('width', 9)
        .attr('height', 9);

    // Insert all of the above into a div.
    var div = jQuery('<div/>')
        .attr('id', 'obj-'+obj_id)
        .append($preview)
        .append($edit)
        .append($view)
        .append($remove);

    return div;
}

jQuery(document).ready(function() {
    // Delete an asset: remove the field value, and the preview with links.
    jQuery(document).on('click', 'div.asset-object div img.remove', function(){
        jQuery(this).parent().parent().parent().find('input.hidden').val('');
        jQuery(this).parent().remove();
    });

    // Radio-image config type
    jQuery('.field-type-radio-image li input:checked').each( function() {
        jQuery(this).parent().addClass('selected');
    });

    jQuery('.field-type-radio-image li').click( function() {
        jQuery(this).parent().find('input:checked').attr('checked',false);
        jQuery(this).find('input').attr('checked',true);
        jQuery(this).parent().find('.selected').removeClass('selected');
        jQuery(this).addClass('selected');
        var changed = jQuery(this).parent().parent().parent().parent().attr('id');
        jQuery('#content-nav ul li.'+changed).addClass('changed');
    });

});
