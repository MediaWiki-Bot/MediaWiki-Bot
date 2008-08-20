package Perlwikipedia;

use strict;
use WWW::Mechanize;
use HTML::Entities;
use URI::Escape;
use XML::Simple;
use Carp;
use Encode;
use URI::Escape qw(uri_escape_utf8);

our $VERSION = '1.2';

=head1 NAME

Perlwikipedia - a Wikipedia bot framework written in Perl

=head1 SYNOPSIS

use Perlwikipedia;

my $editor = Perlwikipedia->new('Account');
$editor->login('Account', 'password');
$editor->revert('Wikipedia:Sandbox', 'Reverting vandalism', '38484848');

=head1 DESCRIPTION

Perlwikipedia is a framework that can be used to write Wikipedia bots.

Many of the methods use the MediaWiki API (L<http://en.wikipedia.org/w/api.php>).

=head1 AUTHOR

The Perlwikipedia team (Alex Rowe, Jmax, Oleg Alexandrov) and others.

=head1 METHODS

=over 4

=item new([$agent[, $assert[, $operator]]])

Calling Perlwikipedia->new will create a new Perlwikipedia object. $agent sets a custom useragent, $assert sets a parameter for the assertedit extension, common is "&assert=bot", $operator allows the bot to send you a message when it fails an assert. The message will tell you that $agent is logged out, so use a descriptive $agent.

=cut

sub new {
    my $package = shift;
    my $agent   = shift || 'Perlwikipedia'; #user-specified agent or default to 'Perlwikipedia'
    my $assert  = shift || undef;
    my $operator= shift || undef;
    if ($operator) {$operator=~s/User://i;} #strip off namespace

    my $self = bless {}, $package;
    $self->{mech} = WWW::Mechanize->new( cookie_jar => {}, onerror => \&Carp::carp, stack_depth => 1 );
    $self->{mech}->agent("$agent/$VERSION");
    $self->{host}   = 'en.wikipedia.org';
    $self->{path}   = 'w';
    $self->{debug}  = 0;
    $self->{errstr} = '';
    $self->{assert} = $assert;
    $self->{operator}=$operator;
    return $self;
}

sub _get {
    my $self      = shift;
    my $page      = shift;
    my $action    = shift || 'view';
    my $extra     = shift;
    my $no_escape = shift || 0;

    $page = uri_escape_utf8($page) unless $no_escape;

    my $url =
      "http://$self->{host}/$self->{path}/index.php?title=$page&action=$action";
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
    print "Retrieving http://$self->{host}/$self->{path}/api.php?$query\n"
      if $self->{debug};
    my $res =
      $self->{mech}->get("http://$self->{host}/$self->{path}/api.php?$query");
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

set_wiki will cause the Perlwikipedia object to use the wiki specified, e.g set_wiki('de.wikipedia.org','w') will tell Perlwikipedia to use http://de.wikipedia.org/w/index.php. The Perlwikipedia default settings are 'en.wikipedia.org' with a path of 'w'.

=cut

sub set_wiki {
    my $self = shift;
    my $host = shift;
    my $path = shift;
    $self->{host} = $host if $host;
    $self->{path} = $path if $path;
    print "Wiki set to http://$self->{host}/$self->{path}\n" if $self->{debug};
    return 0;
}

=item login($username,$password)

Logs the Perlwikipedia object into the specified wiki. If the login was a success, it will return 'Success', otherwise, 'Fail'.

=cut

sub login {
    my $self     = shift;
    my $editor   = shift;
    my $password = shift;
    my $cookies  = ".perlwikipedia-$editor-cookies";
    $self->{mech}->cookie_jar(
        { file => $cookies, autosave => 1 } );
    if ( !defined $password ) {
        $self->{mech}->{cookie_jar}->load($cookies);
        my $cookies_exist = $self->{mech}->{cookie_jar}->as_string;
        if ($cookies_exist) {
            $self->{mech}->{cookie_jar}->load($cookies);
            print "Loaded MediaWiki cookies from file $cookies\n" if $self->{debug};
            return 0;
        } else {
            $self->{errstr} = "Cannot load MediaWiki cookies from file $cookies";
            carp $self->{errstr};
            return 1;
        }
    }
    my $res = $self->_put(
        'Special:Userlogin',
        {
            form_name => 'userlogin',
            fields    => {
                wpName     => $editor,
                wpPassword => $password,
                wpRemember => 1,
            },
        }
    );
    unless (ref($res) eq 'HTTP::Response' && $res->is_success) { return; }
    my $content = $res->decoded_content();
    if ( $content =~ m/var wgUserName = "$editor"/ ) {
        print qq/Login as "$editor" succeeded.\n/ if $self->{debug};
        return 0;
    } else {
        if ( $content =~ m/There is no user by the name/ ) {
            $self->{errstr} = qq/Login as "$editor" failed: User "$editor" does not exist/;
        } elsif ( $content =~ m/Incorrect password entered/ ) {
            $self->{errstr} = qq/Login as "$editor" failed: Bad password/;
        } elsif ( $content =~ m/Password entered was blank/ ) {
            $self->{errstr} = qq/Login as "$editor" failed: Blank password/;
        }
		carp $self->{errstr} if $self->{debug};
		return 1;
    }
}

=item edit($pagename,$page_text,[$edit_summary],[$is_minor],[$assert])

Edits the specified page $pagename and replaces it with $page_text with an edit summary of $edit_summary, optionally marking the edit as minor if specified, and adding an assertion, if requested. Assertions should be of the form "&assert=user".

=cut

sub edit {
    my $self     = shift;
    my $page     = shift;
    my $text     = shift;
    my $summary  = shift;
    my $is_minor = shift || 0;
    my $assert   = shift || $self->{assert};
    my $res;

    $text = encode( 'utf8', $text );
    $summary = encode( 'utf8', $summary );

    my $options  = {
                    form_name => 'editform',
                    fields    => {
                                  wpSummary   => $summary,
                                  wpTextbox1  => $text,
                                 },
                   };

    $options->{fields}->{wpMinoredit} = 1 if ($is_minor);

    $res = $self->_put($page, $options, $assert);
    if ($res==2 and $self->operator) {
        print "edit failed as $self->agent\n";
        unless ($self->get_text("User 
talk:$self->operator")=~/Error with \Q$self->agent\E/) {
            print "Sending warning!\n";
            $self->edit("User talk:$self->operator", $self->get_text("User talk:$self->operator")."\n\n==Error with $self->agent==\n$self->agent needs to be logged in! ~~~~", '', 0, 
'&assert=');
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

	$pagename = uri_escape_utf8( $pagename );
    my @return;
    my @revisions;

    if ( $limit > 50 ) {
        $self->{errstr} = "Error requesting history for $pagename: Limit may not be set to values above 50";
        carp $self->{errstr} if $self->{debug};
        return 1;
    }
    my $query = "action=query&prop=revisions&titles=$pagename&rvlimit=$limit&rvprop=ids|timestamp|user|comment&format=xml";
    if ( $rvstartid ) {
    	$query .= "&rvstartid=$rvstartid";
    }
    if ( $direction ) {
    	$query .= "&rvdir=$direction";
    }
    my $res = $self->_get_api($query);

    unless (ref($res) eq 'HTTP::Response' && $res->is_success) { return 1; }
    my $xml = XMLin( $res->decoded_content );

    if ( ref( $xml->{query}->{pages}->{page}->{revisions}->{rev} ) eq "HASH" ) {
    	$revisions[0] = $xml->{query}->{pages}->{page}->{revisions}->{rev};
    }
    else {
    	@revisions = @{ $xml->{query}->{pages}->{page}->{revisions}->{rev} };
    }

    foreach my $hash ( @revisions ) {
    	my $revid = $hash->{revid};
    	my $user  = $hash->{user};
    	my ( $timestamp_date, $timestamp_time ) = split( /T/, $hash->{timestamp} );
    	$timestamp_time=~s/Z$//;
    	my $comment = $hash->{comment};
    	push ( @return, {
    		revid 	       => $revid,
    		user           => $user,
    		timestamp_date => $timestamp_date,
    		timestamp_time => $timestamp_time,
    		comment	       => $comment,
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

    my $wikitext = '';
    my $res;

    $res = $self->_get( $pagename, 'edit', "&oldid=$revid&section=$section", $dontescape );
    unless (ref($res) eq 'HTTP::Response' && $res->is_success) { return 1; }
    if ($recurse) {
    	until ( ref($res) eq 'HTTP::Response' && $res->is_success && $res->decoded_content =~ m/var wgAction = "edit"/ ) {
    	    my $real_title;
    	    if ( $res->decoded_content =~ m/var wgTitle = "(.+?)"/ ) {
    	        $real_title = $1;
    	    }
    	    $res = $self->_get( $real_title, 'edit' );
    	}
    }
print $res->decoded_content;
    if ( $res->decoded_content =~ /<textarea.+?\s?>(.{2,})<\/textarea>/s ) {
		$wikitext = $1;
    } elsif ( $res->decoded_content =~ /div class="mw-newarticletext"/ or $res->decoded_content=~/div class="permissions-errors".+id="noarticletext"/) {
		return 2;
    } else {
    	$self->{errstr} = "Could not get_text for $pagename";
        carp $self->{errstr} if $self->{debug};
		return 1;
    }

	return decode_entities($wikitext);
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

    my $res =
      $self->_get_api(
"action=query&prop=revisions&titles=$pagename&rvlimit=20&rvprop=ids|user&rvexcludeuser=$editor&format=xml"
      );
    unless (ref($res) eq 'HTTP::Response' && $res->is_success) { return 1; }
    my $xml = XMLin( $res->decoded_content );
    if( ref( $xml->{query}->{pages}->{page}->{revisions}->{rev} ) eq 'ARRAY' ) {
		$revertto = $xml->{query}->{pages}->{page}->{revisions}->{rev}[0]->{revid};
	}
	else {
		$revertto = $xml->{query}->{pages}->{page}->{revisions}->{rev}->{revid};
	}
    return $revertto;
}

=item update_rc([$limit])

Returns an array containing the Recent Changes to the wiki Main namespace. The array structure contains 'pagename', 'revid', 'oldid', 'timestamp_date', and 'timestamp_time'.

=cut

sub update_rc {
    my $self = shift;
    my $limit = shift || 5;
    my @rc_table;

    my $res =
      $self->_get_api(
        "action=query&list=recentchanges&rcnamespace=0&rclimit=$limit&format=xml");
    unless (ref($res) eq 'HTTP::Response' && $res->is_success) { return 1; }

    my $xml = XMLin( $res->decoded_content );
    foreach my $hash ( @{ $xml->{query}->{recentchanges}->{rc} } ) {
    	my ( $timestamp_date, $timestamp_time ) = split( /T/, $hash->{timestamp} );
    	$timestamp_time =~ s/Z$//;
    	push( @rc_table, {
    			pagename       => $hash->{title},
    			revid	       => $hash->{revid},
    			oldid	       => $hash->{old_revid},
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

    my @pages;
    my $res = $self->_get( $category, 'view' );
    unless (ref($res) eq 'HTTP::Response' && $res->is_success) { return 1; }
    my $content = $res->decoded_content;
    if ($content=~/<div id=\"mw-subcategories\">/i) {
        $content=~s/.+<div id=\"mw-subcategories\">//is;
        while ( $content =~ m{href="(?:[^"]+)/Category:[^"]+">([^<]*)</a></div>}ig )
        {
            push @pages, 'Category:' . $1;
        }
    }
    if ($content=~/<div id=\"mw-pages\">/i) {
	$content=~s/.+<div id=\"mw-pages\">//is;
        while ( $content =~
            m{<li><a href="(?:[^"]+)" title="([^"]+)">[^<]*</a></li>}ig ) {
            push @pages, $1;
        }
        while ( $content =~
            m{<div class="gallerytext">\n<a href="[^"]+" title="([^"]+)">[^<]+</a>}ig ) {
            push @pages, $1;
        }
    }
    while ( ($res = $self->{mech}->follow_link( text => 'next 200' ))  && ref($res) eq 'HTTP::Response' && $res->is_success) {
        sleep 1;    #Cheap hack to make sure we don't bog down the server
        $content = $res->decoded_content();

    if ($content=~/<div id=\"mw-subcategories\">/i) {
        $content=~s/.+<div id=\"mw-subcategories\">//is;
        while ( $content =~ m{href="(?:[^"]+)/Category:[^"]+">([^<]*)</a></div>}ig )
        {
            push @pages, 'Category:' . $1;
        }
    }
    if ($content=~/<div id=\"mw-pages\">/i) {
	$content=~s/.+<div id=\"mw-pages\">//is;
        while ( $content =~
            m{<li><a href="(?:[^"]+)" title="([^"]+)">[^<]*</a></li>}ig ) {
            push @pages, $1;
        }
        while ( $content =~
            m{<div class="gallerytext">\n<a href="[^"]+" title="([^"]+)">[^<]+</a>}ig ) {
            push @pages, $1;
        }
    }
    }
    return @pages;
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
	my $res = $self->_get_api("action=query&meta=siteinfo&siprop=namespaces&format=xml");
	my $xml = XMLin( $res->decoded_content );

	foreach my $id ( keys %{ $xml->{query}->{namespaces}->{ns} } ) {
		$return{$id} = $xml->{query}->{namespaces}->{ns}->{$id}->{content};
	}
	return %return;
}

=item links_to_image($page)

Gets a list of pages which include a certain image.

=cut

sub links_to_image {
	my $self	= shift;
	my $page	= shift;
	my $url = "http://$self->{host}/$self->{path}/index.php?title=$page";
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
	my $self	  = shift;
	my $user	  = shift;

	my $res = $self->_get("Special%3AIpblocklist&ip=$user", "", "", 1);
	if ($res->decoded_content=~/not blocked/i) {
		return 0;
	} else {
		return 1;
	}
}

=item test_image_exists($page)

Checks if an image exists at $page. 0 means no, 1 means yes, local, 2 means on commons.

=cut

sub test_image_exists {
	my $self	= shift;
	my $page	= shift;

	my $res = $self->_get($page);
	if ($res->decoded_content=~/No file by this name exists/i) {
	return 0;
	} elsif ($res->decoded_content=~/This is a file from the \<a href=.+commons:Main_Page"\>Wikimedia Commons/is) {
	return 2;
	} else {
	return 1;
	}
}

=item delete_page($page[, $summary])

Deletes the page with the specified summary.

=cut

sub delete_page {
	my $self	= shift;
	my $page	= shift;
	my $summary = shift;
	my $res	 = $self->_get( $page, 'delete' );
	unless ($res) { return; }
	my $options = {
		   fields	=> {
				wpReason  => $summary,
			},
		};
	$res = $self->{mech}->submit_form( %{$options});
	return $res;
}

=item delete_old_image($page, $revision[, $summary])

Deletes the specified revision of the image with the specified summary.

=cut

sub delete_old_image {
	my $self	= shift;
	my $page	= shift;
	my $id	= shift;
	my $summary = shift;
	my $image	= $page;
	$image=~s/\s/_/g;
	$image=~s/\%20/_/g;
	$image=~s/Image://gi;
	my $res	 = $self->_get( $page, 'delete', "&oldimage=$id%21$image" );
	unless ($res) { return; }
	my $options = {
		   fields	=> {
				wpReason  => $summary,
			},
		};
	$res = $self->{mech}->submit_form( %{$options});
	return $res;
}

=item block($user, $length, $summary, $anononly, $autoblock, $blockaccountcreation, $blockemail)

Blocks the user with the specified options.  All options optional except $user and $length. Last four are true/false. Defaults to empty summary, all options disabled.

=cut

sub block {
	my $self	= shift;
	my $user	= shift;
	my $length  = shift;
	my $summary = shift;
	my $anononly= shift;
	my $autoblock=shift;
	my $blockac = shift;
	my $blockemail=shift;
	my $res	 = $self->_get( "Special:Blockip/$user" );
	unless ($res) { return; }
	my $options = {
		   fields	=> {
				wpBlockAddress  => $user,
				wpBlockExpiry  => 'other',
				wpAnonOnly  => $anononly,
				wpCreateAccount => $blockac,
				wpEnableAutoblock => $autoblock,
				wpEmailBan => $blockemail,
				wpBlockReason  => $summary,
				wpBlockOther  => $length,
			},
		};
	$res = $self->{mech}->submit_form( %{$options});
	return $res;
}

=item protect($page, $reason, $editlvl, $movelvl, $time, $cascade)

Protects (or unprotects) the page. $editlvl and $movelvl may be '', 'autoconfirmed', or 'sysop'. $cascade is true/false.

=cut

sub protect {
	my $self	= shift;
	my $page	= shift;
	my $reason	= shift;
	my $editlvl	= shift;
	my $movelvl = shift;
	my $time	= shift;
	my $cascade	= shift;
	my $res	 = $self->_get( $page, 'protect' );
	unless ($res) { return; }
	my $options = {
		   fields	=> {
				'mwProtect-level-edit'  => $editlvl,
				'mwProtect-level-move'  => $movelvl,
#				'mwProtectUnchained'  => 1,
#				'mwProtect-cascade' => $cascade,
				'mwProtect-expiry' => $time,
				'mwProtect-reason' => $reason,
			},
		};
	$res = $self->{mech}->submit_form( %{$options});
	return $res;
}

=item get_pages_in_namespace($namespace_id,$page_limit)

Returns an array containing the names of all pages in the specified namespace. The $namespace_id must be a number, not a namespace name. Setting $page_limit is optional.

=cut

sub get_pages_in_namespace {
	my $self = shift;
	my $namespace = shift;
	my $page_limit = shift;

 	my @return;
	my $query;

	if ($page_limit) {
		$query = "action=query&list=allpages&apnamespace=$namespace&format=xml&aplimit=$page_limit";
	} else {
		$query = "action=query&list=allpages&apnamespace=$namespace&format=xml";
	}  
	  
 	my $res = $self->_get_api($query);
	return 1 unless ( ref($res) eq 'HTTP::Response' && $res->is_success );
 	my $xml = XMLin( $res->decoded_content );

	# If more than 1 page is found then their corresponding hashes are stored in
	# an array but if 1 page is found it is stored in a single hash, no array.
	my $pages = $xml->{query}->{allpages}->{p};
	if ( ref $pages eq "ARRAY" ) {
		foreach my $page ( @$pages ) {
			push @return, $page->{title};
		} 
	} elsif (ref $pages eq "HASH" ) {
		push @return, $pages->{title};
	}
	@return;
}

=item count_contributions($user)

Uses the API to count $user's contributions.

=cut

sub count_contributions {
	my $self=shift;
	my $username=shift;
	$username=~s/User://i; #strip namespace
	my $res = $self->{mech}->get("http://$self->{host}/$self->{path}/query.php?what=contribcounter&titles=User:$username&format=xml");
	if ($res->is_success()) {
		$res->content=~/<count>(.+?)<\/count>/i;
		return $1;
	} else {
		carp "Error requesting contribs for $username: ".$res->status_line();
		return 0;
	}
}

=item last_active($user)

Returns the last active time of $user in YYYY-MM-DDTHH:MM:SSZ

=cut

sub last_active {
	my $self=shift;
	my $username=shift;
	unless ($username=~/User:/i) {$username="User:".$username;}
	my $res = $self->{mech}->get("http://$self->{host}/$self->{path}/query.php?what=usercontribs&titles=$username&uclimit=1&format=xml");
	if ($res->is_success()) {
		$res->content=~/timestamp="(.+?)"/i;
		return $1;
	} else {
		carp "Error requesting contribs for $username: ".$res->status_line();
		return 0;
	}
}

=item recent_edit_to_page($page)

Returns timestamp and username for most recent edit to $page.

=cut

sub recent_edit_to_page {
	my $self=shift;
	my $page=shift;
	my $res = $self->{mech}->get("http://$self->{host}/$self->{path}/query.php?what=revisions&titles=$page&rvlimit=1&format=xml");
	if ($res->is_success()) {
		$res->content=~/timestamp="(.+?)"/i;
		my $timestamp=$1;
		$res->content=~/user="(.+?)"/i;
		return ($timestamp, $1);
	} else {
		carp "Error requesting contribs for $page: ".$res->status_line();
		return 1;
	}
}

=item get_users($page, $limit, $revision, $direction)

Gets the most recent editors to $page, up to $limit, starting from $revision and goint in $direction.

=cut

sub get_users {
	my $self	  = shift;
	my $pagename  = shift;
	my $limit	 = shift || 5;
	my $rvstartid = shift || '';
	my $direction = shift;

	my @return;
	my @revisions;
	
	if ( $limit > 50 ) {
		$self->{errstr} = "Error requesting history for $pagename: Limit may not be set to values above 50";
		carp $self->{errstr};
		return 1;
	}
	my $query = "action=query&prop=revisions&titles=$pagename&rvlimit=$limit&rvprop=ids|timestamp|user|comment&format=xml";
	if ( $rvstartid ) {
		$query .= "&rvstartid=$rvstartid";
	}
	if ( $direction ) {
		$query .= "&rvdir=$direction";
	}
	my $res = $self->_get_api($query);

	unless ($res) { return 1; }
	my $xml = XMLin( $res->decoded_content );

	unless ($xml->{query}->{pages}->{page}->{revisions}->{rev}) {return}

	if ( ref( $xml->{query}->{pages}->{page}->{revisions}->{rev} ) eq "HASH" ) {
		$revisions[0] = $xml->{query}->{pages}->{page}->{revisions}->{rev};
	}
	else {
		@revisions = @{ $xml->{query}->{pages}->{page}->{revisions}->{rev} };
	}
	
	foreach my $hash ( @revisions ) {
		my $revid = $hash->{revid};
		my $user  = $hash->{user};
		my ( $timestamp_date, $timestamp_time ) = split( /T/, $hash->{timestamp} );
		$timestamp_time=~s/Z$//;
		my $comment = $hash->{comment};
		unless ($user=~/[^0123456789\s]/) {next}
		push ( @return, $user );
	}
	return @return;
}

=item test_block_hist($user)

Returns 1 if $user has been blocked.

=cut

sub test_block_hist {
	my $self	  = shift;
	my $user	  = shift;

	$user=~s/User://i;
	my $res = $self->_get("Special:Log&type=block&page=User:$user", "", "", 1);
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
	my $self	= shift;
	my $page	= shift;
	my $text	= shift || undef;

	unless ($text) {
		$text=$self->get_text($page);
	}

	my $res = $self->_get( "Special:ExpandTemplates" );
	my $options = {
		fields	=> {
			contexttitle	=> $page,
			input		=> $text,
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
	my $self	= shift;
	my $page	= shift;
	my $summary = shift;
	my $res	 = $self->_get( "Special:Undelete", "", "&target=$page" );
	unless ($res) { return; }
	if ($res->decoded_content=~/There is no revision history for this page/i) {
		return 1;
	}
	my $options = {
		   fields	=> {
				wpComment  => $summary,
			},
		};
	$res = $self->{mech}->submit_form( %{$options}, button=>"restore");
	return $res;
}

1;

=back

=head1 ERROR HANDLING

All Perlwikipedia functions will return either 0 or 1 if they do not return data. If an error occurs in a function, $perlwikipedia_object->{errstr} is set to the error message and the function will return 1. A robust bot should check $perlwikipedia_object->{errstr} for messages after performing any action with the object.

=cut

__END__

