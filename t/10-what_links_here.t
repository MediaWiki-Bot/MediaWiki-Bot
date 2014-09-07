use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
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

my @pages = $bot->what_links_here('Main Page', 'redirects', undef, {max=>1});

ok(     defined $pages[0],                                  'Something was returned');
isa_ok( $pages[0],                      'HASH',             'A hash was returned');
ok(     defined $pages[0]->{'title'},                       'The hash contains a title');
like(   $pages[0]->{'title'},           qr/\w+/,            'The title looks valid');
ok(     defined $pages[0]->{'redirect'},                    'Redirect status is defined');
ok(     defined($pages[0]->{'redirect'}),                   'We got a redirect when we asked for it');

$bot->what_links_here('Project:Sandbox', 'nonredirects', 0, {max => 1, hook => \&mysub});
my $is_redir;
sub mysub {
    my ($res) = @_;
    my $hash = $res->[0];
    $is_redir = $hash->{'redirect'};
}
isnt(     $is_redir,                                        'We got a normal link when we asked for no redirects');
