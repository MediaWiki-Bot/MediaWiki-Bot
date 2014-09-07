use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More 0.96 tests => 2;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

subtest 'normal namespaces' => sub {
    plan tests => 7;
    my %ns_names = $bot->get_namespace_names();

    is($ns_names{7},  'File talk',    'File talk OK');
    is($ns_names{2},  'User',         'User OK');
    is($ns_names{1},  'Talk',         'Talk OK');
    is($ns_names{14}, 'Category',     'Category OK');
    is($ns_names{0},  '',             'Main OK');
    is($ns_names{-2}, 'Media',        'Media OK');
    is($ns_names{-1}, 'Special',      'Special OK');
};

subtest 'namespace aliases' => sub {
    plan tests => 2;
    my $ns_aliases = $bot->_get_ns_alias_data();
    isa_ok $ns_aliases => 'HASH';
    is $ns_aliases->{Image} => 'File',    'Image alias OK';
};
