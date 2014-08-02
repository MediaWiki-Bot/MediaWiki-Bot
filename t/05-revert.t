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

my $agent = "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)";
my $bot   = MediaWiki::Bot->new({
    agent       => $agent,
    login_data  => $login_data,
    host        => 'test.wikipedia.org',
});

my $title = 'User:Mike.lifeguard/05-revert.t';

subtest revert => sub {
    my @history = $bot->get_history($title, 20);
    my $oldrevid = $history[ int( rand() * 20 ) ]->{revid};
    my $res = $bot->revert($title, $oldrevid, $agent);
    plan defined $bot->{error}->{code} && $bot->{error}->{code} == 3
        ? (skip_all => q{Can't use editing tests: } . $bot->{error}->{details})
        : (tests => 1);

    is $bot->get_text($title, $res->{edit}->{newrevid}) => $bot->get_text($title, $oldrevid),
        'Reverted successfully';
};

subtest undo => sub {
    my @history = $bot->get_history($title, 2);
    my $res = $bot->undo($title, $history[0]->{revid});
    plan defined $bot->{error}->{code} && $bot->{error}->{code} == 3
        ? (skip_all => q{Can't use editing tests: } . $bot->{error}->{details})
        : (tests => 1);

    my $is    = $bot->get_text($title, $res->{edit}->{newrevid});
    my $ought = $bot->get_text($title, $history[1]->{revid});
    is $is => $ought, 'Undo was successful'
        or diag explain { is => $is, ought => $ought, history => \@history };
};
