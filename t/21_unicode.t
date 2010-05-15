# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 6;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use strict;
use MediaWiki::Bot;
use utf8;

my $editor = MediaWiki::Bot->new;

#if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
#   $editor->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
#}

my $string = 'éółŽć';
my ($length, $load) = $editor->get_text('User:ST47/unicode1');
is($load, $string, 'Is our string the same as what we load?');

($length, my $old) = $editor->get_text('User:ST47/unicode2');
my $rand = rand();
my $status = $editor->edit('User:ST47/unicode2', "$rand\n$string\n", 'PWP test');
SKIP: {
    if ($status == 3 and $editor->{error}->{code} == 3) {
        skip 'You are blocked, cannot use editing tests', 4;
    }
    my $rand2 = rand();
    $editor->edit('User:ST47/unicode3', "$rand2\n$load\n", 'PWP test (éółŽć)');
    my @history = $editor->get_history('User:ST47/unicode3', 1);
    is($history[0]->{comment}, 'PWP test (éółŽć)', 'Use unicode in edit summary correctly');
    my $rand3 = rand();
    sleep 1;
    $editor->edit('User:ST47/éółŽć', "$rand3\n$load\n", 'PWP test');
    sleep 1;
    my ($length, $new) = $editor->get_text('User:ST47/unicode2');
    isnt($new, $old, 'Successfully saved test string');             # new from 42; old from 29
    is($new, "$rand\n$string", 'Loaded correct data');              # new from 42; compare against save from 31
    ($length, $new) = $editor->get_text('User:ST47/unicode3');
    is($new, "$rand2\n$string", 'Saved data from load correctly');  # new from 42; compare against save from 37
    ($length, $new) = $editor->get_text('User:ST47/éółŽć');
    is($new, "$rand3\n$string", 'Saved data from load correctly to page with unicode title');
}
