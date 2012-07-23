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
    var dom = '<li class="pkg"><a class="link" href="'+url+'">'+label+'</a> <a class="remove" href="javascript:void(0);"><img src="'+StaticURI+'images/icon_close.png" alt="remove" title="remove" /></a> <a class="edit" href="javascript:void(0);">edit</a></li>';
    var e = jQuery(dom);
    e.find('a.edit').click( handle_edit_click );
    e.find('a.remove').click( handle_delete_click );
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
    var dom = '<li><label class="link-text">Label: <input type="text" class="label" value="'+(typeof label != 'undefined' ? label : '')+'" /></label><label class="link-url">URL: <input type="text" class="url" value="'+(typeof url != 'undefined' ? url : '')+'" /></label> <button>Save</button></li>';
    var e = jQuery(dom);
    e.find('button').click( handle_save_click ); 
    e.find('input.url').focus( function() {
        jQuery(this).bind('keypress', function(event) {
            if (event.keyCode == 13) {
                event.stopPropagation();
                e.find('button').trigger('click');
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
    var text = p.find('span.text');
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
    var dom = '<li class="pkg"><span class="text">'+label+'</span> <a class="remove" href="javascript:void(0);"><img src="'+StaticURI+'images/icon_close.png" alt="remove" title="remove" /></a> <a class="edit" href="javascript:void(0);">edit</a></li>';
    var e = jQuery(dom);
    e.find('a.edit').click( text_handle_edit_click );
    e.find('a.remove').click( text_handle_delete_click );
    return e;
};

function text_handle_save_click() {
    var label = jQuery(this).parent().find('input[class=label]').val();
    if (!label) { return false; }
    jQuery(this).parents('ul').find('li.last').show();
    jQuery(this).parent().replaceWith( render_text(label) );
    return false;
};

function text_handle_delete_click() {
    jQuery(this).parent().remove(); return false;
};

function render_text_form(label,url) {
    var dom = '<li><label class="link-text">Label: <input type="text" class="label" value="'+(typeof label != 'undefined' ? label : '')+'" /></label> <button>Save</button></li>';
    var e = jQuery(dom);
    e.find('button').click( text_handle_save_click ); 
    e.find('input.label').focus( function() {
        jQuery(this).bind('keypress', function(event) {
            if (event.keyCode == 13) {
                event.stopPropagation();
                e.find('button').trigger('click');
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
function removeCustomFieldEntry(el_id, obj_id) {
    // Strip the object ID off of the element.
    var obj_ids = jQuery('#'+el_id).val();
    var re = new RegExp(',?'+obj_id);
    obj_ids = obj_ids.replace(re,'');
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
