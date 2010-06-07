# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Test::More tests => 4;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $log = $bot->get_log({
    type    => 'delete',
    user    => 'East718',
    target  => 'Main Page',
    limit   => 1,
});
my $std = [
          {
            'ns' => 0,
            'timestamp' => '2008-02-04T01:13:02Z',
            'comment' => '3,975 revisions restored: now nobody can delete it again',
            'pageid' => 15580374,
            'action' => 'restore',
            'user' => 'East718',
            'title' => 'Main Page',
            'type' => 'delete',
            'logid' => 13464702
          },
          {
            'ns' => 0,
            'timestamp' => '2008-02-04T01:11:20Z',
            'comment' => 'deleted to make way for move ([[WP:CSD#G6|CSD G6]])',
            'pageid' => 15580374,
            'action' => 'delete',
            'user' => 'East718',
            'title' => 'Main Page',
            'type' => 'delete',
            'logid' => 13464685
          }
        ];

isa_ok($log, 'ARRAY', 'Right return type');
isa_ok($log->[0], 'HASH', 'Contains the right data structure');
is(scalar @$log, 2, 'right size');
is_deeply($log, $std, 'The same - all the way down');

