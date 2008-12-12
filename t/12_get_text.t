# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Perlwikipedia.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 4;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use strict;
use Perlwikipedia;

my $wikipedia = Perlwikipedia->new;

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
	$wikipedia->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $result = $wikipedia->get_text("Main Page");
like( $result, qr/Main Page/, "Main Page found" );

$result = $wikipedia->get_text("God");
my $resultsection = $wikipedia->get_text("God", '', 3);
isnt($resultsection, 2, "Section load pass/fail");
isnt(length($result), length($resultsection), "Section loaded content correct");

$result = $wikipedia->get_text("egaP niaM");
is( $result, 2, "No page found" );
