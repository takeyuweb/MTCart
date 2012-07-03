package MTCart::Util;

use utf8;

use strict;
use warnings;

use MT::Util qw( offset_time_list );

use Encode;

use Exporter;
use base qw/Exporter/;
our @EXPORT_OK = qw( find_by_sql find_by_sql_iter is_app hmac_sha1 raise_error log_error log_security log_info build_tmpl deserialize_cart_data serialize_cart_data utf8_zen2han cart_subtotal payment_methods payment_method get_config );

# SQL実行
# 結果セットを カラム名-値ペアの連想配列の配列で返す
# my @result_set = find_by_sql( $sql, [ $bind_val1, $bind_val2 ] );
#
# [
#   { 'entry_id' => '1', 'score' => '100' },
#   { 'entry_id' => '2', 'score' => '200' },
#   { 'entry_id' => '3', 'score' => '300' },
# ]
#

# 例）ブログ記事ごとのコメント数
# find_by_sql( 'SELECT `comment_entry_id`, COUNT( `comment_id` ) AS count FROM `mt_comment` GROUP BY `comment_entry_id`' );
# $VAR1 = [ { 'count' => '1', 'comment_entry_id' => '1900' },
# { 'count' => '3', 'comment_entry_id' => '2136' },
# { 'count' => '3', 'comment_entry_id' => '2191' },
# { 'count' => '7', 'comment_entry_id' => '2207' },
# { 'count' => '1', 'comment_entry_id' => '2215' } ]; 

sub find_by_sql {
    my ( $sql, $bind_values ) = @_;
    
    my @result_set;
    
    require MT::Object;
    my $driver = MT::Object->driver;
    my $dbh = $driver->{ fallback }->{ dbh };
    my $sth = $dbh->prepare( $sql );
    die $dbh->errstr if $dbh->errstr;
    $sth->execute( @$bind_values );
    die $sth->errstr if $sth->errstr;

    my @row;
    my $column_names = $sth->{ NAME_hash };
    my @next_row;
    @next_row = $sth->fetchrow_array();
    while ( @next_row ) {
        @row = @next_row;
        my $result = {};
        foreach my $column_name ( keys %$column_names ) {
            my $idx = $column_names->{ $column_name };
            $result->{ $column_name } = $row[ $idx ];
        }
        push @result_set, $result;
        
        @next_row = $sth->fetchrow_array();
    }
    $sth->finish();
    
    return @result_set;
}

# my $iter = find_by_sql_iter( $sql, [ $v1, $v2, $v3 ], { per_page => 100 } );
# while( @results = $iter->() ) {
#     foreach my $result ( @results ) {
#         my $entry_id = $result->{ entry_id };
#         my $title = $result->{ title };
#     }
# }
sub find_by_sql_iter {
    my ( $sql, $orig_values, $addition ) = @_;
    
    $addition = {} unless defined( $addition );
    
    my %params = (
        per_page => 100
    );
    
    map { $params{$_} = $addition->{$_} } keys %$addition;
    
    my $page = 1;
    my $limit = $params{ per_page } || 0;
    
    $sql = $sql;
    if (  $sql !~ /\:limit\:/ && $sql !~ /\:offset\:/ ) {
        $sql = $sql . ' LIMIT :limit: OFFSET :offset:;';
    } elsif (  $sql !~ /\:limit\:/ || $sql !~ /\:offset\:/ ) {
        die 'plase use :limit: and :offset: for pagination';
    }
    
    # print $paginate_sql;
    my @values = @$orig_values;
    
    my $iter = sub {
        
        my $paginate_sql = "@{[$sql]}";
        $paginate_sql =~ s/\:limit\:/@{[ $limit ]}/;
        $paginate_sql =~ s/\:offset\:/@{[ $limit * ( $page - 1 ) ]}/;

        my @page_values = @values;

        my %map = ();
        my @result_set = find_by_sql(
            $paginate_sql,
            \@page_values );
        
        $page++;
        
        return @result_set;
    };
    
    return $iter;
}

sub is_app {
    my $app = MT->instance();
    return ( ref $app ) =~ /^MT::App::/ ? 1 : 0;
}


# HMAC-SHA1
# http://adiary.blog.abk.nu/0274
sub hmac_sha1 {
    # my $self = shift;
    my ($key, $msg) = @_;
    my $sha1;

    if ($Digest::SHA::PurePerl::VERSION) {
        $sha1 = Digest::SHA::PurePerl->new(1);
    } else {
        eval {
            require Digest::SHA1;
            $sha1 = Digest::SHA1->new;
        };
        if ($@) {
            require Digest::SHA::PurePerl;
            $sha1 = Digest::SHA::PurePerl->new(1);
        }
    }

    my $bs = 64;
    if (length($key) > $bs) {
        $key = $sha1->add($key)->digest;
        $sha1->reset;
    }
    my $k_opad = $key ^ ("\x5c" x $bs);
    my $k_ipad = $key ^ ("\x36" x $bs);
    $sha1->add($k_ipad);
    $sha1->add($msg);
    my $hk_ipad = $sha1->digest;
    $sha1->reset;
    $sha1->add($k_opad, $hk_ipad);

    my $b64d = $sha1->b64digest;
    $b64d = substr($b64d.'====', 0, ((length($b64d)+3)>>2)<<2);
    return $b64d;
}

sub do_log {
    my ($msg, $class) = @_;
    return unless defined($msg);

    my $app = MT->instance;

    require MT::Log;
    my $log = new MT::Log;
    $log->message($msg);
    $log->blog_id( $app->blog->id ) if defined( $app->blog );
    $log->level(MT::Log::DEBUG());
    $log->class($class) if $class;
    $log->ip( $app->remote_ip );
    $log->save or die $log->errstr;
}

sub raise_error {
    my ( $msg ) = @_;
    log_error( @_ );
    die $msg;
}

sub log_error {
    my ( $msg ) = @_;
    require MT::Log;
    do_log( $msg, MT::Log::ERROR() );
}

sub log_security {
    my ( $msg ) = @_;
    require MT::Log;
    do_log( $msg, MT::Log::SECURITY() );
}

sub log_info {
    my ( $msg ) = @_;
    require MT::Log;
    do_log( $msg, MT::Log::INFO() );
}


sub build_tmpl {
    my ( $tmpl_key, $ctx, $param ) = @_;
    $tmpl_key =~ s/\.tmpl$//;
    
    my $app = MT->instance;
    my $blog = $app->blog;
    
    my $tmpl_name = "$tmpl_key.tmpl";

    my $tmpl = MT->model( 'template' )->load({
        ( $blog ? ( blog_id     => $blog->id) : ()),
        identifier  => 'mtcart.'.$tmpl_key
    }, {
        limit => 1
    });
    unless ( defined $tmpl ) {
        $tmpl = $app->load_tmpl( $tmpl_name )
          or return $app->errstr;
    }

    unless ( $ctx ) {
        require MT::Template::Context;
        $ctx = MT::Template::Context->new;
    }

    $ctx->stash( 'author' => $app->user ) if !$ctx->stash( 'author' );

    if ( !$ctx->stash( 'blog' ) && $blog ) {
        $ctx->stash( blog => $blog );
        $ctx->stash( blog_id => $blog->id );
    }
    unless ( $ctx->{ current_timestamp } ) {
        if ( $blog ) {
            my @ts = offset_time_list( time, $blog->id );
            my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $ts[5] + 1900, $ts[4] + 1,
              @ts[ 3, 2, 1, 0 ];
            $ctx->{ current_timestamp } = $ts;
        }
    }

    $param ||= {};
    $param->{ magic_token } ||=  $app->current_magic;
    $param->{ blog_id } ||= $ctx->stash( 'blog_id' );
    $param->{ mode } ||= $ctx->stash( 'mode' );
    
    
    $app->run_callbacks( 'template_param' . $tmpl_key,
                         $app, $param, $tmpl );

    $ctx->{ __stash}{ vars } =  \( %{ $ctx->{__stash}{vars} }, %$param );
    
    my $tokens = $tmpl->tokens
      or return;
    my $builder = $ctx->{ __stash }{ builder } || MT::Builder->new;
    my $out = $builder->build( $ctx, $tokens );
    
    $out = $app->translate_templatized( $app->process_mt_template( $out ) );

    $app->run_callbacks( 'template_output' . $tmpl_key,
                         $app, \$out, $param, $tmpl );

    $out;
}

sub deserialize_cart_data {
    my ( $data ) = @_;
    my %items;
    foreach my $pair ( split ';', $data ) {
        my ( $item_id, $item_amount ) = split ':', $pair;
        $items{ $item_id } = $item_amount;
    }
    return \%items;
}

sub serialize_cart_data {
    my ( $items ) = @_;
    my @pairs;
    foreach my $item_id ( keys %$items ) {
        my $item_amount = $items->{ $item_id };
        push @pairs, "$item_id:$item_amount";
    }
    join( ';', @pairs );
}

# http://adiary.blog.abk.nu/0263
sub utf8_zen2han {
    my $str = shift;
    my $flag = utf8::is_utf8($str);
    Encode::_utf8_on($str);

    $str =~ tr/　！”＃＄％＆’（）＊＋，－．／０-９：；＜＝＞？＠Ａ-Ｚ［￥］＾＿｀ａ-ｚ｛｜｝/ -}/;

    if (!$flag) { Encode::_utf8_off($str); }
    return $str;
}

sub cart_subtotal {
    my ( $cart ) = @_;
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

sub payment_methods {
    my $payments = MT->registry( "payment_methods" ) || {};
    my %results = ();
    foreach my $method ( keys %$payments ) {
        $results{ $method } = {
            label => $payments->{$method}->{label}->()
        };
    }

    return \%results;
}

sub payment_method {
    my ( $key ) = @_;
    payment_methods()->{ $key };
}

sub get_config {
    my ( $blog_id, $key ) = @_;
    my $config_plugin = MT->component('MTCartConfig');
    $config_plugin->get_config_value( $key, $blog_id ? 'blog:'.$blog_id : 'system');
}

1;
