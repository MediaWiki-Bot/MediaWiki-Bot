# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 3;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (41_test_image_exists.t)',
});

is($bot->test_image_exists('File:d2c6ac30964d4348d1a2b3ff7e97fa08.png'),    0,  'Nonexistent image not found');
is($bot->test_image_exists('File:Windows 7.png'),                           1,  'Image is local');
is($bot->test_image_exists('File:Albert Einstein Head.jpg'),                2,  'Image is on Commons');

