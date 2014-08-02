use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

TODO: {
    todo_skip 'is_locked not implemented yet', 2 unless $bot->can('is_locked');

    # Jimbo is almost certainly not locked right now
    my $result = $bot->is_locked('Jimbo Wales');
    is($result, 0,      'current locks');

    # A random old account I chose - it will probably be locked forever
    # 23:44, 4 March 2009 Mike.lifeguard (talk | contribs) locked global account "User:PLEASE STOP BLOCKING@global" ‎ (inappropriate username)
    $result = $bot->is_locked('User:PLEASE STOP BLOCKING');
    is($result, 1,      'current locks');
}
