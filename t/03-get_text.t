use strict;
use warnings;
use Test::More tests => 6;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $wikitext = $bot->get_text('Main Page');
like($wikitext, qr/MediaWiki/, 'Main Page found');

$wikitext = $bot->get_text('User:Mike.lifeguard/03-get text.t');
is($wikitext, q{I know for a ''fact'' that this page contains 60 characters.}, 'Known text retrieved');

my $page = 'Lestat de Lioncourt';
$wikitext = $bot->get_text($page);
my $section_wikitext = $bot->get_text($page, '', 3);
isnt($section_wikitext, undef,             'Section load pass/fail');
isnt($wikitext, $section_wikitext,         'Section loaded content correctly');
like($wikitext, qr/\Q$section_wikitext\E/, 'Section loaded content correctly');

$wikitext = $bot->get_text('egaP niaM');
is($wikitext, undef, 'No page found');
