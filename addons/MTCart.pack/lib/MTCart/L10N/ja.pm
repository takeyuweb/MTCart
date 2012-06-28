package MTCart::L10N::ja;

use strict;
use base 'MTCart::L10N';
use vars qw( %Lexicon );

our %Lexicon = (
    # MTCart::Config
    'config.description' => 'シンプルなショッピングカート機能を追加します。',
    
    # config.yaml
    'applications.cms.menus.mtcart_goods.label' => '商品マスタ',
    'applications.cms.menus.mtcart_goods.list.label' => '一覧',
    'listing_screens.mtcart_goods.object_label' => '商品',
    'listing_screens.mtcart_goods.screen_label' => '商品マスタ',
    'listing_screens.mtcart_goods.object_label_plural' => '商品',
    
    # lib/MTCart/Goods.pm
    #'mtcart_goods.content_actions.new.label' => '登録',
    

    # lib/MTCart/Callbacks.pm
    'field.label.price' => '価格',
    'field.label.on_sale' => '販売中',
    'field.hint.price' => '商品の価格を半角数字で記入します',

    # MT::App::MTCart.pm
    'app.error.invalid_session' => 'セッションの改ざんを検知しました。受け入れを拒否しました。',
    'app.message.no_secret' => 'mt-config.cgi で CartCookieSecret を設定して下さい。',
    'app.message.entry_not_found' => '商品が見つかりません。',
    'app.message.cart_empty' => 'お客様のショッピングカートに商品はありません。',
    'app.message.request.added' => 'カートに商品を追加しました。',
    'app.message.request.refreshed' => 'カートを最新の状態に更新しました。',
    'app.message.request.removed' => 'カートから商品を取り出しました。',
    'app.message.request.updated' => 'カートの商品の数量を変更しました。',
    'app.message.request.reset' => '申し訳ありません。カートの内容がリセットされました。',
    'app.message.login_failed' => 'ログインできません。メールアドレスとパスワードの組が正しくありません。',
    'app.label.return_to' => '元のページに戻る',
    'app.label.price' => '単価',
    'app.label.amount' => '数量',
    'app.label.subtotal' => '小計',
    'app.label.total' => '合計',
    'app.label.email' => 'メールアドレス',
    'app.label.email_confirmation' => 'メールアドレス（確認用）',
    'app.label.first_use' => '初めてのお客様',
    'app.label.already_registed' => '登録済のお客様',
    'app.label.password' => 'パスワード',
    'app.label.password_confirmation' => 'パスワード（確認用）',
    'app.label.realname' => 'お名前',
    'app.button.update' => '数量を更新',
    'app.button.purchase' => 'レジに進む',
    'app.button.sign_in' => 'サインイン',
    'app.button.sign_up' => 'お客様登録する',

    # MTCart::User
    'user.realname' => 'お名前',
    'user.password' => 'パスワード',
    'user.email' => 'メールアドレス',

    # Validation
    'errors.messages.presence:[_1]' => '[_1]は必ず入力して下さい',
    'errors.messages.confirmation:[_1]' => '[_1]が確認用と一致しません',
    'errors.messages.format:[_1]' => '[_1]の書式が不正です',
    'errors.messages.uniqueness:[_1]' => '[_1]はすでに登録されています。',
    
);
