use strict;
use warnings;
use Test::More tests => 6;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (12_get_text.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $wikitext = $bot->get_text('Main Page');
like($wikitext, qr/Main Page/, 'Main Page found');

$wikitext = $bot->get_text('User:Mike.lifeguard/12 get text.t');
is($wikitext, qq{I know for a ''fact'' that this page contains 60 characters.}, 'Right text retrieved');

$wikitext = $bot->get_text('God');
my $section_wikitext = $bot->get_text('God', '', 3);
isnt($section_wikitext, undef,             'Section load pass/fail');
isnt($wikitext, $section_wikitext,         'Section loaded content correctly');
like($wikitext, qr/\Q$section_wikitext\E/, 'Section loaded content correctly');

$wikitext = $bot->get_text('egaP niaM');
is($wikitext, undef, 'No page found');
