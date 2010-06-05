# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 2;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new();
#$bot->set_wiki( "wiki.xyrael.net","w" );

my $rand = rand();
my $status = $bot->edit('User:ST47/test', $rand, 'MediaWiki::Bot tests');
#eval { use Data::Dumper; print STDERR Dumper($status); };
#if ($@) {print STDERR "#Couldn't load Data::Dumper\n"}
SKIP: {
    if ($status == 3 and $bot->{error}->{code} == 3) {
        skip 'You are blocked, cannot use editing tests', 1;
    }
    #ok( $status->isa("HTTP::Response") );

    my $is = $bot->get_text('User:ST47/test');
    is($is, $rand, 'Did whole-page editing successfully');

    my $rand2 = rand();
    $status = $bot->edit({
        page    => 'User:ST47/test',
        text    => $rand2,
        section => 'new',
        summary => 'MediaWiki::Bot tests',
    });
    $is = $bot->get_text('User:ST47/test');
    my $ought = <<"END";
$rand

== MediaWiki::Bot tests ==

$rand2
END
    is("$is\n", $ought, 'Did section editing successfully');
}
