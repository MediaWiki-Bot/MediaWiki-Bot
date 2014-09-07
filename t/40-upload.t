use strict;
use warnings;
use Test::Is qw(extended);
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More 0.88;
use File::Spec;

use MediaWiki::Bot;
my $t = __FILE__;

my $username = $ENV{'PWPUsername'};
my $password = $ENV{'PWPPassword'};
plan $username && $password
    ? (tests => 2)
    : (skip_all => 'upload test requires login with upload permission');

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
    login_data => { username => $username, password => $password },
});

my $tiny_png_filename = File::Spec->catfile(qw/t tiny.png/);
END { unlink $tiny_png_filename if $tiny_png_filename && -e $tiny_png_filename }

subtest 'file upload' => sub {
    plan skip_all => q{Data::Random and GD needed for generating images}
        unless (eval q{use Data::Random qw(rand_image); use GD; 1 });

    open my $png_out, '>:raw', $tiny_png_filename or die "Couldn't open $tiny_png_filename for writing: $!";
    print $png_out rand_image();
    close $png_out or die "Couldn't close $tiny_png_filename: $!";


    {
        my $status = $bot->upload({
            data => do { local $/; open my $in, '<:raw', $tiny_png_filename or die $!; <$in> },
        });
        is $status, undef or diag explain $status;
        is_deeply $bot->{error}, { code => 6, details => q{You must specify a title to upload to.} } or diag explain $bot;
    }
    {
        my $status = $bot->upload({
            title => rand()
        });
        is $status, undef or diag explain $status;
        is_deeply $bot->{error}, { code => 6, details => q{You must provide either file contents or a filename.} } or diag explain $bot;
    }
    {
        my $filename = rand() . '.png';
        my $status = $bot->upload({
            title => $filename,
            file => $tiny_png_filename,
        });
        ok $status and diag "Uploaded to $filename";
        like $status->{upload}->{result}, qr/Success|Warning/, 'Success or Warning' or diag explain $status;
        is $status->{upload}->{filename}, $filename or diag explain $status if $status->{upload}->{result} eq 'Success';
    }
    {
        my $filename = rand() . '.png';
        my $status = $bot->upload({
            title => $filename,
            data => rand_image(),
        });
        ok $status and diag "Uploaded to $filename";
        like $status->{upload}->{result}, qr/Success|Warning/ or diag explain $status;
        is $status->{upload}->{filename}, $filename
            or diag explain $status if $status->{upload}->{result} eq 'Success';
    }
};

subtest 'url' => sub {
    plan skip_all => 'Unsupported by testwiki';
    diag explain $bot->upload_from_url({
        url => 'http://farm9.staticflickr.com/8282/7874109806_756828bf0e_b_d.jpg',
        title => rand() . '.png',
        summary => "Testing $t",
        text => "testing $t",
    });
    diag explain $bot->{error};
};
