use strict;
use warnings;
use Test::More tests => 7;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @pages = $bot->list_transclusions('Template:Tlx', 'nonredirects', undef, {max=>1});

ok(     defined($pages[0]),                                 'Something was returned');
isa_ok( $pages[0],                      'HASH',             'A hash was returned');
ok(     defined($pages[0]->{'title'}),                      'The hash contains a title');
like(   $pages[0]->{'title'},           qr/\w+/,            'The title looks valid');
ok(     defined($pages[0]->{'redirect'}),                   'Redirect status is defined');
is(     $pages[0]->{'redirect'},        '',                 'We got a redirect when we asked for it');

$bot->list_transclusions('Template:Tlx', 'redirects', undef, { max => 1, hook => \&test_hook});
my $is_redir;
sub test_hook {
    my ($res) = @_;
    $is_redir = $res->[0]->{'redirect'};
}
isnt(   $is_redir,                                          'We got a redirect when we asked for it');
