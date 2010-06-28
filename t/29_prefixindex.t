# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 4;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (29_prefixindex.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $bot->prefixindex("User:Mike.lifeguard/29 prefixindex.t");

is(scalar @pages, 3, 'Correct number of pages');
is($pages[0]->{'title'}, 'User:Mike.lifeguard/29 prefixindex.t',     'Page 0 correct');
is($pages[1]->{'title'}, 'User:Mike.lifeguard/29 prefixindex.t/one', 'Page 1 correct');
is($pages[2]->{'title'}, 'User:Mike.lifeguard/29 prefixindex.t/two', 'Page 2 correct');

