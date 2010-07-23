# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 16;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (18_get_pages.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}
my @pages  = ('Main Page', 'Wikipedia', 'This page had better not exist..........', 'WP:CSD', 'Mouse');

# Do test once with arrayref
my $result = $bot->get_pages(\@pages);
is(     keys %{$result},                                        5,      'Got the right number of pages returned');
isnt(   $result->{'Wikipedia'},                                 undef,  'Check that page exists');
is(     $result->{'This page had better not exist..........'},  undef,  'Check that page does not exist');
ok(     defined($result->{'Wikipedia'}),                                'Check for something not horribly wrong');
ok(!    defined($result->{'Wikipedia:CSD'}),                            'Should not return expanded names where an alias was requested');
ok(     defined($result->{'WP:CSD'}),                                   'Namespace aliases work as expected');
like(   $result->{'Main Page'},                         qr/Main Page/,  'Got Main Page on multi-page get');
like(   $result->{'Wikipedia'},                         qr/Wikipedia/,  '[[Wikipedia]] contains the string "Wikipedia"');

# Do tests again with array
$result = $bot->get_pages(@pages);
is(     keys %{$result},                                        5,      'Got the right number of pages returned');
isnt(   $result->{'Wikipedia'},                                 undef,  'Check that page exists');
is(     $result->{'This page had better not exist..........'},  undef,  'Check that page does not exist');
ok(     defined($result->{'Wikipedia'}),                                'Check for something not horribly wrong');
ok(!    defined($result->{'Wikipedia:CSD'}),                            'Should not return expanded names where an alias was requested');
ok(     defined($result->{'WP:CSD'}),                                   'Namespace aliases work as expected');
like(   $result->{'Main Page'},                         qr/Main Page/,  'Got Main Page on multi-page get');
like(   $result->{'Wikipedia'},                         qr/Wikipedia/,  '[[Wikipedia]] contains the string "Wikipedia"');
