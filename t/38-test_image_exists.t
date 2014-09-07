use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 3;

use MediaWiki::Bot qw(:constants);
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

my @images = (  'File:D2c6ac30964d4348d1a2b3ff7e97fa08.png',
                'File:Test image 13.png',
                'File:Albert Einstein Head.jpg', );

subtest 'numeric codes' => sub {
    plan tests => 3;
    ok($bot->test_image_exists($images[0]) == 0,  'Nonexistent image not found');
    ok($bot->test_image_exists($images[1]) == 1,  'Image is local');
    ok($bot->test_image_exists($images[2]) == 2,  'Image is on Commons');
};

subtest 'constant codes' => sub {
    plan tests => 3;
    is($bot->test_image_exists($images[0]), FILE_NONEXISTENT,  'Nonexistent image not found');
    is($bot->test_image_exists($images[1]), FILE_LOCAL,  'Image is local');
    is($bot->test_image_exists($images[2]), FILE_SHARED,  'Image is on Commons');
};

my $is = $bot->test_image_exists(\@images);
my $ought = [FILE_NONEXISTENT, FILE_LOCAL, FILE_SHARED];
is_deeply($is, $ought, 'Multiple images checked OK')
    or diag explain { is => $is, ought => $ought };
