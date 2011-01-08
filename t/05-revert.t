use strict;
use warnings;
use Test::More tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};
my $login_data;
if (defined($username) and defined($password)) {
    $login_data = { username => $username, password => $password };
}

my $agent = "MediaWiki::Bot tests ($t)";
my $bot   = MediaWiki::Bot->new({
    agent       => $agent,
    login_data  => $login_data,
    host        => 'test.wikipedia.org',
});

SKIP: {
    my $title = 'User:Mike.lifeguard/04-edit.t';
    {   # Exercise revert()
        my @history = $bot->get_history($title, 10);
        my $revid = $history[9]->{'revid'};

        my $text = $bot->get_text($title, $revid);
        my $res = $bot->revert($title, $revid, $agent);
        if (defined($bot->{'error'}->{'code'}) and $bot->{'error'}->{'code'} == 3) {
            skip 'You are blocked, cannot proceed with editing tests', 2;
        }
        my $newtext = $bot->get_text($title);

        is($text, $newtext, 'Reverted successfully');
    }

    {   # Exercise undo()
        my @history = $bot->get_history($title, 2);
        my $revid   = $history[0]->{'revid'};
        my $text    = $bot->get_text($title, $history[1]->{'revid'});
        $bot->undo($title, $revid);
        my $newtext = $bot->get_text($title);

        is($text, $newtext, 'Undo was successful');
    }
}
