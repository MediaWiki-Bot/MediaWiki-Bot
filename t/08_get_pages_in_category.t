# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Perlwikipedia.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use Perlwikipedia;

$wikipedia=Perlwikipedia->new("make test");

my @pages = $wikipedia->get_all_pages_in_category("Category:Perlwikipedia bots");

ok( defined $pages[0] );

#This tests categories with more than one page.
@pages = $wikipedia->get_all_pages_in_category("Category:Wikipedia external links cleanup ");

ok( defined $pages[0] );
