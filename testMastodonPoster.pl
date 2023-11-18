#!/usr/bin/perl --
use strict;
use warnings;
use utf8;
use feature qw(say);

use LWP::UserAgent;
use Module::Load qw( load );

use FindBin qw( $RealBin );
use lib "$RealBin";

binmode $_,":utf8" for \*STDOUT,\*STDERR;

chdir($RealBin) or die "chdir failed. $! $RealBin";

my $ua = LWP::UserAgent->new( timeout => 30);

my $mastodonPoster;

if( not $mastodonPoster){
	load 'YAML::Syck';
	load 'MastodonPoster';
	{
		no warnings;
		$YAML::Syck::ImplicitUnicode = 1;
	}
	my $configFile = "mastodonPoster.yml";
	my $config = YAML::Syck::LoadFile( $configFile);
	$mastodonPoster = MastodonPoster->new( 
	    %$config
	    ,ua => $ua
	    ,verbose =>1
    );
}

my @lt = localtime;
$lt[5]+=1900;$lt[4]+=1;
my $timeStr = sprintf("%d%02d%02d-%02d%02d%02d",reverse @lt[0..5]);

$mastodonPoster->post(
    status => "test $timeStr",
);
