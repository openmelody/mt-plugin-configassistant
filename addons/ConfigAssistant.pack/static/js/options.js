// Utility Functions
function handle_edit_click() {
    var link = $(this).parent().find('a.link');
    if (link.length > 0) {
        $(this).parent().replaceWith( render_link_form( link.html(), link.attr('href') ) );
    } else {
        $(this).parent().before( render_link_form( '','' ) );
        $(this).parent().hide();
    }
    return false;
};
function render_link(label,url) {
    var dom = '<li class="pkg"><a class="link" href="'+url+'">'+label+'</a> <a class="remove" href="javascript:void(0);"><img src="'+StaticURI+'images/icon_close.png" /></a> <a class="edit" href="javascript:void(0);">edit</a></li>';
    var e = $(dom);
    e.find('a.edit').click( handle_edit_click );
    e.find('a.remove').click( handle_delete_click );
    return e;
};
function handle_save_click() {
    var label = $(this).parent().find('input[class=label]').val();
    var url = $(this).parent().find('input[class=url]').val();
    if (!label && !url) { return false; }
    $(this).parents('ul').find('li.last').show();
    $(this).parent().replaceWith( render_link(label,url) );
    return false;
};
function handle_delete_click() {
    $(this).parent().remove(); return false;
};
function handle_remove_file() {
    $(this).parents('.field-content').find('.clear-file').val(1);
    $(this).parent().remove(); return false;
};
function render_link_form(label,url) {
    var dom = '<li class="pkg"><label class="link-text">Label: <input type="text" class="label" value="'+(typeof label != 'undefined' ? label : '')+'" /></label><label class="link-url">URL: <input type="text" class="url" value="'+(typeof url != 'undefined' ? url : '')+'" /></label> <button>Save</button></li>';
    var e = $(dom);
    e.find('button').click( handle_save_click ); 
    e.find('input.url').focus( function() {
        $(this).bind('keypress', function(event) {
            if (event.keyCode == 13) {
                event.stopPropagation();
                e.find('button').trigger('click');
                return false;
            }
        });
    }).blur( function() {
        $(this).unbind('keypress');
    });
    return e;
};
