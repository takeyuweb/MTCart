package MTCartConfig::L10N::ja;

use strict;
use base 'MTCartConfig::L10N';
use vars qw( %Lexicon );

our %Lexicon = (
    # config.yaml
    'plugin.description' => 'シンプルなショッピングカート機能を提供します。',

    # blog_config.tmpl
    'config.label.enable' => '有効',
    'config.label.order_email' => '注文メール送信先',
    'config.hint.order_email' => 'お客様から注文があった際に、ショップ管理者に通知するメールの送り先です。',

    'config.label.order_subject' => '注文確認メール件名',
);
