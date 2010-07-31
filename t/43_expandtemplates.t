# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 2;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (43_expandtemplates.t)',
});

my $text = '<tt><nowiki>{{</nowiki>[[Template:tlx|tlx]]<nowiki>}}</nowiki></tt>';
is($bot->expandtemplates(undef, '{{tlx|tlx}}'), $text, '[[Template:Tlx]] expanded OK');

my $main_page = $bot->get_text('Main Page');
my $expanded  = $bot->expandtemplates('Main Page');
isnt($main_page, $expanded, 'Wikitext != expanded text');

