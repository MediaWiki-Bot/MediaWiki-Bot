# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 2;

#########################

use MediaWiki::Bot;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};
my $login_data;
if (defined($username) and defined($password)) {
    $login_data = { username => $username, password => $password };
}

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (02_edit.t)',
    login_data => $login_data,
});

my $rand = rand();
my $status = $bot->edit('User:ST47/test', $rand, 'MediaWiki::Bot tests (02_edit.t)');

SKIP: {
    if ((defined($bot->{'error'}->{'code'})) and ($bot->{'error'}->{'code'} == 3)) {
        skip 'You are blocked, cannot use editing tests', 2;
    }

    sleep(1);
    my $is = $bot->get_text('User:ST47/test');
    is($is, $rand, 'Did whole-page editing successfully');

    my $rand2 = rand();
    $status = $bot->edit({
        page    => 'User:ST47/test',
        text    => $rand2,
        section => 'new',
        summary => 'MediaWiki::Bot tests (02_edit.t)',
    });
    sleep(1);
    $is = $bot->get_text('User:ST47/test');
    my $ought = <<"END";
$rand

== MediaWiki::Bot tests (02_edit.t) ==

$rand2
END
    is("$is\n", $ought, 'Did section editing successfully');
}
