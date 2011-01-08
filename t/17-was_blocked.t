use strict;
use warnings;
use Test::More tests => 4;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

{
    my $user   = 'Bad Username'; # has been blocked before
    my $result = $bot->was_blocked($user);
    my $bc     = $bot->test_block_hist($user);
    is($result, 1,      'block history - has been blocked');
    is($result, $bc,    'BC method agrees with current method');
}

{
    my $user   = 'Mike.lifeguard'; # I haven't ever been blocked
    my $result = $bot->was_blocked($user);
    my $bc     = $bot->test_block_hist($user);
    is($result, 0,      'block history - never blocked');
    is($result, $bc,    'BC method agrees with current method');
}
