use strict;
use warnings;
use Test::More tests => 7;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my %ns_names = $bot->get_namespace_names;

is($ns_names{7},  'File talk',    'File talk OK');
is($ns_names{2},  'User',         'User OK');
is($ns_names{1},  'Talk',         'Talk OK');
is($ns_names{14}, 'Category',     'Category OK');
is($ns_names{0},  '',             'Main OK');
is($ns_names{-2}, 'Media',        'Media OK');
is($ns_names{-1}, 'Special',      'Special OK');
