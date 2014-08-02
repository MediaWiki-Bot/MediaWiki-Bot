use strict;
use warnings;
use Test::More tests => 1;
use List::MoreUtils qw/uniq/;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

my $title = 'User:Mike.lifeguard/03-get text.t';

my @history = uniq map { $_->{user} } $bot->get_history($title, 5);
my @users   = uniq $bot->get_users($title, 5);

is_deeply(\@users, \@history, 'Concordance between two methods of getting the same data');
