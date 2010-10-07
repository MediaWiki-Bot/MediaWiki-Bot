use strict;
use warnings;
use Test::More tests => 3;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (30_search.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $bot->search('Main Page');
isa_ok(\@pages, 'ARRAY', 'Right return type');
is($pages[0], 'Main Page', 'Found [[Main Page]]');

@pages = $bot->search('62c77d65adf258464e0f0820696b871251c21eb4');
is(scalar @pages, 0, 'No results found for a nonsensical search');
