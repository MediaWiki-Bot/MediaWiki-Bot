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
    agent   => 'MediaWiki::Bot tests (36_is_protected.t)',
});

# [[Main Page]] is probably protected
my @pages = ("Main Page", "Ambrax");
my $result = $bot->is_protected(\@pages);
isa_ok($result,                     'HASH',  'Return value of is_protected()');
isa_ok($result->{'Main Page'},      'ARRAY', '[[Main Page]] protection');
is($result->{'Ambrax'},             undef,   '[[Ambrax]] protection');

# [[User talk:Mike.lifeguard]] is probably not protected
$result = $bot->is_protected("User talk:Mike.lifeguard");
is($result,             undef,   '[[User talk:Mike.lifeguard]] protection');
