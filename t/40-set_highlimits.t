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
    my $hl = 1;
    ok($bot->set_highlimits($hl),               'set_highlimits returns true');
    is($bot->{'highlimits'},        $hl,        'set_highlimits was actually set');
}

{
    my $hl = 0;
    ok($bot->set_highlimits($hl),               'set_highlimits returns true');
    is($bot->{'highlimits'},        $hl,        'set_highlimits was actually set');
}
