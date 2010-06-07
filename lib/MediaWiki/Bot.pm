package MediaWiki::Bot;

use strict;
use warnings;
use WWW::Mechanize;
use HTML::Entities;
use URI::Escape;
use XML::Simple;
use Carp;
use URI::Escape qw(uri_escape_utf8);
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
use MediaWiki::API;

use Module::Pluggable search_path => [qw(MediaWiki::Bot::Plugin)], 'require' => 1;
foreach my $plugin (__PACKAGE__->plugins) {
    print "Found plugin $plugin\n";
    $plugin->import();
}

our $VERSION = '3.1.0';

=head1 NAME

MediaWiki::Bot - a MediaWiki bot framework written in Perl

=head1 SYNOPSIS

use MediaWiki::Bot;

my $bot = MediaWiki::Bot->new({
    useragent   => 'MediaWiki::Bot 3.0.0 (User:Mike.lifeguard)',
    assert      => 'bot',
    protocol    => 'https',
    host        => 'secure.wikimedia.org',
    path        => 'wikipedia/meta/w',
    login_data  => { username => "Mike's bot account", password => "password" },
});

my $revid = $bot->get_last("User:Mike.lifeguard/sandbox", "Mike.lifeguard");
print "Reverting to $revid\n" if defined($revid);
$bot->revert('User:Mike.lifeguard', $revid, 'rvv');

=head1 DESCRIPTION

MediaWiki::Bot is a framework that can be used to write Wikipedia bots.

Many of the methods use the MediaWiki API (L<http://en.wikipedia.org/w/api.php>).

=head1 AUTHOR

The MediaWiki::Bot team (Alex Rowe, Jmax, Oleg Alexandrov, Dan Collins, Mike.lifeguard) and others.

=head1 COPYING

Copyright (C) 2006, 2007 by the MediaWiki::Bot team

This library is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 METHODS

=head2 new($options_hashref)

Calling MediaWiki::Bot->new() will create a new MediaWiki::Bot object.

=over 4

=item *
agent sets a custom useragent

=item *
assert sets a parameter for the AssertEdit extension (commonly 'bot'). Refer to L<http://mediawiki.org/wiki/Extension:AssertEdit>.

=item *
operator allows the bot to send you a message when it fails an assert, and will be integrated into the default useragent (which may not be used if you set agent yourself). The message will tell you that $useragent is logged out, so use a descriptive one if you set it.

=item *
maxlag allows you to set the maxlag parameter (default is the recommended 5s). Please refer to the MediaWiki documentation prior to changing this from the default.

=item *
protocol allows you to specify 'http' or 'https' (default is 'http'). This is commonly used with the domain and path settings below.

=item *
host sets the domain name of the wiki to connect to.

=item *
path sets the path to api.php (with no trailing slash).

=item *
login_data is a hashref of data to pass to login(). See that section for a description.

=back

For example:

    my $bot = MediaWiki::Bot->new({
        useragent   => 'MediaWiki::Bot 3.0.0 (User:Mike.lifeguard)',
        assert      => 'bot',
        protocol    => 'https',
        host        => 'secure.wikimedia.org',
        path        => 'wikipedia/meta/w',
        login_data  => { username => "Mike's bot account", password => "password" },
    });

For backward compatibility, you can specify up to three parameters:

    my $bot = MediaWiki::Bot->new('MediaWiki::Bot 2.3.1 (User:Mike.lifeguard)', $assert, $operator);

This deprecated form will never do auto-login or autoconfiguration.

=cut

sub new {
    my $package = shift;
    my $agent;
    my $assert;
    my $operator;
    my $maxlag;
    my $protocol;
    my $host;
    my $path;
    my $login_data;
    if (ref $_[0] eq 'HASH') {
        $agent      = $_[0]->{'agent'};
        $assert     = $_[0]->{'assert'};
        $operator   = $_[0]->{'operator'};
        $maxlag     = $_[0]->{'maxlag'};
        $protocol   = $_[0]->{'protocol'};
        $host       = $_[0]->{'host'};
        $path       = $_[0]->{'path'};
        $login_data = $_[0]->{'login_data'};
    }
    else {
        $agent      = shift;
        $assert     = shift;
        $operator   = shift;
        $maxlag     = shift;
        $protocol   = shift;
        $host       = shift;
        $path       = shift;
    }

    $assert   =~ s/[&?]assert=// if $assert; # Strip out param part, leaving just the value
    $operator =~ s/^User://i     if $operator;

    # Set defaults
    unless ($agent) {
        $agent  = "MediaWiki::Bot $VERSION";
        $agent .= " (User:$operator)" if $operator;
    }

    my $self = bless({}, $package);
    $self->{mech} = WWW::Mechanize->new(
            cookie_jar => {},
            onerror => \&Carp::carp,
            stack_depth => 1
    );
    $self->{mech}->agent($agent);
    $self->{protocol}                 = $protocol || 'http';
    $self->{host}                     = $host || 'en.wikipedia.org';
    $self->{path}                     = $path || 'w';
    $self->{debug}                    = 0;
    $self->{errstr}                   = '';
    $self->{assert}                   = $assert;
    $self->{operator}                 = $operator;
    $self->{api}                      = MediaWiki::API->new();
    $self->{api}->{ua}->agent($agent);

    # Set wiki if these are set
    $self->set_wiki({
        protocol => $self->{protocol},
        host     => $self->{host},
        path     => $self->{path},
    });

    # Log-in, and maybe autoconfigure
    if ($login_data) {
        $self->login($login_data) or carp "Couldn't log in with supplied settings";
    }

    $self->{api}->{config}->{max_lag}         = $maxlag || 5;
    $self->{api}->{config}->{max_lag_delay}   = 1;
    $self->{api}->{config}->{retries}         = 5;
    $self->{api}->{config}->{max_lag_retries} = -1;
    $self->{api}->{config}->{retry_delay}     = 30;

    return $self;
}

=head2 set_wiki($host[,$path[,$protocol]])

Set what wiki to use. $host is the domain name; $path is the path before api.php (usually 'w'); $protocol is either 'http' or 'https'. For example:

    $bot->set_wiki('de.wikipedia.org', 'w');

will tell it to use http://de.wikipedia.org/w/index.php. The default settings are 'en.wikipedia.org' with a path of 'w'. You can also pass a hashref using keys with the same names as these parameters. To use the secure server:

    $bot->set_wiki(
        protocol    => 'https',
        host        => 'secure.wikimedia.org',
        path        => 'wikipedia/meta/w',
    );

For backward compatibility, you can specify up to two parameters in this deprecated form:

    $bot->set_wiki($host, $path);

=cut

sub set_wiki {
    my $self = shift;
    my $host;
    my $path;
    my $protocol;

    if (ref $_[0] eq 'HASH') {
        $host     = $_[0]->{'host'};
        $path     = $_[0]->{'path'};
        $protocol = $_[0]->{'protocol'};
    }
    else {
        $host = shift;
        $path = shift;
    }

    # Set defaults
    $protocol = 'http' unless $protocol;
    $host = 'en.wikipedia.org' unless $host;
    $path = 'w' unless $path;

    # Clean up the parts we will build a URL with
    $protocol   =~ s,://$,,;
    if ($host =~ m,^(http|https)(://)?, and !$protocol) {
        $protocol = $1;
    }
    $host =~ s,^https?://,,;
    $host =~ s,/$,,;
    $path =~ s,/$,,;

    if ($protocol eq 'https') {
        use Crypt::SSLeay;
    }
    elsif ($protocol eq 'http') {
        #un-use Crypt::SSLeay;
    }
    else {
        $protocol = 'http';
    }

    # Invalidate wiki-specific cached data
    if (($self->{'host'} ne $host)
        or ($self->{'path'} ne $path)
        or ($self->{'protocol'} ne $protocol)
    ) {
        delete $self->{'ns_data'} if $self->{'ns_data'};
    }

    $self->{protocol} = $protocol;
    $self->{host} = $host;
    $self->{path} = $path;

    $self->{api}->{config}->{api_url} = "$protocol://$host/$path/api.php";
    print "Wiki set to $protocol://$host/$path/api.php\n" if $self->{debug};

    return 1;
}

=head2 login($login_hashref)

Logs the use $username in, optionally using $password. First, an attempt will be made to use cookies to log in. If this fails, an attempt will be made to use the password provided to log in, if any. If the login was successful, returns true; false otherwise.

    $bot->login(
        {
            username => $username,
            password => $password,
        }
    ) or die "Login failed";

Once logged in, attempt to do some simple auto-configuration. At present, this consists of:

=over 4

=item *
Warning if the account doesn't have the bot flag, and isn't a sysop account.

=item *
Setting the use of apihighlimits if the account has that userright.

=item *
Setting an appropriate default assert.

=back

You can skip this autoconfiguration by passing C<autoconfig =Z<>> 0>

For backward compatibility, you can call this as

    $bot->login($username, $password);

This deprecated form will never do autoconfiguration.

=cut

sub login {
    my $self = shift;
    my $username;
    my $password;
    my $autoconfig;
    if (ref $_[0] eq 'HASH') {
        $username = $_[0]->{'username'};
        $password = $_[0]->{'password'};
        $autoconfig = defined($_[0]->{'autoconfig'}) ? $_[0]->{'autoconfig'} : 1;
    }
    else {
        $username = shift;
        $password = shift;
        $autoconfig = 0;
    }

    # This seems to not do what we want. Cookies are loaded, but a
    # subsequent userinfo query shows the bot is not logged in.
    my $cookies  = ".mediawiki-bot-$username-cookies";
    $self->{mech}->{cookie_jar}->load($cookies);
    $self->{mech}->{cookie_jar}->{ignore_discard}=1;
    $self->{api}->{ua}->{cookie_jar}->load($cookies);

    $self->{username} = $username; # Remember who we are
    my $logged_in = $self->_is_loggedin();
    if ($logged_in) {
        $self->_do_autoconfig() if $autoconfig;
        carp "Logged in successfully with cookies" if $self->{debug};
        return 1; # If we're already logged in, nothing more is needed
    }

    unless ($password) {
        carp "No login cookies available, and no password to continue with authentication" if $self->{debug};
        return 0;
    }

    my $res = $self->{api}->login({
        lgname     => $username,
        lgpassword => $password
    }) or return $self->_handle_api_error();

    $self->{mech}->{cookie_jar}->extract_cookies($self->{api}->{response});
    $self->{mech}->{cookie_jar}->save($cookies);

#use Data::Dumper; print Dumper $self->{mech}->{cookie_jar};
    $logged_in = $self->_is_loggedin();
    $self->_do_autoconfig() if ($autoconfig and $logged_in);
    carp "Logged in successfully with password" if ($logged_in and $self->{debug});
    return $logged_in;
}

=head2 set_highlimits($flag)

Tells MediaWiki::Bot to start/stop using APIHighLimits for certain queries.

    $bot->set_highlimits(1);

=cut

sub set_highlimits {
    my $self       = shift;
    my $highlimits = shift || 1;

    $self->{highlimits} = $highlimits;
    return 1;
}

=head2 logout()

The logout procedure deletes the login tokens and other browser cookies.

    $bot->logout();

=cut

sub logout {
    my $self     = shift;

    my $hash = {
        action => 'logout',
    };
    $self->{api}->api($hash);
    return 1;
}

=head2 edit($options_hashref)

Puts text on a page. If provided, use a specified edit summary, mark the edit as minor, as a non-bot edit, or add an assertion. Set section to edit a single section instead of the whole page. An MD5 hash is sent to guard against data corruption while in transit.

    my $text = $bot->get_text('My page');
    $text .= "\n\n* More text\n";
    $bot->edit({
        page    => 'My page',
        text    => $text,
        summary => 'Adding new content',
        section => 'new',
    });

You can also call this using the deprecated form:

    $bot->edit($page, $text, $summary, $is_minor, $assert, $markasbot);

=cut

sub edit {
    my $self = shift;
    my $page;
    my $text;
    my $summary;
    my $is_minor;
    my $assert;
    my $markasbot;
    my $section;

    if (ref $_[0] eq 'HASH') {
        $page       = $_[0]->{'page'};
        $text       = $_[0]->{'text'};
        $summary    = $_[0]->{'summary'};
        $is_minor   = $_[0]->{'is_minor'};
        $assert     = $_[0]->{'assert'};
        $markasbot  = $_[0]->{'markasbot'};
        $section    = $_[0]->{'section'};
    }
    else {
        $page       = shift;
        $text       = shift;
        $summary    = shift;
        $is_minor   = shift;
        $assert     = shift;
        $markasbot  = shift;
        $section    = shift;
    }
    # Set defaults
    $summary = 'BOT: Changing page text' unless $summary;
    if ($assert) {
        $assert =~ s/^[&?]assert=//;
    }
    else {
        $assert = $self->{'assert'};
    }
    $is_minor  = 1 unless defined($is_minor);
    $markasbot = 1 unless defined($markasbot);

    my ($edittoken, $lastedit, $tokentime) = $self->_get_edittoken($page);
    my $hash = {
        action          => 'edit',
        title           => $page,
        token           => $edittoken,
        text            => $text,
        md5             => md5_hex(encode_utf8($text)), # Guard against data corruption
                                                        # Pass only bytes to md5_hex()
        summary         => $summary,
        basetimestamp   => $lastedit,  # Guard against edit conflicts
        starttimestamp  => $tokentime, # Guard against the page being deleted/moved
        bot             => $markasbot,
        assert          => $assert,
        minor           => $is_minor,
    };
    $hash->{'section'} = $section if defined($section);

    my $res = $self->{api}->api($hash); # Check if MediaWiki::API::edit() is good enough
    if (!$res) {
        return $self->_handle_api_error();
    }
    if ($res->{edit}->{result} && $res->{edit}->{result} eq 'Failure') {
        if ($self->{mech}->{agent}) {
            carp 'Assertion failed as ' . $self->{mech}->{agent};
            if ($self->{operator}) {
                my $optalk = $self->get_text('User talk:' . $self->{operator});
                unless (!defined($optalk)) {
                    print "Sending warning!\n";
                    $self->edit(
                        page        => "User talk:$self->{operator}",
                        text        => $optalk
                                        . "\n\n==Error with "
                                        . $self->{mech}->{agent} . "==\n"
                                        . $self->{mech}->{agent}
                                        . ' needs to be logged in! ~~~~',
                        summary     => 'bot issue',
                        is_minor    => 0,
                        assert      => ''
                    );
                }
            }
            return undef;
        }
        else {
            carp 'Assertion failed';
        }
    }
    return $res;
}

=head2 move($from, $to, $reason, $options_hashref)

This moves a page from $from to $to. If you wish to specify more options (like whether to suppress creation of a redirect), use $options_hashref.

=over 4

=item *
movetalk specifies whether to attempt to the talk page.

=item *
noredirect specifies whether to suppress creation of a redirect.

=back

    my @pages = ("Humor", "Rumor");
    foreach my $page (@pages) {
        my $to = $page;
        $to =~ s/or$/our/;
        $bot->move($page, $to, "silly 'merricans");
    }

=cut

sub move {
    my $self   = shift;
    my $from   = shift;
    my $to     = shift;
    my $reason = shift;
    my $opts   = shift;

    my $hash = {
        action  => 'move',
        from    => $from,
        to      => $to,
        reason  => $reason,
    };
    $hash->{'movetalk'}   = $opts->{'movetalk'}   if defined($opts->{'movetalk'});
    $hash->{'noredirect'} = $opts->{'noredirect'} if defined($opts->{'noredirect'});

    my $res = $self->{api}->edit($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    return $res; # should we return something more useful?
}

=head2 get_history($pagename[,$limit])

Returns an array containing the history of the specified page, with $limit number of revisions. The array structure contains 'revid', 'user', 'comment', 'timestamp_date', and 'timestamp_time'.

=cut

sub get_history {
    my $self      = shift;
    my $pagename  = shift;
    my $limit     = shift || 5;
    my $rvstartid = shift || '';
    my $direction = shift;

    my @return;
    my @revisions;

    if ($limit > 50) {
        $self->{errstr} = "Error requesting history for $pagename: Limit may not be set to values above 50";
        carp $self->{errstr} if $self->{debug};
        return 1;
    }

    my $hash = {
        action  => 'query',
        prop    => 'revisions',
        titles  => $pagename,
        rvprop  => 'ids|timestamp|user|comment',
        rvlimit => $limit
    };

    $hash->{rvstartid} = $rvstartid if ($rvstartid);
    $hash->{direction} = $direction if ($direction);

    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    my ($id) = keys %{ $res->{query}->{pages} };
    my $array = $res->{query}->{pages}->{$id}->{revisions};

    foreach my $hash (@{$array}) {
        my $revid = $hash->{revid};
        my $user  = $hash->{user};
        my ($timestamp_date, $timestamp_time) = split(/T/, $hash->{timestamp});
        $timestamp_time =~ s/Z$//;
        my $comment =$hash->{comment};
        push(
            @return,
            {
                revid          => $revid,
                user           => $user,
                timestamp_date => $timestamp_date,
                timestamp_time => $timestamp_time,
                comment        => $comment,
            }
        );
    }
    return @return;
}

=head2 get_text($pagename,[$revid,$section_number])

Returns an the wikitext of the specified page. If $revid is defined, it will return the text of that revision; if $section_number is defined, it will return the text of that section. A blank page will return wikitext of "" (which evaluates to false in Perl, but is defined); a nonexistent page will return undef (which also evaluates to false in Perl, but is obviously undefined). You can distinguish between blank and nonexistent by using defined():

    my $wikitext = $bot->get_text('Page title');
    print "Wikitext: $wikitext\n" if defined $wikitext;

=cut

sub get_text {
    my $self       = shift;
    my $pagename   = shift;
    my $revid      = shift;
    my $section    = shift;

    my $hash = {
        action => 'query',
        titles => $pagename,
        prop   => 'revisions',
        rvprop => 'content',
    };
    $hash->{rvstartid} = $revid   if ($revid);
    $hash->{rvsection} = $section if ($section);

    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        my ($id, $data) = %{ $res->{query}->{pages} };
        if ($id == -1) { # Page doesn't exist
            return undef;
        }
        else { # Page exists
            my $wikitext = $data->{revisions}[0]->{'*'};
            return $wikitext;
        }
    }
}

=head2 get_id($pagename)

Returns the id of the specified page. Returns undef if page does not exist.

    my $pageid = $bot->get_id("Main Page");
    croak "Page doesn't exist\n" if !defined($pageid);

=cut

sub get_id {
    my $self     = shift;
    my $pagename = shift;

    my $hash = {
        action => 'query',
        titles => $pagename,
    };

    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    my ($id, $data) = %{ $res->{query}->{pages} };
    if ($id == -1) {
        return undef;
    }
    else {
        return $id;
    }
}

=head2 get_pages(\@pages)

Returns the text of the specified pages in a hashref. Content of undef means page does not exist. Also handles redirects or article names that use namespace aliases.

    my @pages = ('Page 1', 'Page 2', 'Page 3');
    my $thing = $bot->get_pages(\@pages);
    foreach my $page (keys %$thing) {
        my $text = $thing->{$page};
        print "$text\n" if defined($text);
    }

=cut

sub get_pages {
    my $self  = shift;
    my @pages = @_;
    my %return;

    my $hash = {
        action => 'query',
        titles => join('|', @pages),
        prop   => 'revisions',
        rvprop => 'content',
    };

    my $diff;    # Used to track problematic article names
    map { $diff->{$_} = 1; } @pages;

    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }

    foreach my $id (keys %{ $res->{query}->{pages} }) {
        my $page = $res->{'query'}->{'pages'}->{$id};
        if ($diff->{ $page->{'title'} }) {
            $diff->{ $page->{'title'} }++;
        }
        else {
            next;
        }

        if (defined($page->{'missing'})) {
            $return{ $page->{'title'} } = undef;
            next;
        }
        if (defined($page->{'revisions'})) {
            my $revisions = @{ $page->{'revisions'} }[0]->{'*'};
            if (!defined $revisions) {
                $return{ $page->{'title'} } = $revisions;
            }
            elsif (length($revisions) < 150 && $revisions =~ m/\#REDIRECT\s\[\[([^\[\]]+)\]\]/) { # FRAGILE!
                my $redirect_to = $1;
                $return{ $page->{'title'} } = $self->get_text($redirect_to);
            }
            else {
                $return{ $page->{'title'} } = $revisions;
            }
        }
    }

    # Based on api.php?action=query&meta=siteinfo&siprop=namespaces|namespacealiases
    # Should be done on an as-needed basis! This is only correct for enwiki (and
    # it is probably incomplete anyways, or will be eventually).
    my $expand = {
        'WP'         => 'Wikipedia',
        'WT'         => 'Wikipedia talk',
        'Image'      => 'File',
        'Image talk' => 'File talk',
    };
    # Only for those article names that remained after the first part
    # If we're here we are dealing most likely with a WP:CSD type of article name
    for my $title (keys %$diff) {
        if ($diff->{$title} == 1) {
            my @pieces = split(/:/, $title);
            if (@pieces > 1) {
                $pieces[0] = ($expand->{ $pieces[0] } || $pieces[0]);
                my $v = $self->get_text(join ':', @pieces);
                print "Detected article name that needed expanding $title\n" if $self->{debug};

                $return{$title} = $v;
                if ($v =~ m/\#REDIRECT\s\[\[([^\[\]]+)\]\]/) {
                    $v = $self->get_text($1);
                    $return{$title} = $v;
                }
            }
        }
    }
    return \%return;
}

=head2 revert($pagename, $revid[,$summary])

Reverts the specified page to $revid, with an edit summary of $summary. A default edit summary will be used if $summary is omitted.

    my $revid = $bot->get_last("User:Mike.lifeguard/sandbox", "Mike.lifeguard");
    print "Reverting to $revid\n" if defined($revid);
    $bot->revert('User:Mike.lifeguard', $revid, 'rvv');


=cut

sub revert {
    my $self     = shift;
    my $pagename = shift;
    my $revid    = shift;
    my $summary  = shift || "Reverting to old revision $revid";

    my $text = $self->get_text($pagename, $revid);
    my $res  = $self->edit($pagename, $text, $summary);
    return $res;
}

=head2 undo($pagename, $revid[,$summary[,$after]])

Reverts the specified $revid, with an edit summary of $summary, using the undo function. To undo all revisions from $revid up to but not including this one, set $after to another revid. If not set, just undo the one revision ($revid).

=cut

sub undo {
    my $self    = shift;
    my $page    = shift;
    my $revid   = shift;
    my $summary = shift || "Reverting revision #$revid";
    my $after   = shift;
    $summary = "Reverting edits between #$revid & #$after" if defined($after); # Is that clear? Correct?

    my ($edittoken, $basetimestamp, $starttimestamp) = $self->_get_edittoken($page);
    my $hash = {
        action          => 'edit',
        title           => $page,
        undo            => $revid,
        undoafter       => $after,
        summary         => $summary,
        token           => $edittoken,
        starttimestamp  => $starttimestamp,
        basetimestamp   => $basetimestamp,
    };

    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        return $res;
    }
}

=head2 get_last($page, $user)

Returns the revid of the last revision to $page not made by $user. undef is returned if no result was found, as would be the case if the page is deleted.

    my $revid = $bot->get_last("User:Mike.lifeguard/sandbox", "Mike.lifeguard");
    print "Reverting to $revid\n" if defined($revid);
    $bot->revert('User:Mike.lifeguard', $revid, 'rvv');

=cut

sub get_last {
    my $self = shift;
    my $page = shift;
    my $user = shift;

    my $revertto = 0;

    my $res = $self->{api}->api(
        {
            action        => 'query',
            titles        => $page,
            prop          => 'revisions',
            rvlimit       => 1,
            rvprop        => 'ids|user',
            rvexcludeuser => $user,
        }
    );
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        my ($id, $data) = %{ $res->{query}->{pages} };
        my $revid = $data->{'revisions'}[0]->{'revid'};
        return $revid;
    }
}

=head2 update_rc([$limit])

Returns an array containing the Recent Changes to the wiki Main namespace. The array structure contains 'pagename', 'revid', 'oldid', 'timestamp_date', and 'timestamp_time'.

=cut

sub update_rc {
    my $self = shift;
    my $limit = shift || 5;
    my @rc_table;

    my $res = $self->{api}->list(
        {
            action      => 'query',
            list        => 'recentchanges',
            rcnamespace => 0,
            rclimit     => $limit
        },
        { max => $limit }
    );
    foreach my $hash (@{$res}) {
        my ($timestamp_date, $timestamp_time) = split(/T/, $hash->{timestamp});
        $timestamp_time =~ s/Z$//;
        push(
            @rc_table,
            {
                pagename       => $hash->{title},
                revid          => $hash->{revid},
                oldid          => $hash->{old_revid},
                timestamp_date => $timestamp_date,
                timestamp_time => $timestamp_time,
            }
        );
    }
    return @rc_table;
}

=head2 what_links_here($page[,$filter[,$ns[,$options]]])

Returns an array containing a list of all pages linking to $page. The array structure contains 'title' and 'redirect' is defined if the title is a redirect. $filter can be one of: all (default), redirects (list only redirects), nonredirects (list only non-redirects). $ns is a namespace number to search (pass an arrayref to search in multiple namespaces). $options is a hashref as described by MediaWiki::API: Set max to limit the number of queries performed. Set hook to a subroutine reference to use a callback hook for incremental processing. Refer to the section on linksearch() for examples.

A typical query:

    my @links = $bot->what_links_here("Meta:Sandbox", undef, 1, {hook=>\&mysub});
    sub mysub{
        my ($res) = @_;
        foreach my $hash (@$res) {
            my $title = $hash->{'title'};
            my $is_redir = $hash->{'redirect'};
            print "Redirect: $title\n" if $is_redir;
            print "Page: $title\n" unless $is_redir;
        }
    }

Transclusions are no longer handled by what_links_here() - use list_transcludes() instead.

=cut

sub what_links_here {
    my $self    = shift;
    my $page    = shift;
    my $filter  = shift;
    my $ns      = shift;
    my $options = shift;

    $ns = join('|', @$ns) if (ref $ns eq 'ARRAY'); # Allow array of namespaces
    if (defined($filter) and $filter =~ m/(all|redirects|nonredirects)/) { # Verify $filter
        $filter = $1;
    }

    my @links;

    # http://en.wikipedia.org/w/api.php?action=query&list=backlinks&bltitle=template:tlx
    my $hash = {
        action      => 'query',
        list        => 'backlinks',
        bltitle     => $page,
        blnamespace => $ns,
    };
    $hash->{'blfilterredir'} = $filter if $filter;

    my $res = $self->{api}->list($hash, $options);
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        return undef if (! ref $res); # When using a callback hook, this won't be a reference
        foreach my $hashref (@$res) {
            my $title = $hashref->{'title'};
            my $redirect = defined($hashref->{'redirect'});
            push @links, { title => $title, redirect => $redirect };
        }
    }

    return @links;
}

=head2 list_transclusions($page[,$filter[,$ns[,$options]]])

Returns an array containing a list of all pages transcluding $page. The array structure contains 'title' and 'redirect' is defined if the title is a redirect. $filter can be one of: all (default), redirects (list only redirects), nonredirects (list only non-redirects). $ns is a namespace number to search (pass an arrayref to search in multiple namespaces). $options is a hashref as described by MediaWiki::API: Set max to limit the number of queries performed. Set hook to a subroutine reference to use a callback hook for incremental processing. Refer to the section on linksearch() or what_links_here() for examples.

A typical query:

    $bot->list_transclusions("Template:Tlx", undef, 4, {hook => \&mysub});
    sub mysub{
        my ($res) = @_;
        foreach my $hash (@$res) {
            my $title = $hash->{'title'};
            my $is_redir = $hash->{'redirect'};
            print "Redirect: $title\n" if $is_redir;
            print "Page: $title\n" unless $is_redir;
        }
    }

=cut

sub list_transclusions {
    my $self    = shift;
    my $page    = shift;
    my $filter  = shift;
    my $ns      = shift;
    my $options = shift;

    $ns = join('|', @$ns) if (ref $ns eq 'ARRAY');
    if (defined($filter) and $filter =~ m/(all|redirects|nonredirects)/) { # Verify $filter
        $filter = $1;
    }

    my @links;

    # http://en.wikipedia.org/w/api.php?action=query&list=embeddedin&eititle=Template:Stub
    my $hash = {
        action      => 'query',
        list        => 'embeddedin',
        eititle     => $page,
        einamespace => $ns,
    };
    $hash->{'eifilterredir'} = $filter if $filter;

    my $res = $self->{api}->list($hash, $options);
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        return undef if (! ref $res); # When using a callback hook, this won't be a reference
        foreach my $hashref (@$res) {
            my $title = $hashref->{'title'};
            my $redirect = defined($hashref->{'redirect'});
            push @links, { title => $title, redirect => $redirect };
        }
    }

    return @links;
}

=head2 get_pages_in_category($category_name)

Returns an array containing the names of all pages in the specified category (include Category: prefix). Does not recurse into sub-categories.

    my @pages = $bot->get_pages_in_category("Category:People on stamps of Gabon");
    print "The pages in Category:People on stamps of Gabon are:\n@pages\n";

=cut

sub get_pages_in_category {
    my $self     = shift;
    my $category = shift;

    unless ($category =~ m/^Category:/) {
        my $ns_data = $self->_get_ns_data();
        my $cat_ns_name = $ns_data->{'14'};

        $category = "$cat_ns_name:$category" unless ($category =~ m/^$cat_ns_name:/);
    }

    my @return;
    my $res = $self->{api}->list(
        {
            action  => 'query',
            list    => 'categorymembers',
            cmtitle => $category,
            cmlimit => 500
        },
    );
    if (!$res) {
        return $self->_handle_api_error();
    }
    foreach (@{$res}) {
        push @return, $_->{title};
    }
    return @return;
}

=head2 get_all_pages_in_category($category_name)

Returns an array containing the names of ALL pages in the specified category (include the Category: prefix), including sub-categories.

=cut

sub get_all_pages_in_category {
    my $self          = shift;
    my $base_category = shift;
    my @first         = $self->get_pages_in_category($base_category);
    my %data;

    foreach my $page (@first) {
        $data{$page} = '';

        my $ns_data = $self->_get_ns_data();
        my $cat_ns_name = $ns_data->{'14'};

        if ($page =~ /^$cat_ns_name:/) {
            my @pages = $self->get_all_pages_in_category($page);
            foreach (@pages) {
                $data{$_} = '';
            }
        }
    }
    return keys %data;
}

=head2 linksearch($link[,$ns[,$protocol[,$options]]])

Runs a linksearch on the specified link and returns an array containing anonymous hashes with keys 'url' for the outbound URL, and 'title' for the page the link is on. $ns is a namespace number to search (pass an arrayref to search in multiple namespaces). You can search by $protocol (http is default). The optional $options hashref is fully documented in MediaWiki::API: Set `max` to limit the number of queries performed. Set `hook` to a subroutine reference to use a callback hook for incremental processing.

Set max in $options to get more than one query's worth of results:

    my $options = { max => 10, }; # I only want some results
    my @links = $bot->linksearch("slashdot.org", 1, undef, $options);
    foreach my $hash (@links) {
        my $url = $hash->{'url'};
        my $page = $hash->{'title'};
        print "$page: $url\n";
    }

You can also specify a callback function in $options:

    my $options = { hook => \&mysub, }; # I want to do incremental processing
    $bot->linksearch("slashdot.org", 1, undef, $options);
    sub mysub {
        my ($res) = @_;
        foreach my $hashref (@$res) {
            my $url  = $hashref->{'url'};
            my $page = $hashref->{'title'};
            print "$page: $url\n";
        }
    }

=cut

sub linksearch {
    my $self    = shift;
    my $link    = shift;
    my $ns      = shift;
    my $prot    = shift;
    my $options = shift;

    $ns = join('|', @$ns) if (ref $ns eq 'ARRAY');

    my @links;

    my $hash = {
        action      => 'query',
        list        => 'exturlusage',
        euprop      => 'url|title',
        euquery     => $link,
        eunamespace => $ns,
        euprotocol  => $prot,
    };
    my $res = $self->{api}->list($hash, $options);
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        return undef if (! ref $res); # When using a callback hook, this won't be a reference
        foreach my $hashref (@$res) {
            my $url  = $hashref->{'url'};
            my $page = $hashref->{'title'};
            push(@links, {'url' => $url, 'title' => $page});
        }
        return @links;
    }
}

=head2 purge_page($pagename)

Purges the server cache of the specified page. Pass an array reference to purge multiple pages. Returns true on success; false on failure. If you really care, a true return value is the number of pages successfully purged. You could check that it is the same as the number you wanted to purge.- maybe some pages don't exist, or you passed invalid titles, or you aren't allowed to purge the cache:

    my @to_purge = ('Main Page', 'A', 'B', 'C', 'Very unlikely to exist');
    my $size = scalar @to_purge;

    print "all-at-once:\n";
    my $success = $bot->purge_page(\@to_purge);

    if ($success == $size) {
        print "@to_purge: OK ($success/$size)\n";
    }
    else {
        my $missed = @to_purge - $success;
        print "We couldn't purge $missed pages (list was: "
            . join(', ', @to_purge)
            . ")\n";
    }

    # OR
    print "\n\none-at-a-time:\n";
    foreach my $page (@to_purge) {
        my $ok = $bot->purge_page($page);
        print "$page: $ok\n";
    }

=cut

sub purge_page {
    my $self = shift;
    my $page = shift;

    my $hash;
    if (ref $page eq 'ARRAY') {             # If it is an array reference...
        $hash = {
            action  => 'purge',
            titles  => join('|',@$page),    # dereference it and purge all those titles
        };
    }
    else {                                  # Just one page
        $hash = {
            action  => 'purge',
            titles  => $page,
        };
    }

    my $res  = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        my $success = 0;
        foreach my $hashref (@{$res->{'purge'}}) {
            $success++ if exists $hashref->{'purged'};
        }
        return $success;
    }

}

=head2 get_namespace_names

get_namespace_names returns a hash linking the namespace id, such as 1, to its named equivalent, such as "Talk".

=cut

sub get_namespace_names {
    my $self = shift;
    my %return;
    my $res = $self->{api}->api(
        {
            action => 'query',
            meta   => 'siteinfo',
            siprop => 'namespaces'
        }
    );
    if (!$res) {
        return $self->_handle_api_error();
    }
    foreach my $id (keys %{ $res->{query}->{namespaces} }) {
        $return{$id} = $res->{query}->{namespaces}->{$id}->{'*'};
    }
    if ($return{1} or $_[0] > 1) {
        return %return;
    }
    else {
        return $self->get_namespace_names($_[0] + 1);
    }
}

=head2 links_to_image($page)

Gets a list of pages which include a certain image.

=cut

sub links_to_image {
    my $self = shift;
    my $page = shift;
    my $url = "$self->{protocol}://$self->{host}/$self->{path}/index.php?title=$page";
    print "Retrieving $url\n" if $self->{debug};
    my $res = $self->{mech}->get($url);
    $res->decoded_content =~ m/div class=\"linkstoimage\" id=\"linkstoimage\"(.+?)\<\/ul\>/is;
    my $list = $1;
    my @list;

    while ($list =~ /title=\"(.+?)\"/ig) {
        push @list, $1;
    }
    return @list;
}

=head2 is_blocked($user)

Checks if a user is currently blocked.

=cut

sub is_blocked {
    my $self = shift;
    my $user = shift;

    # http://en.wikipedia.org/w/api.php?action=query&meta=blocks&bkusers=$user&bklimit=1&bkprop=id
    my $hash = {
        action  => 'query',
        list    => 'blocks',
        bkusers => $user,
        bklimit => 1,
        bkprop  => 'id',
    };
    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        my $number = scalar @{$res->{query}->{"blocks"}}; # The number of blocks returned

        if ($number == 1) {
            return 1;
        }
        elsif ($number == 0) {
            return 0;
        }
        else {
            # UNPOSSIBLE!
        }
    }
}

=head2 test_blocked($user)

Retained for backwards compatibility. Use is_blocked($user) for clarity.

=cut

sub test_blocked { # For backwards-compatibility
    return (is_blocked(@_));
}

=head2 test_image_exists($page)

Checks if an image exists at $page. 0 means no, 1 means yes, local, 2 means on commons, 3 means doesn't exist but there is text on the page.

=cut

sub test_image_exists {
    my $self  = shift;
    my @pages = @_;

    my $titles = join('|', @pages);
    my $return;
    $titles =~ s/\|{2,}/\|/g;
    $titles =~ s/\|$//;

    my $hash = {
        action  => 'query',
        titles  => $titles,
        iilimit => 1,
        prop    => 'imageinfo'
    };

    #use Data::Dumper; print Dumper($hash);
    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }

    #use Data::Dumper; print Dumper($res);
    foreach my $id (keys %{ $res->{query}->{pages} }) {
        my $title = $res->{query}->{pages}->{$id}->{title};
        if ($res->{query}->{pages}->{$id}->{imagerepository} eq 'shared') {
            $return->{$title} = 2;
        }
        elsif (defined($res->{query}->{pages}->{$id}->{missing})) {
            $return->{$title} = 0;
        }
        elsif ($res->{query}->{pages}->{$id}->{imagerepository} eq '') {
            $return->{$title} = 3;
        }
        elsif ($res->{query}->{pages}->{$id}->{imagerepository} eq 'local') {
            $return->{$title} = 1;
        }
    }
    if (scalar(@pages) == 1) {
        return $return->{ $pages[0] };
    }
    else {
        return $return;
    }
}


=head2 get_pages_in_namespace($namespace_id,$page_limit)

Returns an array containing the names of all pages in the specified namespace. The $namespace_id must be a number, not a namespace name. Setting $page_limit is optional. If $page_limit is over 500, it will be rounded up to the next multiple of 500.

=cut

sub get_pages_in_namespace {
    my $self       = shift;
    my $namespace  = shift;
    my $page_limit = shift || 500;
    my $apilimit   = 500;
    if ($self->{highlimits}) {
        $apilimit = 5000;
    }

    my @return;
    my $max;

    if ($page_limit <= $apilimit) {
        $max = 1;
    }
    else {
        $max        = ($page_limit - 1) / $apilimit + 1;
        $page_limit = $apilimit;
    }

    my $res = $self->{api}->list(
        {
            action      => 'query',
            list        => 'allpages',
            apnamespace => $namespace,
            aplimit     => $page_limit
        },
        { max => $max }
    );
    if (!$res) {
        return $self->_handle_api_error();
    }
    foreach (@{$res}) {
        push @return, $_->{title};
    }
    return @return;
}

=head2 count_contributions($user)

Uses the API to count $user's contributions.

=cut

sub count_contributions {
    my $self     = shift;
    my $username = shift;
    $username =~ s/User://i;    # Strip namespace
    my $res = $self->{api}->list(
        {
            action  => 'query',
            list    => 'users',
            ususers => $username,
            usprop  => 'editcount'
        },
        { max => 1 }
    );
    if (!$res) {
        return $self->_handle_api_error();
    }
    my $return = ${$res}[0]->{'editcount'};

    if ($return or $_[0] > 1) {
        return $return;
    }
    else {
        return $self->count_contributions($username, $_[0] + 1);
    }
}

=head2 last_active($user)

Returns the last active time of $user in YYYY-MM-DDTHH:MM:SSZ

=cut

sub last_active {
    my $self     = shift;
    my $username = shift;
    unless ($username =~ /User:/i) { $username = "User:" . $username; }
    my $res = $self->{api}->list(
        {
            action  => 'query',
            list    => 'usercontribs',
            ucuser  => $username,
            uclimit => 1
        },
        { max => 1 }
    );
    if (!$res) {
        return $self->_handle_api_error();
    }
    return ${$res}[0]->{'timestamp'};
}

=head2 recent_edit_to_page($page)

Returns timestamp and username for most recent (top) edit to $page.

=cut

sub recent_edit_to_page {
    my $self = shift;
    my $page = shift;
    my $res  = $self->{api}->api(
        {
            action  => 'query',
            prop    => 'revisions',
            titles  => $page,
            rvlimit => 1
        },
        { max => 1 }
    );
    if (!$res) {
        return $self->_handle_api_error();
    }
    my ($id, $data) = %{ $res->{query}->{pages} };
    return $data->{revisions}[0]->{timestamp};
}

=head2 get_users($page, $limit, $revision, $direction)

Gets the most recent editors to $page, up to $limit, starting from $revision and goint in $direction.

=cut

sub get_users {
    my $self      = shift;
    my $pagename  = shift;
    my $limit     = shift || 5;
    my $rvstartid = shift;
    my $direction = shift;

    my @return;
    my @revisions;

    if ($limit > 50) {
        $self->{errstr} =
"Error requesting history for $pagename: Limit may not be set to values above 50";
        carp $self->{errstr};
        return 1;
    }
    my $hash = {
        action  => 'query',
        prop    => 'revisions',
        titles  => $pagename,
        rvprop  => 'ids|timestamp|user|comment',
        rvlimit => $limit
    };

    $hash->{rvstartid} = $rvstartid if ($rvstartid);
    $hash->{rvdir}     = $direction if ($direction);

    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    my ($id) = keys %{ $res->{query}->{pages} };
    my $array = $res->{query}->{pages}->{$id}->{revisions};
    foreach (@{$array}) {
        push @return, $_->{user};
    }
    return @return;
}

=head2 was_blocked($user)

Returns 1 if $user has ever been blocked.

=cut

sub was_blocked {
    my $self = shift;
    my $user = shift;
    $user =~ s/User://i; # Strip User: prefix, if present

    # example query
    my $hash = {
        action  => 'query',
        list    => 'logevents',
        letype  => 'block',
        letitle => "User:$user", # Ensure the User: prefix is there!
        lelimit => 1,
        leprop  => 'ids',
    };

    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        my $number = scalar @{$res->{'query'}->{'logevents'}}; # The number of blocks returned

        if ($number == 1) {
            return 1;
        }
        elsif ($number == 0) {
            return 0;
        }
        else {
            # UNPOSSIBLE!
        }
    }
}

=head2 test_block_hist($user)

Retained for backwards compatibility. Use was_blocked($user) for clarity.

=cut

sub test_block_hist { # Backwards compatibility
    return (was_blocked(@_));
}

=head2 expandtemplates($page[, $text])

Expands templates on $page, using $text if provided, otherwise loading the page text automatically.

=cut

sub expandtemplates {
    my $self = shift;
    my $page = shift;
    my $text = shift;

    unless ($text) {
        $text = $self->get_text($page);
    }

    my $hash = {
        action  => 'expandtemplates',
        title   => $page,
        text    => $text,
    };
    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    my $expanded = $res->{'expandtemplates'}->{'*'};

    return $expanded;
}

=head2 get_allusers($limit)

Returns an array of all users. Default limit is 500.

=cut

sub get_allusers {
    my $self   = shift;
    my $limit  = shift;
    my @return = ();

    $limit = 500 unless $limit;

    my $res = $self->{api}->api(
        {
            action  => 'query',
            list    => 'allusers',
            aulimit => $limit
        }
    );

    for my $ref (@{ $res->{query}->{allusers} }) {
        push @return, $ref->{name};
    }
    return @return;
}

=head2 db_to_domain($wiki)

Converts a wiki/database name (enwiki) to the domain name (en.wikipedia.org).

    my @wikis = ("enwiki", "kowiki", "bat-smgwiki", "nonexistent");
    foreach my $wiki (@wikis) {
        my $domain = $bot->db_to_domain($wiki);
        next if !defined($domain);
        print "$wiki: $domain\n";
    }

You can pass an arrayref to do bulk lookup:

    my @wikis = ("enwiki", "kowiki", "bat-smgwiki", "nonexistent");
    my $domains = $bot->db_to_domain(\@wikis);
    foreach my $domain (@$domains) {
        next if !defined($domain);
        print "$domain\n";
    }

=cut

sub db_to_domain {
    my $self = shift;
    my $wiki = shift;

    if (!$self->{sitematrix}) {
        $self->_get_sitematrix();
    }

    if (ref $wiki eq 'ARRAY') {
        my @return;
        foreach my $w (@$wiki) {
            $wiki =~ s/_p$//; # Strip off a _p suffix, if present
            my $domain = $self->{'sitematrix'}->{$w} || undef;
            push(@return, $domain);
        }
        return \@return;
    }
    else {
        $wiki =~ s/_p$//; # Strip off a _p suffix, if present
        my $domain = $self->{'sitematrix'}->{$wiki} || undef;
        return $domain;
    }
}

=head2 domain_to_db($wiki)

As you might expect, does the opposite of domain_to_db(): Converts a domain
name into a database/wiki name.

=cut

sub domain_to_db {
    my $self = shift;
    my $wiki = shift;

    if (!$self->{sitematrix}) {
        $self->_get_sitematrix();
    }

    if (ref $wiki eq 'ARRAY') {
        my @return;
        foreach my $w (@$wiki) {
            my $db = $self->{'sitematrix'}->{$w} || undef;
            push(@return, $db);
        }
        return \@return;
    }
    else {
        my $db = $self->{'sitematrix'}->{$wiki} || undef;
        return $db;
    }
}

=head2 diff($options_hashref)

This allows retrieval of a diff from the API. The return is a scalar containing the HTML table of the diff. Options are as follows:

=over 4

=item *
title is the title to use. Provide I<either> this or revid.

=item *
revid is any revid to diff from. If you also specified title, only title will be honoured.

=item *
oldid is an identifier to diff to. This can be a revid, or the special values 'cur', 'prev' or 'next'

=back

=cut

sub diff {
    my $self = shift;
    my $title;
    my $revid;
    my $oldid;

    if (ref $_[0] eq 'HASH') {
        $title = $_[0]->{'title'};
        $revid = $_[0]->{'revid'};
        $oldid = $_[0]->{'oldid'};
    }
    else {
        $title = shift;
        $revid = shift;
        $oldid = shift;
    }

    my $hash = {
        action      => 'query',
        prop        => 'revisions',
        rvdiffto    => $oldid,
    };
    if ($title) {
        $hash->{'titles'} = $title;
        $hash->{'rvlimit'} = 1;
    }
    elsif ($revid) {
        $hash->{'revids'} = $revid;
    }

    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    my @revids = keys %{ $res->{'query'}->{'pages'} };
    my $diff = $res->{'query'}->{'pages'}->{$revids[0]}->{'revisions'}->[0]->{'diff'}->{'*'};

    return $diff;
}

=head2 prefixindex($prefix[,$filter[,$ns[,$options]]])

This returns an array of hashrefs containing page titles that start with the given $prefix. $filter is one of 'all', 'redirects', or 'nonredirects'; $ns is a single namespace number (unlike linksearch etc, which can accept an arrayref of numbers). $options is a hashref as described in the section on linksearch() or in MediaWiki::API. The hashref has keys 'title' and 'redirect' (present if the page is a redirect, not present otherwise).

    my @prefix_pages = $bot->prefixindex("User:Mike.lifeguard");
    # Or, the more efficient equivalent
    my @prefix_pages = $bot->prefixindex("Mike.lifeguard", 2);
    foreach my $hashref (@pages) {
        my $title = $hashref->{'title'};
        if $hashref->{'redirect'} {
            print "$title is a redirect\n";
        }
        else {
            print "$title\n is not a redirect\n";
        }
    }

=cut

sub prefixindex {
    my $self    = shift;
    my $prefix  = shift;
    my $ns      = shift;
    my $filter  = shift;
    my $options = shift;

    if (defined($filter) and $filter =~ m/(all|redirects|nonredirects)/) { # Verify
        $filter = $1;
    }

    if (!$ns and $prefix =~ m/:/) {
        print "Converted '$prefix' to..." if $self->{debug};
        my ($name) = split(/:/, $prefix, 2);
        my $ns_data = $self->_get_ns_data();
        $ns = $ns_data->{$name};
        $prefix =~ s/^$name://;
        print "'$prefix' with a namespace filter $ns" if $self->{debug};
    }

    my $hash = {
        action      => 'query',
        list        => 'allpages',
        apprefix    => $prefix,
    };
    $hash->{'apnamespace'} = $ns if $ns;
    $hash->{'apfilterredir'} = $filter if $filter;

    my $res = $self->{api}->list($hash, $options);

    my @pages;
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        return undef if (! ref $res); # Not a ref when using callback hook
        foreach my $hashref (@$res) {
            my $title = $hashref->{'title'};
            my $redirect = defined($hashref->{'redirect'});
            push @pages, { title => $title, redirect => $redirect };
        }
    }

    return @pages;
}


################
# Internal use #
################

sub _get_edittoken { # Actually returns ($edittoken, $basetimestamp, $starttimestamp)
    my $self = shift;
    my $page = shift;

    my $hash = {
        action  => 'query',
        titles  => $page,
        prop    => 'info|revisions',
        intoken => 'edit'
    };
    my $res = $self->{api}->api($hash);
    my ($id, $data) = %{ $res->{query}->{pages} };
    my $edittoken = $data->{'edittoken'};
    my $tokentimestamp = $data->{'starttimestamp'};
    my $basetimestamp = $data->{'revisions'}[0]->{'timestamp'};
    return ($edittoken, $basetimestamp, $tokentimestamp);
}

sub _handle_api_error {
    my $self = shift;
    carp 'Error code: ' . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error} = $self->{api}->{error};
    return undef;
}

sub _is_loggedin {
    my $self = shift;

    my $hash = {
        action =>  'query',
        meta    => 'userinfo',
    };
    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }
    my $is = $res->{'query'}->{'userinfo'}->{'name'};
    my $ought = $self->{username};
    carp "Testing if logged in: we are $is, think we should be $ought" if $self->{debug};
    return ($is eq $ought);
}

sub _do_autoconfig {
    my $self = shift;

    # http://en.wikipedia.org/w/api.php?action=query&meta=userinfo&uiprop=rights|groups
    my $hash = {
        action  => 'query',
        meta    => 'userinfo',
        uiprop  => 'rights|groups',
    };
    my $res = $self->{api}->api($hash);
    if (!$res) {
        return $self->_handle_api_error();
    }

    my $is = $res->{'query'}->{'userinfo'}->{'name'};
    my $ought = $self->{username};
    # Should we try to recover by logging in again? croak?
    carp "We're logged in as $is but we should be logged in as $ought" if ($is ne $ought);

    my @rights = @{ $res->{'query'}->{'userinfo'}->{'rights'} };
    my $has_bot = 0;
    my $has_apihighlimits = 0;
    my $default_assert = 'user'; # At a *minimum*, the bot should be logged in.
    foreach my $right (@rights) {
        if ($right eq 'bot') {
            $has_bot = 1;
            $default_assert = 'bot';
        }
        elsif ($right eq 'apihighlimits') {
            $has_apihighlimits = 1;
        }
    }

    my @groups = @{ $res->{'query'}->{'userinfo'}->{'groups'} };
    my $is_sysop = 0;
    foreach my $group (@groups) {
        if ($group eq 'sysop') {
            $is_sysop = 1;
        }
    }

    unless ($has_bot and !$is_sysop) {
        carp "$is doesn't have a bot flag; edits will be visible in RecentChanges" if $self->{debug};
    }
    $self->set_highlimits($has_apihighlimits);
    $self->{'assert'} = $default_assert unless $self->{'assert'};

    return 1;
}

sub _get_sitematrix {
    my $self = shift;

    my $res = $self->{api}->api( { action => 'sitematrix' } );
    if (!$res) {
        return $self->_handle_api_error();
    }
    else {
        my %sitematrix = %{ $res->{'sitematrix'} };
#        use Data::Dumper;
#        print Dumper(\%sitematrix) and die;
        # This hash is a monstrosity (see http://sprunge.us/dfBD?pl), and needs
        # lots of post-processing to have a sane data structure :\
        my %map;
        foreach my $hashref (%sitematrix) {
            if (ref $hashref ne 'HASH') { # Yes, there are non-hashrefs in here, wtf?!
                if ($hashref eq 'specials'){
                    foreach my $special (@{ $sitematrix{'specials'} }) {
                        my $db     = $special->{'code'};
                        my $domain = $special->{'url'};
                        $domain    =~ s,^http://,,;

                        $map{$db} = $domain;
                        $map{$domain} = $db;
                    }
                }
                next;
            }

            my $lang = $hashref->{'code'};

            foreach my $wiki_ref ($hashref->{'site'}) {
                foreach my $wiki_ref2 (@$wiki_ref) {
                    my $family = $wiki_ref2->{'code'};
                    my $domain = $wiki_ref2->{'url'};
                    $domain    =~ s,^http://,,;

                    my $db = $lang . $family; # Is simple concatenation /always/ correct?

                    $map{$db} = $domain;
                    $map{$domain} = $db;
                }
            }
        }

        # This could be saved to disk with Storable. Next time you call this
        # method, if mtime is less than, say, 14d, you could load it from
        # disk instead of over network.
        $self->{'sitematrix'} = \%map;
        return $self->{'sitematrix'};
    }
}

sub _get_ns_data {
    my $self = shift;

    my %ns_data = $self->{'ns_data'} ? %{$self->{'ns_data'}} : $self->get_namespace_names();
    my %reverse = reverse %ns_data;
    %ns_data = (%ns_data, %reverse);
    $self->{'ns_data'} = \%ns_data; # Save for later use
    return $self->{'ns_data'};
}

1;

=head1 ERROR HANDLING

All functions will return undef in any handled error situation. Further error
data is stored in $bot->{error}->{code} and $bot->{error}->{details}.

=cut

__END__
