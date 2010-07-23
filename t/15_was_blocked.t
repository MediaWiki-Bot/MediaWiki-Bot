# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 2;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (15_was_blocked.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# Jimbo has been blocked before
my $result = $bot->was_blocked('User:Jimbo Wales');
is($result, 1, 'block history');

# I haven't ever been blocked
$result = $bot->was_blocked('User:Mike.lifeguard');
is($result, 0, 'block history');
