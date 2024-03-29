use strict;
use warnings;
use Test::RequiresInternet 'meta.wikimedia.org' => 80;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'meta.wikimedia.org',
});

# Hasn't been locked (yet)
my $result = $bot->was_locked('Reedy');
ok(!$result, 'lock history');

# I was once locked
$result = $bot->was_locked('Mike.lifeguard');
ok($result, 'lock history');
