use strict;
use warnings;
use utf8;
use Test::Is qw(extended);
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More 0.94 tests => 2;

BEGIN {
    # Fix "Wide character in print" warning on failure
    my $builder = Test::More->builder;
    binmode $builder->output,           ':encoding(UTF-8)';
    binmode $builder->failure_output,   ':encoding(UTF-8)';
    binmode $builder->todo_output,      ':encoding(UTF-8)';
    binmode STDOUT,                     ':encoding(UTF-8)';
    binmode STDERR,                     ':encoding(UTF-8)';
}

use MediaWiki::Bot qw(:constants);
my $t = __FILE__;

my $agent = "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)";
my $bot   = MediaWiki::Bot->new({
    agent      => $agent,
    host       => 'test.wikipedia.org',
    protocol   => 'https',
    ( $ENV{PWPUsername} && $ENV{PWPPassword}
        ? (login_data => { username => $ENV{PWPUsername}, password => $ENV{PWPPassword} })
        : ()
    ),
});

my $base   = 'User:Mike.lifeguard/07-unicode.t';
my $string = 'éółŽć';

subtest 'read' => sub {
    plan tests => 1;

    is $bot->get_text("$base/1") => $string, 'Is our string the same as what we load?';
};

subtest 'write' => sub {
    plan tests => 4;

    my $old  = $bot->get_text("$base/2");
    my $rand = rand();
    my $status = $bot->edit({
        page    => "$base/2",
        text    => "$rand\n$string\n",
        summary => $agent
    });

    SKIP: {
        skip 'Cannot use editing tests: ' . $bot->{error}->{details}, 4
            if defined $bot->{error}->{code}
            and ($bot->{error}->{code} == ERR_API or $bot->{error}->{code} == ERR_CAPTCHA);

        is $bot->get_text("$base/2", $status->{edit}->{newrevid}) => "$rand\n$string",
            "Successfully edited $base/2";

        my $rand2 = rand();
        $status = $bot->edit({
            page => "$base/3",
            text => "$rand2\n$string\n",
            summary => "$agent ($string)"
        });
        is $bot->get_text("$base/3", $status->{edit}->{newrevid}) => "$rand2\n$string",
            "Edited $base/3 OK";
        my @history = $bot->get_history("$base/3", 1);
        is $history[0]->{comment} => "$agent ($string)",
            "Edited $base/3 with unicode in an edit summary";

        my $rand3 = rand();
        $status = $bot->edit({
            page => "$base/$string",
            text => "$rand3\n$string\n",
            summary => $agent
        });
        is $bot->get_text("$base/$string", $status->{edit}->{newrevid}) => "$rand3\n$string",
            "Edited $base/$string OK";
    } # end SKIP
};
