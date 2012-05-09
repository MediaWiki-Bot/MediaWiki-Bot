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
my @history = $bot->get_history($title, 2);

is_deeply(\@history, [
      {
        'timestamp_time' => '00:17:05',
        'revid' => 132956,
        'comment' => qq{Protected "[[User:Mike.lifeguard/06-get history.t]]": history must be static (\x{200e}[edit=sysop] (indefinite) \x{200e}[move=sysop] (indefinite))},
        'timestamp_date' => '2012-05-09',
        'minor' => 1,
        'user' => 'Mike.lifeguard'
      },
      {
        'timestamp_time' => '00:16:54',
        'revid' => 132955,
        'comment' => 'Created page with "."',
        'timestamp_date' => '2012-05-09',
        'minor' => '',
        'user' => 'Mike.lifeguard'
      }
    ],
    'Loaded page history OK') or diag explain \@history;

my $time = $history[0]->{'timestamp_time'};
my $date = $history[0]->{'timestamp_date'};
my ($timestamp, $user) = $bot->recent_edit_to_page($title);

like($timestamp, qr/^\d{4}-\d{1,2}-\d{1,2}T\d\d:\d\d:\d\dZ$/, 'Timestamp formed properly');
is($timestamp, "${date}T${time}Z", 'Timestamp found OK');
is($user, 'Mike.lifeguard', 'User returned!'); # Unreported bug
