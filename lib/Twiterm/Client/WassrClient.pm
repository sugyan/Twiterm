package Twiterm::Client::WassrClient;

use strict;
use warnings;

use AnyEvent::Wassr;
use Date::Parse 'str2time';
use HTML::Entities;
use Log::Message;


my $log = new Log::Message(
    tag => __PACKAGE__,
);

sub new {
    my $class = shift;
    my %params = (@_);
    my $self  = {
        %{$params{statuses_params} || {}},
        statuses => {
            twitter => {},
            wassr   => {},
        },
        users    => {
            twitter => {},
            wassr   => {},
        },
    };

    my $consumer_key    = $params{consumer_key};
    my $consumer_secret = $params{consumer_secret};
    for my $account (@{$params{accounts}}) {
        my $service = $account->{service};
        my $client;
        if ($service eq 'twitter') {
            $client = AnyEvent::Twitter->new(
                consumer_key    => $consumer_key,
                consumer_secret => $consumer_secret,
                %$account,
            );
        }
        if ($service eq 'wassr') {
            $client = AnyEvent::Wassr->new(
                %$account,
                interval => 30,
            );
        }
        $self->{clients}{$account->{id}} = {
            service  => $service,
            client   => $client,
            friends  => [],
            mentions => [],
        };
    }

    return bless $self, $class;
}

sub add_account {
}

sub start {
    my $self = shift;
    $log->store('start');

    for my $client (values %{$self->{clients}}) {
        if ($client->{service} eq 'twitter') {
            my $w; $w = $client->{client}->reg_cb(
                error => sub {
                    my ($twitter, $error) = @_;
                    $log->store("error: $error");
                    # 401が返ってきた場合のみ中断
                    undef $w if $error =~ /401/;
                },
                statuses_friends => sub {
                    my ($twitter, @statuses) = @_;
                    $log->store("get friends_timeline ($twitter->{id})");
                    $self->_add_twitter($client->{friends}, @statuses);
                    if (defined $self->{update_cb} && defined $self->{delegate}) {
                        &{$self->{update_cb}}($self->{delegate});
                    }
                },
                statuses_mentions => sub {
                    my ($twitter, @statuses) = @_;
                    $log->store("get mentions ($twitter->{id})");
                    $self->_add_twitter($client->{mentions}, @statuses);
                    if (defined $self->{update_cb} && defined $self->{delegate}) {
                        &{$self->{update_cb}}($self->{delegate});
                    }
                },
            );
            # friends_timeline : mentions = 3 : 1
            $client->{client}->receive_statuses_friends(3);
            $client->{client}->receive_statuses_mentions(1);
            $client->{client}->start;
            # 起動時はすべてのタイムラインを取得する
            # 3:1 なら最初は friends_timeline になるので手動で mentions を取得
            $client->{client}->_fetch_status_update('mentions', sub {});
        }
        if ($client->{service} eq 'wassr') {
            my $w; $w = $client->{client}->reg_cb(
                error => sub {
                    my ($wassr, $error) = @_;
                    $log->store("error: $error");
                    # 401が返ってきた場合のみ中断
                    undef $w if $error =~ /401/;
                },
                friends_timeline => sub {
                    my ($wassr, @statuses) = @_;
                    $log->store("get friends_timeline ($wassr->{id})");
                    $self->_add_wassr($client->{friends}, @statuses);
                    if (defined $self->{update_cb} && defined $self->{delegate}) {
                        &{$self->{update_cb}}($self->{delegate});
                    }
                },
                replies => sub {
                    my ($wassr, @statuses) = @_;
                    $log->store("get replies ($wassr->{id})");
                    $self->_add_wassr($client->{mentions}, @statuses);
                    if (defined $self->{update_cb} && defined $self->{delegate}) {
                        &{$self->{update_cb}}($self->{delegate});
                    }
                },
            );
            # friends_timeline : mentions = 3 : 1
            $client->{client}->receive_statuses_friends(3);
            $client->{client}->receive_statuses_replies(1);
            $client->{client}->start;
            # 起動時はすべてのタイムラインを取得する
            # 3:1 なら最初は friends_timeline になるので手動で mentions を取得
            $client->{client}->_fetch_status_update('replies', sub {});
        }
    }
}

sub update {
    my ($self, $account_id, $status, $reply_id) = @_;
    $self->{clients}{$account_id}{client}->update_status(
        $status, sub {
            my ($twitty, $js_status, $error) = @_;
            if (defined $error) {
                $log->store("update error: $error");
            } else {
                my $text = $js_status->{text};
                $log->store(qq/$account_id update success! "$text"/);
            }
            if (defined $self->{update_cb} && defined $self->{delegate}) {
                &{$self->{update_cb}}($self->{delegate});
            }
        },
        $reply_id,
    );
}

sub favorite {
    my $self = shift;
    my ($account_id, $id) = @_;
    my $favorited = $self->status($id)->{favorited};
    my $action    = $favorited ? 'destroy' : 'create';
    # 暫定的に内部データを変更しておく
    $self->{statuses}{$id}{favorited} = !$favorited;
    # 実際のリクエスト
    $log->store($action);
    $self->{clients}{$account_id}{client}->favorite_status(
        $action, $id, sub {
            my ($twitty, $js_status, $error) = @_;
            if (defined $error) {
                $log->store("favorite error: $error");
            } else {
                if (defined $js_status) {
                    my $text = $js_status->{text};
                    $log->store(qq/$account_id $action favorite success! "$text"/);
                    # レスポンスを元にデータを更新
                    $self->{statuses}{$js_status->{id}}{favorited} =
                        !$js_status->{favorited};
                }
            }
            if (defined $self->{update_cb} &&
                    defined $self->{delegate}) {
                &{$self->{update_cb}}($self->{delegate});
            }
        },
    );
}

sub friends {
    my ($self, $id) = @_;

    my $client = $self->{clients}{$id};
    my @ids = reverse @{$client->{friends}};
    return @{$self->{statuses}{$client->{service}}}{@ids};
}

sub mentions {
    my ($self, $id) = @_;

    my $client = $self->{clients}{$id};
    my @ids = reverse @{$client->{mentions}};
    return @{$self->{statuses}{$client->{service}}}{@ids};
}

sub _add {
    my ($self, $timeline, @statuses) = @_;

    for my $status (reverse @statuses) {
        $self->{statuses}{wassr}{$status->{rid}} = {
            screen_name => $status->{user_login_id},
            created_at  => $status->{epoch},
            text        => $status->{text},
            user_id     => $status->{user}{screen_name},
            in_reply_to_screen_name => $status->{reply_user_login_id},
        };
        push @$timeline, $status->{rid};
    }
}

sub user {
    my ($self, $id) = @_;
    return $self->{users}{$id};
}

sub status {
    my ($self, $id) = @_;
    return $self->{statuses}{$id};
}

1;
