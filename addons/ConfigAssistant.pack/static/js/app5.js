jQuery(document).ready( function() {
  var active_elm = jQuery('#content-nav ul li.active a');
  var active;
  if (active_elm) {
    active = active_elm.attr('id');
    jQuery('#' + active + '-content').show();
  }
  else {
//    return;
  }
  jQuery('.field-type-radio-image li input:checked').each( function() { jQuery(this).parent().addClass('selected'); });
  jQuery('.field-type-radio-image li').click( function() {
    jQuery(this).parent().find('input:checked').attr('checked',false);
    jQuery(this).find('input').attr('checked',true);
    jQuery(this).parent().find('.selected').removeClass('selected');
    jQuery(this).addClass('selected');
    var changed = jQuery(this).parent().parent().parent().parent().attr('id');
    jQuery('#content-nav ul li.'+changed).addClass('changed');
  });

//  var active = jQuery('#content-nav ul li.active a').attr('id');
//  jQuery('h2#page-title span').html( jQuery('#content-nav ul li.active a b').html() );
  jQuery('#fieldsets input, #fieldsets select, #fieldsets textarea').change( function () {
    var changed = jQuery(this).parent().parent().parent().attr('id');
    jQuery('#content-nav ul li.'+changed).addClass('changed');
  });
  jQuery('#content-nav ul li a').click( function() {
    var newactive = jQuery(this).attr('id');
    jQuery('#content-nav li.active').removeClass('active');
    jQuery('#' + active + '-content').hide();
    jQuery('#content-nav li.' + newactive).addClass('active');
    jQuery('#' + newactive + '-content').show();
    jQuery('h2#page-title span').html( jQuery('#content-nav ul li.'+newactive+' a b').html() );
    active = newactive;
  });
});
// Utility Functions
function handle_edit_click() {
    var link = jQuery(this).parent().find('a.link');
    if (link.length > 0) {
        jQuery(this).parent().replaceWith( render_link_form( link.html(), link.attr('href') ) );
    } else {
        jQuery(this).parent().before( render_link_form( '','' ) );
        jQuery(this).parent().hide();
    }
    return false;
};
function render_link(label,url) {
    var dom = '<li class="pkg"><a class="link" href="'+url+'">'+label+'</a> <a class="remove" href="javascript:void(0);"><img src="'+StaticURI+'images/icon_close.png" /></a> <a class="edit" href="javascript:void(0);">' + ConfigAssistantMsg.edit_msg + '</a></li>';
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
    var dom = '<li class="pkg"><label class="link-text">' + ConfigAssistantMsg.label_msg + ': <input type="text" class="label" value="'+(typeof label != 'undefined' ? label : '')+'" /></label><label class="link-url">' + ConfigAssistantMsg.url_msg + ': <input type="text" class="url" value="'+(typeof url != 'undefined' ? url : '')+'" /></label> <button>' + ConfigAssistantMsg.save_msg + '</button></li>';
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
