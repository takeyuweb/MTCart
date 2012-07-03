package MTCart::CMS;

use strict;
use warnings;

use utf8;

use MTCart::Util qw( find_by_sql );
use File::Basename;
use File::Spec;

sub install_mtcart_templates {
    my $app = shift;
    my $blog = $app->blog or return $app->trans_error( 'Invalid request' );
    
    return $app->trans_error( 'Invalid Request.' )
      unless $app->validate_magic();

    my $plugin = MT->component( 'MTCart' );
    my $tmpl_path = File::Spec->catdir( $plugin->path, 'tmpl/app/*.tmpl' );
    my @files = glob $tmpl_path;

    require MT::FileMgr;
    my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;

    foreach my $path (@files) {
        my $basename = basename( $path );
        next unless $basename =~ /^(.+)\.tmpl$/;
        my $tmpl_key = $1;

        next unless $fmgr->exists( $path );

        my $identifier = 'mtcart.'.$tmpl_key;
        my $tmpl = MT->model( 'template' )->get_by_key(
            { identifier => $identifier,
              blog_id => $blog->id,
              type => 'custom' }
        );
        unless ( $tmpl->id ) {
            $tmpl->build_dynamic( 0 );
            $tmpl->build_interval( 0 );
            $tmpl->build_type( 0 );
            $tmpl->name( $plugin->translate( '[MTCart] '. $tmpl_key ) );
        }
        my $text = $fmgr->get_data( $path );
        $text = $plugin->translate_templatized( $text );
        $tmpl->text( $text );
        
        $tmpl->save or die $tmpl->errstr;
    }

    $app->add_return_arg( saved => 1 );
    $app->call_return;
}

1;
