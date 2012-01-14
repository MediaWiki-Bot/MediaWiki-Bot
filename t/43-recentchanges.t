use strict;
use warnings;
use Test::More 0.88;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'en.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $tests_run = 0;

{   # General structure
    my @rc = $bot->recentchanges();
    my @keys = qw(comment ns old_revid pageid rcid revid timestamp title type user);
    ok exists $rc[0]->{$_}, "$_ present in hashref" for @keys;
    $tests_run += @keys;

    foreach (@rc) {
        is( $_->{ns}, 0, 'ns 0 used by default');
        $tests_run++;
    }
}

{   # Test some constraints
    my $rows = 10;
    my $ns   = [0, 1, 4];

    my @rc = $bot->recentchanges($ns, $rows);
    is( scalar @rc, $rows,                                                      'Returned the right number of rows');
    $tests_run++;
    for my $i (0..$rows-1) {
        ok(grep($rc[$i]->{ns} == $_, @$ns),                                     'Right namespaces');
        $tests_run++;
        like($rc[$i]->{timestamp},  qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/,      'Timestamp validates');
        $tests_run++;
        like($rc[$i]->{type},       qr/^\w+$/,                                  'Type looks vaguely OK');
        $tests_run++;
        like($rc[$i]->{title},      qr/\w+/,                                    'Title looks vaguely OK');
        $tests_run++;
    }
}

{   # Test using an arrayref of namespace numbers, and the $options_hashref
    my $rows = 10;
    my $ns   = 4;

    my @rc = $bot->recentchanges($ns, $rows, { hook => \&mysub });
    sub mysub {
    my ($res) = @_;
        foreach my $hashref (@$res) {
            is($hashref->{ns}, $ns, 'Right namespace returned');
            $tests_run++;
        }
    }
}

done_testing($tests_run);
