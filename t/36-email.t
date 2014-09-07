use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More;

use MediaWiki::Bot;
my $t = __FILE__;

my $username = $ENV{PWPUsername};
my $password = $ENV{PWPPassword};
plan $username && $password
    ? ( tests => 1 )
    : ( skip_all => q{I can't log in without credentials} );

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
    login_data => { username => $username, password => $password },
});

my $rand = rand();
# The email registered for this account is perlwikibot@mailinator.com
# Accordingly, you can find the inbox at
# http://mailinator.com/maildir.jsp?email=perlwikibot
my $res = $bot->email($username, "MediaWiki::Bot test $rand", $rand);
ok($res,    'Sending an email succeeded');
