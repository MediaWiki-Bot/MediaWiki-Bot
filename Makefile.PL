use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Perlwikipedia',
    VERSION_FROM      => 'lib/Perlwikipedia.pm', # finds $VERSION
    PREREQ_PM         => {
    				WWW::Mechanize => '1.30',
    				HTML::Entities => 1.35,
    				URI::Escape    => 3.28,
    				XML::Simple    => 2.16,
    				Carp 	       => 0,
				Encode         => 0,
				MediaWiki::API => 0.13
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Perlwikipedia.pm', # retrieve abstract from module
       AUTHOR         => 'Perlwikipedia team') : ()),
);
