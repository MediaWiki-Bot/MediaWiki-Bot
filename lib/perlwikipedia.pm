use strict;
use warnings;

use MediaWiki::Bot;
BEGIN {
    warnings::warn('deprecated', 'perlwikipedia is a deprecated alias for MediaWiki::Bot. '
        . 'Please use the modern name; this one will be removed in a future release');
    *perlwikipedia:: = \%MediaWiki::Bot::
}
our $VERSION = $perlwikipedia::VERSION;

=head1 NAME

perlwikipedia - Alias for MediaWiki::Bot, previously known as perlwikipedia or PWP

=head1 SYNOPSIS

    use MediaWiki::Bot;
    my $bot = MediaWiki::Bot->new();

=head1 DESCRIPTION

See L<MediaWiki::Bot>

=cut

1;
