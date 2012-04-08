use strict;
use warnings;
use utf8;
use Test::More 0.94 tests => 2;

# Fix "Wide character in print" warning on failure
my $builder = Test::More->builder;
binmode $builder->output,         ':encoding(UTF-8)';
binmode $builder->failure_output, ':encoding(UTF-8)';
binmode $builder->todo_output,    ':encoding(UTF-8)';

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
    $bot->edit({
        page    => "$base/2",
        text    => "$rand\n$string\n",
        summary => $agent
    });

    SKIP: {
        skip 'Cannot use editing tests: ' . $bot->{error}->{details}, 5 if
            defined $bot->{error}->{code} and $bot->{error}->{code} == 3;

        my $rand2 = rand();
        $bot->edit({page => "$base/3", text => "$rand2\n$string\n", summary => "$agent ($string)"});
        my @history = $bot->get_history("$base/3", 1);
        is($history[0]->{comment}, "$agent ($string)", 'Use unicode in an edit summary correctly');

        my $rand3 = rand();
        $bot->edit({page => "$base/$string", text => "$rand3\n$string\n", summary => $agent});
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
