use strict;
use warnings;
use utf8;
use Test::RequiresInternet 'test.wikipedia.org' => 80;
use Test::More tests => 1;

BEGIN {
    unless (eval q{ use Test::Differences; 1 }) { # If Test::Differences isn't available...
        no warnings 'redefine';
        note 'Test::Differences unavailable - use Test::More::is_deeply to approximate';
        *eq_or_diff_text = \&is_deeply; # make Test::Differences::eq_or_diff an alias to Test::More::is_deeply
        *unified_diff = sub { 1 };      # shim
    }
}

# Fix "Wide character in print" warning on failure
my $builder = Test::More->builder;
binmode $builder->output,         ':encoding(UTF-8)';
binmode $builder->failure_output, ':encoding(UTF-8)';
binmode $builder->todo_output,    ':encoding(UTF-8)';

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests (https://metacpan.org/MediaWiki::Bot; $t)",
    host    => 'test.wikipedia.org',
});

my $is = $bot->diff({
    revid   => 92376,
    oldid   => 92373,
});
$is =~ s{<!-- diff cache key [a-z0-9:.:-]+? -->}{}; # This cache key will change, so strip it out

my $ought = do { local $/; <DATA> };
1 while (chomp $is);
1 while (chomp $ought);

unified_diff;
eq_or_diff_text($is, $ought, 'Diff retrieved correctly');

__DATA__
<tr>
  <td colspan="2" class="diff-lineno">Line 24:</td>
  <td colspan="2" class="diff-lineno">Line 24:</td>
</tr>
<tr>
  <td class="diff-marker">&#160;</td>
  <td class="diff-context"><div>;21-get_allusers.t:gets a list of users from [[Special:ListUsers]] and [[Special:ListUsers/sysop]]</div></td>
  <td class="diff-marker">&#160;</td>
  <td class="diff-context"><div>;21-get_allusers.t:gets a list of users from [[Special:ListUsers]] and [[Special:ListUsers/sysop]]</div></td>
</tr>
<tr>
  <td class="diff-marker">&#160;</td>
  <td class="diff-context"><div>;22-get_id.t:gets the pageid for [[Main Page]]</div></td>
  <td class="diff-marker">&#160;</td>
  <td class="diff-context"><div>;22-get_id.t:gets the pageid for [[Main Page]]</div></td>
</tr>
<tr>
  <td class="diff-marker">−</td>
  <td class="diff-deletedline"><div>;23-list_transclusions.t:requires [[Template:Perlwikibot-test]] and for [[Template:Tlx]] to be used</div></td>
  <td colspan="2" class="diff-empty">&#160;</td>
</tr>
