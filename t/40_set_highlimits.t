use strict;
use warnings;
use Test::More tests => 4;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (40_set_highlimits.t)',
});

{
    my $hl = 1;
    ok($bot->set_highlimits($hl),               'set_highlimits returns true');
    is($bot->{'highlimits'},        $hl,        'set_highlimits was actually set');
}

{
    my $hl = 0;
    ok($bot->set_highlimits($hl),               'set_highlimits returns true');
    is($bot->{'highlimits'},        $hl,        'set_highlimits was actually set');
}
