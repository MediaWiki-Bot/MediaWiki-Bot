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
    agent   => 'MediaWiki::Bot tests (23_is_blocked.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# Jimbo is almost certainly not blocked right now
my $result = $bot->is_blocked('User:Jimbo Wales');
is($result, 0, 'current blocks');

# A random old account I chose - it will probably be blocked forever
# (del/undel) 23:44, 31 December 2006 Agathoclea (talk | contribs | block) blocked Deathtonoobs (talk | contribs) with an expiry time of indefinite (vandalism only - offensive username) (unblock | change block)
$result = $bot->is_blocked('User:Deathtonoobs');
is($result, 1, 'current blocks');
