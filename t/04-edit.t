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

my $bot = MediaWiki::Bot->new({
    agent      => $agent,
    login_data => $login_data,
    host       => 'test.wikipedia.org',
});

my $title  = 'User:Mike.lifeguard/04-edit.t';
my $rand   = rand();
my $status = $bot->edit($title, $rand, $agent);

SKIP: {
    skip 'Cannot use editing tests: ' . $bot->{error}->{details}, 2 if
        defined $bot->{'error'}->{'code'} and $bot->{'error'}->{'code'} == 3;

    sleep(1);
    my $is = $bot->get_text($title);
    is($is, $rand, 'Did whole-page editing successfully');

    my $rand2 = rand();
    $status = $bot->edit({
        page    => $title,
        text    => $rand2,
        section => 'new',
        summary => $agent,
    });
    sleep(1);
    $is = $bot->get_text($title);
    my $ought = <<"END";
$rand

== $agent ==

$rand2
END
    is("$is\n", $ought, 'Did section editing successfully');
}
