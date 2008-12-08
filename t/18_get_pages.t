# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Perlwikipedia.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 6;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use strict;
use Perlwikipedia;

my $wikibot = Perlwikipedia->new;

my $result = $wikibot->get_pages("Main Page", "Wikipedia");

is( keys %{$result}, 2, "Got the right number of pages returned");
isnt( $result->{'Wikipedia'}, 2, "Article doesn't not exist");
ok( defined($result->{'Wikipedia'}), "Check for something not horribly wrong");
like( $result->{'Wikipedia'}, qr/.{15}/, "Check for something at least resembling text in article");
like( $result->{'Main Page'}, qr/Main Page/, "Got main page on multi-page get");
like( $result->{'Wikipedia'}, qr/Wikipedia/, "Article about Wikipedia is not garbled and contains the string 'Wikipedia'");
