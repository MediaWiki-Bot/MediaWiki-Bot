use strict;
use MediaWiki::Bot; BEGIN{ *perlwikipedia:: = \%MediaWiki::Bot:: } our $VERSION=$perlwikipedia::VERSION;
1;

=head1 NAME

PWP - Alias for MediaWiki::Bot, previously known as perlwikipedia or PWP

=head1 SYNOPSIS

 perl -Mperlwikipedia -e "$editor=new perlwikipedia"

=head1 DESCRIPTION

See L<MediaWiki::Bot>

=cut

