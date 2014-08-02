use strict;
use warnings;
use Test::More tests => 10;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $bot->linksearch('*.example.com', undef, undef, { max => 1 });

ok(     defined $pages[0],                                  'Something was returned');
isa_ok( $pages[0],                      'HASH',             'A hash was returned');
ok(     defined $pages[0]->{'url'},                         'The hash contains a URL');
like(   $pages[0]->{'url'},             qr/example\.com/,   'The URL is one we requested');
ok(     defined $pages[0]->{'title'},                       'The has contains a page title');
like(   $pages[0]->{'title'},           qr/\w+/,            'The title looks valid');

$bot->linksearch('*.example.com', undef, undef, { max=> 1, hook => \&test_hook });
my $url;
my $title;
sub test_hook {
    my ($res) = @_;
    my $hashref = $res->[0];
    $url = $hashref->{'url'};
    $title = $hashref->{'title'};
}
ok(     defined($url),                                      'A URL was returned via callback');
like(   $url,                           qr/example\.com/,   'The URL is right');
ok(     defined($title),                                    'A title was returned via callback');
like(   $title,                         qr/\w+/,            'The title looks valid');
