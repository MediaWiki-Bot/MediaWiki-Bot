use strict;
use warnings;
use Test::More tests => 5;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $template_ns = 10;
my @pages = $bot->get_pages_in_namespace($template_ns);
like $pages[0] => qr/^Template:/, 'Template namespace found';

my $page_limit = 1;
@pages = $bot->get_pages_in_namespace($template_ns, $page_limit);
is scalar @pages, $page_limit, 'Correct number of pages retrieved';

@pages = $bot->get_pages_in_namespace('non-existent');
is $pages[0], undef, 'Error code received';
is $bot->{error}->{code}, 3, 'Error code in MediaWiki::Bot object';

@pages = $bot->get_pages_in_namespace(2, 'max', { max => 0 });
cmp_ok scalar @pages, '>', 500, 'Got more than 500 pages'
    or diag explain \@pages; # RT 66790
