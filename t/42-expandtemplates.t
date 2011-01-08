use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

my $text = '<span style="white-space:nowrap">&#123;&#123;[[Template:tlx|tlx]]&#125;&#125;</span>';
is($bot->expandtemplates(undef, '{{tlx|tlx}}'), $text, '[[Template:Tlx]] expanded OK');

my $main_page = $bot->get_text('Main Page');
my $expanded  = $bot->expandtemplates('Main Page');
isnt($main_page, $expanded, 'Wikitext != expanded text');
