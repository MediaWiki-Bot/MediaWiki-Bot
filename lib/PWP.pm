use strict;
use MediaWiki::Bot; BEGIN{ *PWP:: = \%MediaWiki::Bot:: } our $VERSION=$PWP::VERSION;
1;

=head1 NAME

PWP - Alias for Perlwikipedia, now known as MediaWiki::Bot

=head1 SYNOPSIS

 perl -MPWP -e "$editor=new PWP"

=head1 DESCRIPTION

See L<MediaWiki::Bot>

=cut

