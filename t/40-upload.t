use strict;
use warnings;
use Test::More 0.88;

use MediaWiki::Bot;
my $t = __FILE__;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};
if (!defined($username) or !defined($password)) {
    plan skip_all => 'upload test requires login with upload permission';
}
else {
    my $bot = MediaWiki::Bot->new({
        agent   => "MediaWiki::Bot tests ($t)",
        host    => 'test.wikipedia.org',
        login_data => { username => $username, password => $password },
    });
    if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
        $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
    }

    {
        my $status = $bot->upload({
            data => do { local $/; open my $in, '<:raw', 't/tiny.png' or die $!; <$in> },
        });
        is $status, undef or diag "OHNO";
        is_deeply $bot->{error}, { code => 6, details => q{You must specify a title to upload to.} } or diag explain $bot;
    }
    {
        my $status = $bot->upload({
            title => rand
        });
        is $status, undef or diag "OHNO";
        is_deeply $bot->{error}, { code => 6, details => q{You must provide either file contents or a filename.} } or diag explain $bot;
    }
    {
        my $filename = rand . '.png';
        my $status = $bot->upload({
            title => $filename,
            file => 't/tiny.png',
        });
        ok $status and diag "Uploaded to $filename";
        like $status->{upload}->{result}, qr/Success|Warning/ or diag explain $status;
        is $status->{upload}->{filename}, $filename;
    }
    {
        my $filename = rand . '.png';
        my $status = $bot->upload({
            title => $filename,
            data => do { local $/; open my $in, '<:raw', 't/tiny.png' or die $!; <$in> },
        });
        ok $status and diag "Uploaded to $filename";
        like $status->{upload}->{result}, qr/Success|Warning/ or diag explain $status;
        is $status->{upload}->{filename}, $filename;
    }

    done_testing;    
}
