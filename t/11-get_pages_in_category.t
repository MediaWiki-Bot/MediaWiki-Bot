use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More 0.96 tests => 3;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

subtest 'category loop' => sub {
    plan tests => 1;
    my @pages = $bot->get_all_pages_in_category('Category:Category loop', { max => 5 });
    is(scalar @pages, 1, 'Category loop protection works');
};

subtest 'big' => sub {
    plan tests => 2;
    my @pages = $bot->get_all_pages_in_category('Category:Really big category', { max => 51 });
    cmp_ok( scalar(@pages), '>', 500, 'Get big category, enough elements');
    ok(defined $pages[0], 'Get big category');
};

subtest 'callback' => sub {
    plan tests => 6;
    my $title;
    my $ns;
    my $pageid;

    $bot->get_all_pages_in_category('Category:Wikipedia', {
        hook => sub {
            my ($res) = @_;
            $title  = $res->[0]->{title};
            $ns     = $res->[0]->{ns};
            $pageid = $res->[0]->{pageid};
        }
    });

    ok(     defined($title),                    'Title returned via callback');
    like(   $title,             qr/\w+/,        'Title looks valid');

    ok(     defined($ns),                       'Namespace returned via callback');
    like(   $ns,                qr/\d/,         'Namespace is a number');

    ok(     defined($pageid),                   'Pageid returned via callback');
    like(   $pageid,            qr/\d/,         'Pageid is a number');
};
