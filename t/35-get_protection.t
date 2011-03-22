use strict;
use warnings;
use Test::More tests => 6;
use Test::Warn;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

{   # [[Main Page]] is probably protected
    my @pages = ('Main Page', 'SyntaxHighlight GeSHi');
    my $result = $bot->get_protection(\@pages);
    isa_ok($result,                         'HASH',     'Return value of get_protection()');
    isa_ok($result->{'Main Page'},          'ARRAY',    '[[Main Page]] protection');
    is($result->{'SyntaxHighlight GeSHi'},  undef,      '[[SyntaxHighlight GeSHi]] protection');
}

{   # [[User talk:Mike.lifeguard]] is probably not protected
    my $result = $bot->get_protection('User talk:Mike.lifeguard');
    my $bc;
    warning_is(
        sub { $bc = $bot->is_protected('User talk:Mike.lifeguard'); },
        'is_protected is deprecated, and might be removed in a future release; please use get_protection instead',
        'is_protected is deprecated'
    );
    is($result,             undef,      '[[User talk:Mike.lifeguard]] protection');
    is($result,             $bc,        'Agreement between new and old methods');
}
