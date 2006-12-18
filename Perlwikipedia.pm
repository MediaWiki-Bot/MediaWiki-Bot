package Perlwikipedia;

use strict;
use 5.8.8;
use WWW::Mechanize;
use HTML::Entities;
use Carp;
our $version='0.90';

sub new {
	my $package = shift;
	my $self = bless {}, $package;
	$self->{mech}=WWW::Mechanize->new(cookie_jar => {file => '.perlwikipedia_cookies.dat'}, onerror=> sub {carp ''});
	$self->{mech}->agent("Perlwikipedia/$version");
	$self->{host}='en.wikipedia.org';
	$self->{path}='w';

	return $self;
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
	$self->{mech}->get("http://$self->{host}/$self->{path}/index.php?title=Special:Userlogin");
	my $content = $self->{mech}->submit_form(
        form_name => 'userlogin',
        fields    => { 
            wpName => $editor,
            wpPassword => $password,
        },
    )->content;
	if ($content=~m/\QYou have successfully signed in to Wikipedia as "$editor".\E/) {
		return "Success";
	}
	elsif ($content=~!m/\QYou have successfully signed in to Wikipedia as "$editor".\E/) {
		return "Fail";
	}

	return;
}

sub edit {
	my $self=shift;
	my $page=shift;
	my $text=shift;
	my $summary=shift;

	$self->{mech}->get("http://$self->{host}/$self->{path}/index.php?title=$page&action=edit");
	$self->{mech}->form_name('editform');
	$self->{mech}->field('wpSummary',$summary);
	$self->{mech}->field('wpTextbox1',$text);

	$self->{mech}->click_button(name=>'wpSave');
}

sub edit_talk {
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
	
	my $history=$self->{mech}->get("http://$self->{host}/$self->{path}/api.php?action=query&prop=revisions&titles=$pagename&rvlimit=20&rvprop=user|comment")->content;

	decode_entities($history);
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
	my $fetch='';

	if ($revid eq undef) {	
		$fetch = HTTP::Request->new(GET => "http://$self->{host}/$self->{path}/index.php?title=$pagename&action=edit");
	}
	elsif ($revid ne undef) {
		$fetch = HTTP::Request->new(GET => "http://$self->{host}/$self->{path}/index.php?title=$pagename&action=edit&oldid=$revid");
	}
	my $response=$self->{mech}->request($fetch);
	my $content=$response->content;	
	
	if ($content=~/<textarea name='wpTextbox1' .+?>(.+)<\/textarea>/s) {$wikitext=$1;} 

	decode_entities($wikitext);

	return $wikitext;
}

sub revert {
	my $self=shift;	
	my $pagename=shift;
	my $summary=shift;
	my $revid=shift;

	$self->{mech}->get("http://$self->{host}/$self->{path}/index.php?title=$pagename&action=edit&oldid=$revid");

	$self->{mech}->form_name('editform');
	$self->{mech}->field('wpSummary',$summary);
	$self->{mech}->field('wpScrolltop','');
	$self->{mech}->field('wpSection','');

	$self->{mech}->click_button(name=>'wpSave');
}

sub get_last {
	my $self     = shift;
	my $pagename = shift;
	my $editor   = shift;

	my $revertto = 0;
	my $request = HTTP::Request->new(GET=>"http://$self->{host}/$self->{path}/api.php?action=query&prop=revisions&titles=$pagename&rvlimit=20&rvprop=user");
	my $response = $self->{mech}->request($request);
	my $history  = $response->content;

	decode_entities($history);
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
	
	my $history=$self->{mech}->get("http://$self->{host}/$self->{path}/api.php?action=query&list=recentchanges&rcnamespace=0&rclimit=$limit")->content;
	
	decode_entities($history);
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

	$_ = $self->{mech}->get("http://$self->{host}/$self->{path}/index.php?title=Special:Whatlinkshere&target=$article&limit=5000")->content;
	while (/<li><a href=\".+\" title=\"(.+)\">.+<\/a>(.*)<\/li>/g) {
		my $title = $1;
		my $type = $&;
		if ($type !~ /\(redirect page\)/ && $type !~ /\(transclusion\)/) { $type = ""; }
		if ($type =~ /\(redirect page\)/) { $type = "redirect"; }
		if ($type =~ /\(transclusion\)/) { $type = "transclusion"; }
		
		push @links, {title => $title, type => $type};
	}

	return @links;
}

1;


__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

perlwikipedia - a Wikipedia bot framework written in Perl

=head1 SYNOPSIS

  use Perlwikipedia;
  my $editor=Perlwikipedia->new;
  $editor->login('Account','password');
  $editor->revert('Wikipedia:Sandbox','Reverting vandalism','38484848');

=head1 DESCRIPTION

perlwikipedia is a bot framework for Wikipedia that can be used to write bots (you guessed it!).

=head2 EXPORT

None by default.



=head1 SEE ALSO


=head1 AUTHOR

Alex Rowe (alex.d.rowe@gmail.com)

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Alex Rowe

This library is free software; it is distributed under the terms and conditions of the GNU Public License version 2. A copy of the GPLv2 is included with this distribution.

=cut
