jQuery(document).ready( function($) {
  jQuery('h2#page-title span').html( jQuery('#content-nav ul li.active a b').html() );
  jQuery('#fieldsets input, #fieldsets select, #fieldsets textarea').change( function () {
    var changed = jQuery(this).parent().parent().parent().attr('id');
    jQuery('#content-nav ul li.'+changed).addClass('changed');
  });
  jQuery('#content-nav ul li a').click( function() {
    var active    = jQuery(this).parents('ul').find('li.active a').attr('id').replace(/-tab$/,'');
    var newactive = jQuery(this).attr('id').replace(/-tab$/,'');
    jQuery('#content-nav li.active').removeClass('active');
    jQuery('#' + active + '-tab-content').hide();
    jQuery('#content-nav li.' + newactive+'-tab').addClass('active');
    jQuery('#' + newactive + '-tab-content').show();
    jQuery('h2#page-title span').html( jQuery('#content-nav ul li.'+newactive+'-tab a b').html() );
    document.title = jQuery(this).attr('title');
    window.location.hash = newactive;
  });
  jQuery.history.init(function(hash){
    if (hash == "") {
        hash = jQuery('#content-nav ul li:first-child a').attr('id').replace(/-tab$/,'');
    }
    jQuery('#content-nav ul li.'+hash+'-tab a').click();
  });
});
