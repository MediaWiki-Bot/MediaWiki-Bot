# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 1;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use MediaWiki::Bot;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};

SKIP: {
    if (!defined($username) or !defined($password)) {
        skip('No account credentials provided in %ENV', 1);
    }
    my $bot = MediaWiki::Bot->new({
        agent   => 'MediaWiki::Bot tests (37_email.t)',
        login_data => { username => $username, password => $password },
    });

    my $rand = rand();
    # The email registered for this account is perlwikibot@mailinator.com
    # Accordingly, you can find the inbox (where you can delete your email,
    # if you don't want your own address to be public) at
    # http://mailinator.com/maildir.jsp?email=perlwikibot
    my $res = $bot->email('Email testing account', "MediaWiki::Bot test $rand", $rand);
    ok($res,    'Sending an email succeeded');
}

