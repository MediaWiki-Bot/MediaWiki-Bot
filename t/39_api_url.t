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

my $bot_one = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (39_api_url.t)',
    host    => '127.0.0.1',
    path    => '',
});

is($bot_one->{api}->{config}->{api_url}, 'http://127.0.0.1/api.php', 'api.php with null path is OK');

my $bot_two = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (39_api_url.t)',
    host    => '127.0.0.1',
    path    => undef,
});

is($bot_two->{api}->{config}->{api_url}, 'http://127.0.0.1/w/api.php', 'api.php with undef path is OK');

