use strict;
use warnings;
use Test::More tests => 1;

use MediaWiki::Bot;
my $t = __FILE__;

my $username = $ENV{'PWPUsername'} || 'Perlwikibot testing';
my $password = $ENV{'PWPPassword'} || 'test';

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
    login_data => { username => $username, password => $password },
});

my $rand = rand();
# The email registered for this account is perlwikibot@mailinator.com
# Accordingly, you can find the inbox at
# http://mailinator.com/maildir.jsp?email=perlwikibot
my $res = $bot->email($username, "MediaWiki::Bot test $rand", $rand);
ok($res,    'Sending an email succeeded');
