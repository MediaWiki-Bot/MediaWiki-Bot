# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 2;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests',
    host    => 'meta.wikimedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# 127.0.0.1 has been blocked before
my $result = $bot->was_g_blocked('127.0.0.1');
is($result, 1, 'globalblock history');

# 127.0.4.4 probably hasn't been
$result = $bot->was_g_blocked('127.0.0.4');
is($result, 0, 'globalblock history');

