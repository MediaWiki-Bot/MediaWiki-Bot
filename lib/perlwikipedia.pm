use strict;
use warnings;

use MediaWiki::Bot;
BEGIN {
    *perlwikipedia:: = \%MediaWiki::Bot::
}
our $VERSION = $perlwikipedia::VERSION;

=head1 NAME

perlwikipedia - Alias for MediaWiki::Bot, previously known as perlwikipedia or PWP

=head1 SYNOPSIS

    use perlwikipedia;
    my $bot = perlwikipedia->new();

=head1 DESCRIPTION

See L<MediaWiki::Bot>

=cut

1;
