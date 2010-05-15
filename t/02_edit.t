# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 1;

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

    sleep 1;
    my $text = $bot->get_text('User:ST47/test');
    $text =~ s/\n//;
    is($text,$rand);
}
