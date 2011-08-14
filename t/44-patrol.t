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

pass;
my $tests_run = 1;
{
    my @rc = $bot->recentchanges(0, 1);
    if ($rc[0]->{type} eq 'edit') {
        my $success = $bot->patrol($rc[0]->{rcid});

        if ($bot->{error}->{details} !~ m/^permissiondenied/) {
            ok $success, 'Patrolled the page OK' or diag explain [$success, $bot->{error}];
            $tests_run++;
        }
    }
}

{
    my $rows      = 10;
    my @rc        = $bot->recentchanges(0, $rows, { hook => \&mysub });

    sub mysub {
        my ($res) = @_;
        foreach my $hashref (@$res) {
            next unless defined $hashref->{rcid} and $hashref->{type} eq 'edit';
            my $success = $bot->patrol($hashref->{rcid});

            if ($bot->{error}->{details} !~ m/^permissiondenied/) {
                ok $success, 'Patrolled the page OK' or diag explain [$success, $bot->{error}];
                $tests_run++;
            }
        }
    }
}

done_testing($tests_run);
