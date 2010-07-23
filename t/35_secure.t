# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 1;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (35_secure.t)',
    host    => 'secure.wikimedia.org',
    path    => 'wikipedia/en/w',
    protocol=> 'https',
});

my $rand = rand();
my $status = $bot->edit({
    page    => 'User:ST47/test',
    text    => $rand,
    summary => 'MediaWiki::Bot tests (35_secure.t)',
});
SKIP: {
    if ($status == 3 and $bot->{error}->{code} == 3) {
        skip 'You are blocked, cannot use editing tests', 1;
    }

    my $is = $bot->get_text('User:ST47/test');
    is($is, $rand, 'Edited via secure server successfully');
}
