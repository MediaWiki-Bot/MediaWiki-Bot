#!/usr/bin/perl -w

use Term::ReadKey;
use Perlwikipedia;

print "\nPlease enter the username of the account you are logging in: ";

my $username=<STDIN>;

chomp $username;

print "\nPlease enter the password of the account: ";

ReadMode('noecho');

my $password=ReadLine(0);

chomp $password;

ReadMode('normal');

my $perlwikipedia=Perlwikipedia->new($username);

# Turn debugging on, to see what the bot is doing
$perlwikipedia->{debug} = 1;

print "\nPlease enter the host of the wiki, such as \'en.wikipedia.org\': ";

my $host=<STDIN>;

chomp $host;

print "\nPlease enter the path to index.php, such as \'w\' on Wikipedia: ";

my $path=<STDIN>;

chomp $path;

$perlwikipedia->set_wiki($host, $path);

print "\nTrying to log in...";

my $login_status=$perlwikipedia->login($username, $password);

print "\nLogin returned \'$login_status\'\n";
