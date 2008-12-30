# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 6;
BEGIN { use_ok('MediaWiki::Bot');
	use_ok('PWP'); };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

$wikipedia=MediaWiki::Bot->new;

ok(defined $wikipedia, "new() works");
ok($wikipedia->isa("MediaWiki::Bot"), "Right class");

$wikipediaalias=PWP->new;

ok(defined $wikipediaalias, "new() works");
ok($wikipediaalias->isa("MediaWiki::Bot"), "Right class");
