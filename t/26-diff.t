use strict;
use warnings;
use utf8;
use Test::More tests => 1;
BEGIN {
    if (!eval q{ use Test::Differences; 1 }) { # If Test::Differences isn't available,
        *eq_or_diff = \&is_deeply;             # make Test::Differences::eq_or_diff
    }                                          # an alias to Test::More::is_deeply.
}

# Fix "Wide character in print" warning on failure
my $builder = Test::More->builder;
binmode $builder->output,         ':utf8';
binmode $builder->failure_output, ':utf8';
binmode $builder->todo_output,    ':utf8';

use MediaWiki::Bot;
my $t = __FILE__;

my $bot = MediaWiki::Bot->new({
    agent   => "MediaWiki::Bot tests ($t)",
    host    => 'test.wikipedia.org',
});

if(defined($ENV{'PWPMakeTestSetWikiHost'})) {
    $bot->set_wiki($ENV{'PWPMakeTestSetWikiHost'}, $ENV{'PWPMakeTestSetWikiDir'});
}

my $is = $bot->diff({
    revid   => 92373,
    oldid   => 92361,
});
$is =~ s{<!-- diff cache key [a-z0-9:.]+? -->\n$}{}m; # This cache key will change, so strip it out
my $ought = do { local $/; <DATA> };

eq_or_diff($is, $ought, 'Diff retrieved correctly');

__DATA__
<tr>
  <td colspan="2" class="diff-lineno">Line 2:</td>
  <td colspan="2" class="diff-lineno">Line 2:</td>
</tr>
<tr>
  <td class="diff-marker"> </td>
  <td class="diff-context"></td>
  <td class="diff-marker"> </td>
  <td class="diff-context"></td>
</tr>
<tr>
  <td class="diff-marker"> </td>
  <td class="diff-context"><div>;00-initialize.t:none</div></td>
  <td class="diff-marker"> </td>
  <td class="diff-context"><div>;00-initialize.t:none</div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;01-<span class="diffchange">api_error</span>.t:<span class="diffchange">none</span>
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;01-<span class="diffchange">login</span>.t:<span class="diffchange">logs into [[w:|enwiki]] and [[m:|meta]] using http and https; does [[m:SUL|SUL]] login</span>
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;02-<span class="diffchange">login</span>.t:<span class="diffchange">logs into </span>[[<span class="diffchange">w:|enwiki</span>]] <span class="diffchange">and </span>[[<span class="diffchange">m:|meta</span>]] <span class="diffchange">using http </span>and <span class="diffchange">https; does </span>[[<span class="diffchange">m:SUL|SUL</span>]] <span class="diffchange">login</span>
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;02-<span class="diffchange">get_text</span>.t:<span class="diffchange">fetches </span>[[<span class="diffchange">Main Page</span>]]<span class="diffchange">, </span>[[<span class="diffchange">../02-get_text.t</span>]]<span class="diffchange">, </span>and [[<span class="diffchange">Lestat de Lioncourt</span>]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;03-<span class="diffchange">get_text</span>.t:<span class="diffchange">fetches [[Main Page]], </span>[[../03-<span class="diffchange">get_text</span>.t<span class="diffchange">]], and [[Lestat de Lioncourt</span>]]
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;03-<span class="diffchange">edit</span>.t:<span class="diffchange">edits </span>[[../03-<span class="diffchange">edit</span>.t]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;04-<span class="diffchange">edit</span>.t:edits [[../<span class="diffchange">04</span>-edit.t]]
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;04-<span class="diffchange">revert</span>.t:edits [[../<span class="diffchange">03</span>-edit.t]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;05-<span class="diffchange">revert</span>.t:<span class="diffchange">edits </span>[[../<span class="diffchange">04</span>-<span class="diffchange">edit</span>.t]]
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;05-<span class="diffchange">get_history</span>.t:<span class="diffchange">reads history of </span>[[../<span class="diffchange">05</span>-<span class="diffchange">get_history</span>.t]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;06-<span class="diffchange">get_history</span>.t:reads <span class="diffchange">history of </span>[[../06-<span class="diffchange">get_history</span>.t]]
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;06-<span class="diffchange">unicode</span>.t:reads [[../06-<span class="diffchange">unicode</span>.t<span class="diffchange">/1]], [[../06-unicode.t/2]], [[../06-unicode.t/3]], and [[../06-unicode.t/éółŽć</span>]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;07-<span class="diffchange">unicode</span>.t:reads [[../<span class="diffchange">07</span>-<span class="diffchange">unicode</span>.t<span class="diffchange">/1]], [[../07-unicode.t/2]], [[../07-unicode.t/3]], and [[../07-unicode.t/éółŽć</span>]]
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;07-<span class="diffchange">get_last</span>.t:reads <span class="diffchange">history of </span>[[../<span class="diffchange">05</span>-<span class="diffchange">get history</span>.t]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;08-<span class="diffchange">get_last</span>.t:reads <span class="diffchange">history of </span>[[<span class="diffchange">../06-get history.t</span>]]
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;08-<span class="diffchange">update_rc</span>.t:reads [[<span class="diffchange">Special:RecentChanges</span>]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;09-<span class="diffchange">update_rc</span>.t:reads [[Special:<span class="diffchange">RecentChanges</span>]]
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;09-<span class="diffchange">what_links_here</span>.t:reads [[Special:<span class="diffchange">WhatLinksHere/Main Page]] and [[Special:WhatLinksHere/Project:Sandbox</span>]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;10-<span class="diffchange">what_links_here.t</span>:<span class="diffchange">reads </span>[[<span class="diffchange">Special</span>:<span class="diffchange">WhatLinksHere/Main Page</span>]] and [[<span class="diffchange">Special</span>:<span class="diffchange">WhatLinksHere/Project</span>:<span class="diffchange">Sandbox</span>]]
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;10-<span class="diffchange">get_pages_in_category</span>:<span class="diffchange">uses </span>[[:<span class="diffchange">Category:Category loop]], [[:Category:Really big category</span>]]<span class="diffchange">, </span>and [[:<span class="diffchange">Category</span>:<span class="diffchange">Wikipedia</span>]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;11-<span class="diffchange">get_pages_in_category</span>:uses [[:<span class="diffchange">Category:Category loop]], [[:Category:Really big category]], and [[:Category:Wikipedia</span>]]
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;11-<span class="diffchange">linksearch.t</span>:uses [[<span class="diffchange">Special</span>:<span class="diffchange">LinkSearch/*.example.com</span>]]
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;12-<span class="diffchange">linksearch</span>.t:<span class="diffchange">uses [[Special:LinkSearch/*.example.com]]</span>
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;12-<span class="diffchange">get_namespace_names</span>.t:<span class="diffchange">none</span>
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;13-<span class="diffchange">get_namespace_names</span>.t:none
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;13-<span class="diffchange">get_pages_in_namespace</span>.t:none
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;14-<span class="diffchange">get_pages_in_namespace</span>.t:<span class="diffchange">none</span>
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;14-<span class="diffchange">count_contributions</span>.t:<span class="diffchange">counts [[User:Mike.lifeguard|my]] edits and those of a nonexistent user</span>
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>
;15-<span class="diffchange">count_contributions</span>.t:<span class="diffchange">counts </span>[[User:Mike.lifeguard|my]] <span class="diffchange">edits and those of a nonexistent user</span>
  </div></td>
  <td class="diff-marker">+</td>
  <td class="diff-addedline"><div>
;15-<span class="diffchange">last_active</span>.t:<span class="diffchange">Checks </span>[[User:Mike.lifeguard|my]] <span class="diffchange">last edit timestamp</span>
  </div></td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>;16-last_active.t:checks [[User:Mike.lifeguard|my]] last edit timestamp</div></td>
  <td colspan="2">&nbsp;</td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>;17-was_blocked.t:checks if [[User:Bad Username]] and [[User:Mike.lifeguard|I]] have ever been blocked</div></td>
  <td colspan="2">&nbsp;</td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>;18-is_blocked.t:checks if...</div></td>
  <td colspan="2">&nbsp;</td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>;19-get_pages.t:relies on the following pages existing: [[Main Page]], [[Wikipedia:What Test Wiki is not]], [[WP:SAND]]; relies on [[This page had better not exist..........]] ''not'' existing</div></td>
  <td colspan="2">&nbsp;</td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>;20-assert_edit.t:requires, but does not edit, [[../20-assert_edit.t]]</div></td>
  <td colspan="2">&nbsp;</td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>;21-get_allusers.t:gets a list of users from [[Special:ListUsers]] and [[Special:ListUsers/sysop]]</div></td>
  <td colspan="2">&nbsp;</td>
</tr>
<tr>
  <td class="diff-marker">-</td>
  <td class="diff-deletedline"><div>;22-get_id.t:gets the pageid for [[Main Page]]</div></td>
  <td colspan="2">&nbsp;</td>
</tr>
