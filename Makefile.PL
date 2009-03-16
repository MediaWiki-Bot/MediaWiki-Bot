use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'MediaWiki::Bot',
    VERSION_FROM      => 'lib/MediaWiki/Bot.pm', # finds $VERSION
    PREREQ_PM         => { WWW::Mechanize => '1.30',
			   HTML::Entities => 1.35,
			   URI::Escape    => 3.28,
			   XML::Simple    => 2.16,
			   Carp 	       => 0,
			   Encode         => 0,
			   MediaWiki::API => 0.20,
			   Module::Pluggable => 0 },
	 ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
	 (ABSTRACT_FROM    => 'lib/MediaWiki/Bot.pm', # retrieve abstract from module
    AUTHOR            => 'Perlwikipedia team') : () ),
    LICENSE           => 'gpl',
);
