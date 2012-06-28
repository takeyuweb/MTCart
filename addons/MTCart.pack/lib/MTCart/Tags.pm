package MTCart::Tags;

use strict;
use warnings;
use utf8;

use MT::Util qw( encode_html );
use MTCart::Util qw( deserialize_cart_data );

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

    my $entry;
    my $entry_id = $args->{ entry_id };
    if ( defined $entry_id ) {
        $entry = MT->model( 'mtcart.entry' )->load( $entry_id );
    } else {
        $entry = $ctx->stash('entry');
    }
    return $ctx->_no_entry_error() unless defined $entry;

    my $sess_obj = $ctx->stash( 'mtcart_session' );
    my $cart = deserialize_cart_data( $sess_obj->get( 'cart_data' ) || '' );

    my @ids = keys %$cart;
    my $terms = { id => \@ids };
    my @entries = MT->model( 'mtcart.entry' )->load( $terms );
    my $subtotal = 0;
    foreach my $entry ( @entries ) {
        my $amount = $cart->{ $entry->id } || 0;
        $subtotal += $entry->price * $amount;
    }
    $subtotal;
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

sub _hdlr_cart_user_realname {
    my ( $ctx, $args ) = @_;
    my $user = $ctx->stash( 'author' );
    return $ctx->error( 'no user' ) unless $user;

    $user->can_do( 'realname' ) ? $user->realname : '';
}

1;
