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

    'Install' => 'インストール',
    'Install MTCart templates' => 'MTCartテンプレートのインストール',
    'config.label.install_templates' => 'テンプレート',
    'config.hint.install_templates' => 'カート画面のカスタマイズのために、テンプレートに追加できます。',
    'Really?' => "カート画面のカスタマイズのために、テンプレートに追加できます。\n\n本当にインストールしますか？\nインストール済のMTCartテンプレートがある場合、上書きされます。",

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
    'app.message.order_not_found' => '注文が見つかりません。',
    'app.message.sent_success order_id:[_1] to:[_2](id:[_3] [_4])' => '注文確認メールを送信しました 注文ID:[_1] 送信先:[_2]（ID:[_3] [_4]様）',
    'app.message.sent_error order_id:[_1] to:[_2](id:[_3] [_4]) [_5]' => '注文確認メールの送信に失敗しました 注文ID:[_1] 送信先:[_2]（ID:[_3] [_4]様） エラー内容：[_5]',
    'app.label.return_to' => '元のページに戻る',
    'app.label.item_name' => '商品名',
    'app.label.unit_price' => '単価',
    'app.label.price' => '金額',
    'app.label.amount' => '数量',
    'app.label.subtotal' => '小計',
    'app.label.total' => '合計',
    'app.label.email' => 'メールアドレス',
    'app.label.email_confirmation' => 'メールアドレス（確認用）',
    'app.label.first_use' => '初めてのお客様',
    'app.label.already_registed' => '登録済のお客様',
    'app.label.password' => 'パスワード',
    'app.label.password_confirmation' => 'パスワード（確認用）',
    'app.label.mtcart_name' => 'お名前',
    'app.button.update' => '数量を更新',
    'app.button.purchase' => 'レジに進む',
    'app.button.sign_in' => 'サインイン',
    'app.button.sign_up' => 'お客様登録する',
    'app.button.update_user' => 'お客様情報を更新',

    # MTCart::User
    'user.delivery_name' => 'お名前',
    'user.password' => 'パスワード',
    'user.email' => 'メールアドレス',
    'user.delivery_address1' => '住所1',
    'user.delivery_address2' => '住所2',
    'user.delivery_state' => '都道府県',
    'user.delivery_tel' => '電話番号',
    'user.delivery_postal1' => '郵便番号',
    'user.delivery_postal2' => '郵便番号',
    'user.delivery_postal' => '郵便番号',

    # MTCart::Order
    'order.is_gift' => 'ギフト',
    'order.name' => 'お届け先氏名',
    'order.postal1' => '郵便番号',
    'order.postal2' => '郵便番号',
    'order.postal' => '郵便番号',
    'order.address1' => '住所1',
    'order.address2' => '住所2',
    'order.state' => '都道府県',
    'order.tel' => '電話番号',
    'order.payment' => '支払い方法',
    'order.date_on' => '配達希望日',
    'order.timezone' => '配達希望時間帯',

    # Validation
    'errors.messages.presence:[_1]' => '[_1]は必ず入力して下さい',
    'errors.messages.choice:[_1]' => '[_1]は必ず指定して下さい',
    'errors.messages.confirmation:[_1]' => '[_1]が確認用と一致しません',
    'errors.messages.format:[_1]' => '[_1]の書式が不正です',
    'errors.messages.uniqueness:[_1]' => '[_1]はすでに登録されています。',
);
