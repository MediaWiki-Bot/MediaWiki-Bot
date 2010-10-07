use strict;
use warnings;
use Test::More tests => 3;

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (03_get_history.t)',
});

my @history = $bot->get_history('User:Shadow1/perlwikipedia/Check', 1);
is($history[0]->{'comment'}, 'Perlwikipedia tests', 'Comment found OK');

my $time = $history[0]->{'timestamp_time'};
my $date = $history[0]->{'timestamp_date'};
my $timestamp = $bot->recent_edit_to_page('User:Shadow1/perlwikipedia/Check');
is($timestamp, "${date}T${time}Z", 'Timestamp found OK');
like($timestamp, qr/^\d{4}-\d{1,2}-\d{1,2}T\d\d:\d\d:\d\dZ$/, 'Timestamp formed properly');
