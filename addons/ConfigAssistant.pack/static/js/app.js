jQuery(document).ready( function($) {
  $('h2#page-title span').html( $('#content-nav ul li.active a b').html() );
  $('#fieldsets input, #fieldsets select, #fieldsets textarea').change( function () {
    var changed = $(this).parent().parent().parent().attr('id');
    $('#content-nav ul li.'+changed).addClass('changed');
  });
  $('#content-nav ul li a').click( function() {
    var active    = $(this).parents('ul').find('li.active a').attr('id').replace(/-tab$/,'');
    var newactive = $(this).attr('id').replace(/-tab$/,'');
    $('#content-nav li.active').removeClass('active');
    $('#' + active + '-tab-content').hide();
    $('#content-nav li.' + newactive+'-tab').addClass('active');
    $('#' + newactive + '-tab-content').show();
    $('h2#page-title span').html( $('#content-nav ul li.'+newactive+'-tab a b').html() );
    document.title = $(this).attr('title');
    window.location.hash = newactive;
  });
  $('.field-type-radio-image li input:checked').each( function() { $(this).parent().addClass('selected'); });
  $('.field-type-radio-image li').click( function() {
    $(this).parent().find('input:checked').attr('checked',false);
    $(this).find('input').attr('checked',true);
    $(this).parent().find('.selected').removeClass('selected');
    $(this).addClass('selected');
    var changed = $(this).parent().parent().parent().parent().attr('id');
    $('#content-nav ul li.'+changed).addClass('changed');
  });
  $.history.init(function(hash){
    if (hash == "") {
        hash = $('#content-nav ul li:first-child a').attr('id').replace(/-tab$/,'');
    }
    $('#content-nav ul li.'+hash+'-tab a').click();
  });
});
