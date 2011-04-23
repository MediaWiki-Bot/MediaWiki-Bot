use strict;
use warnings;
use Test::More tests => 3;
use Test::Warn;

BEGIN {
    warning_like(
        sub { require PWP; },
        qr/PWP.*deprecated/, 'warnings!');
}

{
    no warnings;
    warning_is(
        sub { my $bot = PWP->new('test.wikipedia.org');
    }, '', 'no warnings with all warnings off');
}

{
    no warnings 'deprecated';
    warning_is(
        sub { my $bot = PWP->new('test.wikipedia.org');
    }, '', 'no warnings with all warnings off');
}
