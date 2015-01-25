use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More 0.96;

use MediaWiki::Bot;
my $t = __FILE__;

plan eval q{ use Imager; use Imager::File::JPEG; 1 }
    ? (tests => 3)
    : (skip_all => q{Imager & Imager::File::JPEG required});

my $bot = MediaWiki::Bot->new({
    agent    => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host     => 'test.wikipedia.org',
});

my $image_name = 'File:Wiki.png';
subtest 'no width, no height' => sub {
    plan tests => 4;
    my $data = $bot->get_image($image_name);
    ok $data, 'nonscaled image retrieved';

    my $img = Imager->new;
    my $did_read = $img->read(data => $data);
    ok $did_read, 'retrieved nonscaled data is an image'
        or diag $img->errstr;

    is $img->getwidth(),  135, 'nonscaled img has w 135';
    is $img->getheight(), 155, 'nonscaled img has h 155';
};

subtest 'supply a width' => sub {
    plan tests => 3;
    my $data = $bot->get_image($image_name, {width => 16});
    ok $data, 'wscaled image retrieved';

    my $img = Imager->new;
    my $did_read = $img->read(data => $data);
    ok $did_read, 'retrieved wscaled data is an image.'
        or diag $img->errstr;

    is $img->getwidth(),  16, 'wscaled img has w 16';
};

#supply a width & a not-to-scale height. These
# should both be considered maximum dimensions,
# and scale should be proportional.
subtest 'supply a width and a not-to-scale height' => sub {
    plan tests => 4;
    my $data = $bot->get_image($image_name, {width => 100, height => 100});
    ok $data, 'whscaled image retrieved';

    my $img = Imager->new;
    my $did_read = $img->read(data => $data);
    ok $did_read, 'retrieved whscaled data is an image.'
        or diag $img->errstr;

    cmp_ok $img->getwidth(),  '<=', 100, '100 height is max';
    cmp_ok $img->getheight(), '<=', 100, '100 width is max';
};
