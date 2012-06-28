package MT::App::MTCart;

use strict;
use warnings;
use utf8;

use base 'MT::App';

use MTCart::Util qw( hmac_sha1 log_error log_security build_tmpl deserialize_cart_data serialize_cart_data );

sub id { 'mtcart' }

sub app_path {
    return MT->config->CartPath || MT->config->CGIPath;
}

sub script {
    return MT->config( 'CartScript' );
}

sub uri {
    my $app = shift;
    $app->app_path . $app->script . $app->uri_params(@_);
}

sub init {
    my $app = shift;
    $app->SUPER::init( @_ ) or return;

    my $component = MT->component( 'MTCart' );

    $app->{ plugin_template_path } = File::Spec->catdir( $component->path, 'tmpl/app' );
    $app;
}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request( @_ );
    $app->set_no_cache;

    $app->{ default_mode } = 'show';
}

sub post_run {
    MT->instance->_write_session();

    MT::App::post_run( @_ );
}

sub _cart_session {
    my $app = shift;
    use MT::Request;
    my $r = MT::Request->instance;
    my $session = $r->cache( 'mtcart_session' );
    return $session if defined $session;

    $session = $app->_get_session();
    $r->cache( 'mtcart_session', $session );
    return $session;
}

sub _write_session {
    my $app = shift;
    my $sess_obj = $app->_cart_session();
    my $id = $sess_obj->id();
    my $secret = $app->_get_secret();
    my $digest = hmac_sha1( $secret, $id );
    my $signed = $id . ':' . $digest;

    if ( $sess_obj->is_dirty ) {
        $sess_obj->save or die $sess_obj->errstr;
    }

    my %kookee = (
        -name  => $app->config->CartCookie,
        -value => $signed,
        -path  => $app->config->CartSessionPath,
        -expires => '+' . $app->config->CartSessionTimeout . 's'
    );
    $app->bake_cookie(%kookee);
}

sub _get_secret {
    my $app = shift;
    my $secret = $app->config->CartCookieSecret;
    my $component = MT->component( 'MTCart' );
    $app->_error( 'app.message.no_secret' ) unless $secret;
    $secret;
}

sub _get_session {
    my $app = shift;
    my $component = MT->component( 'MTCart' );

    require MT::Session;

    my $cookie_name = $app->config->CartCookie;
    my $signed = $app->cookie_val($cookie_name) || "";

    my $sess_key = '';
    if ( $signed =~ /^(.+):(.+?)$/ ) {
        my $tmp = $1;
        my $digest = $2;
        if ( $digest eq hmac_sha1( $app->_get_secret(), $tmp ) ) {
            $sess_key = $tmp;
        } else {
            log_security $component->translate( 'app.error.invalid_session' );
        }
    }
    
    unless ( $sess_key ) {
        $sess_key = $app->make_magic_token;
    }

    my $sess_obj = MT::Session::get_unexpired_value(
        $app->config->CartSessionTimeout,
        { id => $sess_key,
          kind => 'MC' } );
    unless ( defined $sess_obj ) {
        $sess_obj = MT::Session->new;
        $sess_obj->id( $sess_key );
        $sess_obj->kind( 'MC' );
        $sess_obj->start( time );
        $sess_obj->save;
    }

    $sess_obj;
}

sub _cart_entries {
    my $app  = shift;
    
    my $sess_obj = $app->_cart_session;
    my $data = $sess_obj->get( 'cart_data' ) || '';
    my $items = deserialize_cart_data( $data );
    my @ids = keys(%$items);
    my $terms = { id => \@ids };

    MT->model( 'mtcart.entry' )->load( $terms );
}

# @Override
sub current_magic {
    my $app  = shift;
    my $sess = $app->_cart_session;
    return ( $sess ? $sess->id : undef );
}

# @Override
sub validate_magic {
    my $app = shift;
    return ( $app->current_magic || '' ) eq ( $app->param('magic_token') || '' );
}

sub show {
    my $app = shift;
    my $blog = $app->blog;

    return $app->_error( 'Invlid Request.' ) unless $blog;    

    require MT::Template::Context;
    my $ctx = MT::Template::Context->new;
    $ctx->stash( mtcart_session => $app->_cart_session );
    

    my $param = {};
    foreach my $key ( qw( added updated removed refreshed reset ) ) {
        $param->{ "request.$key" } = $app->param( $key );
    }

    my $return_to = $app->param( 'return_to' );
    $return_to = $blog->site_url unless $return_to;
    $param->{ return_to } = $return_to;

    build_tmpl( 'show.tmpl', $ctx, $param );
}

sub add {
  my $app = shift;
  my $blog = $app->blog or return $app->trans_error( 'Invlid Request.' );

    # チェック＆カート追加処理
    my $entry_id = $app->param( 'id' );
    my $blog_id = $app->param( 'blog_id' );
    my $amount = int( $app->param( 'amount' ) );

    $entry_id =~ s/\D//g;
    $blog_id =~ s/\D//g;
    
    my $entry = MT->model( 'mtcart.entry' )->load(
        { id => $entry_id,
          blog_id => $blog_id,
      },
        { limit => 1 }
    );
    return $app->_error( 'app.message.entry_not_found' ) unless $entry;

    return $app->redirect( $entry->permalink ) unless $amount > 0;

    my $sess_obj = $app->_cart_session;
    my $data = $sess_obj->get( 'cart_data' ) || '';
    my $items = deserialize_cart_data( $data );
    $items->{ $entry->id } += $amount;

    $sess_obj->set( 'cart_data', serialize_cart_data( $items ) );

    my $return_to = $app->param( 'return_to' );
    $return_to = $entry->permalink unless $return_to;

    $app->redirect(
        $app->uri(
            'mode' => 'show',
            args => {
                blog_id => $blog->id,
                added => 1,
                return_to => $return_to
            }
        )
    );
}

sub update {
    my $app = shift;

    my $blog = $app->blog or return $app->_error( 'Invlid Request.' );
    unless ( $app->validate_magic() ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'show',
                args => {
                    blog_id => $blog->id
                }
            )
        );
    }
    
    my $new_cart = {};
    my @entries = $app->_cart_entries();
    foreach my $entry ( @entries ) {
        my $new_amount = int( $app->param( "amount_@{[ $entry->id ]}" ) );
        next unless $new_amount > 0;
        $new_cart->{ $entry->id } = $new_amount;
    }
    $app->_cart_session->set( 'cart_data', serialize_cart_data( $new_cart ) );

    my $return_to = $app->param( 'return_to' );

    $app->redirect(
        $app->uri(
            'mode' => 'show',
            args => {
                blog_id => $blog->id,
                updated => 1,
            return_to => $return_to
        }
        )
    );
}

sub sign_in {
    my $app = shift;

    my $blog = $app->blog or return $app->_error( 'Invlid Request.' );
    unless ( $app->validate_magic() ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'show',
                args => {
                    blog_id => $blog->id
                }
            )
        );
    }

    my $next = $app->param( 'next' ) || 'purchase';

    # ログイン状態を調べる
    $app->_set_user;
    
    if ( defined $app->user ) {
        # ログイン済
        $app->redirect(
            $app->uri(
                'mode' => $next,
                args => {
                    blog_id => $blog->id,
                    magic_token => $app->current_magic,
                })
        );
    } else {
        my @errors = ();
        
        my $email = $app->param( 'email' );
        my $password = $app->param( 'password' );
        if ( $app->mode eq 'do_sign_in' ) {
            if ($email && $password ) {
                my $user = MT->model( 'mtcart.user' )->load(
                    { email => $email },
                    { limit => 1 }
                );
                if ( $user && $user->is_valid_password( $password ) ) {
                    $app->_do_sign_in( $user );
                    
                    return $app->redirect(
                        $app->uri(
                            'mode' => $next,
                            args => {
                                blog_id => $blog->id,
                                magic_token => $app->current_magic,
                            })
                    );
                }
            }
            my $component = MT->component( 'MTCart' );
            push @errors, $component->translate( 'app.message.login_failed' );
        }
        require MT::Template::Context;
        my $ctx = MT::Template::Context->new;
        $ctx->stash( mtcart_session => $app->_cart_session );
       
        my $param = {};
        $param->{ next } = $next;
        $param->{ email } = $email;
        $param->{ errstr } = join "\n", @errors;
        build_tmpl( 'sign_in.tmpl', $ctx, $param );
    }
}

sub sign_up {
    my $app = shift;
    
    my $blog = $app->blog or return $app->_error( 'Invlid Request.' );
    unless ( $app->request_method eq 'POST' &&
               $app->validate_magic() ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'show',
                args => {
                    blog_id => $blog->id
                }
            )
        );
    }
    
    my $next = $app->param( 'next' ) || 'purchase';
    
    # ログイン状態を調べる
    $app->_set_user;
    
    if ( defined $app->user ) {
        # ログイン済
        $app->redirect(
            $app->uri(
                'mode' => $next,
                args => {
                    blog_id => $blog->id
                }
            )
        );
    } else {
        my $user = MT->model( 'mtcart.user' )->new;
        
        my $param = {};

        foreach my $field ( qw( realname email email_confirmation password password_confirmation) ) {
            $param->{ $field } = $user->$field( $app->param( $field ) || '' );
        }
        
        my @errors = ();
        if ( $app->mode eq 'do_sign_up' ) {
            if ( $user->save ) {
                $app->_do_sign_in( $user );

                return $app->redirect(
                    $app->uri(
                        'mode' => $next,
                        args => {
                            blog_id => $blog->id,
                            magic_token => $app->current_magic,
                        })
                );
            } else {
                push @errors, $user->errstr;
            }
        }
      
        # 登録してすすむ or 登録しないですすむ
        require MT::Template::Context;
        my $ctx = MT::Template::Context->new;
        $ctx->stash( mtcart_session => $app->_cart_session );
        $ctx->stash( author => $user );
        
        
        $param->{ next } = $next;
        $param->{ errstr } = join "\n", @errors;
        
        build_tmpl( 'sign_up.tmpl', $ctx, $param );
    }
}

sub _do_sign_in {
    my $app = shift;
    my ( $user ) = @_;
    return unless $user && $user->id;
    my $sess = $app->_cart_session;
    $sess->set( 'user_id', $user->id );
    1;
}

sub purchase {
    my $app = shift;

    my $blog = $app->blog or return $app->_error( 'Invlid Request.' );
    unless ( $app->validate_magic() ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'show',
                args => {
                    blog_id => $blog->id
                }
            )
        );
    }

    # ログイン状態を調べる
    $app->_set_user;
    
    if ( defined $app->user ) {
        require MT::Template::Context;
        my $ctx = MT::Template::Context->new;
        $ctx->stash( mtcart_session => $app->_cart_session );
       
        my $param = {};
        build_tmpl( 'purchase.tmpl', $ctx, $param );
    } else {
        $app->redirect(
            $app->uri(
                'mode' => 'sign_in',
                args => {
                    blog_id => $blog->id,
                    'next' => 'purchase',
                })
        );
        
    }
}

sub _set_user {
    my $app = shift;

    my $sess = $app->_cart_session;
    my $user_id = $sess->get( 'user_id' );
    return unless defined( $user_id );
    my $user = MT->model( 'mtcart.user' )->load( $user_id );
    $app->user( $user );
}

sub _error {
    my $app = shift;
    my ( $message ) = @_;

    my $component = MT->component( 'MTCart' );

    my $blog = $app->blog;

    my $param = {
        'message' => $component->translate( $message )
    };

    log_error( $param->{ message } );
    build_tmpl( 'error.tmpl', undef, $param );
}

1;
