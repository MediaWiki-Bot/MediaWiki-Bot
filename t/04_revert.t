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

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (04_revert.t)',
});
my @history = $bot->get_history('User:ST47/test', 10);
my $revid = $history[9]->{'revid'};

my $text = $bot->get_text('User:ST47/test', $revid);
my $res = $bot->revert('User:ST47/test', $revid, 'MediaWiki::Bot tests (04_revert.t)');
sleep(1);
my $newtext = $bot->get_text('User:ST47/test');
is($text, $newtext, 'Reverted successfully');
