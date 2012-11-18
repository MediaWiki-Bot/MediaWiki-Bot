use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'meta.wikimedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# 127.0.0.1 has been blocked before
ok $bot->was_g_blocked('127.0.0.1'), q{127.0.0.1 has been globalblocked};

# 127.0.4.4 probably hasn't been
ok !$bot->was_g_blocked('127.0.4.4'), q{127.0.4.4 hasn't been globalblocked};
