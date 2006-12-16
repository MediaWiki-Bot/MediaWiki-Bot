package Perlwikipedia;

use strict;
use 5.8.8;
use LWP::UserAgent;
use WWW::Mechanize;

my $agent=LWP::UserAgent->new;
$agent->agent('Perlwikipedia/0.90');
$agent->cookie_jar({file=> '.perlwikipedia-cookies'});

my $mech=WWW::Mechanize->new();
$mech->agent("Perlwikipedia/0.90");
$mech->cookie_jar($agent->cookie_jar());

our $VERSION = '0.90';

my $host='en.wikipedia.org';
my $path='w';

sub new {
	my $self = shift;
	return (bless {}, $self);
}

sub set_wiki {
	my $self=shift;
	($host, $path)=@_;
}

sub login {
	my $self=shift;	
	my $editor=shift;
	my $password=shift;
	
	my $login = HTTP::Request->new(POST => "http://$host/$path/index.php?title=Special:Userlogin&action=submitlogin&type=login");
	$login->content_type('application/x-www-form-urlencoded');
	$login->content("wpName=$editor&wpPassword=$password&wpRemember=1&wpLoginattempt=Log+in");
	my $logger_inner = $agent->request($login);
	
my $do_redirect=HTTP::Request->new(GET =>'http://$host/$path/index.php?title=Special:Userlogin&wpCookieCheck=login');
	my $redirecter= $agent->request($do_redirect);
	my $is_success=$redirecter->content;
	
	if ($is_success=~m/\QYou have successfully signed in to Wikipedia as "$editor".\E/) {
		return "Success";
	}
	elsif ($is_success=~!m/\QYou have successfully signed in to Wikipedia as "$editor".\E/) {
		return "Fail";
	}

	return;
}

sub edit {
	my $self=shift;
	my $page=shift;
	my $summary=shift;
	my $text=shift;

	$mech->get("http://$host/$path/index.php?title=$page&action=edit");
	$mech->form_name('editform');
	$mech->field('wpSummary',$summary);
	$mech->field('wpTextbox1',$text);

	$mech->click_button(name=>'wpSave');
}
sub edit_talk {
	my $self=shift;
	my $user=shift;
	my $summary=shift;
	my $text=shift;

	$mech->get("http://$host/$path/index.php?title=User_talk:$user&action=edit&section=new");
	$mech->form_name('editform');
	$mech->field('wpSummary',$summary);
	$mech->field('wpTextbox1',$text);

	$mech->click_button(name=>'wpSave');
}

sub get_history {
	my $self = shift;
	my $pagename = shift;
	my $type = shift;
	
	my $request=HTTP::Request->new(GET=>"http://$host/$path/api.php?action=query&prop=revisions&titles=$pagename&rvlimit=20&rvprop=user");
	my $response = $agent->request($request);
	my $history  = $response->content;

	$history =~ s/<.+?>//g;
	$history =~ s/&lt;/</g;
	$history =~ s/&gt;/>/g;
	$history =~ s/ anon=""//g;
	$history =~ s/ minor=""//g;

	my @history = split( /\n/, $history );
	my @users;
	my @revids;

	foreach (@history) {
		if ( $_ =~ m/<rev revid="(\d+)" pageid="(\d+)" oldid="(\d+)" user="(.+)" \/>/ ) {

			my $revid = $1;
			my $oldid = $3;
			my $user  = $4;

			push(@users,$user);
			push(@revids,$revid);
		}
	}

	if ($type eq 'users') {
		return @users;
	}
	elsif ($type eq 'revids') {
		return @revids;
	}			

	return;
}

sub grab_text {
	my $self=shift;	
	my $pagename=shift;
	my $revid=shift;

	my $wikitext='';
	my $fetch='';

	if ($revid eq undef) {	
		$fetch = HTTP::Request->new(GET => "http://$host/$path/index.php?title=$pagename&action=edit");
	}
	elsif ($revid ne undef) {
		$fetch = HTTP::Request->new(GET => "http://$host/$path/index.php?title=$pagename&action=edit&oldid=$revid");
	}
	my $response=$agent->request($fetch);
	my $content=$response->content;
	if ($content=~m/cols='80' >(.+)<\/textarea>/s) { $wikitext=$1; }

	$wikitext =~ s/&lt;/</g;
	$wikitext =~ s/&gt;/>/g;
	$wikitext =~ s/&quot;/\"/g;
	$wikitext =~ s/&amp;/&/g;

	return $wikitext;
}

sub revert {
	my $self=shift;	
	my $pagename=shift;
	my $summary=shift;
	my $revid=shift;

	$mech->get("http://$host/$path/index.php?title=$pagename&action=edit&oldid=$revid");

	$mech->form_name('editform');
	$mech->field('wpSummary',$summary);
	$mech->field('wpScrolltop','');
	$mech->field('wpSection','');

	$mech->click_button(name=>'wpSave');
}

sub get_last {
	my $self     = shift;
	my $pagename = shift;
	my $editor   = shift;

	my $revertto = 0;
	my $request = HTTP::Request->new(GET=>"http://$host/$path/api.php?action=query&prop=revisions&titles=$pagename&rvlimit=20&rvprop=user");
	my $response = $agent->request($request);
	my $history  = $response->content;

	$history =~ s/<.+?>//g;
	$history =~ s/&lt;/</g;
	$history =~ s/&gt;/>/g;
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
	my @pagenames;
	my @revids;
	my @oldids;
	my %rc_table;
	
	my $request = new HTTP::Request(GET => 'http://$host/$path/api.php?action=query&list=recentchanges&rcnamespace=0&rclimit=5');
	my $response = $agent->request($request);
	my $contents = $response->content;
	
	$contents =~ s/<.+?>//g;
	$contents =~ s/&lt;/</g;
	$contents =~ s/&gt;/>/g;
	my @rctable = split(/\n/,$contents);
	foreach (@rctable) {
		if (/<rc ns="0" title="(.+)" pageid="\d+" revid="(\d+)" old_revid="(\d+)" type="0" timestamp=".+" \/>/) {

			my $pagename = $1;
			my $revid = $2;
			my $oldid = $3;

			$rc_table{$pagename} = "$revid:$oldid";
		}
	}

	return %rc_table;
}

sub what_links_here {
	my $self = shift;
	my $article = shift;
	my @links;

	$_ = $agent->get("http://$host/$path/index.php?title=Special:Whatlinkshere&target=$article&limit=5000")->content;
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
