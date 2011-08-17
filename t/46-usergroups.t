use strict;
use warnings;
use Test::More tests => 1;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @usergroups = $bot->usergroups('Mike.lifeguard');
is_deeply [ sort @usergroups ], [ sort qw(* user autoconfirmed patroller editor import reviewer sysop) ], 'Right usergroups were returned';
