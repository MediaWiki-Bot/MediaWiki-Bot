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

        my $res = $bot->revert($title, $revid, $agent);

        skip 'Cannot use editing tests: ' . $bot->{error}->{details}, 2 if
            defined $bot->{error}->{code} and $bot->{error}->{code} == 3;

        is $bot->get_text($title) => $bot->get_text($title, $revid), 'Reverted successfully';
    }

    $bot->purge_page($title);

    {   # Exercise undo()
        my @history = $bot->get_history($title, 2);
        my $revid   = $history[0]->{revid};
        $bot->undo($title, $revid);

        is $bot->get_text($title) => $bot->get_text($title, $history[1]->{revid}),
            'Undo was successful';
    }
}
