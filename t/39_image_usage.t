# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 5;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (39_image_usage.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $bot->image_usage('File:Albert Einstein Head.jpg', undef, undef, { max => 1 });
ok(     @pages,                                             'No error');
cmp_ok( scalar @pages,                  '>', 1,             'More than one result');
ok(     defined($pages[0]),                                 'Something was returned');
like(   $pages[0],                      qr/\w+/,            'The title looks valid');

SKIP: {
    skip('Need to find an image that has redirects pointing at it', 1);
    $bot->image_usage("File:Albert Einstein Head.jpg", undef, 'redirects', {hook=>\&mysub, max=>5});
    my $is_redir = 1;
    sub mysub {
        my $res = shift;
        $is_redir = ${ $res->[0]->{'redirect'} };
    }
    isnt(     $is_redir,                                        'We got a normal link when we asked for no redirects');
}

