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
    my $oldrevid;
    {   # Exercise revert()
        my @history = $bot->get_history($title, 10);
        $oldrevid = $history[ int( rand() * 10) ]->{revid};

        my $res = $bot->revert($title, $oldrevid, $agent);

        skip 'Cannot use editing tests: ' . $bot->{error}->{details}, 2 if
            defined $bot->{error}->{code} and $bot->{error}->{code} == 3;

        is $bot->get_text($title, $res->{edit}->{newrevid}) => $bot->get_text($title, $oldrevid),
            'Reverted successfully';
    }
    {   # Exercise undo()
        my $res = $bot->edit({ page => $title, text => rand() });
        $res = $bot->undo($title, $res->{edit}->{newrevid});

        is $bot->get_text($title, $res->{edit}->{newrevid}) => $bot->get_text($title, $oldrevid),
            'Undo was successful';
    }
}
