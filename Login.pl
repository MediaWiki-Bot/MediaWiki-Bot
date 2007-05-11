use Term::ReadKey;
use Perlwikipedia;

my $perlwikipedia=Perlwikipedia->new;

print "Please enter the host of the wiki, such as \'en.wikipedia.org\': ";

my $host=<STDIN>;

chomp $host;

print "\nPlease enter the path to index.php, such as \'w\' on Wikipedia: ";

my $path=<STDIN>;

chomp $path;

$perlwikipedia->set_wiki($host,$path);

print "\nPlease enter the username of the account you are logging in: ";

my $username=<STDIN>;

chomp $username;

print "\nPlease enter the password of the account: ";

ReadMode('noecho');

my $password=ReadLine(0);

chomp $password;

ReadMode('normal');

print "\nTrying to log in...";

my $login_status=$perlwikipedia->login($username,$password);

print "\nLogin returned \'$login_status\'\n";
