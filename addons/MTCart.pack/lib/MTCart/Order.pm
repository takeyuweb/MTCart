package MTCart::Order;

use strict;
use utf8;

use base qw( MT::Object );

use MTCart::Util qw( utf8_zen2han );

__PACKAGE__->install_properties ({
    column_defs => {
        id          => 'integer not null auto_increment',
        blog_id     => 'integer',
        cart_data   => 'blob',

        # 注文者
        user_id     => 'integer',
        user_name   => 'string(255)',
        remote_ip => 'string(255)',

        is_gift     => 'smallint',
        
        # 配送先
        name        => 'string(255)',
        postal      => 'string(255)',
        address1    => 'string(255)',
        address2    => 'string(255)',
        state       => 'string(255)',
        tel         => 'string(255)',
        payment     => 'string(255)',

        # 配送希望日時
        date_on     => 'datetime',
        timezone    => 'string(255)',

        note        => 'text',
        total_price => 'integer',
    },
    indexes     => {
        blog_id      => 1,
        created_on   => 1,
        user_id      => 1,
    },
    audit       => 1,
    child_of    => [ 'MT::Blog', 'MTCart::User' ],
    datasource  => 'mtcart_order',
    primary_key => 'id',
    class_type  => 'mtcart_order',
});

sub postal1 {
    my $order = shift;
    if ( @_ ) {
        $_[0] =~ s/\s//g;
        $_[0] = utf8_zen2han( $_[0] );
        $order->{ __postal1 } = $_[0];
    }
    return $order->{ __postal1 };
}  

sub postal2 {
    my $order = shift;
    if ( @_ ) {
        $_[0] =~ s/\s//g;
        $_[0] = utf8_zen2han( $_[0] );
        $order->{ __postal2 } = $_[0];
    }
    return $order->{ __postal2 };
}  

sub is_valid {
    my $order = shift;
    my $plugin = MT->component( 'MTCart' );
    my $app = MT->instance;

    my @errors = ();
    my @presences = qw(name address1 state tel payment user_id user_name);
    foreach my $presence ( @presences ) {
        push @errors, $plugin->translate( 'errors.messages.presence:[_1]', $plugin->translate( "order.$presence" ) )
          unless $order->$presence;
    }
    if ( $order->postal1 || $order->postal2 ) {
        unless ( $order->postal1 =~ /^\d{3}$/ && $order->postal2 =~ /^\d{4}$/ ) {
            push @errors, $plugin->translate( 'errors.messages.format:[_1]', $plugin->translate( "order.postal" ) );
            $order->postal( undef );
        } else {
            $order->postal( "@{[ $order->postal1 ]}-@{[ $order->postal2 ]}" );
        }
    } else {
        unless ( $order->postal ) {
            push @errors, $plugin->translate( 'errors.messages.format:[_1]', $plugin->translate( "order.postal" ) );
            $order->postal( undef );
        }
    }
    if ( $order->payment ) {
        my $payments = { cod => {}, bank => {}, postal => {} };
        push @errors, $plugin->translate( 'errors.messages.choice:[_1]', $plugin->translate( "order.payment" ) )
          unless $payments->{ $order->payment };
    }
 
    $order->total_price( 0 ) unless $order->total_price;

    $app->run_callbacks( 'mtcart_validation.order', $app, $order, \@errors );

    if ( @errors ) {
        return $order->error( join( "\n", @errors ) );
    } else {
        return 1;
    }
}

sub save {
    my $order = shift;
    my $plugin = MT->component( 'MTCart' );

    return 0 unless ( $order->is_valid );

    if ( $order->SUPER::save(@_) ) {
        my @errors = ( $order->errstr );
        push( @errors, $order->errstr ) if $order->errstr;
        return $order->error( join( "\n", @errors ) );
    }

    1;
}


sub save {
    my $order = shift;
    if ( my $data = $order->{ __cart_data } ) {
        require MT::Serialize;
        my $ser = MT::Serialize->serialize( \$data );
        $order->SUPER::cart_data($ser);
    }
    $order->{ __dirty } = 0;
    $order->SUPER::save(@_);
}

sub cart_data {
    my $order = shift;
    if ( @_ ) {
        $order->{ __cart_data } = @_[0];
        $order->{__dirty} = 1;
    } else {
        $order->thaw_cart_data;
    }
    $order->{ __cart_data }
}

sub is_dirty {
    my $order = shift;
    $order->{ __dirty };
}

sub thaw_cart_data {
    my $order = shift;
    return $order->{__cart_data} if $order->{__cart_data};
    my $data = $order->SUPER::cart_data();
    $data = '' unless $data;
    require MT::Serialize;
    my $out = MT::Serialize->unserialize($data);
    if ( ref $out eq 'REF' ) {
        $order->{__cart_data} = $$out;
    }
    else {
        $order->{__cart_data} = {};
    }
    $order->{__dirty} = 0;
    $order->{__cart_data};
}

1;
