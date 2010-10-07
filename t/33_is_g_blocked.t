use strict;
use warnings;
use Test::More tests => 1;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (33_is_g_blocked.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# 127.0.4.4 is almost certainly not blocked right now
my $result = $bot->is_g_blocked('127.0.4.4');
is($result, 0, 'current global blocks');
