package MTCartPaymentCOD::Plugin;

use strict;
use utf8;

sub _cb_mtcart_validation_order {
    my ( $cb, $app, $order, $errors ) = @_;

    if ( $order->is_gift && $order->payment eq 'cod' ) {
        push @$errors, 'ギフト配送の場合、代金引換決済はご利用になりません。';
    }
}

1;

