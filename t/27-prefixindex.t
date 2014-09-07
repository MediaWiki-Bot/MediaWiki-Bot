use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 4;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $bot->prefixindex('User:Mike.lifeguard/27-prefixindex.t');

is(scalar @pages, 3, 'Correct number of pages');
is($pages[0]->{'title'}, 'User:Mike.lifeguard/27-prefixindex.t',     'Page 0 correct');
is($pages[1]->{'title'}, 'User:Mike.lifeguard/27-prefixindex.t/one', 'Page 1 correct');
is($pages[2]->{'title'}, 'User:Mike.lifeguard/27-prefixindex.t/two', 'Page 2 correct');
