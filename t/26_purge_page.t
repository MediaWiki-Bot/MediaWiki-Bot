# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 3;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use strict;
use warnings;
use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

$bot->login('Perlwikipedia testing', 'test');

my $result = $bot->purge_page('Main Page');
is($result, 1, 'Purge a single page');

$result = $bot->purge_page('tsixe reven lliw');
is($result, 0, 'Fail to purge a non-existent page');

my @purges = ('Main Page', 'Main Page', 'tsixe reven lliw', 'User:Mike.lifeguard');
$result = $bot->purge_page(\@purges);
is($result, 2, 'Purge some of an array of pages');
