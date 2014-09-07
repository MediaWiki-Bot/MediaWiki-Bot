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

cmp_ok($bot->count_contributions('Mike.lifeguard'),                  '>', 10,   q{Count Mike's contribs});
is($bot->count_contributions('Non-existent username!! (hopefully)'), undef,     q{Count a nonexistent user's contribs});
