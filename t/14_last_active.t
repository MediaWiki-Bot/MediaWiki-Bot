# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Perlwikipedia.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use strict;
use Perlwikipedia;

my $wikibot = Perlwikipedia->new;

my $result = $wikibot->last_active("User:Jimbo Wales");
like($result, qr/20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, "last active");
