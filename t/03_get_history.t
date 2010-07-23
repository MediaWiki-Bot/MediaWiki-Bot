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

my @history = $bot->get_history('User:Shadow1/perlwikipedia/Check', 1);
is($history[0]->{comment}, 'Perlwikipedia tests');
