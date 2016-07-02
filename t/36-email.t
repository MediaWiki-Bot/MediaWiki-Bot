use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More;

use MediaWiki::Bot;
my $t = __FILE__;

# Need to figure out a new testing strategy here. [[User:Perlwikibot testing]]
# was created with a confirmed email so you could send emails to it. The
# account was then locked (in CentralAuth), but this still permitted emails
# to be sent. MediaWiki no longer allows this. We need to figure out another
# plan.
plan skip_all => "Can't email locked accounts";

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
note 'You can find the inbox at https://mailinator.com/inbox2.jsp?public_to=perlwikibot';
