use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 3;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

my $result = $bot->get_id('Main Page');
is($result, 11791, 'Main Page found');

$result = $bot->get_id('egaP niaM');
is($result, MediaWiki::Bot::PAGE_NONEXISTENT, 'No page found');

$result = $bot->get_id();
is($result, undef, 'param missing');
