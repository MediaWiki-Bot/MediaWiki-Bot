
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'File::Find' => '0',
    'File::Temp' => '0',
    'Module::Build' => '0.3601',
    'Test::More' => '0.96',
    'Test::Warn' => '0',
    'utf8' => '0'
  },
  'configure_requires' => {
    'ExtUtils::MakeMaker' => '6.30',
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'a high-level bot framework for interacting with MediaWiki wikis',
  'dist_author' => [
    'Dan Collins <dcollins@cpan.org>',
    'Mike.lifeguard <lifeguard@cpan.org>',
    'Alex Rowe <alex.d.rowe@gmail.com>',
    'Oleg Alexandrov <oleg.alexandrov@gmail.com>',
    'jmax.code <jmax.code@gmail.com>',
    'Stefan Petrea <stefan.petrea@gmail.com>',
    'kc2aei <kc2aei@gmail.com>',
    'bosborne@alum.mit.edu',
    'Brian Obio <brianobio@gmail.com>',
    'patch and bug report contributors'
  ],
  'dist_name' => 'MediaWiki-Bot',
  'dist_version' => 'v3.4.2',
  'license' => 'gpl',
  'module_name' => 'MediaWiki::Bot',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'Carp' => '0',
    'Digest::MD5' => '2.39',
    'Encode' => '0',
    'File::Basename' => '0',
    'HTML::Entities' => '3.28',
    'LWP::Protocol::https' => '0.57',
    'MediaWiki::API' => '0.36',
    'Module::Pluggable' => '0',
    'perl' => '5.008'
  },
  'script_files' => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
