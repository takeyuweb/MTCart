(function($){
    $('#mtcart-purchase').ready(function(){
        function giftToggle(){
            if($('#is_gift:checked').val() == 1){
                $('#user.delivery').hide();
                $('#gift.delivery').show();
            }else{
                $('#user.delivery').show();
                $('#gift.delivery').hide();
            }
        }
        giftToggle();
        $('#is_gift').click(giftToggle);
    });
})(jQuery);