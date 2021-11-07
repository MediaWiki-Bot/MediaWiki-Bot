use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 12;
use Test::Warn;

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

my $page = 'User:Mike.lifeguard/index';
$wikitext = $bot->get_text($page);
my $section_wikitext = $bot->get_text($page, {'rvsection' => 2});
isnt $section_wikitext => undef,             'Section load pass/fail';
isnt $wikitext => $section_wikitext,         'Section loaded content correctly';
like $wikitext => qr/\Q$section_wikitext\E/, 'Section loaded content correctly';

# test backward-compatibility
warning_is(
    sub { $section_wikitext = $bot->get_text($page, undef, 2); },
    'Please pass a hashref; this method of calling get_text is deprecated and will be removed in a future release',
    'deprecated usage of get_text'
);
isnt $section_wikitext => undef,             'Section load pass/fail';
isnt $wikitext => $section_wikitext,         'Section loaded content correctly';
like $wikitext => qr/\Q$section_wikitext\E/, 'Section loaded content correctly';

# page does not exist
my $options = {};
is $bot->get_text('egaP niaM', $options) => undef, 'No page found';
is($options->{'pageid'}, MediaWiki::Bot::PAGE_NONEXISTENT, 'Check pageid, if no page found');

# required param is missing
my $result = $bot->get_text();
is($result, undef, 'required param missing');
