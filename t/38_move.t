# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 3;

#########################

use MediaWiki::Bot;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};

SKIP: {
    if (!defined($username) or !defined($password)) {
        skip('No account credentials provided in %ENV', 3);
    }

    my $bot = MediaWiki::Bot->new({
        agent   => 'MediaWiki::Bot tests (38_move.t)',
        login_data => { username => $username, password => $password },
    });
    my $res = $bot->{api}->api({
        action => 'query',
        meta   => 'userinfo',
        uiprop => 'rights',
    });
    my @rights = @{ $res->{'query'}->{'userinfo'}->{'rights'} };
    # grep is slow; might be worth using List::Util if the main module gains that as a dependency
    if (! grep $_ eq 'suppressredirect', @rights) {
        skip( qq{The account doesn't have the 'suppressredirect' right}, 3);
    }

    my $rand = rand();
    my $status = $bot->move('User:Mike.lifeguard/38_move.t', "User:Mike.lifeguard/$rand", 'MediaWiki::Bot tests (38_move.t)');

    if ((defined($bot->{'error'}->{'code'})) and ($bot->{'error'}->{'code'} == 3)) {
        skip('You are blocked, cannot use editing tests', 3);
    }

    ok($status,                     'Page moved successfully');

    $status = $bot->move("User:Mike.lifeguard/$rand", 'User:Mike.lifeguard/38_move.t', 'MediaWiki::Bot tests (38_move.t)', { noredirect => 1 });
    ok($status,                     'Page moved back successfully');

    my $text = $bot->get_text("User:Mike.lifeguard/$rand");
    is($text, undef,                'Redirect creation successfully suppressed');
}

