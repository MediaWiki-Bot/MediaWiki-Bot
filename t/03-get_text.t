use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 6;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

my $wikitext = $bot->get_text('Main Page');
like($wikitext, qr/MediaWiki/, 'Main Page found');

$wikitext = $bot->get_text('User:Mike.lifeguard/03-get text.t');
is($wikitext, q{I know for a ''fact'' that this page contains 60 characters.}, 'Known text retrieved');

my $page = 'Main Page';
$wikitext = $bot->get_text($page);
my $section_wikitext = $bot->get_text($page, undef, 3);
isnt $section_wikitext => undef,             'Section load pass/fail';
isnt $wikitext => $section_wikitext,         'Section loaded content correctly';
like $wikitext => qr/\Q$section_wikitext\E/, 'Section loaded content correctly';

is $bot->get_text('egaP niaM') => undef, 'No page found';
