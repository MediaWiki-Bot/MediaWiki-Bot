# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 9;
BEGIN {
    use_ok('MediaWiki::Bot');
    use_ok('PWP');
    use_ok('perlwikipedia');
};

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (00_initialize.t)',
});

ok(defined $bot, 'new() works');
ok($bot->isa('MediaWiki::Bot'), 'Right class');

my $bot_alias = PWP->new();

ok(defined $bot_alias, 'new() works');
ok($bot_alias->isa('MediaWiki::Bot'), 'Right class');

my $bot_alias_2 = perlwikipedia->new();

ok(defined $bot_alias_2, 'new() works');
ok($bot_alias_2->isa('MediaWiki::Bot'), 'Right class');

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
sleep(2)
