# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 3;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use MediaWiki::Bot;
my $bot = MediaWiki::Bot->new();

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $bot->search('Main Page');
isa_ok(\@pages, 'ARRAY', 'Right return type');
is($pages[0], 'Main Page', 'Found [[Main Page]]');

@pages = $bot->search('62c77d65adf258464e0f0820696b871251c21eb4');
is(scalar @pages, 0, 'No results found for a nonsensical search');

