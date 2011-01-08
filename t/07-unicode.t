use strict;
use warnings;
use utf8;
use Test::More 0.94 tests => 2;

# Fix "Wide character in print" warning on failure
my $builder = Test::More->builder;
binmode $builder->output,         ':utf8';
binmode $builder->failure_output, ':utf8';
binmode $builder->todo_output,    ':utf8';

use MediaWiki::Bot;
my $t = __FILE__;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};
my $login_data;
if (defined($username) and defined($password)) {
    $login_data = { username => $username, password => $password };
}

my $agent = "MediaWiki::Bot tests ($t)";
my $bot   = MediaWiki::Bot->new({
    agent      => $agent,
    login_data => $login_data,
    host       => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
   $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $base   = 'User:Mike.lifeguard/07-unicode.t';
my $string = 'éółŽć';

subtest 'read' => sub {
    plan tests => 1;

    my $load   = $bot->get_text("$base/1");

    is($load, $string, 'Is our string the same as what we load?');
};

subtest 'write' => sub {
    plan tests => 5;

    my $old  = $bot->get_text("$base/2");
    my $rand = rand();
    $bot->edit("$base/2", "$rand\n$string\n", $agent);
    SKIP: {
        if (defined $bot->{error}->{code} and $bot->{error}->{code} == 3) {
            skip 'You are blocked, cannot use editing tests', 5;
        }

        my $rand2 = rand();
        $bot->edit("$base/3", "$rand2\n$string\n", "$agent ($string)");
        my @history = $bot->get_history("$base/3", 1);
        is($history[0]->{comment}, "$agent ($string)", 'Use unicode in an edit summary correctly');

        my $rand3 = rand();
        $bot->edit("$base/$string", "$rand3\n$string\n", $agent);
        {
            my $new = $bot->get_text("$base/2");
            isnt($new, $old,                  'Successfully saved test string');
            is(  $new, "$rand\n$string",      'Successfully loaded test string');
        }
        {
            my $new = $bot->get_text("$base/3");
            is($new, "$rand2\n$string",       'Saved data from load correctly');
        }
        {
            my $new = $bot->get_text("$base/$string");
            is($new, "$rand3\n$string",       'Saved data from load correctly to page with unicode title');
        }
    } # end SKIP
};
