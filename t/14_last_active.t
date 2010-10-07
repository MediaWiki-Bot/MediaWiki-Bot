use strict;
use warnings;
use Test::More tests => 1;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (14_last_active.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $result = $bot->last_active('User:Jimbo Wales');
like($result, qr/20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, 'last active');
