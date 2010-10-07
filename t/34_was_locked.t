use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (34_was_blocked.t)',
    host    => 'meta.wikimedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# Hasn't been locked (yet)
my $result = $bot->was_locked('Jimbo Wales');
is($result, 0, 'lock history');

# I was once locked
$result = $bot->was_locked('Mike.lifeguard');
is($result, 1, 'lock history');
