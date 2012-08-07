$(document).ready(function() {
    BASEURL = document.getElementsByTagName('link')[0].href.replace(/\/css.*/, '');
    ELEMENTS_CAN_BE_FIXED = 1; // TODO

    $('#navbar').fixedNavbar();
    $('pre').addClass('prettyprint');
    if(typeof prettyPrint != 'undefined') prettyPrint(); // add syntax highlightning to <pre> tags

    // post form on change
    $('form.submit-on-change input').change(function() {
        var $form = $(this).parents('form');
        var $msg = $('<div>Uploading "' + this.value + '" to server.<br>Please wait...</div>');

        $('body').append($msg);
        $msg.dialog({
            title: 'Upload in progress',
            closeOnEscape: false,
            draggable: false,
            resizable: false,
            modal: true
        }).parent().find('.ui-dialog-titlebar-close').hide();

        $form.submit();
    });
});

jQuery.fn.fixedNavbar = function() {
    this.each(function() {
        var $fixed = $(this);
        var $parent_element = $fixed.parent();
        var $clone = $('<div>&nbsp;</div>');
        var offset = $fixed.offset();

        offset.top -= $fixed.outerHeight() - $fixed.height();

        $clone.css({
            'width': $fixed.outerWidth(),
            'height': $fixed.outerHeight() + 10,
        });
        $fixed.before($clone).css({
            'width': $fixed.width(),
            'top': offset.top,
            'z-index': 100,
            'position': 'absolute'
        });

        $(window).bind('scroll', function(event) {
            var scroll_top = $(window).scrollTop();
            if(offset.top <= scroll_top) {
                $fixed.css(
                    ELEMENTS_CAN_BE_FIXED
                        ? { 'top': 0, 'position': 'fixed' }
                        : { 'top': scroll_top, 'position': 'absolute' }
                );
            }
            else {
                $fixed.css({ 'top': offset.top, 'position': 'absolute' });
            }
        });
    });
};
