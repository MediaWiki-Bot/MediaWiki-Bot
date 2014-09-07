use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

{
    my @array = $bot->get_allusers(10);
    is(scalar(@array), 10, 'Got 10 users');
}

{
    my @array = $bot->get_allusers(10, 'sysop');
    is(scalar(@array), 10, 'Got 10 sysops');
}
