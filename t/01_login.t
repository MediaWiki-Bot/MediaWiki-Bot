# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 5;

#########################

use MediaWiki::Bot;

my $username = defined($ENV{'PWPUsername'}) ? $ENV{'PWPUsername'} : 'Perlwikipedia testing';
my $password = defined($ENV{'PWPPassword'}) ? $ENV{'PWPPassword'} : 'test';

my $useragent = 'MediaWiki::Bot tests (01_login.t)';

my $bot = MediaWiki::Bot->new({
    agent   => $useragent,
});

is($bot->login({ username => $username, password => $password }), 1, 'Log in');
ok($bot->_is_loggedin(), q{Double-check we're logged in});

my $cookiemonster = MediaWiki::Bot->new({
    agent   => $useragent,
});

is($cookiemonster->login($username), 1, 'Cookie log in');
ok($bot->_is_loggedin(), q{Double-check we're cookie logged in});

my $failbot = MediaWiki::Bot->new({
    agent   => $useragent,
    login_data => { username => "Mike's test account", password => '' },
});
is($failbot, undef, 'Auto-login failed');
