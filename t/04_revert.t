use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};
my $login_data;
if (defined($username) and defined($password)) {
    $login_data = { username => $username, password => $password };
}

my $bot = MediaWiki::Bot->new({
    agent       => 'MediaWiki::Bot tests (04_revert.t)',
    login_data  => $login_data,
});

SKIP: {
    {   # Exercise revert()
        my @history = $bot->get_history('User:ST47/test', 10);
        my $revid = $history[9]->{'revid'};

        my $text = $bot->get_text('User:ST47/test', $revid);
        my $res = $bot->revert('User:ST47/test', $revid, 'MediaWiki::Bot tests (04_revert.t)');
        if (defined($bot->{'error'}->{'code'}) and $bot->{'error'}->{'code'} == 3) {
            skip 'You are blocked, cannot proceed with editing tests', 2;
        }
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
}
