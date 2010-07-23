# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 15;
BEGIN {
    use_ok('MediaWiki::Bot');
    use_ok('PWP');
    use_ok('perlwikipedia');
};

#################################
# Provide some info to the tester
print STDERR <<"_end_";
\r# Thanks for using MediaWiki::Bot. If any of these
# tests fail, or you need any other assistance with
# the module, please email our support mailing list
# at perlwikibot\@googlegroups.com, or submit a bug
# to our tracker http://perlwikipedia.googlecode.com
_end_
print STDERR <<"_end_" if (!defined($ENV{'PWPUsername'}) and !defined($ENV{'PWPPassword'}));
#
# If you want, you can log in for editing tests.
# To log in for those tests, stop the test suite now,
# set the environment variables PWPUsername and
# PWPPassword, and run the test suite.
_end_
sleep(2);

#######################
# Simple initialization
my $bot = MediaWiki::Bot->new();
ok(defined $bot, 'new() works');
ok($bot->isa('MediaWiki::Bot'), 'Right class');

my $bot_alias = PWP->new();
ok(defined $bot_alias, 'new() works');
ok($bot_alias->isa('MediaWiki::Bot'), 'Right class');

my $bot_alias_2 = perlwikipedia->new();
ok(defined $bot_alias_2, 'new() works');
ok($bot_alias_2->isa('MediaWiki::Bot'), 'Right class');

#########################
# Some deeper diagnostics
my $useragent   = 'MediaWiki::Bot tests (00_initialize.t)';
my $host        = '127.0.0.1';
my $assert      = 'bot';
my $operator    = 'MediaWiki::Bot tester';

my $test_one = MediaWiki::Bot->new({
    agent       => $useragent,
    host        => $host,
    path        => '',
    assert      => $assert,
    operator    => $operator,
});
is($test_one->{api}->{ua}->agent(),         $useragent,                     'Specified useragent set correctly');
is($test_one->{assert},                     $assert,                        'Specified assert set orrectly');
is($test_one->{operator},                   $operator,                      'Specified operator set correctly');
is($test_one->{api}->{config}->{api_url},   "http://$host/api.php",         'api.php with null path is OK'); # Issue 111: Null $path value returns "w"

like($bot->{api}->{ua}->agent(),            qr{^MediaWiki::Bot/\d\.\d\.\d{1,2}$}, 'Useragent built correctly');

my $test_two = MediaWiki::Bot->new({
    agent   => $useragent,
    host    => $host,
    path    => undef,
});
is($test_two->{api}->{config}->{api_url}, 'http://127.0.0.1/w/api.php', 'api.php with undef path is OK');

