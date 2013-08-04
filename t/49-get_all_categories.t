use strict;
use warnings;
use Test::More tests => 3;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my @categories = $bot->get_all_categories;
ok(@categories, "Retrieved categories");
is(scalar @categories, 10, "Got right default number");

@categories = $bot->get_all_categories({max => 0});
is(scalar @categories, 500, "Got right maximum number");
