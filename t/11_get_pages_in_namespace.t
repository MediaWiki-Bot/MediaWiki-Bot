# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 4;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $namespace_id = '10';
my $page_limit = 1;

my @pages = $bot->get_pages_in_namespace($namespace_id);
like($pages[0], qr/^Template/, 'Template namespace found');

@pages = $bot->get_pages_in_namespace($namespace_id, $page_limit);
is(scalar @pages, $page_limit, 'Correct number of pages retrieved');

$namespace_id = 'non-existent';
print STDERR "\rYou should receive an error message below. This is an expected part of the test.\n";
@pages = $bot->get_pages_in_namespace($namespace_id);

is($pages[0], undef, 'Error code received');
is($bot->{error}->{code}, 3, 'Error code in MediaWiki::Bot object');
