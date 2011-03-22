use strict;
use warnings;
use Test::More tests => 3;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

$bot->login({username => 'Perlwikibot testing', password => 'test'});

my $result = $bot->purge_page('Main Page');
is($result, 1, 'Purge a single page');

$result = $bot->purge_page('tsixe reven lliw');
is($result, 0, 'Fail to purge a non-existent page');

my @purges = ('Main Page', 'Main Page', 'tsixe reven lliw', 'User:Mike.lifeguard');
$result = $bot->purge_page(\@purges);
is($result, 2, 'Purge some of an array of pages');
