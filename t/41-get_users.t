use strict;
use warnings;
use Test::More tests => 1;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

my $title = 'User:Mike.lifeguard/04-edit.t';

my @history = map { $_->{user} } $bot->get_history($title, 5);
my @users   = $bot->get_users($title, 5);

is_deeply(\@users, \@history, 'Concordance between two methods of getting the same data');
