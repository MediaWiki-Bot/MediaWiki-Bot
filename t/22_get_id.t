# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 2;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (22_get_id.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $result = $bot->get_id('Main Page');
is($result, 15580374, 'Main Page found');

$result = $bot->get_text('egaP niaM');
is($result, undef, 'No page found');

