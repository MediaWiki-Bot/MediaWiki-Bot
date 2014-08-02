use strict;
use warnings;
use Test::More tests => 9;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}
my @pages  = ('Main Page', 'Wikipedia:What Test Wiki is not', 'This page had better not exist..........', 'WP:SAND');

# Do test once with arrayref
my $result = $bot->get_pages(\@pages);
is(     keys %{$result},                                        4,      'Got the right number of pages returned');
isnt(   $result->{'Wikipedia:What Test Wiki is not'},           undef,  'Check that page exists');
is(     $result->{'This page had better not exist..........'},  undef,  'Check that page does not exist');
ok(     defined($result->{'Wikipedia:What Test Wiki is not'}),          'Check for something not horribly wrong');
ok(!    defined($result->{'Wikipedia:SAND'}),                           'Should not return expanded names where an alias was requested');
ok(     defined($result->{'WP:SAND'}),                                  'Namespace aliases work as expected');
like(   $result->{'Main Page'},                         qr/MediaWiki/,  'Got Main Page on multi-page get');
like(   $result->{'Wikipedia:What Test Wiki is not'},   qr/Wikipedia/,  '[[Wikipedia:What Test Wiki is not]] contains the string "Wikipedia"');

# Do tests again with array
my $repeat = $bot->get_pages(@pages);
is_deeply($repeat, $result, 'Array and Arrayref return the same data');
