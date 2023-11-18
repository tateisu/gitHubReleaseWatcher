#!/usr/bin/perl --
use v5.34.0;
use strict;
use warnings;
use utf8;
use feature qw(say);
use LWP::UserAgent;
use JSON::XS;
use DateTime::Format::ISO8601;
use Data::Dump qw(dump);
use URI::Escape;
use Module::Load qw( load );
use Getopt::Long;
use FindBin qw( $RealBin );
use lib "$RealBin";

binmode $_,":utf8" for \*STDOUT,\*STDERR;

my $verbose = 0;
GetOptions("verbose:+"=>\$verbose) or die "bad options.";

my @repoNames = qw(
    matrix-org/synapse
    vector-im/element-web
    coturn/coturn
    LemmyNet/lemmy
    mastodon/mastodon
    redis/redis
);
# LemmyNet/lemmy-ui はタグだけ打っててリリースしないからチェックをやめる

chdir($RealBin) or die "chdir failed. $! $RealBin";

my $iso8601 = DateTime::Format::ISO8601->new;
my $ua = LWP::UserAgent->new( timeout => 30);
my $lemmyPoster =undef;

# return true if not $b or $a > $b
sub newer($$){
    my($a,$b)=@_;
    return 1 if not $b;
    my $adt = $iso8601->parse_datetime($a->{created_at});
    my $bdt = $iso8601->parse_datetime($b->{created_at});

    my $i = DateTime->compare( $adt, $bdt );
    return $i > 0;
}

sub safeName($){
	my($a)=@_;
	$a =~ s/[\\\/:*?"<>|_]+/_/g;
	$a;
}
mkdir "check";

for my $repoName (@repoNames){
	# https://developer.github.com/v3/repos/releases/
	my $url = "https://api.github.com/repos/$repoName/releases";
	my $res = $ua->get($url,'Accept' => 'application/vnd.github.v3+json');
	$res->is_success or die "$url\n",$res->status_line;
	
	my $list = decode_json $res->content;

	my $latest;
	for my $item (@$list){
		next if $item->{prerelease};
		$latest = $item if newer $item,$latest;
	}
	if( not $latest){
		warn "missing latest: $repoName\n";
		print dump($latest);
		next;
	}

	my $name = $latest->{name};
	$name =~ s/\A\s+//;
	$name =~ s/\s+\z//;
	$verbose and say "$repoName $name";

	$url = $latest->{ html_url };
	my $checkFile = "check/".safeName($url);
	next if -e $checkFile;
	
	if( not $lemmyPoster){
		load 'YAML::Syck';
		load 'LemmyPoster';
		{
			no warnings;
			$YAML::Syck::ImplicitUnicode = 1;
		}
		my $lemmyConfig = YAML::Syck::LoadFile( "lemmyPoster.yml");
		die "missing 'community' in lemmyPoster.yml" unless $lemmyConfig->{community};

		$lemmyPoster = LemmyPoster->new( %$lemmyConfig, ua => $ua ,verbose=>$verbose);
	}

	$lemmyPoster->post(
		$lemmyPoster->{community},
		$url,
		"$repoName $name"
	);

	open(my $fh,">:raw",$checkFile) or die "$! $checkFile";
	close($fh) or die "$! $checkFile";
}
