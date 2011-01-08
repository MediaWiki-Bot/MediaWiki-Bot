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
    # Jimbo is almost certainly not blocked right now
    my $result = $bot->is_blocked('Jimbo Wales');
    my $bc     = $bot->test_blocked('User:Jimbo Wales');
    is($result, 0,      'current blocks');
    is($result, $bc,    'BC method returned the same as the current method');
}

{
    # A random old account I chose - it will probably be blocked forever
    # (del/undel) 21:48, July 26, 2008 Cometstyles (talk | contribs | block) blocked Hiwhispees (talk | contribs) with an expiry time of infinite (account creation disabled, e-mail blocked) ‎ (bye grawp) (unblock | change block)
    my $result = $bot->is_blocked('User:Hiwhispees');
    my $bc     = $bot->test_blocked('Hiwhispees');
    is($result, 1,      'current blocks');
    is($result, $bc,    'BC method returned the same as the current method');
}
