use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 3;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

my @categories = $bot->get_all_categories;
ok(@categories, "Retrieved categories");
is(scalar @categories, 10, "Got right default number");

@categories = $bot->get_all_categories({max => 0});
is(scalar @categories, 500, "Got right maximum number");
