# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 6;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new();

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $bot->linksearch("*.example.com", undef, undef, {max=>1});

ok(     defined $pages[0],                                  'Something was returned');
isa_ok( $pages[0],                      'HASH',             'A hash was returned');
ok(     defined $pages[0]->{'url'},                         'The hash contains a URL');
like(   $pages[0]->{'url'},             qr/example\.com/,   'The URL is one we requested');
ok(     defined $pages[0]->{'title'},                       'The has contains a page title');
like(   $pages[0]->{'title'},           qr/\w+/,            'The title looks valid');

