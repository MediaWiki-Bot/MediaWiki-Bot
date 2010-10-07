use strict;
use warnings;
use Test::More tests => 5;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (24_api_error.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $revid = $bot->get_last("User:Mike.lifeguard/doesn't exist"); # Leaves out the username, a required param

ok(defined($bot->{'error'}),                                'The error data is there');
is(ref $bot->{'error'}, 'HASH',                             'The error data is a hash');
is($bot->{'error'}->{'code'}, 3,                            'The right error code is there');
like($bot->{'error'}->{'stacktrace'}, qr/MediaWiki::Bot/,   'The stacktrace includes "MediaWiki::Bot"');
is($bot->{'error'}->{'details'}, 'rvbaduser_rvexcludeuser: Invalid value for user parameter rvexcludeuser', 'The API error text was returned');
