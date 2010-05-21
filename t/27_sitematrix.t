# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 10;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new('make test');

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# db->domain
my @wikis = ("enwiktionary", "bat-smgwiki", "nonexistentwiki", "meta");
my $domains = $bot->db_to_domain(\@wikis);

ok(     @$domains,                                      'Something was returned');
is(     $domains->[0],        'en.wiktionary.org',      'enwiktionary was found');
is(     $domains->[1],        'bat-smg.wikipedia.org',  'bat-smgwiki was found');
is(     $domains->[2],        undef,                    "nonexistentwiki wasn't found");
is(     $domains->[3],        'meta.wikimedia.org',     'meta was found');

# domain->db
my @domains = ("en.wiktionary.org", "bat-smg.wikipedia.org", "this.dont.exist", "meta.wikimedia.org");
my $wikis = $bot->domain_to_db(\@domains);

ok(     @$wikis,                                        'Something was returned');
is(     $wikis->[0],            'enwiktionary',         'en.wiktionary.org was found');
is(     $wikis->[1],            'bat-smgwiki',          'bat-smg.wikipedia.org was found');
is(     $wikis->[2],            undef,                  "this.dont.exist wasn't found");
is(     $wikis->[3],            'meta',                 'meta.wikimedia.org was found');
