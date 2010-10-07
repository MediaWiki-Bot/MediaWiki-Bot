use strict;
use warnings;
use Test::More tests => 4;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (15_was_blocked.t)',
});

{
    # Jimbo has been blocked before
    my $result = $bot->was_blocked('User:Jimbo Wales');
    my $bc     = $bot->test_block_hist('User:Jimbo Wales');
    is($result, 1,      'block history - has been blocked');
    is($result, $bc,    'BC method agrees with current method');
}

{
    # I haven't ever been blocked
    my $result = $bot->was_blocked('User:Mike.lifeguard');
    my $bc     = $bot->test_block_hist('User:Mike.lifeguard');
    is($result, 0,      'block history - never blocked');
    is($result, $bc,    'BC method agrees with current method');
}
