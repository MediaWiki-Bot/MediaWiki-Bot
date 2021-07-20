use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 4;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

{   # db->domain
    my @wikis = ('enwiktionary', 'bat-smgwiki', 'nonexistentwiki', 'meta', 'otrs-wiki', 'aawiki');
    my $ought = [
              'en.wiktionary.org',      # ok
              'bat-smg.wikipedia.org',  # ok
              undef,                    # doesn't exist
              'meta.wikimedia.org',     # ok
              undef,                    # private
              'aa.wikipedia.org'        # closed
            ];
    my $domains = $bot->db_to_domain(\@wikis);

    ok(     @$domains,                  'Something was returned');
    is_deeply($domains,     $ought,     'db->domain OK');
}

{   # domain->db
    my @domains = ('en.wiktionary.org', 'bat-smg.wikipedia.org', 'this.dont.exist', 'meta.wikimedia.org', 'otrs-wiki.wikimedia.org', 'aa.wikipedia.org');
    my $wikis = $bot->domain_to_db(\@domains);
    my $ought = [
          'enwiktionary',   # ok
          'bat-smgwiki',    # ok
          undef,            # doesn't exist
          'meta',           # ok
          undef,            # private
          'aawiki'          # closed
        ];

    ok(     @$wikis,                    'Something was returned');
    is_deeply($wikis,       $ought,     'domain->db OK');
}
