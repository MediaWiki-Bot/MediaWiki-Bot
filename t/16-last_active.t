use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $result = $bot->last_active('Mike.lifeguard');
like($result, qr/20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, 'last active');
is($bot->last_active('User:Mike.lifeguard'), $result, 'Same result with User: prefix');
