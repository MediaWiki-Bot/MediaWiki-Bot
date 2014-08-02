use strict;
use warnings;
use Test::More tests => 1;

use MediaWiki::Bot qw(:constants);
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $rand = rand();
my $status = $bot->edit({
    page    => 'User:Mike.lifeguard/19-assert_edit.t',
    text    => $rand,
    assert  => 'bot', # was 'false', but AssertEdit isn't a standard extension
});

SKIP: {
    skip q{Unexpected error: } . $bot->{error}->{details}, 1
        if defined $bot->{error}->{code}
        and $bot->{error}->{code} == ERR_API
        and $bot->{error}->{details} !~ m{^assert\w+failed:};

    is $status->{edit}->{result} => undef, 'Intentionally bad assertion'
        or diag explain { edit => $status, error => $bot->{error} };
}
