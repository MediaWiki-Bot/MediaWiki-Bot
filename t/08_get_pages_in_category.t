# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Perlwikipedia.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 5;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use Perlwikipedia;
SKIP: {
skip("wiki.xyrael.net is down",5);

$wikipedia=Perlwikipedia->new("make test");
$wikipedia->set_wiki('wiki.xyrael.net', 'w');

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
	$wikipedia->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $wikipedia->get_all_pages_in_category("Category:Perlwikipedia test nest2");

ok( defined $pages[0], "Get small category" );

#This tests categories with more than one page.
$wikipedia->set_wiki('en.wikipedia.org', 'w');
@pages = $wikipedia->get_all_pages_in_category("Category:Wikipedia external links cleanup");

ok( defined $pages[0], "Get big category" );
cmp_ok ( scalar(@pages), ">", 500, "Get big category, enough elements");

$wikipedia->set_wiki('wiki.xyrael.net', 'w');
@pages = $wikipedia->get_all_pages_in_category("Category:Perlwikipedia test nest1");
is ( scalar(@pages), 3, "Nested categories, one level");

@pages = $wikipedia->get_all_pages_in_category("Category:Perlwikipedia test");
is ( scalar(@pages), 5, "Nested categories, two levels");
}
