use strict;
use warnings;
use Test::More tests => 4;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (41_test_image_exists.t)',
});

my @images = (  'File:D2c6ac30964d4348d1a2b3ff7e97fa08.png',
                'File:Windows 7.png',
                'File:Albert Einstein Head.jpg', );

is($bot->test_image_exists($images[0]),    0,  'Nonexistent image not found');
is($bot->test_image_exists($images[1]),    1,  'Image is local');
is($bot->test_image_exists($images[2]),    2,  'Image is on Commons');

my $is = $bot->test_image_exists(\@images);
my $ought = [0, 1, 2];
is_deeply($is, $ought, 'Multiple images checked OK');
