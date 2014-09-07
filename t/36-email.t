use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More;

use MediaWiki::Bot;
my $t = __FILE__;

plan $ENV{PWPUsername} && $ENV{PWPPassword}
    ? ( tests => 1 )
    : ( skip_all => q{I can't log in without credentials} );

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
    login_data => { username => $ENV{PWPUsername}, password => $ENV{PWPPassword} },
    protocol => 'https',
});

my $rand = rand();
my $res = $bot->email('User:Perlwikibot testing', "MediaWiki::Bot test $rand", $rand);
ok($res, 'Sending an email succeeded') or diag explain $bot->{error};
note 'This test sent an email to [[User:Perlwikibot testing]].';
note 'The email registered for this account is perlwikibot@mailinator.com';
note 'You can find the inbox at https://perlwikibot.mailinator.com';
