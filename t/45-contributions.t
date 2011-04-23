use strict;
use warnings;
use Test::More 0.96 tests => 2;
use MediaWiki::Bot;

my $t = __FILE__;
my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

subtest 'patrolled' => sub { # issue 151
    plan tests => 2;
    my @contribs = $bot->contributions('Mike.lifeguard', 0);

    ok(!$bot->{error}->{code}, 'No error in bot')
        or diag explain $bot->{error};

    ok(!$bot->{api}->{error}->{code}, 'No error in api')
        or diag explain $bot->{api}->{error};
};

subtest 'contribs' => sub {
    plan tests => 2;
    my @contribs = $bot->contributions('Mike.lifeguard', 0);

    isa_ok(\@contribs, 'ARRAY', 'Got an array');
    isa_ok($contribs[0], 'HASH', 'array of hashes');
};
