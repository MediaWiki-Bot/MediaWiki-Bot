use strict;
use warnings;
use Test::More tests => 5;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (36_get_protection.t)',
});

{   # [[Main Page]] is probably protected
    my @pages = ('Main Page', 'Ambrax');
    my $result = $bot->get_protection(\@pages);
    isa_ok($result,                     'HASH',  'Return value of get_protection()');
    isa_ok($result->{'Main Page'},      'ARRAY', '[[Main Page]] protection');
    is($result->{'Ambrax'},             undef,   '[[Ambrax]] protection');
}

{   # [[User talk:Mike.lifeguard]] is probably not protected
    my $result = $bot->get_protection('User talk:Mike.lifeguard');
    my $bc     = $bot->is_protected('User talk:Mike.lifeguard');
    is($result,             undef,      '[[User talk:Mike.lifeguard]] protection');
    is($result,             $bc,        'Agreement between new and old methods');
}
