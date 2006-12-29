package Perlwikipedia;

use strict;
use WWW::Mechanize;
use HTML::Entities;
use URI::Escape;
use Carp;


our $VERSION = '0.90';

sub new {
	my $package = shift;
	my $self = bless {}, $package;
	$self->{mech}=WWW::Mechanize->new(cookie_jar => {file => '.perlwikipedia_cookies.dat'}, onerror=> \&Carp::carp);
	$self->{mech}->agent("Perlwikipedia/$VERSION");
	$self->{host}='en.wikipedia.org';
	$self->{path}='w';

	return $self;
}

sub _get {
    my $self = shift;
    my $page = shift;
    my $action = shift || 'view';
    my $extra = shift;
    $page = uri_escape($page);
    my $url = "http://$self->{host}/$self->{path}/index.php?title=$page&action=$action";
    $url .= $extra if $extra;
    my $res = $self->{mech}->get($url);
    if ($res->is_success()) {
        return $res;
    } else {
        carp "Error requesting $page: ".$res->status_line();
        return;
    }
}

sub _get_api {
    my $self = shift;
    my $query = shift;
    my $res = $self->{mech}->get("http://$self->{host}/$self->{path}/api.php?$query");
    if ($res->is_success()) {
        return $res;
    } else {
        carp "Error requesting api.php?$query: ".$res->status_line();
        return;
    }
}

sub _put {
    my $self = shift;
    my $page = shift;
    my $options = shift;
    my $extra = shift;
    my $res = $self->_get($page, 'edit', $extra);
    return $self->{mech}->submit_form(%{$options});
}



sub set_wiki {
	my $self=shift;
	$self->{host}=shift;
	$self->{path}=shift;
}

sub login {
	my $self = shift;	
	my $editor = shift;
	my $password = shift;
    
	my $res = $self->_put('Special:Userlogin', { 
        form_name => 'userlogin',
        fields => {
            wpName => $editor,
            wpPassword => $password,
        },
    });
    my $content = $res->decoded_content();
	if ($content =~ m/\QYou have successfully signed in to Wikipedia as "$editor".\E/) {
		return "Success";
	} else {
		return "Fail";
	}
}

sub edit {
	my $self=shift;
	my $page=shift;
	my $text=shift;
	my $summary=shift;
    my $is_minor = shift || 0;

	return $self->_put($page, {
        form_name => 'editform',
        fields => {
            wpSummary => $summary,
            wpTextbox1 => $text,
            
        },
    });
}

sub edit_talk { # is this really necessary? -- Jmax
	my $self=shift;
	my $user=shift;
	my $summary=shift;
	my $text=shift;

	$self->{mech}->get("http://$self->{host}/$self->{path}/index.php?title=User_talk:$user&action=edit&section=new");
	$self->{mech}->form_name('editform');
	$self->{mech}->field('wpSummary',$summary);
	$self->{mech}->field('wpTextbox1',$text);

	$self->{mech}->click_button(name=>'wpSave');
}

sub get_history {
	my $self = shift;
	my $pagename = shift;
	my $type = shift;
	
	my $res = $self->_get_api("action=query&prop=revisions&titles=$pagename&rvlimit=20&rvprop=user|comment");
    my $history = $res->content;

	$history =~ s/ anon=""//g;
	$history =~ s/ minor=""//g;

	my @history = split( /\n/, $history );
	my @users;
	my @revids;
	my @comments;
	foreach (@history) {
		if ( $_ =~ m/<rev revid="(\d+)" pageid="(\d+)" oldid="(\d+)" user="(.+)"/ ) {

			my $revid = $1;
			my $oldid = $3;
			my $user  = $4;

			push(@users,$user);
			push(@revids,$revid);
			if (/comment="(.+)"/) {
				my $comment=$1;
				push @comments,$comment;
			}
		}
	}

	if ($type eq 'users') {
		return @users;
	}
	elsif ($type eq 'revids') {
		return @revids;
	}			
	elsif ($type eq 'comments') {
		return @comments;
	}
	
	return;
}

sub get_text {
	my $self=shift;	
	my $pagename=shift;
	my $revid=shift;

	my $wikitext='';
	my $res;

	if ($revid eq undef) {	
		$res = $self->_get($pagename, 'edit');
	} else {
        $res = $self->_get($pagename, 'edit', "&oldid=$revid");
	}

        if(($res->content) =~ /<textarea.+?\s?>(.+)<\/textarea>/s) {$wikitext=$1;} else { carp "Could not get_text for $pagename!";}
	return decode_entities($wikitext);

}

sub revert {
	my $self=shift;	
	my $pagename=shift;
	my $summary=shift;
	my $revid=shift;
    
    return $self->_put($pagename, "&oldid=$revid", {
        form_name => 'editform',
        fields => {
            wpSummary => $summary,
            wpScrolltop => '',
            wpSection => '',
        },
    });
}

sub get_last {
	my $self     = shift;
	my $pagename = shift;
	my $editor   = shift;

	my $revertto = 0;

    my $res = $self->_get_api("action=query&prop=revisions&titles=$pagename&rvlimit=20&rvprop=user");
    my $history = decode_entities($res->content);
	
    $history =~ s/ anon=""//g;
	$history =~ s/ minor=""//g;
	my @history = split( /\n/, $history );

	foreach (@history) {
		if ( $_ =~ m/<rev revid="(\d+)" pageid="(\d+)" oldid="(\d+)" user="(.+)" \/>/ ) {
			my $revid = $1;
			my $oldid = $3;
			my $user  = $4;

			if ( $user ne $editor ) {
				$revertto=$revid;
				return $revertto;
			}
		}
	}

	return $revertto;
}

sub update_rc {
	my $self=shift;
	my $limit=shift || 5;
	my @pagenames;
	my @revids;
	my @oldids;
	my @rc_table;
	
    my $res = $self->_get_api("action=query&list=recentchanges&rcnamespace=0&rclimit=$limit");
    my $history = decode_entities($res->content);

	my @content = split(/\n/,$history);
	foreach (@content) {
		if (/<rc ns="0" title="(.+)" pageid="\d+" revid="(\d+)" old_revid="(\d+)" type="0" timestamp=".+" \/>/) {

			my $pagename = $1;
			my $revid = $2;
			my $oldid = $3;
			push @rc_table, {pagename=>$pagename, revid=>$revid, oldid=>$oldid};
			
		}
	}

	return @rc_table;
}

sub what_links_here {
	my $self = shift;
	my $article = shift;
	my @links;

	my $res = $self->_get('Special:Whatlinkshere', 'view', "&target=$article&limit=5000");
    my $content = $res->content;
	while ($content =~ m/<li><a href=\".+\" title=\"(.+)\">.+<\/a>(.*)<\/li>/g) {
		my $title = $1;
		my $type = $&;
		if ($type !~ /\(redirect page\)/ && $type !~ /\(transclusion\)/) { $type = ""; }
		if ($type =~ /\(redirect page\)/) { $type = "redirect"; }
		if ($type =~ /\(transclusion\)/) { $type = "transclusion"; }
		
		push @links, {title => $title, type => $type};
	}

	return @links;
}

sub get_pages_in_category {
    my $self = shift;
    my $category = shift;

    my @pages;
    my $res = $self->_get($category, 'view');
    my $content = $res->content;
    while ($content =~ m{href="(?:[^"]+)/Category:[^"]+">([^<]*)</a></div>}ig) {
        push @pages, 'Category:'.$1;
    }
    while ($content =~ m{<li><a href="(?:[^"]+)" title="([^"]+)">[^<]*</a></li>}ig) {
        push @pages, $1;
    }
    while (my $res = $self->{mech}->follow_link(text => 'next 200')) {
        my $content = $res->content;
        while ($content =~ m{<li><a href="(?:[^"]+)" title="([^"]+)">[^<]*</a></li>}ig) {
            push @pages, $1;
        }
    }
    return @pages;
}

sub get_all_pages_in_category {
    my $self = shift;
    my $base_category = shift;
    my @first = $self->get_pages_in_category($base_category);
    my %data;
    foreach my $page (@first) {
        $data{ $page } = '';
        if ($page =~ /^Category:/) {
            my @pages = $self->get_pages_in_category($page);
            foreach (@pages) {
                $data{ $_ } = '';
            }
        }
    }
    return keys %data;
}

sub purge_page {
    my $self=shift;
    my $page=shift;
    my $res = $self->_get($page,'purge');
}
1;


__END__

=head1 NAME

perlwikipedia - a Wikipedia bot framework written in Perl

=head1 SYNOPSIS

  use Perlwikipedia;

  my $editor = Perlwikipedia->new;
  $editor->login('Account', 'password');
  $editor->revert('Wikipedia:Sandbox', 'Reverting vandalism', '38484848');

=head1 DESCRIPTION

perlwikipedia is a bot framework for Wikipedia that can be used to write 
bots (you guessed it!).  Information and policy on bots on the english 
Wikipedia can be found at L<http://en.wikipedia.org/wiki/WP:BOT>

=head1 AUTHOR

Alex Rowe (alex.d.rowe@gmail.com)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Alex Rowe

This library is free software; it is distributed under the terms and conditions of the GNU Public License version 2. A copy of the GPLv2 is included with this distribution.

=cut
