# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Perlwikipedia.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use Perlwikipedia;

$wikipedia=Perlwikipedia->new;
SKIP: {
skip("wiki.xyrael.net is down",2);

$wikipedia->set_wiki("wiki.xyrael.net","w");

my %namespaces = $wikipedia->get_namespace_names;

is( $namespaces{1}, "Talk" );
}
