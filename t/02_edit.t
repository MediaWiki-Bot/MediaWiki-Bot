# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Perlwikipedia.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Perlwikipedia;

$wikipedia=Perlwikipedia->new;

#$wikipedia->set_wiki( "wiki.xyrael.net","w" );

SKIP: {
#	skip("Skipping edit test for now",2);

	my $rand = rand();
	my $status = $wikipedia->edit("User:ST47/test",$rand,"Perlwikipedia tests");
#	ok( $status->isa("HTTP::Response") );

	my $text = $wikipedia->get_text("User:ST47/test");
	$text =~ s/\n//;
	is($text,$rand);
}
