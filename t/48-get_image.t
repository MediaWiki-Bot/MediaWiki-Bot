use strict;
use warnings;
use Test::More 0.88;

use MediaWiki::Bot;
my $t = __FILE__;

unless (eval q{use Imager; 1 }) {
    plan skip_all => q{Imager required};
    exit;
}

#my $username = $ENV{'PWPUsername'};
#my $password = $ENV{'PWPPassword'};
my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
    #  login_data => { username => $username, password => $password },
});
if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

{ #no width, no height
   my $data = $bot->get_image('File:Test-favicon.png');
   ok($data, 'nonscaled image retrieved');
   
   my $img = Imager->new;
   my $did_read = $img->read(data=>$data);
   diag $img->errstr unless $did_read;
   ok($did_read, 'retrieved nonscaled data is an image.');

   is($img->getwidth(),16, 'nonscaled img has w 16');
   is($img->getheight(),16, 'nonscaled img has h 16');
}
{ #supply a width
   my $data = $bot->get_image('File:Test-favicon.png',{width=>12});
   ok($data, 'wscaled image retrieved');
   
   my $img = Imager->new;
   my $did_read = $img->read(data=>$data);
   diag $img->errstr unless $did_read;
   ok($did_read, 'retrieved wscaled data is an image.');

   is($img->getwidth(),12, 'wscaled img has w 12');
   is($img->getheight(),12, 'wscaled img has h 12');
}
{  #supply a width & a not-to-scale height. These 
   # should both be considered maximum dimensions,
   # and scale should be proportional.
   my $data = $bot->get_image('File:Test-favicon.png',{width=>4,height=>8});
   ok($data, 'whscaled image retrieved');

   my $img = Imager->new;
   my $did_read = $img->read(data=>$data);
   diag $img->errstr unless $did_read;
   ok($did_read, 'retrieved whscaled data is an image.');

   is($img->getwidth(),4, 'whscaled img has w 4');
   is($img->getheight(),4, 'whscaled img has h 4');
}

done_testing;
