package MT::App::MTCart;

use strict;
use warnings;
use utf8;

use base 'MT::App';

use MT::Mail;

use MTCart::Util qw( hmac_sha1 log_error log_security log_info build_tmpl deserialize_cart_data serialize_cart_data
                     cart_subtotal payment_methods get_config );

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

    $app->{ default_mode } = 'view_cart';
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
        #-expires => '+' . $app->config->CartSessionTimeout . 's'
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
    my $cart = deserialize_cart_data( $data );
    my @ids = keys(%$cart);
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

sub view_cart {
    my $app = shift;
    my $blog = $app->blog;

    return $app->_error( 'Invalid request' ) unless $blog;    

    unless ( get_config( $blog->id, 'enable' ) ) {
        return $app->_error( 'Invalid request' );
    }

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
    
    build_tmpl( 'view_cart', $ctx, $param );
}

sub add {
    my $app = shift;
    my $blog = $app->blog or return $app->trans_error( 'Invalid request' );

    unless ( get_config( $blog->id, 'enable' ) ) {
        return $app->_error( 'Invalid request' );
    }

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
    my $cart = deserialize_cart_data( $data );
    $cart->{ $entry->id } += $amount;

    $sess_obj->set( 'cart_data', serialize_cart_data( $cart ) );

    my $return_to = $app->param( 'return_to' );
    $return_to = $entry->permalink unless $return_to;

    $app->redirect(
        $app->uri(
            'mode' => 'view_cart',
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

    my $blog = $app->blog or return $app->_error( 'Invalid request' );

    unless ( get_config( $blog->id, 'enable' ) ) {
        return $app->_error( 'Invalid request' );
    }

    unless ( $app->validate_magic() ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'view_cart',
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
            'mode' => 'view_cart',
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

    my $blog = $app->blog or return $app->_error( 'Invalid request' );

    unless ( get_config( $blog->id, 'enable' ) ) {
        return $app->_error( 'Invalid request' );
    }

    unless ( $app->validate_magic() ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'view_cart',
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
                    { email => $email,
                      status => MT::Author::APPROVED() },
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
        build_tmpl( 'sign_in', $ctx, $param );
    }
}

sub sign_up {
    my $app = shift;
    
    my $blog = $app->blog or return $app->_error( 'Invalid request' );

    unless ( get_config( $blog->id, 'enable' ) ) {
        return $app->_error( 'Invalid request' );
    }

    unless ( $app->request_method eq 'POST' &&
               $app->validate_magic() ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'view_cart',
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
        $user->status( MT::Author::APPROVED() );
        my $param = {};
        my @states = qw(北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県 東京都 神奈川県 埼玉県 千葉県 茨城県 栃木県 群馬県 山梨県 新潟県 長野県 富山県 石川県 福井県 愛知県 岐阜県 静岡県 三重県 大阪府 兵庫県 京都府 滋賀県 奈良県 和歌山県 鳥取県 島根県 岡山県 広島県 山口県 徳島県 香川県 愛媛県 高知県 福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県);
        $param->{states} = \@states;
        
        foreach my $field ( qw(delivery_name delivery_address1 delivery_address2 delivery_state delivery_tel delivery_postal1 delivery_postal2 email email_confirmation password password_confirmation) ) {
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
        
        build_tmpl( 'sign_up', $ctx, $param );
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

    my $blog = $app->blog or return $app->_error( 'Invalid request' );

    unless ( get_config( $blog->id, 'enable' ) ) {
        return $app->_error( 'Invalid request' );
    }

    unless ( $app->validate_magic() ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'view_cart',
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
       
        my $tmpl_param = _build_purchase_tmpl_param();

        my $payments = payment_methods();
        $tmpl_param->{ payments } = $payments;

        build_tmpl( 'purchase', $ctx, $tmpl_param );
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

sub order {
    my $app = shift;
    my $component = MT->component( 'MTCart' );

    my $blog = $app->blog or return $app->_error( 'Invalid request' );

    unless ( get_config( $blog->id, 'enable' ) ) {
        return $app->_error( 'Invalid request' );
    }

    unless ( $app->validate_magic() ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'view_cart',
                args => {
                    blog_id => $blog->id
                }
            )
        );
    }

    # ログイン状態を調べる
    my $user = $app->_set_user;
    
    unless ( defined $user ) {
        $app->redirect(
            $app->uri(
                'mode' => 'sign_in',
                args => {
                    blog_id => $blog->id,
                    'next' => 'purchase',
                })
        );
    }

    require MT::Template::Context;
    my $ctx = MT::Template::Context->new;
    $ctx->stash( mtcart_session => $app->_cart_session );
    my $tmpl_param = _build_purchase_tmpl_param();

    my $order = MT->model( 'mtcart.order' )->new;
    $order->blog_id( $blog->id );
    $order->user_id( $user->id );
    $order->user_name( $user->delivery_name );
    $order->remote_ip( $app->remote_ip );

    my @fields = qw(is_gift name address1 address2 state tel payment date_on timezone postal1 postal2 note);
    foreach my $field ( @fields ) {
        $tmpl_param->{ $field } = $order->$field( $app->param( $field ) );
    }

    unless ( $order->is_gift ) {
        foreach my $field ( qw(name address1 address2 state tel postal1 postal2) ) {
            my $user_field = "delivery_$field";
            $tmpl_param->{ $field } = $order->$field( $user->$user_field );
        }
    }

    my $sess_obj = $app->_cart_session;
    my $data = $sess_obj->get( 'cart_data' ) || '';
    my $cart = deserialize_cart_data( $data );
    
    my @cart_data = ();
    foreach my $entry ( $app->_cart_entries() ) {
        my $price = $entry->price;
        my $amount = $cart->{ $entry->id };
        push @cart_data, { id => $entry->id,
                           title => $entry->title,
                           price => $price,
                           amount => $amount,
                           subtotal => $price * $amount
                       };
    }
    $order->cart_data( \@cart_data );
    $order->total_price( cart_subtotal( $cart ) );

    unless ( @cart_data ) {
        return $app->redirect(
            $app->uri(
                'mode' => 'view_cart',
                args => {
                    blog_id => $blog->id
                }
            )
        );
    }

    if ( $order->is_valid ) {
        if ( $app->mode ne 'order' ) {
            build_tmpl( 'confirm', $ctx, $tmpl_param );
        } else {
            $app->run_callbacks( 'mtcart_pre_save.order', $app, $order );
            $order->save or return $order->errstr;
            $app->run_callbacks( 'mtcart_post_save.order', $app, $order );

            # reset
            $app->_cart_session->set( 'cart_data', serialize_cart_data( {} ) );

            $order = MT->model( 'mtcart.order' )->load( $order->id );

            my $mail_param = {};
            my $mail_ctx = MT::Template::Context->new;
            $mail_ctx->stash('order', $order);
            my $mail_body = build_tmpl( 'order_mail', $mail_ctx, $mail_param );

            my $mail_head = {
                To => $user->email,
                Cc => get_config( $blog->id, 'order_email' ),
                Subject => get_config( $blog->id, 'order_subject' ),
            };

            my $flag = MT::Mail->send( $mail_head, $mail_body );
            if ( $flag ) {
                log_info( $component->translate( 'app.message.sent_success order_id:[_1] to:[_2](id:[_3] [_4])', $order->id, $user->email, $user->id, $user->delivery_name ) );
            } else {
                log_error( $component->translate( 'app.message.sent_error order_id:[_1] to:[_2](id:[_3] [_4]) [_5]', $order->id, $user->email, $user->id, $user->delivery_name, MT::Mail->errstr ) );
            }

            $app->redirect(
                $app->uri(
                    'mode' => 'view_order',
                    args => {
                        blog_id => $blog->id,
                        id => $order->id,
                        ordered => 1
                    })
            );
        }
    } else {
        $tmpl_param->{ errstr } = join "\n", $order->errstr;
        build_tmpl( 'purchase', $ctx, $tmpl_param );
    }
}

sub _build_purchase_tmpl_param {
    my $tmpl_param = {};
    my @states = qw(北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県 東京都 神奈川県 埼玉県 千葉県 茨城県 栃木県 群馬県 山梨県 新潟県 長野県 富山県 石川県 福井県 愛知県 岐阜県 静岡県 三重県 大阪府 兵庫県 京都府 滋賀県 奈良県 和歌山県 鳥取県 島根県 岡山県 広島県 山口県 徳島県 香川県 愛媛県 高知県 福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県);
    $tmpl_param->{ states } = \@states;
    my $payments = payment_methods();
    $tmpl_param->{ payments } = $payments;

    my @dates = ();
    my $now = time;
    for( my $i=0; $i<14; $i++ ) {
        my ( $sec, $min, $hour, $mday, $month, $year, $wday, $stime ) = localtime( $now + ($i + 4) * 60*60*24 );
        push @dates, sprintf( "%04d-%02d-%02d", $year+1900, $month+1, $mday );
    }
    $tmpl_param->{ dates } = \@dates;

    my @timezones = qw( 12-14 14-16 16-18 18-20 20-21 );
    $tmpl_param->{ timezones } = \@timezones;

    return $tmpl_param;
}

sub view_order {
    my $app = shift;
    my $blog = $app->blog;

    return $app->_error( 'Invalid request' ) unless $blog;    

    my $order_id = $app->param( 'id' );
    return $app->_error( 'Invalid request' ) unless $order_id;

    $app->_set_user;    
    unless ( defined $app->user ) {
        $app->redirect(
            $app->uri(
                'mode' => 'sign_in',
                args => {
                    blog_id => $blog->id,
                    'next' => 'view_order',
                    order_id => $order_id
                })
        );
    }

    my $order = MT->model( 'mtcart.order' )->load(
        { id => $order_id,
          blog_id => $blog->id,
          user_id => $app->user->id },
        { limit => 1 }
    );

    unless ( defined $order ) {
        return $app->_error( 'app.message.order_not_found' );
    }
    
    require MT::Template::Context;
    my $ctx = MT::Template::Context->new;
    $ctx->stash( 'mtcart_session', $app->_cart_session);
    $ctx->stash( 'order', $order );

    my $param = {};
    foreach my $key ( qw( ordered ) ) {
        $param->{ "request.$key" } = $app->param( $key );
    }

    my $return_to = $app->param( 'return_to' );
    $return_to = $blog->site_url unless $return_to;
    $param->{ return_to } = $return_to;
    
    build_tmpl( 'view_order', $ctx, $param );
}

sub edit_user {
    my $app = shift;
    
    my $blog = $app->blog or return $app->_error( 'Invalid request' );

    unless ( get_config( $blog->id, 'enable' ) ) {
        return $app->_error( 'Invalid request' );
    }

    if ( $app->mode eq 'update_user' ) {
        unless ( $app->request_method eq 'POST' &&
                   $app->validate_magic() ) {
            return $app->redirect(
                $app->uri(
                    'mode' => 'view_cart',
                    args => {
                        blog_id => $blog->id
                    }
                )
            );
        }
    }
    
    my $next = $app->param( 'next' ) || 'view_cart';
    
    # ログイン状態を調べる
    my $user = $app->_set_user;
    
    unless ( defined $user ) {
        $app->redirect(
            $app->uri(
                'mode' => 'view_cart',
                args => {
                    blog_id => $blog->id
                }
            )
        );
    } else {
        my $param = {};
        my @states = qw(北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県 東京都 神奈川県 埼玉県 千葉県 茨城県 栃木県 群馬県 山梨県 新潟県 長野県 富山県 石川県 福井県 愛知県 岐阜県 静岡県 三重県 大阪府 兵庫県 京都府 滋賀県 奈良県 和歌山県 鳥取県 島根県 岡山県 広島県 山口県 徳島県 香川県 愛媛県 高知県 福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県);
        $param->{states} = \@states;
        
        my @errors = ();
        if ( $app->mode eq 'update_user' ) {
            foreach my $field ( qw(delivery_name delivery_address1 delivery_address2 delivery_state delivery_tel delivery_postal1 delivery_postal2) ) {
                $param->{ $field } = $user->$field( $app->param( $field ) || '' );
            }
            if ( $app->param( 'email_confirmation' ) ) {
                foreach my $field ( qw(email email_confirmation) ) {
                    $param->{ $field } = $user->$field( $app->param( $field ) || '' );
                }                
            } else {
                $param->{ 'email' } = $user->email;
            }
            if ( $app->param( 'password' ) || $app->param( 'password_confirmation' ) ) {
                foreach my $field ( qw(password password_confirmation) ) {
                    $param->{ $field } = $user->$field( $app->param( $field ) || '' );
                }
            }

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
        } else {
            foreach my $field ( qw(delivery_name delivery_address1 delivery_address2 delivery_state delivery_tel delivery_postal1 delivery_postal2 email) ) {
                $param->{ $field } = $user->$field();
            }
        }
      
        require MT::Template::Context;
        my $ctx = MT::Template::Context->new;
        $ctx->stash( mtcart_session => $app->_cart_session );
        $ctx->stash( author => $user );
        
        
        $param->{ next } = $next;
        $param->{ errstr } = join "\n", @errors;
        
        build_tmpl( 'edit_user', $ctx, $param );
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

    my $param = {
        'message' => $component->translate( $message )
    };
    
    log_error( $param->{ message } );
    build_tmpl( 'error', undef, $param );
}


1;
