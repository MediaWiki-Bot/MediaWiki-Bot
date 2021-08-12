use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 5;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

my $revid = $bot->get_last(q{User:Mike.lifeguard/doesn't exist}); # Leaves out the username, a required param

ok(defined($bot->{error}),                              'The error data is there');
is(ref $bot->{error}, 'HASH',                           'The error data is a hash');
is($bot->{error}->{code}, 3,                            'The right error code is there');
like($bot->{error}->{stacktrace}, qr/MediaWiki::Bot/,   'The stacktrace includes "MediaWiki::Bot"');
like($bot->{error}->{details}, 
	qr/(^?:rvbaduser_rvexcludeuser:.*|Invalid value .* for user parameter ")rvexcludeuser/, 
	'The API error text was returned');
