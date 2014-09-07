use strict;
use warnings;
use Test::Is qw(extended);
use Test::RequiresInternet 'test.wikipedia.org' => 80, 'test.wikipedia.org' => 443;
use Test::More 0.96;
use Test::Warn;

use MediaWiki::Bot;
my $t = __FILE__;

my $username = $ENV{PWPUsername};
my $password = $ENV{PWPPassword};
plan defined $username
    ? (tests => 6)
    : (skip_all => q{I can't log in without credentials});
unlink ".mediawiki-bot-$username-cookies"
    if $username and -e ".mediawiki-bot-$username-cookies";

my $useragent = "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)";
my $host = 'test.wikipedia.org';

subtest 'one wiki' => sub {
    plan tests => 3;

    my $bot = MediaWiki::Bot->new({
        agent   => $useragent,
        host    => $host,
        # debug   => 2,
    });

    warning_is(
        sub {is($bot->login($username, $password), 1, 'Login OK'); },
        'Please pass a hashref; this method of calling login is deprecated and will be removed in a future release',
        'old login call style warns'
    );
    ok($bot->_is_loggedin(), q{Double-check we're logged in});
};

subtest 'cookies' => sub {
    plan tests => 3;

    my $cookiemonster = MediaWiki::Bot->new({
        agent   => $useragent,
        host    => $host,
        # debug   => 2,
    });

    is($cookiemonster->login({username => $username}), 1, 'Cookie log in');
    ok($cookiemonster->_is_loggedin(), q{Double-check we're logged in with only cookies});
    ok($cookiemonster->logout(), 'Logged out');
};

subtest 'SUL' => sub {
    plan tests => 9;

    my $bot = MediaWiki::Bot->new({
        agent   => $useragent,
        host    => $host,
        # debug => 2,
    });

    is($bot->login({
            username => $username,
            password => $password,
            do_sul => 1
        }), 1,                                              q{SUL login});

    is($bot->{host}, $host,                                 q{We're still on the wiki we started on});
    ok($bot->_is_loggedin(),                                q{Double-check we're logged in});

    is($bot->set_wiki({host=>'meta.wikimedia.org'}), 1,     q{Switched wikis OK});
    ok($bot->_is_loggedin(),                                q{Double-check we're logged in via SUL});

    is($bot->logout(), 1,                                   q{logout returned true});
    ok(!$bot->_is_loggedin(),                               q{Double-check we're actually logged out});

    is($bot->set_wiki({host=>'en.wikipedia.org'}), 1,       q{Switched wikis OK});
    ok(!$bot->_is_loggedin(),                               q{Double-check we're logged out for SUL});
};

subtest 'fail' => sub {
    plan tests => 1;

    my $failbot = MediaWiki::Bot->new({
        agent   => $useragent,
        login_data => { username => q{Mike's test account}, password => q{} },
    });
    is($failbot, undef, 'Auto-login failed');
};

subtest 'secure' => sub {
    plan tests => 1;

    my $secure = MediaWiki::Bot->new({
        agent       => $useragent,
        protocol    => 'https',
        host        => 'secure.wikimedia.org',
        path        => 'wikipedia/en/w',
    });

    warning_like(
        sub { $secure->login({ username => $username, password => $password, do_sul => 1 }) },
        qr{^\QSSL is now supported on the main Wikimedia Foundation sites.}
    );
};

subtest 'new-secure' => sub {
    plan tests => 5;

    my $secure = MediaWiki::Bot->new({
        agent       => $useragent,
        protocol    => 'https',
        host        => 'en.wikipedia.org',
    });

    is($secure->login({
            username => $username,
            password => $password,
            do_sul => 1,
        }), 1,                                              q{Secure login});
    ok($secure->_is_loggedin(),                             q{Double-check we're actually logged in});
    is($secure->set_wiki({host => 'fr.wikipedia.org'}), 1,  q{Switched wikis OK}); # Don't specify path or protocol
    is($secure->{api}->{config}->{api_url}, 'https://fr.wikipedia.org/w/api.php', q{Protocol and path retained properly});
    ok($secure->_is_loggedin(),                             q{Double-check we're logged in on secure})
        or is($secure->{error}->{code}, 3);
};

END {
    unlink ".mediawiki-bot-$username-cookies"
        if $username and -e ".mediawiki-bot-$username-cookies";
}
