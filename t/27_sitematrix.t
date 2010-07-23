# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 14;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (27_sitematrix.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

# db->domain
my @wikis = ('enwiktionary', 'bat-smgwiki', 'nonexistentwiki', 'meta', 'otrs-wiki', 'aawiki');
my $domains = $bot->db_to_domain(\@wikis);

ok(     @$domains,                                          qq{Something was returned});
is(     $domains->[0],          'en.wiktionary.org',        qq{enwiktionary was found});
is(     $domains->[1],          'bat-smg.wikipedia.org',    qq{bat-smgwiki was found});
is(     $domains->[2],          undef,                      qq{nonexistentwiki wasn't found});
is(     $domains->[3],          'meta.wikimedia.org',       qq{meta was found});
is(     $domains->[4],          undef,                      qq{otrs-wiki wasn't found (private)});
is(     $domains->[5],          undef,                      qq{aawiki wasn't found (closed)});

# domain->db
my @domains = ('en.wiktionary.org', 'bat-smg.wikipedia.org', 'this.dont.exist', 'meta.wikimedia.org', 'otrs-wiki.wikimedia.org', 'aa.wikipedia.org');
my $wikis = $bot->domain_to_db(\@domains);

ok(     @$wikis,                                            qq{Something was returned});
is(     $wikis->[0],            'enwiktionary',             qq{en.wiktionary.org was found});
is(     $wikis->[1],            'bat-smgwiki',              qq{bat-smg.wikipedia.org was found});
is(     $wikis->[2],            undef,                      qq{this.dont.exist wasn't found});
is(     $wikis->[3],            'meta',                     qq{meta.wikimedia.org was found});
is(     $wikis->[4],            undef,                      qq{otrs-wiki.wikimedia.org wasn't found (private)});
is(     $wikis->[5],            undef,                      qq{aa.wikipedia.org wasn't found (closed)});

