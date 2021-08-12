use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 1;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

my @usergroups = $bot->usergroups('Mike.lifeguard');
is_deeply [ sort @usergroups ], [ sort qw(* user autoconfirmed reviewer) ],
    'Right usergroups were returned';
