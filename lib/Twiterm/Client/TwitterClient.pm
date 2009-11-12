package Twiterm::Client::TwitterClient;

use strict;
use warnings;

use AnyEvent::Twitter;
use AnyEvent::Twitter::Extension;
use Date::Parse 'str2time';
use HTML::Entities;
use Log::Message;


my $log = new Log::Message(
    tag => __PACKAGE__,
);

sub new {
    my $class = shift;
    my $self  = {
        @_,
        statuses => {},
        users    => {},
    };

    return bless $self, $class;
}

sub add_account {
    my ($self, $id, $params) = @_;

    $self->{accounts}{$id} = {
        client   => AnyEvent::Twitter->new(
            consumer_key    => $self->{consumer_key},
            consumer_secret => $self->{consumer_secret},
            %$params,
        ),
        friends  => [],
        mentions => [],
    };
}

sub start {
    my $self = shift;
    $log->store('start');

    while (my ($id, $client) = each %{$self->{accounts}}) {
        my $w; $w = $client->{client}->reg_cb(
            error => sub {
                my ($twitter, $error) = @_;
                $log->store("error: $error");
                # 401が返ってきた場合のみ中断
                undef $w if $error =~ /401/;
            },
            statuses_friends => sub {
                my ($twitter, @statuses) = @_;
                $log->store("get friends_timeline ($id)");
                $self->_add($client->{friends}, @statuses);
                if (defined $self->{update_cb} && defined $self->{delegate}) {
                    &{$self->{update_cb}}($self->{delegate});
                }
            },
            statuses_mentions => sub {
                my ($twitter, @statuses) = @_;
                $log->store("get mentions ($id)");
                $self->_add($client->{mentions}, @statuses);
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
}

sub update {
    my ($self, $account_id, $status, $reply_id) = @_;
    $self->{accounts}{$account_id}{client}->update_status(
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
    my ($account_id, $status_id) = @_;
    my $status    = $self->{statuses}{$status_id};
    my $favorited = $status->{favorited};
    my $action    = $favorited ? 'destroy' : 'create';
    # 暫定的に内部データを変更しておく
    $status->{favorited} = !$favorited;
    # 実際のリクエスト
    $log->store($action);
    $self->{accounts}{$account_id}{client}->favorite_status(
        $action, $status_id, sub {
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

    my $client = $self->{accounts}{$id};
    my @ids = reverse @{$client->{friends}};
    return @{$self->{statuses}}{@ids};
}

sub mentions {
    my ($self, $id) = @_;

    my $client = $self->{accounts}{$id};
    my @ids = reverse @{$client->{mentions}};
    return @{$self->{statuses}}{@ids};
}

sub _add {
    my ($self, $timeline, @statuses) = @_;

    for my $status (reverse @statuses) {
        # データのカスタマイズ
        my $raw_data = $status->[1];
        my $text = $status->[0]{text};
        $text =~ s/[\x00-\x1F]/ /xmsg;
        my $source = $raw_data->{source};
        if ($source =~ m!<a \s href.*?>(.*)</a>!xms) {
            $source = $1;
        }
        # statusの追加
        $self->{statuses}{$raw_data->{id}} = {
            id          => $raw_data->{id},
            screen_name => $status->[0]{screen_name},
            created_at  => $status->[0]{timestamp},
            text        => $text,
            source      => $source,
            user_id     => $raw_data->{user}{id},
            favorited   => $raw_data->{favorited},
            in_reply_to_screen_name => $raw_data->{in_reply_to_screen_name},
            in_reply_to_status_id   => $raw_data->{in_reply_to_status_id},
        };
        # userの追加
        $self->{users}{$raw_data->{user}{id}} = $raw_data->{user};
        # id のみtimelineに追加
        push @$timeline, $raw_data->{id};
    }
}

sub user {
    my ($self, $user_id) = @_;
    return $self->{users}{$user_id};
}

sub detail_info {
    my ($self, $status) = @_;

    my $user = $self->{users}{$status->{user_id}};
    my $date_and_client = sprintf "%s - from %s",
        (scalar localtime $status->{created_at}, $status->{source});
    my $user_name = ($user->{protected} ? '(protected) ' : '')
        . sprintf "%s / %s", ($status->{screen_name}, $user->{name});
    my $reply_to = $status->{in_reply_to_screen_name};
    my $reply_text = '';
    if (defined $reply_to) {
        if (my $reply_id = $status->{in_reply_to_status_id}) {
            my $reply_status = $self->{statuses}{$reply_id};
            if (defined $reply_status) {
                $reply_text = $reply_status->{text};
            } else {
                $reply_text = "http://twitter.com/$reply_to/status/$reply_id";
            }
        }
    }
    my $friends_and_followers = sprintf "%d friends, %d followers",
        ($user->{friends_count}, $user->{followers_count});

    return {
        date => $date_and_client,
        user => $user_name,
        text => $status->{text},
        reply_to   => $reply_to,
        reply_text => $reply_text,
        user_info  => [
            $friends_and_followers,
            $user->{location}    || '',
            $user->{url}         || '',
            $user->{description} || '',
        ],
    };
}

1;
