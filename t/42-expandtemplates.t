use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

is
    $bot->expandtemplates(undef, '{{tlxtest|tlxtest}}') =>
    '<tt><nowiki>{{</nowiki>[[Template:tlxtest|tlxtest]]<nowiki>}}</nowiki></tt>',
    '[[Template:Tlxtest]] expanded OK';

isnt
    $bot->get_text('Main Page') =>
    $bot->expandtemplates('Main Page'),
    'Wikitext != expanded text';
