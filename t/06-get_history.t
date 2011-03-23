use strict;
use warnings;
use Test::More tests => 4;

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});
my $title = 'User:Mike.lifeguard/06-get_history.t';
my @history = $bot->get_history($title, 1);

is_deeply(\@history, [
          {
            'timestamp_time' => '03:59:45',
            'revid' => 92366,
            'comment' => 'moved [[User:Mike.lifeguard/05-get history.t]] to [[User:Mike.lifeguard/06-get history.t]]',
            'timestamp_date' => '2011-01-07',
            'user' => 'Mike.lifeguard'
          }
        ],                                           'Loaded page history OK');

my $time = $history[0]->{'timestamp_time'};
my $date = $history[0]->{'timestamp_date'};
my ($timestamp, $user) = $bot->recent_edit_to_page($title);

like($timestamp, qr/^\d{4}-\d{1,2}-\d{1,2}T\d\d:\d\d:\d\dZ$/, 'Timestamp formed properly');
is($timestamp, "${date}T${time}Z", 'Timestamp found OK');
is($user, 'Mike.lifeguard', 'User returned!'); # Unreported bug
