package Twiterm::AnyEvent::Twitter;

use AnyEvent::HTTP;
use Carp 'croak';
use Digest::SHA;
use Log::Message;

use base 'AnyEvent::Twitter';

my $log = new Log::Message(
    tag => __PACKAGE__,
);

sub new {
   my $this  = shift;
   my $class = ref ($this) || $this;
   my %param = (@_);
   if (defined $param{access_token}
           && defined $param{access_token_secret}) {
       $log->store('use OAuth');
       $param{username} = '';
       $param{password} = '';
       $param{oauth} = 1;
   } else {
       $log->store('use BASIC Auth');
   }
   my $self  = $class->SUPER::new(%param);

   $log->store('new ok');
   return $self;
}

sub _fetch_status_update {
    my ($self, $statuses_cat, $next_cb, $task) = @_;
    $log->store('_fetch_status_update');
    # BASIC認証の場合はAnyEvent::Twitterのものをそのまま使用
    if (!$self->{oauth}) {
        return $self->SUPER::_fetch_status_update(@_);
    }

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
    $log->store("$url");

    my $request;
    {
        local $Net::OAuth::SKIP_UTF8_DOUBLE_ENCODE_CHECK = 1;
        $request = $self->_make_oauth_request(
            'protected resource',
            request_url    => $url,
            request_method => 'GET',
            token          => $self->{access_token},
            token_secret   => $self->{access_token_secret},
            extra_params   => $args,
        );
        $log->store("$request");
    }

    weaken $self;
    $self->{http_get}->{$category} =
        http_get $request->to_url(), sub {
            my ($data, $hdr) = @_;

            delete $self->{http_get}->{$category};
            #d# warn "FOO: " . JSON->new->pretty->encode ($hdr) . "\n";
            if ($hdr->{Status} =~ /^2/) {
                $self->_analze_statuses ($category, $data);
            } else {
                $self->error ("error while fetching statuses for $category: "
                                  . "$hdr->{Status} $hdr->{Reason}");
            }
            $next_cb->($hdr);
        };
}

sub _make_oauth_request {
    my ($self, $type, %params) = @_;

    my $request = $self->_oauth->request($type)->new(
        version          => '1.0',
        consumer_key     => $self->{consumer_key},
        consumer_secret  => $self->{consumer_secret},
        request_method   => 'GET',
        signature_method => 'HMAC-SHA1',
        timestamp        => time,
        nonce            => Digest::SHA::sha1_base64(time . $$ . rand),
        %params,
    );
    $request->sign;

    return $request;
}

sub _oauth {
    my $self = shift;

    return $self->{_oauth} ||= do {
        eval "use Net::OAuth 0.16";
        croak "Install Net::OAuth for OAuth support" if $@;

        eval '$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A';
        die $@ if $@;

        'Net::OAuth';
    };
}

1;
