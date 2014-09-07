use strict;
use warnings;
use Test::RequiresInternet 'commons.wikimedia.org' => 80;
use Test::More tests => 3;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'commons.wikimedia.org',
});

my $file = 'File:Example.jpg';

subtest 'default' => sub {
    plan tests => 5;

    my @pages = $bot->global_image_usage($file);

    ok(     @pages,                                             'No error');
    cmp_ok( scalar @pages,                  '>', 1,             'More than one result');
    ok(     defined($pages[0]),                                 'Something was returned');
    isa_ok( $pages[0],                      'HASH',             'Results are hashref');
    is_deeply( [sort keys %{ $pages[0] }], [sort qw(title url wiki)], 'Has the right keys');
};

subtest 'limit' => sub {
    my $limit = 20;
    my @pages = $bot->global_image_usage($file, $limit);

    is scalar @pages, $limit, "$limit results returned";
};

subtest 'more' => sub {
    my $limit = 10000000;
    my @pages = $bot->global_image_usage('SadSmiley.svg', $limit, 1);

    cmp_ok scalar @pages, '<', $limit, "<$limit results returned";
};
