# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 1;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new('make test');
my $article = 'WMIZ';

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
    $article = 'Main Page' unless ($ENV{'PWPMakeTestSetWikiHost'}.$ENV{'PWPMakeTestSetWikiDir'} eq 'en.wikipedia.orgw');
}

my @links = $bot->what_links_here($article);

ok(defined $links[0]->{title});
