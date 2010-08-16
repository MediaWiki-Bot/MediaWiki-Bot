use strict;
use warnings;

use MediaWiki::Bot;
BEGIN {
    *PWP:: = \%MediaWiki::Bot::
}
our $VERSION = $PWP::VERSION;

=head1 NAME

PWP - Alias for MediaWiki::Bot, previously known as perlwikipedia or PWP

=head1 SYNOPSIS

    use PWP;
    my $bot = PWP->new();

=head1 DESCRIPTION

See L<MediaWiki::Bot>

=cut

1;
