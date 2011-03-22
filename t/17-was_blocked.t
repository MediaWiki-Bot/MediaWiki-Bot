use strict;
use warnings;
use Test::More tests => 6;
use Test::Warn;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

{
    my $user   = 'Bad Username'; # has been blocked before
    my $result = $bot->was_blocked($user);
    my $bc;
    warning_is(
        sub { $bc = $bot->test_block_hist($user); },
        'test_block_hist is an alias of was_blocked; please use the new method name. This alias might be removed in a future release',
        'test_block_hist is deprecated'
    );
    is($result, 1,      'block history - has been blocked');
    is($result, $bc,    'BC method agrees with current method');
}

{
    my $user   = 'Mike.lifeguard'; # I haven't ever been blocked
    my $result = $bot->was_blocked($user);
    my $bc;
    warning_is(
        sub { $bc = $bot->test_block_hist($user); },
        'test_block_hist is an alias of was_blocked; please use the new method name. This alias might be removed in a future release',
        'test_block_hist is deprecated'
    );
    is($result, 0,      'block history - never blocked');
    is($result, $bc,    'BC method agrees with current method');
}
