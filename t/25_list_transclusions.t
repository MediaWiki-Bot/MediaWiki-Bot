# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 7;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (25_list_transclusions.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $bot->list_transclusions('Template:Tlx', 'redirects', undef, {max=>1});

ok(     defined $pages[0],                                  'Something was returned');
isa_ok( $pages[0],                      'HASH',             'A hash was returned');
ok(     defined $pages[0]->{'title'},                       'The hash contains a title');
like(   $pages[0]->{'title'},           qr/\w+/,            'The title looks valid');
ok(     defined $pages[0]->{'redirect'},                    'Redirect status is defined');
ok(     defined($pages[0]->{'redirect'}),                   'We got a redirect when we asked for it');

@pages = $bot->what_links_here('Template:Tlx', 'nonredirects', undef, {max=>1});

isnt(     defined($pages[0]->{'redirect'}),                   'We got a normal link when we asked for no redirects');
