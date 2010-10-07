use strict;
use warnings;
use Test::More tests => 4;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (23_is_blocked.t)',
});

{
    # Jimbo is almost certainly not blocked right now
    my $result = $bot->is_blocked('User:Jimbo Wales');
    my $bc     = $bot->test_blocked('User:Jimbo Wales');
    is($result, 0,      'current blocks');
    is($result, $bc,    'BC method returned the same as the current method');
}

{
    # A random old account I chose - it will probably be blocked forever
    # (del/undel) 23:44, 31 December 2006 Agathoclea (talk | contribs | block) blocked Deathtonoobs (talk | contribs) with an expiry time of indefinite (vandalism only - offensive username) (unblock | change block)
    my $result = $bot->is_blocked('User:Deathtonoobs');
    my $bc     = $bot->test_blocked('User:Deathtonoobs');
    is($result, 1,      'current blocks');
    is($result, $bc,    'BC method returned the same as the current method');
}
