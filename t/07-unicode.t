use strict;
use warnings;
use utf8;
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
    agent      => $agent,
    login_data => $login_data,
    host       => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
   $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

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
        skip 'Cannot use editing tests: ' . $bot->{error}->{details}, 4 if
            defined $bot->{error}->{code} and $bot->{error}->{code} == 3;

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
