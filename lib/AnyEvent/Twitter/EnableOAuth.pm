package AnyEvent::Twitter::EnableOAuth;

use strict;
use warnings;

use base qw/Object::Event/;
use AnyEvent::HTTP;
use Carp 'croak';
use Encode 'encode_utf8';
use Digest::SHA;
use JSON 'decode_json';

sub enable_oauth {
    return if AnyEvent::Twitter->VERSION > 0.26;
    no warnings 'redefine';
    # 引数にusername, password が無くてもOAuth用のtokenがあればnew可能に
    *new = sub {
        my $this  = shift;
        my $class = ref ($this) || $this;
        my $self  = $class->SUPER::new(
            bandwidth      => 0.95,
            @_,
            enable_methods => 1,
        );
        if ($self->{bandwidth} == 0) {
            croak "zero 'bandwidth' is an invalid value!\n";
        }
        $self->{state} ||= {};
        $self->{base_url} = 'http://www.twitter.com'
            unless defined $self->{base_url};

        # OAuthを使用するか否かを決定
        if (defined $self->{consumer_key} &&
                defined $self->{access_token}) {
            $self->{oauth} = do {
                eval "use Net::OAuth 0.16";
                croak "Install Net::OAuth for OAuth support" if $@;

                eval '$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A';
                die $@ if $@;

                'Net::OAuth';
            };
        } else {
            unless (defined $self->{username}) {
                croak "no 'username' given to AnyEvent::Twitter\n";
            }
            unless (defined $self->{password}) {
                croak "no 'password' given to AnyEvent::Twitter\n";
            }
        }

        return $self;
    };
    # update処理のOAuth対応
    *update_status = sub {
        my ($self, $status, $done_cb) = @_;

        my $url = URI::URL->new ($self->{base_url});
        $url->path_segments('statuses', "update.json");

        # http_postの引数を認証方法に応じて変更
        my ($target_url, $body, %params);
        if ($self->{oauth}) {
            my $request = $self->_make_oauth_request(
                request_url    => $url,
                request_method => 'POST',
                token          => $self->{access_token},
                token_secret   => $self->{access_token_secret},
                extra_params   => {
                    status => $status,
                },
            );
            $target_url = $request->normalized_request_url();
            $body       = $request->to_post_body();
        } else {
            my $status_e = encode_utf8 $status;
            $url->query_form(status => $status_e);
            $target_url = $url->as_string;
            $body       = '';
            %params     = (
                headers => { $self->_get_basic_auth },
            );
        }

        weaken $self;
        $self->{http_posts}->{status} =
            http_post $target_url, $body, %params, sub {
                my ($data, $hdr) = @_;
                delete $self->{http_posts}->{status};

                if ($hdr->{Status} =~ /^2/) {
                    my $js;
                    eval {
                        $js = decode_json($data);
                    };
                    if ($@) {
                        $done_cb->($self, undef, undef,
                                   "error when receiving your status update "
                                       . "and parsing it's JSON: $@");
                        return;
                    }
                    $done_cb->($self, $status, $js);
                } else {
                    $done_cb->($self, undef, undef,
                               "error while updating your status: "
                                   . "$hdr->{Status} $hdr->{Reason}");
                }
            };
    };
    # timelineをgetする処理のOAuth対応
    *_fetch_status_update = sub {
        my ($self, $statuses_cat, $next_cb, $task) = @_;

        my $category =
            $statuses_cat =~ /^(.*?)_timeline$/ ? $1 : $statuses_cat;
        my $st = ($self->{state}->{statuses}->{$category} ||= {});
        my $url  = URI::URL->new($self->{base_url});
        $url->path_segments('statuses', $statuses_cat . ".json");
        if (defined $st->{id}) {
            $url->query_form(since_id => $st->{id});
        } else {
            $url->query_form(count => 200); # fetch as many as possible
        }

        # http_getの引数を認証方法に応じて変更
        my ($target_url, %params);
        if ($self->{oauth}) {
            my $request = $self->_make_oauth_request(
                request_url    => $url,
                request_method => 'GET',
                token          => $self->{access_token},
                token_secret   => $self->{access_token_secret},
            );
            $target_url = $request->to_url;
        } else {
            $target_url = $url->as_string;
            %params = (
                headers => { $self->_get_basic_auth },
            );
        }

        weaken $self;
        $self->{http_get}->{$category} =
            http_get $target_url, %params, sub {
                my ($data, $hdr) = @_;
                delete $self->{http_get}->{$category};
                if ($hdr->{Status} =~ /^2/) {
                    $self->_analze_statuses($category, $data);
                } else {
                    $self->error(
                        "error while fetching statuses for $category: "
                            . "$hdr->{Status} $hdr->{Reason}");
                }
                $next_cb->($hdr);
            };
    };
    # OAuth用のリクエスト生成
    *_make_oauth_request = sub {
        my ($self, %params) = @_;

        local $Net::OAuth::SKIP_UTF8_DOUBLE_ENCODE_CHECK = 1;
        my $request = $self->{oauth}->request('protected resource')->new(
            version          => '1.0',
            consumer_key     => $self->{consumer_key},
            consumer_secret  => $self->{consumer_secret},
            signature_method => 'HMAC-SHA1',
            timestamp        => time,
            nonce            => Digest::SHA::sha1_base64(time . $$ . rand),
            %params,
        );
        $request->sign;

        return $request;
    };
    # メソッドの交換
    *AnyEvent::Twitter::new                  = \&new;
    *AnyEvent::Twitter::update_status        = \&update_status;
    *AnyEvent::Twitter::_fetch_status_update = \&_fetch_status_update;
    *AnyEvent::Twitter::_make_oauth_request  = \&_make_oauth_request;
    return 1;
}

*import = \&enable_oauth;

1;
