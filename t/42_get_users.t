# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 1;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (03_get_history.t)',
});

my @history = $bot->get_history('User:ST47/test', 5);
my @history_users;
foreach my $entry (@history) {
    push(@history_users, $entry->{'user'});
}
my @users   = $bot->get_users('User:ST47/test', 5);
is_deeply(\@users, \@history_users,     'Concordance between two methods of getting the same data');

