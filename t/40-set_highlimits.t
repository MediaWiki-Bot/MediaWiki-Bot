use strict;
use warnings;
use Test::More tests => 4;
use Test::Warn;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

warning_is(
    sub { ok(!$bot->set_highlimits(1), 'set_highlimits returns true'); },
    'Use of set_highlimits() is deprecated, and has no effect',
    'set_highlimits(1) is deprecated'
);

warning_is(
    sub { ok(!$bot->set_highlimits(0), 'set_highlimits returns true'); },
    'Use of set_highlimits() is deprecated, and has no effect',
    'set_highlimits(0) is deprecated'
);
