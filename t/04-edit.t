use strict;
use warnings;
use Test::Is qw(extended);
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More;

use MediaWiki::Bot qw(:constants);
my $t = __FILE__;

plan tests => ($ENV{PWPUsername} && $ENV{PWPPassword} ? 4 : 2);

my $agent = "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)";
my $bot = MediaWiki::Bot->new({
    agent       => $agent,
    host        => 'test.wikipedia.org',
    protocol    => 'https',
    ( $ENV{PWPUsername} && $ENV{PWPPassword}
        ? ( login_data => { username => $ENV{PWPUsername}, password => $ENV{PWPPassword} } )
        : ()
    ),
});

my $title  = 'User:Mike.lifeguard/04-edit.t';
my $rand   = rand();
my $status = $bot->edit({
    page => $title,
    text => $rand,
    summary => $agent . ' (should be a minor edit)',
    minor   => 1,
});

SKIP: {
    skip 'Cannot use editing tests: ' . $bot->{error}->{details}, 2
        if defined $bot->{error}->{code}
        and ($bot->{error}->{code} == ERR_API or $bot->{error}->{code} == ERR_CAPTCHA);

    is $bot->get_text($title, $status->{newrevid}) => $rand, 'Did whole-page editing successfully';

    my $rand2 = rand();
    $status = $bot->edit({
        page    => $title,
        text    => $rand2,
        section => 'new',
        summary => $agent,
    });
    skip 'Cannot use editing tests: ' . $bot->{error}->{details}, 1
        if defined $bot->{error}->{code}
        and ($bot->{error}->{code} == ERR_API or $bot->{error}->{code} == ERR_CAPTCHA);
    diag explain $bot->{error} unless $status;

    like $bot->get_text($title, $status->{edit}->{newrevid}) => qr{== \Q$agent\E ==\n\n\Q$rand2\E},
        'Did section editing successfully'
        or diag explain { status => $status, error => $bot->{error} };

    if ($ENV{PWPUsername} and $ENV{PWPPassword}) {
        my @hist = $bot->get_history($title, 2);
        ok $hist[1]->{minor}, 'Minor edit' or diag explain \@hist;

        $status = $bot->edit({
            page    => $title,
            text    => $rand2.$rand,
            summary => $agent . ' (major)',
            minor   => 0,
        });
        @hist = $bot->get_history($title, 1);
        ok !$hist[0]->{minor}, 'Not a minor edit'
            or diag explain { hist => \@hist, status => $status };
    }
}
