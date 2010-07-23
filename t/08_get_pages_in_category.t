# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 9;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (08_get_pages_in_category.t)',
});

my @loop_pages = $bot->get_all_pages_in_category('Category:Category loop', { max => 5 });
is(     scalar @loop_pages, 1,              'Category loop protection works');

my @pages = $bot->get_all_pages_in_category('Category:Wikipedia external links cleanup', { max => 51 });
ok(     defined $pages[0],                  'Get big category');
cmp_ok( scalar(@pages),     '>', 500,       'Get big category, enough elements');

$bot->get_all_pages_in_category('Category:Copy to Wikisource', { hook => \&test_hook });
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

