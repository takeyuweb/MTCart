package MTCart::CMS;

use strict;
use warnings;

use utf8;

use MTCart::Util qw( find_by_sql );

sub _manage_mtcart_goods {
    my ( $app ) = @_;
    
    my $blog = $app->blog;
    return $app->error( 'Invalid Request.' ) unless $blog;

    my $entry_id = $app->param( 'entry_id' );
    my $entry = $entry_id ? MT->model( 'entry' )->load(
        { id => $entry_id, blog_id => $blog->id },
        { limit => 1 } ) : undef;
    return $app->error( 'Invalid Request.' ) unless defined $entry;

    my $variation_keys_str = $entry->variation_keys;
    # my @variation_keys = grep length $_, ( split /,/, $variation_keys_str );

    my @goods = MT->model( 'mtcart_goods' )->load(
        { entry_id => $entry->id },
        undef
    );

    my $sql = <<__SQL__;
SELECT mtcart_variation_key
FROM `@{[ MT->model( 'mtcart_variation' )->table_name ]}`
INNER JOIN `@{[ MT->model( 'mtcart_goods' )->table_name ]}`
ON mtcart_variation_goods_id = mtcart_goods_id
WHERE mtcart_goods_entry_id = ?
GROUP BY mtcart_variation_key
__SQL__
    my $values = [ $entry->id ];
    my @records = find_by_sql( $sql, $values );
    my @variation_keys = map { $_->{ mtcart_variation_key } } @records;

    my $variations = ();
    foreach my $key ( @variation_keys ) {
        my @values = map { $_->{ mtcart_variation_value } } find_by_sql( <<__SQL__, [ $entry->id, $key ] );
SELECT mtcart_variation_value
FROM `@{[ MT->model( 'mtcart_variation' )->table_name ]}`
JOIN `@{[ MT->model( 'mtcart_goods' )->table_name ]}`
ON mtcart_variation_goods_id = mtcart_goods_id
WHERE mtcart_goods_entry_id = ? AND mtcart_variation_key = ?
__SQL__
        my $ref = \@values;
        $variations->{ $key } = @{ $ref };
    }

    #die Data::Dumper->Dump([ \$variations ]);

    #push @{$variations}, $variation;

    my $tmpl = $app->load_tmpl( 'manage_mtcart_goods.tmpl' );

    my $ctx = $tmpl->context;
    $ctx->stash( 'entry', $entry );
    $ctx->stash( 'blog', $blog );    

    my $params = {
        blog_id => $blog,
        entry_id => $entry->id,
        variation_keys => \@variation_keys,
        variations => $variations,
    };
    
    return $app->build_page( $tmpl, $params );
}

1;
