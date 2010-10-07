use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (32_was_g_blocked.t)',
    host    => 'meta.wikimedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# 127.0.0.1 has been blocked before
my $result = $bot->was_g_blocked('127.0.0.1');
is($result, 1, 'globalblock history');

# 127.0.4.4 probably hasn't been
$result = $bot->was_g_blocked('127.0.4.4');
is($result, 0, 'globalblock history');
