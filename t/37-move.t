use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 3;

use MediaWiki::Bot;
my $t = __FILE__;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};

SKIP: {
    skip('No account credentials provided in %ENV', 3) unless defined $username and defined $password;

    my $agent = "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)";
    my $bot = MediaWiki::Bot->new({
        agent   => $agent,
        host    => 'test.wikipedia.org',
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
    my $status = $bot->move('User:Mike.lifeguard/37-move.t', "User:Mike.lifeguard/$rand", $agent);

    if ((defined($bot->{'error'}->{'code'})) and ($bot->{'error'}->{'code'} == 3)) {
        skip('You are blocked, cannot use editing tests', 3);
    }

    ok($status,                     'Page moved successfully');

    $status = $bot->move("User:Mike.lifeguard/$rand", 'User:Mike.lifeguard/37-move.t', $agent, { noredirect => 1 });
    ok($status,                     'Page moved back successfully');

    my $text = $bot->get_text("User:Mike.lifeguard/$rand");
    is($text, undef,                'Redirect creation successfully suppressed');
}
