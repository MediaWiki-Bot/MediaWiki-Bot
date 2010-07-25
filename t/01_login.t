# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 8;

#########################

use MediaWiki::Bot;

my $username = defined($ENV{'PWPUsername'}) ? $ENV{'PWPUsername'} : 'Perlwikipedia testing';
my $password = defined($ENV{'PWPPassword'}) ? $ENV{'PWPPassword'} : 'test';

my $useragent = 'MediaWiki::Bot tests (01_login.t)';

my $bot = MediaWiki::Bot->new({
    agent   => $useragent,
});

isa_ok($bot, 'MediaWiki::Bot'); # Make sure we have a bot object to work with
is($bot->login({ username => $username, password => $password, do_sul => 1 }), 11, q{SUL login});
ok($bot->_is_loggedin(),                                        q{Double-check we're logged in});
is($bot->set_wiki({host=>'meta.wikimedia.org'}), 1,             q{Switched wikis OK});
ok($bot->_is_loggedin(),                                        q{Double-check we're logged in via SUL});

my $cookiemonster = MediaWiki::Bot->new({
    agent   => $useragent,
});

is($cookiemonster->login($username), 1, 'Cookie log in');
ok($bot->_is_loggedin(), q{Double-check we're cookie logged in});

my $failbot = MediaWiki::Bot->new({
    agent   => $useragent,
    login_data => { username => q{Mike's test account}, password => q{} },
});
is($failbot, undef, 'Auto-login failed');

