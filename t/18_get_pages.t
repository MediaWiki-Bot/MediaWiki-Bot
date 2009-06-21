# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 8;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use strict;
use MediaWiki::Bot;

my $wikipedia = MediaWiki::Bot->new;

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
	$wikipedia->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $result = $wikipedia->get_pages("Main Page", "Wikipedia", "This page had better not exist..........", "WP:CSD");

is( keys %{$result}, 4, "Got the right number of pages returned");
isnt( $result->{'Wikipedia'}, 2, "Article doesn't not exist");
is( $result->{'This page had better not exist..........'}, 2, "Article doesn't exist");
ok( defined($result->{'Wikipedia'}), "Check for something not horribly wrong");
TODO: {
	local $TODO = "Namespace alias handling not yet implemented";
	ok( defined($result->{'WP:CSD'}), "Namespace aliases work as expected");
}
like( $result->{'Wikipedia'}, qr/.{15}/, "Check for something at least resembling text in article");
like( $result->{'Main Page'}, qr/Main Page/, "Got main page on multi-page get");
like( $result->{'Wikipedia'}, qr/Wikipedia/, "Article about Wikipedia is not garbled and contains the string 'Wikipedia'");
