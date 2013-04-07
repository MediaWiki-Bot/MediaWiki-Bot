
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "a high-level bot framework for interacting with MediaWiki wikis",
  "AUTHOR" => "Dan Collins <dcollins\@cpan.org>, Mike.lifeguard <lifeguard\@cpan.org>, Alex Rowe <alex.d.rowe\@gmail.com>, Oleg Alexandrov <oleg.alexandrov\@gmail.com>, jmax.code <jmax.code\@gmail.com>, Stefan Petrea <stefan.petrea\@gmail.com>, kc2aei <kc2aei\@gmail.com>, bosborne\@alum.mit.edu, Brian Obio <brianobio\@gmail.com>, patch and bug report contributors",
  "BUILD_REQUIRES" => {
    "Module::Build" => "0.3601"
  },
  "CONFIGURE_REQUIRES" => {
    "Module::Build" => "0.3601"
  },
  "DISTNAME" => "MediaWiki-Bot",
  "EXE_FILES" => [],
  "LICENSE" => "gpl",
  "NAME" => "MediaWiki::Bot",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Digest::MD5" => "2.39",
    "Encode" => 0,
    "File::Basename" => 0,
    "HTML::Entities" => "3.28",
    "LWP::Protocol::https" => "0.57",
    "List::Util" => 0,
    "MediaWiki::API" => "0.36",
    "Module::Pluggable" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Find" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "Test::More" => "0.96",
    "Test::NoWarnings" => 0,
    "Test::Warn" => 0,
    "utf8" => 0
  },
  "VERSION" => "5.005006",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



