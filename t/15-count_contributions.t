use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

cmp_ok($bot->count_contributions('Mike.lifeguard'),                  '>', 10,   q{Count Mike's contribs});
is($bot->count_contributions('Non-existent username!! (hopefully)'), undef,     q{Count a nonexistent user's contribs});
