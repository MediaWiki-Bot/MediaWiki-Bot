use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

my $text = '<tt><nowiki>{{</nowiki>[[Template:tlxtest|tlxtest]]<nowiki>}}</nowiki></tt>';
is($bot->expandtemplates(undef, '{{tlxtest|tlxtest}}'), $text, '[[Template:Tlxtest]] expanded OK');

my $main_page = $bot->get_text('Main Page');
my $expanded  = $bot->expandtemplates('Main Page');
isnt($main_page, $expanded, 'Wikitext != expanded text');
