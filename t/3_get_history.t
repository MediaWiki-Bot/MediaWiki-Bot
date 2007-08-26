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

@history = $wikipedia->get_history("User:Shadow1/perlwikipedia/Check",1);

is($history[0]->{comment},"Perlwikipedia tests");
