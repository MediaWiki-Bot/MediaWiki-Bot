# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 2;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (04_revert.t)',
});

{   # Exercise revert()
    my @history = $bot->get_history('User:ST47/test', 10);
    my $revid = $history[9]->{'revid'};

    my $text = $bot->get_text('User:ST47/test', $revid);
    my $res = $bot->revert('User:ST47/test', $revid, 'MediaWiki::Bot tests (04_revert.t)');
    sleep(1);
    my $newtext = $bot->get_text('User:ST47/test');
    is($text, $newtext, 'Reverted successfully');
}

{   # Exercise undo()
    my @history = $bot->get_history('User:ST47/test', 2);
    my $revid   = $history[0]->{'revid'};
    my $text    = $bot->get_text('User:ST47/test', $history[1]->{'revid'});
    $bot->undo('User:ST47/test', $revid);
    my $newtext = $bot->get_text('User:ST47/test');
    is($text, $newtext, 'Undo was successful');
}
