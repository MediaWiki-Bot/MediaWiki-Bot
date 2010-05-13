package MediaWiki::Bot;

use strict;
use warnings;
use WWW::Mechanize;
use HTML::Entities;
use URI::Escape;
use XML::Simple;
use Carp;
use Encode;
use URI::Escape qw(uri_escape_utf8);
use MediaWiki::API;

use Module::Pluggable   search_path => [ qw(MediaWiki::Bot::Plugin) ],
            'require'   => 1;

foreach my $plugin (__PACKAGE__->plugins) {
    print "Found plugin $plugin\n";
    $plugin->import();
}


our $VERSION = '2.3.1';

=head1 NAME

MediaWiki::Bot - a Wikipedia bot framework written in Perl

=head1 SYNOPSIS

use MediaWiki::Bot;

my $editor = MediaWiki::Bot->new('Account');
$editor->login('Account', 'password');
$editor->revert('Wikipedia:Sandbox', 'Reverting vandalism', '38484848');

=head1 DESCRIPTION

MediaWiki::Bot is a framework that can be used to write Wikipedia bots.

Many of the methods use the MediaWiki API (L<http://en.wikipedia.org/w/api.php>).

=head1 AUTHOR

The MediaWiki::Bot team (Alex Rowe, Jmax, Oleg Alexandrov, Dan Collins) and others.

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

=over 4

=item new([$agent[, $assert[, $operator]]])

Calling MediaWiki::Bot->new will create a new MediaWiki::Bot object.
$agent sets a custom useragent, $assert sets a parameter for the assertedit extension, common is "&assert=bot", $operator allows the bot to send you a message when it fails an assert. The message will tell you that $agent is logged out, so use a descriptive $agent. $protocol allows you to specify 'http' or 'https' (default is 'http'). For example:

$bot = MediaWiki::Bot->new("MediaWiki::Bot", undef, undef, 5, "https");

=cut

sub new {
    my $package = shift;
    my $agent   = shift || 'MediaWiki::Bot'; #user-specified agent or default
    my $assert  = shift || undef;
    my $operator= shift || undef;
    my $maxlag  = shift || 5;

    # added for https
    my $protocol = shift || "http";

    if ($operator) {$operator=~s/User://i;} #strip off namespace
    $assert=~s/\&?assert=// if $assert;

    my $self = bless {}, $package;

    # added for https
    $self->{protocol} = $protocol;
    if ($self->{protocol} eq "https") {
        use Crypt::SSLeay;
    }

    $self->{mech} = WWW::Mechanize->new( cookie_jar => {}, onerror => \&Carp::carp, stack_depth => 1 );
    $self->{mech}->agent("$agent/$VERSION");
    $self->{host}   = 'en.wikipedia.org';
    $self->{path}   = 'w';
    $self->{debug}  = 0;
    $self->{errstr} = '';
    $self->{assert} = $assert;
    $self->{operator}=$operator;
    $self->{api}    = MediaWiki::API->new();
    $self->{api}->{config}->{api_url} = 'http://en.wikipedia.org/w/api.php';
    $self->{api}->{config}->{max_lag} = $maxlag;
    $self->{api}->{config}->{max_lag_delay} = 1;
    $self->{api}->{config}->{retries} = 5;
    $self->{api}->{config}->{max_lag_retries} = -1;
    $self->{api}->{config}->{retry_delay} = 30;

    return $self;
}

=item set_highlimits([$flag])

Tells MediaWiki::Bot to start using the APIHighLimits for certain queries.

=cut

sub set_highlimits {
    my $self = shift;
    my $highlimits = shift;
    unless (defined($highlimits)) {$highlimits=1}
    $self->{highlimits}=1;
}

sub _get {
    my $self      = shift;
    my $page      = shift;
    my $action    = shift || 'view';
    my $extra     = shift;
    my $no_escape = shift || 0;

    $page = uri_escape_utf8($page) unless $no_escape;

    my $url =
      "$self->{protocol}://$self->{host}/$self->{path}/index.php?title=$page&action=$action";
    $url .= $extra if $extra;
    print "Retrieving $url\n" if $self->{debug};
    my $res = $self->{mech}->get($url);
    if ( ref($res) eq 'HTTP::Response' && $res->is_success() ) {
        if ( $res->decoded_content =~
    m/The action you have requested is limited to users in the group (.+)\./
          ) {
            my $group = $1;
            $group =~ s/<.+?>//g;
            $self->{errstr} = qq/Error requesting $page: You must be in the user group "$group"/;
            carp $self->{errstr} if $self->{debug};
            return 1;
        } else {
            return $res;
        }
    } else {
        $self->{errstr} = "Error requesting $page: " . $res->status_line();
        carp $self->{errstr} if $self->{debug};
        return 1;
    }
}

sub _get_api {
    my $self  = shift;
    my $query = shift;
    print "Retrieving $self->{protocol}://$self->{host}/$self->{path}/api.php?$query\n"
      if $self->{debug};
    my $res =
      $self->{mech}->get("$self->{protocol}://$self->{host}/$self->{path}/api.php?$query");
    if ( ref($res) eq 'HTTP::Response' && $res->is_success() ) {
        return $res;
    } else {
        $self->{errstr} = "Error requesting api.php?$query: " . $res->status_line();
        carp $self->{errstr} if $self->{debug};
        return 1;
    }
}

sub _put {
    my $self    = shift;
    my $page    = shift;
    my $options = shift;
    my $extra   = shift;
    my $type    = shift;
    my $res     = $self->_get( $page, 'edit', $extra );
    unless (ref($res) eq 'HTTP::Response' && $res->is_success) { return; }
    if ( ( $res->decoded_content ) =~ m/<textarea .+?readonly="readonly"/ ) {
        $self->{errstr} = "Error editing $page: Page is protected";
        carp $self->{errstr} if $self->{debug};
        return 1;
    } elsif ( ($res->decoded_content) =~ m/The specified assertion \(.+?\) failed/) {
        $self->{errstr} = "Error editing $page: Assertion failed";
        return 2;
    } elsif ( ($res->decoded_content) !~ /class=\"diff-lineno\">/ and $type eq 'undo') {
        $self->{errstr} = "Error editing $page: Undo failed";
        return 3;
    } else {
        $res = $self->{mech}->submit_form( %{$options} );
        return $res;
    }
}

=item set_wiki([$wiki_host[,$wiki_path]])

set_wiki will cause the MediaWiki::Bot object to use the wiki specified, e.g set_wiki('de.wikipedia.org','w') will tell it to use http://de.wikipedia.org/w/index.php. The default settings are 'en.wikipedia.org' with a path of 'w'.

=cut

sub set_wiki {
    my $self = shift;
    my $host = shift || 'en.wikipedia.org';
    my $path = shift || 'w';
    $self->{host} = $host if $host;
    $self->{path} = $path if $path;
    $self->{api}->{config}->{api_url} = "$self->{protocol}://$host/$path/api.php";
    print "Wiki set to $self->{protocol}://$self->{host}/$self->{path}\n" if $self->{debug};
    return 0;
}

=item login($username,$password)

Logs the object into the specified wiki. If the login was a success, it will return 'Success', otherwise, 'Fail'.

=cut

sub login {
    my $self     = shift;
    my $editor   = shift;
    my $password = shift;
    my $cookies  = ".mediawiki-bot-$editor-cookies";
    $self->{mech}->cookie_jar(
        { file => $cookies, autosave => 1 } );
    if ( !defined $password ) {
        $self->{mech}->{cookie_jar}->load($cookies);
        my $cookies_exist = $self->{mech}->{cookie_jar}->as_string;
        if ($cookies_exist) {
            $self->{mech}->{cookie_jar}->load($cookies);
            print "Loaded MediaWiki cookies from file $cookies\n" if $self->{debug};
        $self->{api}->{ua}->{cookie_jar} = $self->{mech}->{cookie_jar};
            return 0;
        } else {
            $self->{errstr} = "Cannot load MediaWiki cookies from file $cookies";
            carp $self->{errstr};
            return 1;
        }
    }

    my $res = $self->{api}->api( {
        action=>'login',
        lgname=>$editor,
        lgpassword=>$password } );
    if (!$res) {
        carp "Error code: " . $self->{api}->{error}->{code};
        carp $self->{api}->{error}->{details};
        $self->{error}=$self->{api}->{error};
        return $self->{error}->{code};
    }
    my $result = $res->{login}->{result};
    if ($result eq "NeedToken") {
          my $lgtoken=$res->{login}->{token};
          $res = $self->{api}->api( {
                                     action=>'login',
                                     lgname=>$editor,
                                     lgpassword=>$password,
                                     lgtoken=>$lgtoken } );
          if (!$res) {
            carp "Error code: " . $self->{api}->{error}->{code};
            carp $self->{api}->{error}->{details};
            $self->{error}=$self->{api}->{error};
            return $self->{error}->{code};
          }
          $result = $res->{login}->{result};
        }
    $self->{mech}->{cookie_jar}->extract_cookies($self->{api}->{response});
    if ($result eq "Success") {
    return 0;
    } else {
    return 1;
    }
}

=item edit($pagename,$page_text,[$edit_summary],[$is_minor],[$assert])

Edits the specified page $pagename and replaces it with $page_text with an edit summary of $edit_summary, optionally marking the edit as minor if specified, and adding an assertion, if requested. Assertions should be of the form "user".

=cut

sub edit {
    my $self     = shift;
    my $page     = shift;
    my $text     = shift;
    my $summary  = shift;
    my $is_minor = shift || 0;
    my $assert   = shift || $self->{assert};
    my $res;

    $assert=~s/\&?assert=// if $assert;

    $res = $self->{api}->api( {
        action=>'query',
        titles=>$page,
        prop=>'info|revisions',
        intoken=>'edit' } );
    my ($id, $data)=%{$res->{query}->{pages}};
    my $edittoken=$data->{edittoken};
    my $lastedit=$data->{revisions}[0]->{timestamp};

    my $savehash = {
        action=>'edit',
        title=>$page,
        token=>$edittoken,
        text=>$text,
        summary=>$summary,
        basetimestamp=>$lastedit,
        bot=>1};

    $savehash->{assert}=$assert if ($assert);
    $savehash->{minor}=$is_minor if ($is_minor);

    $res = $self->{api}->api( $savehash );
    if (!$res) {
        carp "Error code: " . $self->{api}->{error}->{code};
        carp $self->{api}->{error}->{details};
        $self->{error}=$self->{api}->{error};
        return $self->{error}->{code} if $self->{error}->{code}!=2;
    }
    if ($res->{edit}->{result} && $res->{edit}->{result} eq 'Failure') {
        if ($self->{mech}->{agent}) {
            carp "Assertion failed as ".$self->{mech}->{agent};
        if ($self->{operator}) {
            my $optalk=$self->get_text("User talk:".$self->{operator});
                unless ($optalk=~/Error with \Q$self->{mech}->{agent}\E/) {
                print "Sending warning!\n";
                $self->edit("User talk:$self->{operator}", $optalk."\n\n==Error with ".$self->{mech}->{agent}."==\n".$self->{mech}->{agent}." needs to be logged in! ~~~~", 'bot issue', 0, 'assert=');

            }
        }
        return 2;
        } else {
            carp "Assertion failed";
        }
        }
    return $res;
}

=item get_history($pagename,$limit)

Returns an array containing the history of the specified page, with $limit number of revisions. The array structure contains 'revid','user','comment','timestamp_date', and 'timestamp_time'.

=cut

sub get_history {
    my $self      = shift;
    my $pagename  = shift;
    my $limit     = shift || 5;
    my $rvstartid = shift || '';
    my $direction = shift;

    my @return;
    my @revisions;

    if ( $limit > 50 ) {
        $self->{errstr} = "Error requesting history for $pagename: Limit may not be set to values above 50";
        carp $self->{errstr} if $self->{debug};
        return 1;
    }

    my $hash = {
        action=>'query',
        prop=>'revisions',
        titles=>$pagename,
        rvprop=>'ids|timestamp|user|comment',
        rvlimit=>$limit
    };

    $hash->{rvstartid}=$rvstartid if ($rvstartid);
    $hash->{direction}=$direction if ($direction);

    my $res = $self->{api}->api( $hash );
    if (!$res) {
        carp "Error code: " . $self->{api}->{error}->{code};
        carp $self->{api}->{error}->{details};
        $self->{error}=$self->{api}->{error};
        return $self->{error}->{code};
    }
    my ($id)=keys %{$res->{query}->{pages}};
    my $array=$res->{query}->{pages}->{$id}->{revisions};

    foreach my $hash ( @{$array} ) {
        my $revid = $hash->{revid};
        my $user  = $hash->{user};
        my ( $timestamp_date, $timestamp_time ) = split( /T/, $hash->{timestamp} );
        $timestamp_time=~s/Z$//;
        my $comment = $hash->{comment};
        push ( @return, {
            revid          => $revid,
            user           => $user,
            timestamp_date => $timestamp_date,
            timestamp_time => $timestamp_time,
            comment        => $comment,
        } );
    }
    return @return;
}

=item get_text($pagename,[$revid,$section_number])

Returns the text of the specified page. If $revid is defined, it will return the text of that revision; if $section_number is defined, it will return the text of that section. Returns 2 if page does not exist.

=cut

sub get_text {
    my $self     = shift;
    my $pagename = shift;
    my $revid    = shift || '';
    my $section  = shift || '';
    my $recurse  = shift || 0;
    my $dontescape=shift || 0;

    my $hash = {
        action=>'query',
        titles=>$pagename,
        prop=>'revisions',
        rvprop=>'content',
    };

    $hash->{rvsection}=$section if ($section);
    $hash->{rvstartid}=$revid if ($revid);

    my $res = $self->{api}->api( $hash );
    if (!$res) {
        carp "Error code: " . $self->{api}->{error}->{code};
        carp $self->{api}->{error}->{details};
        $self->{error}=$self->{api}->{error};
        return $self->{error}->{code};
    }
    my ($id, $data)=%{$res->{query}->{pages}};

    if ($id==-1) {return 2}

    my $wikitext=$data->{revisions}[0]->{'*'};
    return $wikitext;
}

=item get_id($pagename)

Returns the id of the specified page. Returns 2 if page does not exist.

=cut

sub get_id {
    my $self     = shift;
    my $pagename = shift;

    my $hash = {
        action=>'query',
        titles=>$pagename,
    };

    my $res = $self->{api}->api( $hash );
    if (!$res) {
        carp "Error code: " . $self->{api}->{error}->{code};
        carp $self->{api}->{error}->{details};
        $self->{error}=$self->{api}->{error};
        return $self->{error}->{code};
    }

    my ($id, $data) = %{$res->{query}->{pages}};

    if ($id == -1) {return 2}

    return $id;
}

=item get_pages(@pages)

Returns the text of the specified pages in a hashref. Content of '2' means page does not exist.
Also handles redirects or article names that use namespace aliases

=cut

sub _get_one_page {
    my ($self,$title) = @_;
    my $hash = {
    action=>'query',
    prop=>'revisions',
    rvprop=>'content',
    };

    my $mw_temp = MediaWiki::API->new();
    $mw_temp->{config}->{api_url} = $self->{api}->{config}->{api_url};
    $hash->{titles} = $title;
    my $res_temp = $mw_temp->api($hash);
    my ($k,$v) = each %{ $res_temp->{query}->{pages} };
    return $v;
}

sub get_pages {
    my $self     = shift;
    my @pages    = @_;
    my %return;

    my $hash = {
    action=>'query',
    titles=>join('|', @pages),
    prop=>'revisions',
    rvprop=>'content',
    };

    my $diff;  # used to track problematic article names
    map { $diff->{$_}=1; } @pages;
    my $res = $self->{api}->api( $hash );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    #need to add shift @pages before each next , and
    foreach my $id (keys %{$res->{query}->{pages}}) {
    my $page = $res->{query}->{pages}->{$id};
    if($diff->{ $page->{title} }){
        $diff->{ $page->{title} }++ ;
    } else {
        next;
    }

    if (defined($page->{missing})) {
        $return{$page->{title}}=2;
        next;
    }
    if (defined($page->{revisions})) {
        my $revisions = @{$page->{revisions}}[0]->{'*'};
        if (! defined $revisions) {
        $return{$page->{title}} = $revisions;
        } elsif (
        length($revisions)< 150 &&
        $revisions =~ /\#REDIRECT\s\[\[([^\[\]]*)\]\]/
        ) {
        my $redirect_to = $1;
        $redirect_to=~ s/\s/_/g;
        my $v = $self->_get_one_page($redirect_to);
        $return{ $page->{title}}= @{ $v->{revisions} }[0]->{'*'};
        } else {
        $return{$page->{title}}= $revisions;
        };
    }
    };

    #based on
    #http://en.wikipedia.org/w/api.php?action=query&meta=siteinfo&siprop=namespaces|namespacealiases
    my $expand = {
    WP  => 'Wikipedia',
    WT  => 'Wikipedia talk',
    Image   => 'File',
    'Image Talk' => 'File talk',
    };
    for my $title ( keys %$diff ) {
    #only for those article names that remained after the first part
    #if we're here we are dealing most likely with a WP:CSD type of article name
    if($diff->{$title}==1) {
        my @pieces = split ':',$title;
        if(@pieces>1) {
        $pieces[0] = ($expand->{$pieces[0]} || $pieces[0]);
        my $v = $self->_get_one_page(join ':',@pieces);
        print "Detected article name that needed expanding $title\n" if @{ $v->{revisions} }[0]->{'*'} && $self->{debug};

        $return{$title} = @{ $v->{revisions} }[0]->{'*'};
        if(@{ $v->{revisions} }[0]->{'*'} =~ /\#REDIRECT\s\[\[([^\[\]]*)\]\]/) {
            my $v = $self->_get_one_page($1);
            $return{$title} = @{ $v->{revisions} }[0]->{'*'};
        }
        }
    }
    }
    return \%return;
}

=item revert($pagename,$edit_summary,$old_revision_id)

Reverts the specified page to $old_revision_id, with an edit summary of $edit_summary.

=cut

sub revert {
    my $self     = shift;
    my $pagename = shift;
    my $summary  = shift;
    my $revid    = shift;

    return $self->_put(
    $pagename,
    {
        form_name => 'editform',
        fields    => { wpSummary => $summary, },
    },
    "&oldid=$revid"
    );
}

=item undo($pagename,$edit_summary,$revision_id,$after)

Reverts the specified page to $revision_id, with an edit summary of $edit_summary, using the undo function. To use old revision id instead of new, set last param to 'after'.

=cut

sub undo {
    my $self     = shift;
    my $pagename = shift;
    my $summary  = shift;
    my $revid    = shift;
    my $after    = shift || '';

    return $self->_put(
    $pagename,
    {
        form_name => 'editform',
        fields    => { wpSummary => $summary, },
    },
    "&undo$after=$revid",
    "undo" #For the error detection in _put.
    );
}

=item get_last($pagename,$username)

Returns the number of the last revision not made by $username.

=cut

sub get_last {
    my $self     = shift;
    my $pagename = shift;
    my $editor   = shift;

    my $revertto = 0;
    $pagename = uri_escape_utf8( $pagename );

    my $res = $self->{api}->api( {
        action=>'query',
        titles=>$pagename,
        prop=>'revisions',
        rvlimit=>20,
        rvprop=>'ids|user',
        rvexcludeuser=>$editor } );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    my ($id, $data)=%{$res->{query}->{pages}};
    return $data->{revisions}[0]->{revid};
}

=item update_rc([$limit])

Returns an array containing the Recent Changes to the wiki Main namespace. The array structure contains 'pagename', 'revid', 'oldid', 'timestamp_date', and 'timestamp_time'.

=cut

sub update_rc {
    my $self = shift;
    my $limit = shift || 5;
    my @rc_table;

    my $res = $self->{api}->list( {
        action=>'query',
        list=>'recentchanges',
        rcnamespace=>0,
        rclimit=>$limit },
    { max=>$limit } );
    foreach my $hash (@{$res}) {
    my ( $timestamp_date, $timestamp_time ) = split( /T/, $hash->{timestamp} );
    $timestamp_time =~ s/Z$//;
    push( @rc_table, {
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

=item what_links_here($pagename)

Returns an array containing a list of all pages linking to the given page. The array structure contains 'title' and 'type', the type being a transclusion, redirect, or neither.

=cut

sub what_links_here {
    my $self    = shift;
    my $article = shift;
    my @links;

    $article = uri_escape_utf8( $article );

    my $res =
    $self->_get( 'Special:Whatlinkshere', 'view',
    "&target=$article&limit=5000" );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    unless (ref($res) eq 'HTTP::Response' && $res->is_success) { return 1; }
    my $content = $res->decoded_content;
    while (
    $content =~ m{<li><a href="[^"]+" title="([^"]+)">[^<]+</a>([^<]*)}g ) {
    my $title = $1;
    my $type  = $2;
    if ( $type !~ /\(redirect page\)/ && $type !~ /\(transclusion\)/ ) {
        $type = "";
    }
    if ( $type =~ /\(redirect page\)/ ) { $type = "redirect"; }
    if ( $type =~ /\(transclusion\)/ )  { $type = "transclusion"; }

    push @links, { title => $title, type => $type };
    }

    return @links;
}

=item get_pages_in_category($category_name)

Returns an array containing the names of all pages in the specified category. Does not go into sub-categories.

=cut

sub get_pages_in_category {
    my $self     = shift;
    my $category = shift;

    my @return;
    my $res = $self->{api}->list( {
        action=>'query',
        list=>'categorymembers',
        cmtitle=>$category,
        cmlimit=>500 },
    );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    foreach (@{$res}) {
    push @return, $_->{title};
    }
    return @return;
}

=item get_all_pages_in_category($category_name)

Returns an array containing the names of ALL pages in the specified category, including sub-categories.

=cut

sub get_all_pages_in_category {
    my $self          = shift;
    my $base_category = shift;
    my @first         = $self->get_pages_in_category($base_category);
    my %data;
    foreach my $page (@first) {
    $data{$page} = '';
    if ( $page =~ /^Category:/ ) {
        my @pages = $self->get_all_pages_in_category($page);
        foreach (@pages) {
        $data{$_} = '';
        }
    }
    }
    return keys %data;
}

=item linksearch($link)

Runs a linksearch on the specified link and returns an array containing anonymous hashes with keys "link" for the outbound link name, and "page" for the page the link is on.

=cut

sub linksearch {
    my $self = shift;
    my $link = shift;
    my @links;
    my $res =
    $self->_get( "Special:Linksearch", "edit", "&target=$link&limit=500" );
    unless (ref($res) eq 'HTTP::Response' && $res->is_success) { return 1; }
    my $content = $res->decoded_content;
    while ( $content =~
    m{<li><a href.+>(.+?)</a> linked from <a href.+>(.+)</a></li>}g ) {
    push( @links, { link => $1, page => $2 } );
    }
    while ( my $res = $self->{mech}->follow_link( text => 'next 500' ) && ref($res) eq 'HTTP::Response' && $res->is_success ) {
    sleep 2;
    my $content = $res->decoded_content;
    while ( $content =~
        m{<li><a href.+>(.+?)</a> linked from <a href=.+>(.+)</a></li>}g ) {
        push( @links, { link => $1, page => $2 } );
    }
    }
    return @links;
}

=item purge_page($pagename)

Purges the server cache of the specified page.

=cut

sub purge_page {
    my $self = shift;
    my $page = shift;
    my $res  = $self->_get( $page, 'purge' );

}

=item get_namespace_names

get_namespace_names returns a hash linking the namespace id, such as 1, to its named equivalent, such as "Talk".

=cut

sub get_namespace_names {
    my $self = shift;
    my %return;
    my $res = $self->{api}->api( {
        action=>'query',
        meta=>'siteinfo',
        siprop=>'namespaces'} );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    foreach my $id (keys %{$res->{query}->{namespaces}}) {
    $return{$id} = $res->{query}->{namespaces}->{$id}->{'*'};
    }
    if ($return{1} or $_[0]>1) {
    return %return;
    } else {
    return $self->get_namespace_names($_[0]+1);
    }
}

=item links_to_image($page)

Gets a list of pages which include a certain image.

=cut

sub links_to_image {
    my $self    = shift;
    my $page    = shift;
    my $url = "$self->{protocol}://$self->{host}/$self->{path}/index.php?title=$page";
    print "Retrieving $url\n" if $self->{debug};
    my $res = $self->{mech}->get($url);
    $res->decoded_content=~/div class=\"linkstoimage\" id=\"linkstoimage\"(.+?)\<\/ul\>/is;
    my $list=$1;
    my @list;
    while ($list=~/title=\"(.+?)\"/ig) {
    push @list, $1;
    }
    return @list;
}

=item test_blocked($user)

Checks if a user is currently blocked.

=cut

sub test_blocked {
    my $self      = shift;
    my $user      = shift;

    my $res = $self->_get("Special%3AIpblocklist&ip=$user", "", "", 1);
    if ($res->decoded_content=~/not blocked/i) {
    return 0;
    } else {
    return 1;
    }
}

=item test_image_exists($page)

Checks if an image exists at $page. 0 means no, 1 means yes, local, 2 means on commons, 3 means doesn't exist but there is text on the page.

=cut

sub test_image_exists {
    my $self    = shift;
    my @pages   = @_;

    my $titles=join('|', @pages);
    my $return;
    $titles=~s/\|{2,}/\|/g;
    $titles=~s/\|$//;

    my $hash = {
    action => 'query',
    titles => $titles,
    iilimit => 1,
    prop => 'imageinfo'};

#   use Data::Dumper; print Dumper($hash);
    my $res = $self->{api}->api($hash);
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
#   use Data::Dumper; print Dumper($res);
    foreach my $id (keys %{$res->{query}->{pages}}) {
    my $title=$res->{query}->{pages}->{$id}->{title};
    if ($res->{query}->{pages}->{$id}->{imagerepository} eq 'shared') {
        $return->{$title}=2;
    } elsif (defined($res->{query}->{pages}->{$id}->{missing})) {
        $return->{$title}=0;
    } elsif ($res->{query}->{pages}->{$id}->{imagerepository} eq '') {
        $return->{$title}=3;
    } elsif ($res->{query}->{pages}->{$id}->{imagerepository} eq 'local') {
        $return->{$title}=1;
    }
    }
    if (scalar(@pages)==1) {
    return $return->{$pages[0]};
    } else {
    return $return;
    }
}

=item delete_page($page[, $summary])

Deletes the page with the specified summary.

=cut

sub delete_page {
    my $self    = shift;
    my $page    = shift;
    my $summary = shift;

    my $res = $self->{api}->api( {
        action=>'query',
        titles=>$page,
        prop=>'info|revisions',
        intoken=>'delete' } );
    my ($id, $data)=%{$res->{query}->{pages}};
    my $edittoken=$data->{deletetoken};
    $res = $self->{api}->api( {
        action=>'delete',
        title=>$page,
        token=>$edittoken,
        reason=>$summary } );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    return $res;
}

=item delete_old_image($page, $revision[, $summary])

Deletes the specified revision of the image with the specified summary.

=cut

sub delete_old_image {
    my $self    = shift;
    my $page    = shift;
    my $id  = shift;
    my $summary = shift;
    my $image   = $page;
    $image=~s/\s/_/g;
    $image=~s/\%20/_/g;
    $image=~s/Image://gi;
    my $res  = $self->_get( $page, 'delete', "&oldimage=$id%21$image" );
    unless ($res) { return; }
    my $options = {
    fields  => {
        wpReason  => $summary,
    },
    };
    $res = $self->{mech}->submit_form( %{$options});
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
#use Data::Dumper;print Dumper($res);
#print $res->decoded_content."\n";
    return $res;
}

=item block($user, $length, $summary, $anononly, $autoblock, $blockaccountcreation, $blockemail, $blocktalk)

Blocks the user with the specified options.  All options optional except $user and $length. Last four are true/false. Defaults to empty summary, all options disabled.

=cut

sub block {
    my $self    = shift;
    my $user    = shift;
    my $length  = shift;
    my $summary = shift;
    my $anononly= shift;
    my $autoblock=shift;
    my $blockac = shift;
    my $blockemail=shift;
    my $blocktalk   = shift;
    my $res;
    my $edittoken;

    if ($self->{'blocktoken'}) {
    $edittoken=$self->{'blocktoken'};
    } else {
    $res = $self->{api}->api( {
        action=>'query',
        titles=>'Main_Page',
        prop=>'info|revisions',
        intoken=>'block' } );
    my ($id, $data)=%{$res->{query}->{pages}};
    $edittoken=$data->{blocktoken};
    $self->{'blocktoken'}=$edittoken;
    }
    my $hash = {
    action=>'block',
    user=>$user,
    token=>$edittoken,
    expiry=>$length,
    reason=>$summary };
    $hash->{anononly}=$anononly if ($anononly);
    $hash->{autoblock}=$autoblock if ($autoblock);
    $hash->{nocreate}=$blockac if ($blockac);
    $hash->{noemail}=$blockemail if ($blockemail);
    $hash->{allowusertalk}=1 if (!$blocktalk);
    $res = $self->{api}->api( $hash );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }

    return $res;
}

=item unblock($user)

Unblocks the user.

=cut

sub unblock {
    my $self    = shift;
    my $user    = shift;
    my $res;
    my $edittoken;
    if ($self->{'unblocktoken'}) {
    $edittoken=$self->{'unblocktoken'};
    } else {
    $res = $self->{api}->api( {
        action=>'query',
        titles=>'Main_Page',
        prop=>'info|revisions',
        intoken=>'unblock' } );
    my ($id, $data)=%{$res->{query}->{pages}};
    $edittoken=$data->{unblocktoken};
    $self->{'unblocktoken'}=$edittoken;
    }
    my $hash = {
    action=>'unblock',
    user=>$user,
    token=>$edittoken};
    $res = $self->{api}->api( $hash );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }

    return $res;
}

=item protect($page, $reason, $editlvl, $movelvl, $time, $cascade)

Protects (or unprotects) the page. $editlvl and $movelvl may be '', 'autoconfirmed', or 'sysop'. $cascade is true/false.

=cut

sub protect {
    my $self    = shift;
    my $page    = shift;
    my $reason  = shift;
    my $editlvl = shift || 'all';
    my $movelvl     = shift || 'all';
    my $time    = shift || 'infinite';
    my $cascade = shift;

    if ($cascade and ($editlvl ne 'sysop' or $movelvl ne 'sysop')) {
    carp "Can't set cascading unless both editlvl and movelvl are sysop."
    }
    my $res = $self->{api}->api( {
        action=>'query',
        titles=>$page,
        prop=>'info|revisions',
        intoken=>'protect' } );
#use Data::Dumper;print STDERR Dumper($res);
    my ($id, $data)=%{$res->{query}->{pages}};
    my $edittoken=$data->{protecttoken};
    my $hash={  action=>'protect',
    title=>$page,
    token=>$edittoken,
    reason=>$reason,
    protections=>"edit=$editlvl|move=$movelvl",
    expiry=>$time };
    $hash->{'cascade'}=$cascade if ($cascade);
    $res = $self->{api}->api( $hash );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }

    return $res;
}

=item get_pages_in_namespace($namespace_id,$page_limit)

Returns an array containing the names of all pages in the specified namespace. The $namespace_id must be a number, not a namespace name. Setting $page_limit is optional. If $page_limit is over 500, it will be rounded up to the next multiple of 500.

=cut

sub get_pages_in_namespace {
    my $self = shift;
    my $namespace = shift;
    my $page_limit = shift || 500;
    my $apilimit=500;
    if ($self->{highlimits}) {
    $apilimit=5000;
    }

    my @return;
    my $max;

    if ($page_limit<=$apilimit) {
    $max=1;
    } else {
    $max=($page_limit-1)/$apilimit+1;
    $page_limit=$apilimit;
    }

    my $res = $self->{api}->list( {
        action=>'query',
        list=>'allpages',
        apnamespace=>$namespace,
        aplimit=>$page_limit },
    { max=>$max } );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    foreach (@{$res}) {
    push @return, $_->{title};
    }
    return @return;
}

=item count_contributions($user)

Uses the API to count $user's contributions.

=cut

sub count_contributions {
    my $self=shift;
    my $username=shift;
    $username=~s/User://i; #strip namespace
    my $res = $self->{api}->list( {
        action=>'query',
        list=>'users',
        ususers=>$username,
        usprop=>'editcount' },
    { max=>1 } );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    my $return = ${$res}[0]->{'editcount'};

    if ($return or $_[0]>1) {
    return $return;
    } else {
    return $self->count_contributions($username, $_[0]+1);
    }
}

=item last_active($user)

Returns the last active time of $user in YYYY-MM-DDTHH:MM:SSZ

=cut

sub last_active {
    my $self=shift;
    my $username=shift;
    unless ($username=~/User:/i) {$username="User:".$username;}
    my $res = $self->{api}->list( {
        action=>'query',
        list=>'usercontribs',
        ucuser=>$username,
        uclimit=>1 },
    { max=>1 } );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    return ${$res}[0]->{'timestamp'};
}

=item recent_edit_to_page($page)

Returns timestamp and username for most recent edit to $page.

=cut

sub recent_edit_to_page {
    my $self=shift;
    my $page=shift;
    my $res = $self->{api}->api( {
        action=>'query',
        prop=>'revisions',
        titles=>$page,
        rvlimit=>1 },
    { max=>1 } );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    my ($id, $data)=%{$res->{query}->{pages}};
    return $data->{revisions}[0]->{timestamp};
}

=item get_users($page, $limit, $revision, $direction)

Gets the most recent editors to $page, up to $limit, starting from $revision and goint in $direction.

=cut

sub get_users {
    my $self      = shift;
    my $pagename  = shift;
    my $limit    = shift || 5;
    my $rvstartid = shift;
    my $direction = shift;

    my @return;
    my @revisions;

    if ( $limit > 50 ) {
    $self->{errstr} = "Error requesting history for $pagename: Limit may not be set to values above 50";
    carp $self->{errstr};
    return 1;
    }
    my $hash = {
    action=>'query',
    prop=>'revisions',
    titles=>$pagename,
    rvprop=>'ids|timestamp|user|comment',
    rvlimit=>$limit
    };

    $hash->{rvstartid}=$rvstartid if ($rvstartid);
    $hash->{rvdir}=$direction if ($direction);

    my $res = $self->{api}->api( $hash );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    my ($id)=keys %{$res->{query}->{pages}};
    my $array=$res->{query}->{pages}->{$id}->{revisions};
    foreach (@{$array}) {
    push @return, $_->{user};
    }
    return @return;
}

=item test_block_hist($user)

Returns 1 if $user has been blocked.

=cut

sub test_block_hist {
    my $self      = shift;
    my $user      = shift;

    $user=~s/User://i;
    my $res = $self->_get("Special:Log&type=block&page=User:$user", "", "", 1);
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    if ($res->decoded_content=~/no matching/i) {
    return 0;
    } else {
    return 1;
    }
}

=item expandtemplates($page[, $text])

Expands templates on $page, using $text if provided, otherwise loading the page text automatically.

=cut

sub expandtemplates {
    my $self    = shift;
    my $page    = shift;
    my $text    = shift || undef;

    unless ($text) {
    $text=$self->get_text($page);
    }

    my $res = $self->_get( "Special:ExpandTemplates" );
    my $options = {
    fields  => {
        contexttitle    => $page,
        input       => $text,
        removecomments  => undef,
    },
    };
    $res = $self->{mech}->submit_form( %{$options});
    $res->decoded_content=~/\<textarea id=\"output\"(.+?)\<\/textarea\>/si;
    return $1;
}

=item undelete($page, $summary)

Undeletes $page with $summary.

=cut

sub undelete {
    my $self    = shift;
    my $page    = shift;
    my $summary = shift;
    my $res  = $self->_get( "Special:Undelete", "", "&target=$page" );
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    if ($res->decoded_content=~/There is no revision history for this page/i) {
    return 1;
    }
    my $options = {
    fields  => {
        wpComment  => $summary,
    },
    };
    $res = $self->{mech}->submit_form( %{$options}, button=>"restore");
    if (!$res) {
    carp "Error code: " . $self->{api}->{error}->{code};
    carp $self->{api}->{error}->{details};
    $self->{error}=$self->{api}->{error};
    return $self->{error}->{code};
    }
    return $res;
}

=item get_allusers($limit)

Returns an array of all users. Default limit is 500.

=cut

sub get_allusers {
    my $self  = shift;
    my $limit = shift;
    my @return = ();

    $limit = 500 unless $limit;

    my $res = $self->{api}->api( { action  =>'query',
        list    =>'allusers',
        aulimit => $limit } );

    for my $ref ( @{$res->{query}->{allusers}} ) {
    push @return, $ref->{name};
    }
    return @return;
}


1;

=back

=head1 ERROR HANDLING

All functions will return an integer error value in any handled error
situation. Error codes are stored in $agent->{error}->{code}, error text
in $agent->{error}->{details}.

=cut

__END__
