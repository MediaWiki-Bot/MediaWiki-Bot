# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl MediaWiki::Bot.t'

#########################

use strict;
use warnings;
use Test::More tests => 1;

#########################

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    agent   => 'MediaWiki::Bot tests (28_diff.t)',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $is = $bot->diff({
    revid   => 346575722,
    oldid   => 350492216,
});
$is =~ s/<!-- diff cache key .* -->\n$//; # This cache key will change, so strip it out
my $ought = <<'END-DIFF';
<tr>
  <td colspan="2" class="diff-lineno">Line 4:</td>
  <td colspan="2" class="diff-lineno">Line 4:</td>
</tr>
<tr>
  <td class="diff-marker"> </td>
  <td class="diff-context"><div>Admins are welcome to ask me to import something if an AFD is closed as "Transwiki to Wikibooks" but please ''please'' make sure you actually want it to be transwikied to Wikibooks. We are not a dumping ground for stuff you don't want. Just like Wikipedia has an [[WP:WIW|inclusion policy]], so too does [[b:WB:WIW|Wikibooks]].</div></td>
  <td class="diff-marker"> </td>
  <td class="diff-context"><div>Admins are welcome to ask me to import something if an AFD is closed as "Transwiki to Wikibooks" but please ''please'' make sure you actually want it to be transwikied to Wikibooks. We are not a dumping ground for stuff you don't want. Just like Wikipedia has an [[WP:WIW|inclusion policy]], so too does [[b:WB:WIW|Wikibooks]].</div></td>
</tr>
<tr>
  <td class="diff-marker"> </td>
  <td class="diff-context"><div>----</div></td>
  <td class="diff-marker"> </td>
  <td class="diff-context"><div>----</div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
If I removed your favourite link, I consider it to be spam. If you disagree, revert me. If you'd rather talk about it, please do so on [[m:|Meta]].
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
If I removed your favourite link, I consider it to be spam. If you disagree, revert me. If you'd rather talk about it, please do so on [[m:<span class="diffchange">User talk:Mike.lifeguard</span>|Meta]].
  </div></td>
</tr>
END-DIFF
is($is, $ought, 'Retrieved diff correctly');
