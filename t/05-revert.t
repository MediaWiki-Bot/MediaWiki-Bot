use strict;
use warnings;
use Test::Is qw(extended);
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 2;

use MediaWiki::Bot qw(:constants);
my $t = __FILE__;

my $agent = "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)";
my $bot   = MediaWiki::Bot->new({
    agent       => $agent,
    host        => 'test.wikipedia.org',
    protocol    => 'https',
    ( $ENV{PWPUsername} && $ENV{PWPPassword}
        ? ( login_data => { username => $ENV{PWPUsername}, password => $ENV{PWPPassword} } )
        : ()
    ),
});

my $title = 'User:Mike.lifeguard/05-revert.t';

subtest revert => sub {
    my @history = $bot->get_history($title, 20);
    my $oldrevid = $history[ int( rand() * 20 ) ]->{revid};
    my $res = $bot->revert($title, $oldrevid, $agent);
    plan defined $bot->{error}->{code} && ($bot->{error}->{code} == ERR_API or $bot->{error}->{code} == ERR_CAPTCHA)
        ? (skip_all => q{Can't use editing tests: } . $bot->{error}->{details})
        : (tests => 1);

    is $bot->get_text($title, $res->{edit}->{newrevid}) => $bot->get_text($title, $oldrevid),
        'Reverted successfully';
};

subtest undo => sub {
    my @history = $bot->get_history($title, 2);
    my $res = $bot->undo($title, $history[0]->{revid});
    plan defined $bot->{error}->{code} && ($bot->{error}->{code} == ERR_API or $bot->{error}->{code} == ERR_CAPTCHA)
        ? (skip_all => q{Can't use editing tests: } . $bot->{error}->{details})
        : (tests => 1);

    my $is    = $bot->get_text($title, $res->{edit}->{newrevid});
    my $ought = $bot->get_text($title, $history[1]->{revid});
    is $is => $ought, 'Undo was successful'
        or diag explain { is => $is, ought => $ought, history => \@history };
};
