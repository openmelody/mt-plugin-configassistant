jQuery(document).ready( function($) {

    // Create list items for the navigation tabs.
    var nav_lis = jQuery('<ul id="nav-tabs" />');
    jQuery('.fieldset-options').each( function(){
        jQuery('<li/>')
            .html(
                jQuery('<a/>')
                    .attr('href', '#'+jQuery(this).attr('id') )
                    .text( jQuery(this).find('> h2.fieldset-header').text() )
            )
            .appendTo(nav_lis);
    });

    // Build the navigation tabs.
    jQuery('#fieldsets').prepend(nav_lis).tabs();

});
