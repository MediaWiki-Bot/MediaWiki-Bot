# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 5;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use MediaWiki::Bot;
SKIP: {
    skip('wiki.xyrael.net is down', 5);

    my $bot = MediaWiki::Bot->new('make test');
    $bot->set_wiki('wiki.xyrael.net', 'w');

    if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
        $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
    }

    my @pages = $bot->get_all_pages_in_category('Category:MediaWiki::Bot test nest2');

    ok(defined $pages[0], 'Get small category');

    #This tests categories with more than one page.
    $bot->set_wiki('en.wikipedia.org', 'w');
    @pages = $bot->get_all_pages_in_category('Category:Wikipedia external links cleanup');

    ok(defined $pages[0], 'Get big category');
    cmp_ok(scalar(@pages), '>', 500, 'Get big category, enough elements');

    $bot->set_wiki('wiki.xyrael.net', 'w');
    @pages = $bot->get_all_pages_in_category('Category:MediaWiki::Bot test nest1');
    is(scalar(@pages), 3, 'Nested categories, one level');

    @pages = $bot->get_all_pages_in_category('Category:MediaWiki::Bot test');
    is (scalar(@pages), 5, 'Nested categories, two levels');
}
