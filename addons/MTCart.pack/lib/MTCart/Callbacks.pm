package MTCart::Callbacks;

use strict;
use warnings;
use utf8;

our $plugin = MT->component( 'MTCart' );
our $config_plugin = MT->component( 'MTCartConfig' );

sub _hdlr_template_source_edit_entry {
    my ( $cb, $app, $tmpl_ref ) = @_;
    
}

sub _hdlr_template_param_edit_entry {
    my ( $cb, $app, $param, $tmpl ) = @_;

    my $blog_id = $app->blog ? $app->blog->id : undef;

    return unless $blog_id &&
      $config_plugin->get_config_value( 'enable', "blog:$blog_id" );

    push (@{ $param->{ 'field_loop' } }, {
        field_id => 'price',
        lock_field => '0',
        field_name => 'price',
        show_field => '1',
        field_label => $plugin->translate( 'field.label.price' ),
        label_class => 'top-label',
        required => '0',
        field_html => <<__EOF__,
<p><mt:If name="on_sale"><input type="checkbox" id="on_sale" name="on_sale" value="1" checked="checked" /><mt:Else><input type="checkbox" id="on_sale" name="on_sale" value="1" /></mt:If><input type="hidden" name="on_sale" value="0" /> <label for="on_sale">@{[ $plugin->translate('field.label.on_sale') ]}</label></p>
<p><input type="text" name="price" id="price" class="full-width" value="<mt:var name="price" escape="html">" /><br/ >
@{[ $plugin->translate( 'field.hint.price' ) ]}</p>
__EOF__
    });
}

1;
