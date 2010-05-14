# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use strict;
use MediaWiki::Bot;

my $wikipedia = MediaWiki::Bot->new("PWP test");

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $wikipedia->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# Jimbo has been blocked before
my $result = $wikipedia->was_blocked("User:Jimbo Wales");
is($result, 1, "block history");

# I haven't ever been blocked
$result = $wikipedia->was_blocked("User:Mike.lifeguard");
is($result, 0, "block history");
