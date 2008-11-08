use Test::More;
eval "use Test::Pod::Coverage tests=>1";
plan skip_all("Test::Pod 1.00 required for testing POD") if $@;
pod_coverage_ok( "Perlwikipedia", "Perlwikipedia is covered" );
