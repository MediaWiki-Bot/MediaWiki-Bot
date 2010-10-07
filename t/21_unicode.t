use strict;
use warnings;
use utf8;
use Test::More tests => 8;

# Fix "Wide character in print" warning on failure
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";

use MediaWiki::Bot;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};
my $login_data;
if (defined($username) and defined($password)) {
    $login_data = { username => $username, password => $password };
}

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (21_unicode.t)',
    login_data => $login_data,
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
   $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $string = 'éółŽć';
my $load = $bot->get_text('User:ST47/unicode1');
is($load, $string, 'Is our string the same as what we load?');

my $old = $bot->get_text('User:ST47/unicode2');
my $rand = rand();
my $status = $bot->edit('User:ST47/unicode2', "$rand\n$string\n", 'MediaWiki::Bot tests (21_unicode.t)');
SKIP: {
    if (defined($bot->{error}->{code}) and $bot->{error}->{code} == 3) {
        skip 'You are blocked, cannot use editing tests', 5;
    }
    my $rand2 = rand();
    $bot->edit('User:ST47/unicode3', "$rand2\n$load\n", 'MediaWiki::Bot tests (21_unicode.t) (éółŽć)');
    my @history = $bot->get_history('User:ST47/unicode3', 1);
    is($history[0]->{comment}, 'MediaWiki::Bot tests (21_unicode.t) (éółŽć)', 'Use unicode in edit summary correctly');
    my $rand3 = rand();
    sleep 1;
    $bot->edit('User:ST47/éółŽć', "$rand3\n$load\n", 'MediaWiki::Bot tests (21_unicode.t)');
    sleep 1;
    my $new = $bot->get_text('User:ST47/unicode2');
    isnt($new, $old, 'Successfully saved test string');             # new from 42; old from 29
    is($new, "$rand\n$string", 'Loaded correct data');              # new from 42; compare against save from 31
    $new = $bot->get_text('User:ST47/unicode3');
    is($new, "$rand2\n$string", 'Saved data from load correctly');  # new from 42; compare against save from 37
    $new = $bot->get_text('User:ST47/éółŽć');
    is($new, "$rand3\n$string", 'Saved data from load correctly to page with unicode title');
}

my $unititle = $bot->get_text("User:ST47/testőá");
is($unititle, "testőácontenthere", 'Loaded correct data from page with unicode title');

my $bigtext = <<'end';
more text... éółŽć
 \n
oh, hello there: ãďᶑⅷ


ʬഌ𐎪𐑞ᥤ༒ꀥ

ᐐàáâãäåæ
end
my $text = $bot->get_text('User:Mike.lifeguard/21_unicode.t');
is("$text\n", $bigtext, 'Loaded a wide range of unicode chars correctly');
