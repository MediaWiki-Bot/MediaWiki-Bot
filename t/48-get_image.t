use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More 0.96;

use MediaWiki::Bot;
my $t = __FILE__;

plan eval q{ use Imager; use Imager::File::JPEG; 1 }
    ? (tests => 3)
    : (skip_all => q{Imager & Imager::File::JPEG required});

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};
my $login_data;
if (defined($username) and defined($password)) {
    $login_data = { username => $username, password => $password };
}

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
    login_data => $login_data,
});

my $image_name = 'File:Albert_Einstein_Head.jpg';
subtest 'no width, no height' => sub {
    plan tests => 4;
    my $data = $bot->get_image($image_name);
    ok $data, 'nonscaled image retrieved';

    my $img = Imager->new;
    my $did_read = $img->read(data => $data);
    ok $did_read, 'retrieved nonscaled data is an image'
        or diag $img->errstr;

    is $img->getwidth(),   924, 'nonscaled img has w 924';
    is $img->getheight(), 1203, 'nonscaled img has h 1203';
};

subtest 'supply a width' => sub {
    plan tests => 3;
    my $data = $bot->get_image($image_name, {width => 12});
    ok $data, 'wscaled image retrieved';

    my $img = Imager->new;
    my $did_read = $img->read(data => $data);
    ok $did_read, 'retrieved wscaled data is an image.'
        or diag $img->errstr;

    is $img->getwidth(),  12, 'wscaled img has w 12';
};

#supply a width & a not-to-scale height. These
# should both be considered maximum dimensions,
# and scale should be proportional.
subtest 'supply a width and a not-to-scale height' => sub {
    plan tests => 4;
    my $data = $bot->get_image($image_name, {width => 200, height => 200});
    ok $data, 'whscaled image retrieved';

    my $img = Imager->new;
    my $did_read = $img->read(data => $data);
    ok $did_read, 'retrieved whscaled data is an image.'
        or diag $img->errstr;

    cmp_ok $img->getwidth(),  '<=', 200, '200 height is max';
    cmp_ok $img->getheight(), '<=', 200, '200 width is max';
};
