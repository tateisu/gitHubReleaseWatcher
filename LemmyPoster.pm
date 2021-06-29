package LemmyPoster;
use strict;
use warnings;
use utf8;
use feature qw(say);

use Carp;
use URI::Escape;
use Scalar::Util qw(looks_like_number);
use JSON::XS;
use LWP::UserAgent;

sub new{
	my $class = shift;
	my $self = bless { communityIdMap=>{}, @_ }, $class;

	my @errors;
	push @errors,"missing 'host' parameter." unless $self->{host};
	push @errors,"missing 'ua' parameter." unless $self->{ua};
	push @errors,"missing 'auth' parameter, or pair of 'user','password' parameters." unless ($self->{auth} || ($self->{user} && $self->{password}));
	@errors and croak join("\n",@errors);

	return $self;
}

sub encodeQuery($){
    my($hash)=@_;
    return join "&",map{ uri_escape($_)."=".uri_escape($hash->{$_}) } sort keys %$hash;
}

sub lemmyApi{
	my($self,$method,$endpoint,$params)=@_;

	$params and $self->{auth} and $params->{auth} = $self->{auth};

	my($ua,$host)= @{$self}{qw(ua host)};
	
	my $url = "https://$host/api/v3$endpoint";

	my $res;
	if ("GET" eq $method) {
		$params and $url = "$url?".encodeQuery($params);
		say "$method $url";
		$res = $ua->get($url);
	}elsif( "POST" eq $method ){
		my $body = encode_json( $params // {} );
		say "$method $url body=$body";
		$res = $ua->post( $url, "Content-Type" => "application/json", Content => $body );
	}else{
		die "lemmyApi: unknown method $method";
	}
	$res->is_success or die "$method $url\n",$res->status_line;
	$self->{lastContent} = $res->decoded_content;
	return decode_json $res->content;
}

# ログインする
sub login{
	my($self)=@_;
	croak "missing pair of 'user','password' parameters." unless ($self->{user} && $self->{password});

	my $root = $self->lemmyApi(
		"POST",
		"/user/login",
		{ "username_or_email" => $self->{user}, "password" =>$self->{password} }
	);
	my $auth = eval{ $root->{jwt} } 
		or die "can't get auth token. $self->{lastContent}";
	$self->{verbose} and say "auth: $auth";
	$self->{auth} = $auth;
}

# 投稿先のコミュニティーIDを調べる
sub getCommunityId{
	my($self,$commSpec)=@_;

	return 0+$commSpec if looks_like_number $commSpec;

	my $cached = $self->{communityIdMap}{$commSpec};
	$cached and return $cached;

	my $root = $self->lemmyApi(
		"GET",
		"/community",
		{ name => $commSpec }
	);
	my $id = eval{ $root->{community_view}{community}{id} }
		or die "can't get community id for '$commSpec'. $self->{lastContent}";
	$id = 0+$id;

	$self->{verbose} and say "getCommunityId: $commSpec $id";
	$self->{communityIdMap}{$commSpec} = $id;

	return $id;
}

sub post($$$$){
	my($self,$commSpec,$url,$title)=@_;
	say "postLemmy $title $url";

	$self->{auth} or $self->login;
	
	my $communityId = $self->getCommunityId($commSpec);

	# URLで既出チェックする
	my $root = $self->lemmyApi(
		"GET",
		"/search",
		{
			"q" => $url,
			"type_" => "Url",
			"sort" => "TopAll",
			"page" => 1,
			"limit" => 3
		}
	);

	my($postId) = eval{ 
		map{ $_->{post}{ap_id} }
		grep{ $_->{community}{name} eq $commSpec } 
		@{$root->{posts}}
	};
	if($postId){
		say("already exists post $postId for $url.");
		return $postId;
	}

	$root = $self->lemmyApi(
		"POST",
		"/post",
		{
			"community_id" => $communityId,
			"url" => $url,
			"name" => $title,
			"nsfw"=> \0, # false for JSON::XS
		}
	);
	$postId = eval{ $root->{"post_view"}{"post"}{"ap_id"}}
		or die "can't get postId. $self->{lastContent}";

	$self->{verbose} and say("post succeeded. $postId");

	return $postId;
}

1;
