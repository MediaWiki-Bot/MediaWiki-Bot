use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'meta.wikimedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# Hasn't been locked (yet)
my $result = $bot->was_locked('Jimbo Wales');
ok(!$result, 'lock history');

# I was once locked
$result = $bot->was_locked('Mike.lifeguard');
ok($result, 'lock history');
