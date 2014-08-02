use strict;
use warnings;
use Test::More tests => 6;
use Test::Warn;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

{
    # Jimbo is almost certainly not blocked right now
    my $result = $bot->is_blocked('Jimbo Wales');
    my $bc;
    warning_is(
        sub { $bc = $bot->test_blocked('User:Jimbo Wales'); },
        'test_blocked is an alias of is_blocked; please use the new name. This alias might be removed in a future release',
        'test_blocked is deprecated'
    );
    is($result, 0,      'current blocks');
    is($result, $bc,    'BC method returned the same as the current method');
}

{
    # A random old account I chose - it will probably be blocked forever
    # (del/undel) 21:48, July 26, 2008 Cometstyles (talk | contribs | block) blocked Hiwhispees (talk | contribs) with an expiry time of infinite (account creation disabled, e-mail blocked) ‎ (bye grawp) (unblock | change block)
    my $result = $bot->is_blocked('User:Hiwhispees');
    my $bc;
    warning_is(
        sub { $bc = $bot->test_blocked('Hiwhispees'); },
        'test_blocked is an alias of is_blocked; please use the new name. This alias might be removed in a future release',
        'test_blocked is deprecated'
    );
    is($result, 1,      'current blocks');
    is($result, $bc,    'BC method returned the same as the current method');
}
