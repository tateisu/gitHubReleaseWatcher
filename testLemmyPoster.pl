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

my $lemmyPoster;
if( not $lemmyPoster){
	load 'YAML::Syck';
	load 'LemmyPoster';
	{
		no warnings;
		$YAML::Syck::ImplicitUnicode = 1;
	}
	my $lemmyConfig = YAML::Syck::LoadFile( "lemmyPoster.yml");
	$lemmyPoster = LemmyPoster->new( %$lemmyConfig, ua => $ua);
}

my @lt = localtime;
$lt[5]+=1900;$lt[4]+=1;
my $timeStr = sprintf("%d%02d%02d-%02d%02d%02d",reverse @lt[0..5]);

$lemmyPoster->post(
	"sandbox",
	"https://juggler.jp/$timeStr",
	"test $timeStr"
);
