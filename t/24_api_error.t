# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 5;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (24_api_error.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $revid = $bot->get_last("User:Mike.lifeguard/doesn't exist"); # Leaves out the username, a required param
my $error = $bot->{'error'};
ok(defined($error), 'The error data is there');
is(ref $error, 'HASH', 'The error data is a hash');
is($error->{'code'}, 3, 'The right error code is there');
like($error->{'stacktrace'}, qr/MediaWiki::Bot/, 'The stacktrace includes "MediaWiki::Bot"');
is($error->{'details'}, 'rvbaduser_rvexcludeuser: Invalid value for user parameter rvexcludeuser', 'The API error text was returned');
