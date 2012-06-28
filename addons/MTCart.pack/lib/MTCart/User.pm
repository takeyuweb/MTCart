package MTCart::User;

use strict;
use base qw( MT::Author );

use MT::Util qw( is_valid_email );
use MTCart::Util qw( utf8_zen2han );

use utf8;

__PACKAGE__->install_properties(
    {
        column_defs => {
            'realname' => 'string(255)',
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

sub save {
    my $user = shift;
    my $plugin = MT->component( 'MTCart' );;

    my @errors = ();
    unless( $user->realname ) {
        push @errors, $plugin->translate( 'errors.messages.presence:[_1]', $plugin->translate( 'user.realname' ) );
    }

    unless ( $user->email ) {
        push @errors, $plugin->translate( 'errors.messages.presence:[_1]', $plugin->translate( 'user.email' ) );
    } else {
        if (is_valid_email( $user->email )) {
            if ( MT->model( 'mtcart.user' )->exist( { email => $user->email } ) ) {
                push @errors, $plugin->translate( 'errors.messages.uniqueness:[_1]', $plugin->translate( 'user.email' ) );
            }
            $user->name( $user->email );
            if ( !$user->nickname && $user->email =~ /^(.+)\@/ ) {
                $user->nickname( $1 );
            }
        } else {
            push @errors, $plugin->translate( 'errors.messages.format:[_1]', $plugin->translate( 'user.email' ) );
        }
    }
    unless ( $user->validate_email_confirmation ) {
        push @errors, $plugin->translate( 'errors.messages.confirmation:[_1]', $plugin->translate( 'user.email' ) );
    }
    unless ( $user->password ) {
        push @errors, $plugin->translate( 'errors.messages.presence:[_1]', $plugin->translate( 'user.password' ) );
    } else {
        $user->set_password( $user->password ) if $user->password_present;
    }
    unless ( $user->validate_password_confirmation ) {
        push @errors, $plugin->translate( 'errors.messages.confirmation:[_1]', $plugin->translate( 'user.password' ) );
    }

    unless ( scalar( @errors ) == 0 && $user->SUPER::save(@_) ) {
        push( @errors, $user->errstr ) if $user->errstr;
        return $user->error( join( "\n", @errors ) );
    }

    1;
}

sub load {
    my $entry = shift;
    my ( $terms, $args ) = @_;

    if ( defined $terms
           && ( !ref $terms || ( ref $terms ne 'HASH' && ref $terms ne 'ARRAY' ) ) ) {
        $terms = {
            id => $terms,
            auth_type => 'MTCart',
        };
        $args = { limit => 1 };
        return $entry->SUPER::load( $terms, $args );
    } else {
        if ( ref $terms eq 'ARRAY' ) {
            $terms = {
                id => $terms,
                auth_type => 'MTCart',
            };
        } else {
            local $terms->{ auth_type } = 'MTCart';
        }
        return $entry->SUPER::load( $terms, $args );
    }
}

sub load_iter {
    my $author = shift;
    my ( $terms, $args ) = @_;
    if ( defined $terms
           && ( !ref $terms || ( ref $terms ne 'HASH' && ref $terms ne 'ARRAY' ) ) ) {
        $terms = {
            id => $terms,
            auth_type => 'MTCart',
        };
        $args = { limit => 1 };
        return $entry->SUPER::load_iter( $terms, $args );
    } else {
        if ( ref $terms eq 'ARRAY' ) {
            $terms = {
                id => $terms,
                auth_type => 'MTCart',
            };
          } else {
              local $terms->{ auth_type } = 'MTCart';
          }
        return $entry->SUPER::load_iter( $terms, $args );
    }
}


1;
