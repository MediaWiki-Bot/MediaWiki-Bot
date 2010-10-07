use strict;
use warnings;
use Test::More tests => 1;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (05_get_last.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $revid = $bot->get_last('Main Page', 'Not a real editor');
cmp_ok($revid, '>', 0, 'Find the last revision');
