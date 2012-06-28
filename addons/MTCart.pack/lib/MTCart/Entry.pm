package MTCart::Entry;

use strict;
use base qw( MT::Entry );

sub load {
    my $entry = shift;
    my ( $terms, $args ) = @_;

    if ( defined $terms
           && ( !ref $terms || ( ref $terms ne 'HASH' && ref $terms ne 'ARRAY' ) ) ) {
        $terms = {
            id => $terms,
            on_sale => 1,
            status => MT::Entry::RELEASE()
        };
        $args = { limit => 1 };
        return $entry->SUPER::load( $terms, $args );
    } else {
        if ( ref $terms eq 'ARRAY' ) {
            $terms = {
                id => $terms,
                on_sale => 1,
                status => MT::Entry::RELEASE()
            };
          } else {
              local $terms->{ on_sale } = 1;
              local $terms->{ status } = MT::Entry::RELEASE();
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
            on_sale => 1,
            status => MT::Entry::RELEASE()
        };
        $args = { limit => 1 };
        return $entry->SUPER::load_iter( $terms, $args );
    } else {
        if ( ref $terms eq 'ARRAY' ) {
            $terms = {
                id => $terms,
                on_sale => 1,
                status => MT::Entry::RELEASE()
            };
          } else {
              local $terms->{ on_sale } = 1;
              local $terms->{ status } = MT::Entry::RELEASE();
          }
        return $entry->SUPER::load_iter( $terms, $args );
    }
}

1;
