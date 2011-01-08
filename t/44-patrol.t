use strict;
use warnings;
use Test::More 0.88;

use MediaWiki::Bot;
my $t = __FILE__;

my $host     = $ENV{'PWPMakeTestSetWikiHost'} || 'test.wikipedia.org';
my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};
plan skip_all => 'Login with patrol rights required'
    unless $host and $username and defined $password;

my $bot = MediaWiki::Bot->new({
    agent => "MediaWiki::Bot tests ($t)",
    login_data => {
        username => $username,
        password => $password,
        do_sul => 0,
    },
    host => $host,
});

my $tests_run = 0;
my $rows      = 10;
my @rc        = $bot->recentchanges(3, $rows, { hook => \&mysub });

sub mysub {
    my ($res) = @_;
    foreach my $hashref (@$res) {
        my $success = $bot->patrol($hashref->{rcid}) if defined $hashref->{rcid};
        ok($success, "Patrolled the page OK");
        $tests_run++;
    }
}
is($tests_run, $rows, 'Ran the right number of tests');
$tests_run++;

done_testing($tests_run);
