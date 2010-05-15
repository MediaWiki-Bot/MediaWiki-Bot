# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 8;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new();

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $result = $bot->get_pages('Main Page', 'Wikipedia', 'This page had better not exist..........', 'WP:CSD', 'Mouse');

is(keys %{$result}, 5, 'Got the right number of pages returned');
isnt($result->{'Wikipedia'}, 2, "Article doesn't not exist"); # Does this check for the page existing or not?
is($result->{'This page had better not exist..........'}, 2, "Article doesn't exist");
ok(defined($result->{'Wikipedia'}), 'Check for something not horribly wrong');
ok(!defined($result->{'Wikipedia:CSD'}), 'Should not return expanded names where an alias was requested');
ok(defined($result->{'WP:CSD'}), 'Namespace aliases work as expected');
like($result->{'Main Page'}, qr/Main Page/, 'Got Main Page on multi-page get');
like($result->{'Wikipedia'}, qr/Wikipedia/, 'Article about Wikipedia is not garbled and contains the string "Wikipedia"');
