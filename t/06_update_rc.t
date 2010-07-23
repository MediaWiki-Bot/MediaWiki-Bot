# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 1;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (06_update_rc.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @rc = $bot->update_rc(2);
ok(defined $rc[0]->{'title'});
