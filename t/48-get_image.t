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
   my $data = $bot->get_image('File:Foo bar foo bar.gif');
   ok($data, 'nonscaled image retrieved');
   my $img = Imager->new(data=>$data);
   ok($img, 'hopefully retrieved nonscaled data is an image.');
   is($img->getwidth(),15, 'nonscaled img has w 15');
   is($img->getheight(),15, 'nonscaled img has h 15');
}
{ #supply a width
   my $data = $bot->get_image('File:Foo bar foo bar.gif',{width=>5});
   ok($data, 'wscaled image retrieved');
   my $img = Imager->new(data=>$data);
   ok($img, 'hopefully retrieved wscaled data is an image.');
   is($img->getwidth(),5, 'wscaled img has w 5');
   is($img->getheight(),5, 'wscaled img has h 5');
}
{  #supply a width & a not-to-scale height. These 
   # should both be considered maximum dimensions,
   # and scale should be proportional.
   my $data = $bot->get_image('File:Foo bar foo bar.gif',{width=>5,height=>3});
   ok($data, 'whscaled image retrieved');
   my $img = Imager->new(data=>$data);
   ok($img, 'hopefully retrieved whscaled data is an image.');
   is($img->getwidth(),3, 'nonscaled img has w 3');
   is($img->getheight(),3, 'nonscaled img has h 3');
}

done_testing;
