// Utility Functions
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
function handle_remove_file() {
    jQuery(this).parents('.field-content').find('.clear-file').val(1);
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

// text-group Utility Functions
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
