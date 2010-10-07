use strict;
use warnings;
use Test::More tests => 1;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (19_assert_edit.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $rand = rand();
my $status = $bot->edit({
    page    => 'User:ST47/test',
    text    => $rand,
    assert  => 'false'
});

SKIP: {
    if (defined($bot->{'error'}->{'code'}) and $bot->{'error'}->{'code'} == 3) {
        skip q{You're blocked; cannot use this test}, 1;
    }
    is($status->{'edit'}->{'result'}, undef,        'Intentionally bad assertion');
}
