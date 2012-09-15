use strict;
use warnings;
use Test::More 0.96 tests => 5;
BEGIN {
    my $bail_diagnostic = <<'END';
There was a problem loading the module. Typically,
this means you have installed MediaWiki::Bot without
the prerequisites. Please check the documentation for
installation instructions, or ask for help from the
members of perlwikibot@googlegroups.com.

The test suite will bail out now; doing more testing is
pointless since everything will fail.
END
    use_ok('MediaWiki::Bot') or BAIL_OUT($bail_diagnostic);
};

# Provide some info to the tester
unless ($ENV{AUTOMATED_TESTING}) {
    diag <<'END';

Thanks for using MediaWiki::Bot. If any of these
tests fail, or you need any other assistance with
the module, please email our support mailing list
at perlwikibot@googlegroups.com, or submit a bug
to our tracker on github: http://goo.gl/5Ns48
END
    if (!defined($ENV{'PWPUsername'}) and !defined($ENV{'PWPPassword'})) {
        diag <<'END';

If you want, you can log in for editing tests.
To log in for those tests, stop the test suite now,
set the environment variables PWPUsername and
PWPPassword, and run the test suite.
END
        sleep(2);
    }
}

my $bot   = new_ok('MediaWiki::Bot'); # outside subtest b/c reused later

# Some deeper diagnostics
my $useragent   = 'MediaWiki::Bot tests (00-init.t)';
my $host        = '127.0.0.1';
my $assert      = 'bot';
my $operator    = 'MediaWiki::Bot tester';

subtest 'diag-one' => sub {
    plan tests => 5;
    my $test_one = MediaWiki::Bot->new({
        agent       => $useragent,
        host        => $host,
        path        => '',
        assert      => $assert,
        operator    => $operator,
    });
    is($test_one->{api}->{ua}->agent(),         $useragent,             'Specified useragent set correctly');
    is($test_one->{assert},                     $assert,                'Specified assert set orrectly');
    is($test_one->{operator},                   $operator,              'Specified operator set correctly');
    is($test_one->{api}->{config}->{api_url},   "http://$host/api.php", 'api.php with null path is OK'); # Issue 111: Null $path value returns "w"
    like($bot->{api}->{ua}->agent(),            qr{^MediaWiki::Bot/(v?[[:digit:]._]+|dev)$}, 'Useragent built correctly');
};

subtest 'diag-two' => sub {
    plan tests => 2;
    my $test_two = MediaWiki::Bot->new({
        host        => $host,
        path        => undef,
        operator    => $operator,
    });
    is(  $test_two->{api}->{config}->{api_url}, 'http://127.0.0.1/w/api.php',   'api.php with undef path is OK');
    like($test_two->{api}->{ua}->agent(),       qr/\Q$operator\E/,              'operator appears in the useragent');
};

subtest 'no assert' => sub {
    plan tests => 1;
    my $no_assert_bot = MediaWiki::Bot->new({
        host    => $host,
    });
    ok( not exists $bot->{assert} ) or diag explain $bot;
};
