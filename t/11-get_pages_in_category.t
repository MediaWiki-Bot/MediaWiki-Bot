use strict;
use warnings;
use Test::More tests => 9;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

my @loop_pages = $bot->get_all_pages_in_category('Category:Category loop', { max => 5 });
is(     scalar @loop_pages, 1,              'Category loop protection works');

my @pages = $bot->get_all_pages_in_category('Category:Really big category', { max => 51 });
ok(     defined $pages[0],                  'Get big category');
cmp_ok( scalar(@pages),     '>', 500,       'Get big category, enough elements');

$bot->get_all_pages_in_category('Category:Wikipedia', { hook => \&test_hook });
my $title;
my $ns;
my $pageid;
sub test_hook {
    my ($res) = @_;
    $title  = $res->[0]->{'title'};
    $ns     = $res->[0]->{'ns'};
    $pageid = $res->[0]->{'pageid'};
}
ok(     defined($title),                    'Title returned via callback');
like(   $title,             qr/\w+/,        'Title looks valid');

ok(     defined($ns),                       'Namespace returned via callback');
like(   $ns,                qr/\d/,         'Namespace is a number');

ok(     defined($pageid),                   'Pageid returned via callback');
like(   $pageid,            qr/\d/,         'Pageid is a number');
