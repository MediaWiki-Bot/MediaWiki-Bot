use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More 0.96 tests => 3;

use MediaWiki::Bot;

my $t = __FILE__;
my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
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
    plan tests => 1;
    my @contribs = $bot->contributions('Mike.lifeguard');

    isa_ok $contribs[0], 'HASH', 'array of hashes' or diag explain \@contribs;
};

subtest 'multiple users' => sub {
    plan tests => 3;
    my @contribs = $bot->contributions(['User:Mike.lifeguard', 'User:Reedy']);

    isa_ok $contribs[0], 'HASH', 'array of hashes' or diag explain \@contribs;
    my %users = map { $_->{user} => 1 } @contribs;
    ok exists $users{'Mike.lifeguard'}, 'Mike.lifeguard is represented in the results'
        or diag explain { users => [keys %users] };
    ok exists $users{'Reedy'}, 'Reedy is represented in the results'
        or diag explain { users => [keys %users] };
};
