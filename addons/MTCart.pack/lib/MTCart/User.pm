package MTCart::User;

use strict;
use base qw( MT::Author );

use MT::Util qw( is_valid_email );
use MTCart::Util qw( utf8_zen2han );

use utf8;

__PACKAGE__->install_properties(
    {
        column_defs => {
            delivery_name => 'string(255)',
            delivery_postal => 'string(255)',
            delivery_address1 => 'string(255)',
            delivery_address2 => 'string(255)',
            delivery_state => 'string(255)',
            delivery_tel => 'string(255)',
        },
        defaults => {
            'auth_type' => 'MTCart',
        },
    }); 

sub password {
    my $user = shift;
    my ( $password ) = @_;
    if ( $password ) {
        $password =~ s/\s//g;
        $user->{ __password } = utf8_zen2han( $password );
    } else {
        $user->{ __password };
    }
}

sub password_confirmation {
    my $user = shift;
    my ( $password ) = @_;
    if ( $password ) {
        $password =~ s/\s//g;
        $user->{ __password_confirmation } = utf8_zen2han( $password );
    } else {
        $user->{ __password_confirmation }
    }
}

sub password_present {
    my $user = shift;
    defined( $user->password )
}

sub validate_password_confirmation {
    my $user = shift;
    return 1 unless $user->password_present;
    
    $user->password_confirmation &&
      $user->password eq $user->password_confirmation;
}

sub email {
    my $user = shift;
    if ( @_ ) {
        $_[0] =~ s/\s//g;
        $_[0] = utf8_zen2han( $_[0] );
    }
    $user->SUPER::email( @_ );
}

sub email_confirmation {
    my $user = shift;
    my ( $email ) = @_;
    if ( $email ) {
        $email =~ s/\s//g;
        $user->{ __email_confirmation } = utf8_zen2han( $email );
    } else {
        $user->{ __email_confirmation };
    }
}

sub validate_email_confirmation {
    my $user = shift;
    return 1 unless defined( $user->email_confirmation );
    $user->email &&
      $user->email eq $user->email_confirmation;
}

sub delivery_postal1 {
    my $order = shift;
    if ( @_ ) {
        my $str = $_[0];
        $str =~ s/\s//g;
        $str = utf8_zen2han( $_[0] );
        $order->{ __delivery_postal1 } = $str;
    } else {
        unless ( exists $order->{ __delivery_postal1 } ) {
            $order->delivery_postal =~ /^(\d{3})-(\d{4})$/;
            $order->{ __delivery_postal1 } = $1;
        }
    }
    return $order->{ __delivery_postal1 };
}

sub delivery_postal2 {
    my $order = shift;
    if ( @_ ) {
        my $str = $_[0];
        $str =~ s/\s//g;
        $str = utf8_zen2han( $_[0] );
        $order->{ __delivery_postal2 } = $str;
    } else {
        unless ( exists $order->{ __delivery_postal2 } ) {
            $order->delivery_postal =~ /^(\d{3})-(\d{4})$/;
            $order->{ __delivery_postal2 } = $2;
        }
    }
    return $order->{ __delivery_postal2 };
}

sub is_valid {
    my $user = shift;
    my $app = MT->instance;
    my $plugin = MT->component( 'MTCart' );;

    my @errors = ();
    my @presences = qw(delivery_name delivery_address1 delivery_state delivery_tel delivery_postal1 delivery_postal2);
    foreach my $presence ( @presences ) {
        push @errors, $plugin->translate( 'errors.messages.presence:[_1]', $plugin->translate( "user.$presence" ) )
          unless $user->$presence;
    }

    if ( $user->delivery_postal1 || $user->delivery_postal2 ) {
        unless ( $user->delivery_postal1 =~ /^\d{3}$/ && $user->delivery_postal2 =~ /^\d{4}$/ ) {
            push @errors, $plugin->translate( 'errors.messages.format:[_1]', $plugin->translate( "user.delivery_postal" ) );
            $user->delivery_postal( undef );
        } else {
            $user->delivery_postal( "@{[ $user->delivery_postal1 ]}-@{[ $user->delivery_postal2 ]}" );
        }
    }

    unless ( $user->email ) {
        push @errors, $plugin->translate( 'errors.messages.presence:[_1]', $plugin->translate( 'user.email' ) );
    } else {
        if (is_valid_email( $user->email )) {
            my $terms = { email => $user->email };
            if ( $user->id ) {
                $terms = { id => { -not => $user->id } };
            }
            if ( MT->model( 'mtcart.user' )->exist( $terms ) ) {
                push @errors, $plugin->translate( 'errors.messages.uniqueness:[_1]', $plugin->translate( 'user.email' ) );
            }
            $user->name( $user->email );
            if ( !$user->nickname && $user->email =~ /^(.+)\@/ ) {
                $user->nickname( $1 );
            }

            unless ( $user->validate_email_confirmation ) {
                push @errors, $plugin->translate( 'errors.messages.confirmation:[_1]', $plugin->translate( 'user.email' ) );
            }
        } else {
            push @errors, $plugin->translate( 'errors.messages.format:[_1]', $plugin->translate( 'user.email' ) );
        }
    }

    if ( $user->password_present ) {
        unless ( $user->password ) {
            push @errors, $plugin->translate( 'errors.messages.presence:[_1]', $plugin->translate( 'user.password' ) );
        } else {
            
            unless ( $user->validate_password_confirmation ) {
                push @errors, $plugin->translate( 'errors.messages.confirmation:[_1]', $plugin->translate( 'user.password' ) );
            } else {
                $user->set_password( $user->password );
            }
        }
    }

    $app->run_callbacks( 'mtcart_validation.user', $app, $user, \@errors );

    if ( @errors ) {
        return $user->error( join( "\n", @errors ) );
    } else {
        return 1;
    }
}

sub save {
    my $user = shift;
    my $plugin = MT->component( 'MTCart' );

    return 0 unless ( $user->is_valid );

    unless ( $user->SUPER::save(@_) ) {
        my @errors = ( $user->errstr );
        return $user->error( join( "\n", @errors ) );
    }

    1;
}

sub load {
    my $user = shift;
    my ( $terms, $args ) = @_;

    if ( defined $terms
           && ( !ref $terms || ( ref $terms ne 'HASH' && ref $terms ne 'ARRAY' ) ) ) {
        $terms = {
            id => $terms,
            auth_type => 'MTCart',
        };
        $args = { limit => 1 };
        return $user->SUPER::load( $terms, $args );
    } else {
        if ( ref $terms eq 'ARRAY' ) {
            $terms = {
                id => $terms,
                auth_type => 'MTCart',
            };
            return $user->SUPER::load( $terms, $args );
        } else {
            local $terms->{ auth_type } = 'MTCart';
            return $user->SUPER::load( $terms, $args );
        }
    }
}

sub load_iter {
    my $user = shift;
    my ( $terms, $args ) = @_;
    if ( defined $terms
           && ( !ref $terms || ( ref $terms ne 'HASH' && ref $terms ne 'ARRAY' ) ) ) {
        $terms = {
            id => $terms,
            auth_type => 'MTCart',
        };
        $args = { limit => 1 };
        return $user->SUPER::load_iter( $terms, $args );
    } else {
        if ( ref $terms eq 'ARRAY' ) {
            $terms = {
                id => $terms,
                auth_type => 'MTCart',
            };
            return $user->SUPER::load_iter( $terms, $args );
          } else {
              local $terms->{ auth_type } = 'MTCart';
              return $user->SUPER::load_iter( $terms, $args );
          }
    }
}

sub count {
    my $user = shift;
    my ( $terms, $args ) = @_;

    if ( defined $terms
           && ( !ref $terms || ( ref $terms ne 'HASH' && ref $terms ne 'ARRAY' ) ) ) {
        $terms = {
            id => $terms,
            auth_type => 'MTCart',
        };
        $args = {};
        return $user->SUPER::count( $terms, $args );
    } else {
        if ( ref $terms eq 'ARRAY' ) {
            $terms = {
                id => $terms,
                auth_type => 'MTCart',
            };
            return $user->SUPER::count( $terms, $args );
        } else {
            local $terms->{ auth_type } = 'MTCart';
            return $user->SUPER::count( $terms, $args );
        }
    }
}

1;
