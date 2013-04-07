
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "a high-level bot framework for interacting with MediaWiki wikis",
  "dist_author" => [
    "Dan Collins <dcollins\@cpan.org>",
    "Mike.lifeguard <lifeguard\@cpan.org>",
    "Alex Rowe <alex.d.rowe\@gmail.com>",
    "Oleg Alexandrov <oleg.alexandrov\@gmail.com>",
    "jmax.code <jmax.code\@gmail.com>",
    "Stefan Petrea <stefan.petrea\@gmail.com>",
    "kc2aei <kc2aei\@gmail.com>",
    "bosborne\@alum.mit.edu",
    "Brian Obio <brianobio\@gmail.com>",
    "patch and bug report contributors"
  ],
  "dist_name" => "MediaWiki-Bot",
  "dist_version" => "5.005006",
  "license" => "gpl",
  "module_name" => "MediaWiki::Bot",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Digest::MD5" => "2.39",
    "Encode" => 0,
    "File::Basename" => 0,
    "HTML::Entities" => "3.28",
    "LWP::Protocol::https" => "0.57",
    "List::Util" => 0,
    "MediaWiki::API" => "0.36",
    "Module::Pluggable" => 0,
    "perl" => "5.008",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => [],
  "test_requires" => {
    "File::Find" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "Test::More" => "0.96",
    "Test::NoWarnings" => 0,
    "Test::Warn" => 0,
    "utf8" => 0
  }
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  my $tr = delete $module_build_args{test_requires};
  my $br = $module_build_args{build_requires};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
