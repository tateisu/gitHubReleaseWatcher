package MastodonPoster;
use 5.32.1;
use strict;
use warnings;

use Carp;
use URI::Escape;
use Scalar::Util qw(looks_like_number);
use JSON::XS;
use LWP::UserAgent;
use Encode;

my $utf8 = Encode::find_encoding("UTF-8");

sub new{
	my $class = shift;
	my $self = bless { communityIdMap=>{}, @_ }, $class;

	my @errors;
	push @errors,"missing 'apiUrlPrefix' parameter." unless $self->{apiUrlPrefix};
	push @errors,"missing 'userAccessToken' parameter." unless $self->{userAccessToken};
	push @errors,"missing 'ua' parameter." unless $self->{ua};
	@errors and croak join("\n",@errors);

	return $self;
}

sub encodeQuery($){
    my($hash)=@_;
    return join "&",map{ uri_escape($_)."=".uri_escape($hash->{$_}) } sort keys %$hash;
}

# methodとpathとパラメータを指定して投稿する
# 応答データをjsonデコードしたものを返す
# - URLの前半は設定ファイルの apiUrlPrefix 
# - 
sub jsonCall{
    my(
        $self,
        $method,
        $path,
        $params,
    ) = @_;
    
    my $url = "$self->{apiUrlPrefix}$path";

    $method = uc $method;
	my $req = HTTP::Request->new($method,$url);

    # 認証トークンがあればヘッダに指定する
	my $accessToken = $self->{userAccessToken};
	if($accessToken){
        $req->header("Authorization","Bearer $accessToken");
    }
    if( 0+ keys %$params){
        if( grep{ $method eq $_} qw(POST PUT) ){
            # パラメータはリクエストボディにjson形式で格納する
        	$req->header("Content-Type","application/json");
        	$req->content( encode_json $params );
        }else{
            # パラメータはリクエストURLに付与する
            # 未実装
            die "not implemented: append parameters to method $method";
        }
    }

    my $res = $self->{ua}->request( $req );
    if($res->is_success){
        $self->{lastContent} = $res->decoded_content;
        return decode_json $res->content;
    }
    my $body = $utf8->decode( $res->content );
    die "ERROR: $method $url\n", $res->status_line,"\nbody=\[$body]";
}


# Mastodonに投稿する
# 引数はmastodonの/api/v1/statusesのフォームパラメータそのもの
# 例 $poster->post( status => "abc" );
sub post{
    my $self = shift;
    my $params = { @_ };

    # 公開範囲が指定されておらず、設定ファイルにデフォルトが指定されていれば補う
    if(not $params->{visibility} ){
        my $postVisibilityDefault = $self->{postVisibilityDefault};
        if( $postVisibilityDefault ){
            $params->{visibility} = $postVisibilityDefault;
        }
    }

    return $self->jsonCall("POST","/api/v1/statuses",$params);
}

1;
