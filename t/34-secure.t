use strict;
use warnings;
use Test::More tests => 1;

use MediaWiki::Bot qw(:constants);
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
    host        => 'test.wikipedia.org',
    protocol    => 'https',
    login_data  => $login_data,
});

my $rand   = rand();
my $page   = 'User:Mike.lifeguard/34-secure.t';
my $status = $bot->edit({
    page    => $page,
    text    => $rand,
    summary => $agent,
});
SKIP: {
    skip 'You are blocked, cannot use editing tests', 1
        if defined $bot->{error}->{code}
        and ($bot->{error}->{code} == ERR_API or $bot->{error}->{code} == ERR_CAPTCHA);

    my $is = $bot->get_text($page);
    is($is, $rand, 'Edited via secure server successfully');
}
