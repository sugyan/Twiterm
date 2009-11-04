package AnyEvent::Wassr;

use base 'Object::Event';
use AnyEvent::HTTP;
use Carp 'croak';
use JSON 'decode_json';
use MIME::Base64;
use Scalar::Util 'weaken';
use Try::Tiny;
use URI::URL;

our $VERSION = '0.1';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(
        @_,
        enable_methods => 1,
    );

    # required arguments
    if (!defined $self->{username}) {
        croak "no 'username' given to AnyEvent::Wassr\n";
    }
    if (!defined $self->{password}) {
        croak "no 'password' given to AnyEvent::Wassr\n";
    }

    # default values
    if (!defined $self->{base_url}) {
        $self->{base_url} = 'http://api.wassr.jp';
    }
    if (!defined $self->{interval}) {
        $self->{interval} = 60;
    }
    if (!defined $self->{state}) {
        $self->{state} = {};
    }

    # invalid
    if ($self->{interval} < 10) {
        croak "invalid value of 'interval'. it must be more than 10\n";
    }

    return $self;
}

sub receive_statuses_friends {
    my ($self, $weight) = @_;

    weaken $self;
    $self->{schedule}{statuses_friends} = {
        wait    => 0,
        weight  => $weight || 1,
        request => sub {
            $self->_fetch_status_update('friends_timeline', @_);
        },
    };
}

sub receive_statuses_replies {
    my ($self, $weight) = @_;

    weaken $self;
    $self->{schedule}{statuses_replies} = {
        wait    => 0,
        weight  => $weight || 1,
        request => sub {
            $self->_fetch_status_update('replies', @_);
        },
    };
}

sub start {
    my $self = shift;

    $self->_tick;
}

sub error {
}

sub update_status {
    my ($self, $status, $done_cb, $reply_id) = @_;

    my $url = URI::URL->new($self->{base_url});
    $url->path_segments('statuses', "update.json");

    $self->_post_data($url, {
        status           => $status,
        reply_status_rid => $reply_id,
        source           => __PACKAGE__,
    }, $done_cb, 'update');
}

sub favorite_status {
    my ($self, $action, $id, $done_cb) = @_;

    my $url = URI::URL->new($self->{base_url});
    $url->path_segments('favorites', $action, "$id.json");

    $self->_post_data($url, {}, $done_cb, "${action}_favorite");
}

sub _tick {
    my $self = shift;

    my $max_task;
    for my $schedule (keys %{$self->{schedule}}) {
        my $task = $self->{schedule}{$schedule};
        $task->{wait} += $task->{weight};

        $max_task = $task if !defined $max_task;
        $max_task = $task if $max_task->{wait} <= $task->{wait};
    }

    return if !defined $max_task;

    weaken $self;
    $max_task->{request}(
        sub { $self->_schedule_next_tick(shift) }, $max_task,
    );
    $max_task->{wait} = 0;
}

sub _fetch_status_update {
    my ($self, $tl_name, $next_cb) = @_;

    my $url = URI::URL->new($self->{base_url});
    $url->path_segments('statuses', $tl_name . '.json');

    weaken $self;
    $self->{http_get}{$statuses} = http_get(
        $url->as_string,
        headers => $self->_get_basic_auth,
        sub {
            my ($data, $headers) = @_;

            delete $self->{http_get}{$statuses};
            if ($headers->{Status} =~ /^2/) {
                $self->event(
                    $tl_name,
                    $self->_analze_statuses($tl_name, $data),
                );
            } else {
                $self->error(
                    "error while fetching statuses for $statuses: "
                        . "$headers->{Status} $headers->{Reason}");
            }
            $next_cb->($headers);
        },
    );
}

sub _post_data {
    my ($self, $url, $param, $done_cb, $api) = @_;

    $url->query_form(%$param);

    weaken $self;
    $self->{http_post}{$api} = http_post(
        $url->as_string,
        undef,
        headers => $self->_get_basic_auth,
        sub {
            my ($data, $headers) = @_;

            delete $self->{http_post}{$api};
            if ($headers->{Status} =~ /^2/) {
                my $json;
                try {
                    $json = decode_json($data);
                } catch {
                    $done_cb->(
                        $self, undef,
                        "error when receiving your post $api "
                            . "and parsing it's JSON: $_");
                    return;
                };
                $done_cb->($self, $json);
            } else {
                $done_cb->(
                    $self, undef,
                    "error while $api: "
                        . "$headers->{Status} $headers->{Reason}");
            }
        },
    );
}

sub _schedule_next_tick {
    my ($self, $headers) = @_;

    $self->_tick and return if !defined $headers;
    my $next_tick = $self->{interval};

    weaken $self;
    $self->{_tick_timer} = AnyEvent->timer(
        after => $next_tick,
        cb    => sub {
            delete $self->{_tick_timer};
            $self->_tick;
        },
    );
}

sub _get_basic_auth {
    my $self = shift;

    my $base64 = encode_base64("$self->{username}:$self->{password}");
    return {
        Authorization => "Basic $base64",
    };
}

sub _analze_statuses {
    my ($self, $tl_name, $raw_data) = @_;

    my $data;
    try {
        $data = decode_json($raw_data);
    } catch {
        $self->error("error while parsing statuses for $status_name: $_");
    };

    my $state = ($self->{state}{statuses}{$tl_name} ||= {});
    my @statuses = grep {
        $_->{epoch} > $state->{epoch};
    } @$data;

    $state->{epoch} = $statuses[0]->{epoch} if @statuses;

    return @statuses;
}

1;
