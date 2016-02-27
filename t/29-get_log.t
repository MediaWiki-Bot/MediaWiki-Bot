use strict;
use warnings;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 1;

use MediaWiki::Bot;

my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

my $is = $bot->get_log({
    type    => 'delete',
    user    => 'Mark',
    target  => 'Main Page',
    limit   => 1,
});
my $ought = [
          {
            'ns' => 0,
            'timestamp' => '2007-05-07T17:06:47Z',
            'comment' => '24 revisions restored',
            'pageid' => 11791,
            'action' => 'restore',
            'user' => 'Mark',
            'title' => 'Main Page',
            'type' => 'delete',
            'logid' => 3672,
            'logpage' => 0,
            'params' => {},
          },
          {
            'ns' => 0,
            'timestamp' => '2007-05-07T16:58:39Z',
            'comment' => 'content was: \'This is a test wiki that runs from the current NFS copy of MediaWiki. Changes to the code will generally appear here a few minutes before they appear ...\'',
            'pageid' => 11791,
            'action' => 'delete',
            'user' => 'Mark',
            'title' => 'Main Page',
            'type' => 'delete',
            'logid' => 3671,
            'logpage' => 0,
            'params' => {},
          }
        ];

is_deeply($is, $ought, 'The same - all the way down');
