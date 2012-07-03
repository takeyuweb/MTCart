package MTCart::Tags;

use strict;
use warnings;
use utf8;

use MT::Util qw( encode_html );
use MTCart::Util qw( deserialize_cart_data cart_subtotal payment_method );

our $plugin = MT->component( 'MTCart' );

sub _hdlr_cart_script {
    require MT::App::MTCart;
    MT::App::MTCart->script;
}

sub _hdlr_cart_path {
    require MT::App::MTCart;
    MT::App::MTCart->app_path;
}

sub _hdlr_entry_price {
    my ($ctx, $args) = @_;

    my $entry;
    my $entry_id = $args->{ entry_id };
    if ( defined $entry_id ) {
        $entry = MT->model( 'mtcart.entry' )->load( $entry_id );
    } else {
        $entry = $ctx->stash('entry');
    }
    return $ctx->_no_entry_error() unless defined $entry;

    $entry->price;
}

sub _hdlr_cart_entry_amount {
    my ($ctx, $args) = @_;

    my $entry;
    my $entry_id = $args->{ entry_id };
    if ( defined $entry_id ) {
        $entry = MT->model( 'mtcart.entry' )->load( $entry_id );
    } else {
        $entry = $ctx->stash( 'entry' );
    }
    return $ctx->_no_entry_error() unless defined $entry;

    my $sess_obj = $ctx->stash( 'mtcart_session' );

    my $amount = $ctx->{__stash}{__amount};
    return $amount if defined $amount;

    my $cart = deserialize_cart_data( $sess_obj->get( 'cart_data' ) || '' );
    $cart->{ $entry->id } || 0;
}

sub _hdlr_cart_entry_amount_selector {
    my ($ctx, $args) = @_;

    my $entry;
    my $entry_id = $args->{ entry_id };
    if ( defined $entry_id ) {
        $entry = MT->model( 'mtcart.entry' )->load( $entry_id );
    } else {
        $entry = $ctx->stash( 'entry' );
    }
    return $ctx->_no_entry_error() unless defined $entry;

    my $amount = _hdlr_cart_entry_amount( @_ );

    my $attrs = '';
    foreach my $key ( qw( id style class ) ) {
        my $val = $args->{ $key };
        $attrs .= " $key=\"@{[ MT::Util::encode_html($val) ]}\"" if $val;
    }

    my $out = <<HTML;
<select name="amount_@{[ $entry->id ]}"$attrs>
HTML
    for ( my $i=0; $i<=20; $i++ ) {
        $out .= "<option value=\"$i\"@{[ $i == $amount ? ' selected=\"selected\"' : '' ]}>$i</option>";
    }
    $out .= '</select>';
}

sub _hdlr_cart_entry_subtotal {
    my ($ctx, $args) = @_;

    my $entry;
    my $entry_id = $args->{ entry_id };
    if ( defined $entry_id ) {
        $entry = MT->model( 'mtcart.entry' )->load( $entry_id );
    } else {
        $entry = $ctx->stash('entry');
    }
    return $ctx->_no_entry_error() unless defined $entry;

    my $amount = _hdlr_cart_entry_amount( $ctx, $args );
    $entry->price * $amount;
}

sub _hdlr_cart_subtotal {
    my ($ctx, $args) = @_;

    my $sess_obj = $ctx->stash( 'mtcart_session' );
    my $cart = deserialize_cart_data( $sess_obj->get( 'cart_data' ) || '' );

    cart_subtotal( $cart );
}

sub _hdlr_add_to_cart_form {
    my ( $ctx, $args, $cond ) = @_;

    my $entry;
    my $entry_id = $args->{ entry_id };
    if ( defined $entry_id ) {
        $entry = MT->model( 'mtcart.entry' )->load( $entry_id );
    } else {
        $entry = $ctx->stash('entry');
    }
    return $ctx->_no_entry_error() unless defined $entry;

    unless ( $entry->on_sale ) {
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }

    my $attrs = '';
    foreach my $key ( qw( id style class ) ) {
        my $val = $args->{ $key };
        $attrs .= " $key=\"@{[ MT::Util::encode_html($val) ]}\"" if $val;
    }

    my $return_to = $args->{ 'return_to' };

    my $out = <<"EOF";
<form method="POST" onsubmit="this.elements['return_to'].value=window.location.href; return true;" action="@{[ _hdlr_cart_path() ]}@{[ _hdlr_cart_script() ]}"$attrs>
<div style="line-height: 0; height: 0; display: inline; margin: 0; padding: 0;"><input type="hidden" name="blog_id" value="@{[ $entry->blog_id ]}" /><input type="hidden" name="id" value="@{[ $entry->id ]}" /><input type="hidden" name="__mode" value="add" /><input type="hidden" name="return_to" value="" /></div>
EOF

    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    
    $out .= $builder->build( $ctx, $tokens );
    return $ctx->error( $builder->errstr ) unless defined $out;

    $out .= "</form>";

    $out;
}

sub _hdlr_cart_entries {
    my ( $ctx, $args, $cond ) = @_;

    my $sess_obj = $ctx->stash( 'mtcart_session' );
    
    my $cart_entry_ids = '';

    my $app = MT->instance;
    
    my $cart = deserialize_cart_data( $sess_obj->get( 'cart_data' ) || '' );

    my @ids = keys %$cart;

    my $terms = {
        id => \@ids,
    };
    my $params = {
    };
    my @entries = MT->model( 'mtcart.entry' )->load( $terms, $params );
    my $total = MT->model( 'mtcart.entry' )->count( $terms );
    
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    
    my $vars = $ctx->{__stash}{vars} ||= {};

    my $i = 1;
    my $res = '';
    foreach my $entry ( @entries ) {
        local $vars->{__first__} = $i == 1;
        local $vars->{__last__} = ( $i == scalar( @entries ) );
        local $vars->{__odd__} = ( $i % 2 ) == 1;
        local $vars->{__even__} = ( $i % 2 ) == 0;
        local $vars->{__counter__} = $i;
        local $vars->{__total__} = $total;
        
        local $ctx->{__stash}{blog} = $entry->blog;
        local $ctx->{__stash}{blog_id} = $entry->blog_id;
        local $ctx->{current_timestamp} = $entry->authored_on;
        local $ctx->{__stash}{entry} = $entry;

        local $ctx->{__stash}{__amount} = $cart->{ $entry->id };

        my $out = $builder->build(
            $ctx, $tokens,
            {   %$cond,
                EntriesHeader => $i == 1,
                EntriesFooter => !defined $entries[ $i ],
            }
        );
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
        $i++;
    }
    if ( !@entries ) {
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }

    $res;
}

sub _hdlr_cart_user_name {
    my ( $ctx, $args ) = @_;
    my $user = $ctx->stash( 'author' );
    return $ctx->error( 'no user' ) unless $user;

    $user->delivery_name;
}

sub _hdlr_cart_user_postalcode {
    my ( $ctx, $args ) = @_;
    my $user = $ctx->stash( 'author' );
    return $ctx->error( 'no user' ) unless $user;

    $user->delivery_postal;
}

sub _hdlr_cart_user_state {
    my ( $ctx, $args ) = @_;
    my $user = $ctx->stash( 'author' );
    return $ctx->error( 'no user' ) unless $user;

    $user->delivery_state;
}

sub _hdlr_cart_user_address1 {
    my ( $ctx, $args ) = @_;
    my $user = $ctx->stash( 'author' );
    return $ctx->error( 'no user' ) unless $user;

    $user->delivery_address1;
}

sub _hdlr_cart_user_address2 {
    my ( $ctx, $args ) = @_;
    my $user = $ctx->stash( 'author' );
    return $ctx->error( 'no user' ) unless $user;

    $user->delivery_address2;
}

sub _hdlr_cart_user_tel {
    my ( $ctx, $args ) = @_;
    my $user = $ctx->stash( 'author' );
    return $ctx->error( 'no user' ) unless $user;

    $user->delivery_tel;
}

sub _hdlr_order_entries {
    my ( $ctx, $args, $cond ) = @_;

    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;
    
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    
    my $vars = $ctx->{__stash}{vars} ||= {};

    my $i = 1;
    my $res = '';
    
    my $lines = $order->cart_data;
    foreach my $line ( @$lines ) {
        my $entry_id = $line->{ id };
        my $entry_title = $line->{ title };
        my $entry_price = $line->{ price };
        my $entry_amount = $line->{ amount };
        my $entry_subtotal = $line->{ subtotal };
        my $entry = MT->model( 'mtcart.entry' )->load( $entry_id );
        
        local $vars->{__first__} = $i == 1;
        local $vars->{__last__} = ( $i == scalar( @$lines ) );
        local $vars->{__odd__} = ( $i % 2 ) == 1;
        local $vars->{__even__} = ( $i % 2 ) == 0;
        local $vars->{__counter__} = $i;
        local $vars->{__total__} = scalar( @$lines );
        
        local $ctx->{__stash}{blog} = $entry ? $entry->blog : undef;
        local $ctx->{__stash}{blog_id} = $entry ? $entry->blog_id : undef;
        local $ctx->{current_timestamp} = $entry ? $entry->authored_on : undef;
        local $ctx->{__stash}{entry} = $entry;

        local $ctx->{__stash}{__id} = $entry_id;
        local $ctx->{__stash}{__title} = $entry_title;
        local $ctx->{__stash}{__price} = $entry_price;
        local $ctx->{__stash}{__amount} = $entry_amount;
        local $ctx->{__stash}{__subtotal} = $entry_subtotal;
        
        my $out = $builder->build(
            $ctx, $tokens,
            {   %$cond,
                OrderEntriesHeader => $i == 1,
                OrderEntriesFooter => !defined $lines->[ $i ],
            }
        );
        return $ctx->error( $builder->errstr ) unless defined $out;
        $res .= $out;
        $i++;
    }
    
    if ( ! @$lines ) {
        return MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }

    $res;
}

sub _hdlr_order_by {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->user_name;
}

sub _hdlr_order_name {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->name;
}

sub _hdlr_order_postalcode {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->postal;
}

sub _hdlr_order_address1 {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->address1;
}

sub _hdlr_order_address2 {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->address2;
}

sub _hdlr_order_state {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->state;
}
sub _hdlr_order_tel {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->tel;
}

sub _hdlr_order_payment {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    my $payment = payment_method( $order->payment );
    $payment ? $payment->{ label } : '(Unknown)';
}
sub _hdlr_order_delivery_date_on {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $args->{ts} = $order->date_on;
    return $ctx->build_date( $args );
    # $order->date_on;
}
sub _hdlr_order_delivery_timezone {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->timezone;
}
sub _hdlr_order_entry_title {
    my ( $ctx, $args ) = @_;
    $ctx->stash( '__title' );
}
sub _hdlr_order_entry_price {
    my ( $ctx, $args ) = @_;
    $ctx->stash( '__price' );
}
sub _hdlr_order_entry_amount {
    my ( $ctx, $args ) = @_;
    $ctx->stash( '__amount' );
}
sub _hdlr_order_entry_subtotal {
    my ( $ctx, $args ) = @_;
    $ctx->stash( '__subtotal' );
}
sub _hdlr_order_total_price {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->total_price;
}
sub _hdlr_order_note {
    my ( $ctx, $args ) = @_;
    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    $order->note;
}

sub _hdlr_order_billing_user {
    my ( $ctx, $args, $cond ) = @_;

    my $order = $ctx->stash( 'order' );
    return $ctx->error( 'no order' ) unless $order;

    
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    
    my $vars = $ctx->{__stash}{vars} ||= {};

    my $user_id = $order->user_id;
    return '' unless $user_id;
    my $user = MT->model( 'mtcart.user' )->load( $user_id );
    return '' unless $user;

    local $ctx->{__stash}{author} = $user;
    
    my $out = $builder->build( $ctx, $tokens );
    return $ctx->error( $builder->errstr ) unless defined $out;
    if ( $out ) {
        $out;
    } else {
        MT::Template::Context::_hdlr_pass_tokens_else(@_);
    }
}

1;
