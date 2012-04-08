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

my $title = 'User:Mike.lifeguard/05-revert.t';
SKIP: {
    {   # Exercise revert()
        my @history = $bot->get_history($title, 10);
        my $revid = $history[ int( rand() * 10) ]->{revid};

        my $text = $bot->get_text($title, $revid);
        my $res = $bot->revert($title, $revid, $agent);
        my $err = $bot->{error};

        if ($err->{code} and $err->{code} == 3) {
            diag explain { error => $bot->{error}, revid => $revid, text => $text };
            skip 'Cannot proceed with editing tests', 2;
        }

        my $newtext = $bot->get_text($title);

        is $text, $newtext, 'Reverted successfully';
    }

    $bot->purge_page($title);

    {   # Exercise undo()
        my @history = $bot->get_history($title, 2);
        my $revid   = $history[0]->{revid};
        my $text    = $bot->get_text($title, $history[1]->{revid});
        $bot->undo($title, $revid);
        my $newtext = $bot->get_text($title);

        is $text, $newtext, 'Undo was successful';
    }
}
