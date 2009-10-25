package Twiterm::Statuses;

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
    my %params = (@_);
    my $self  = {
        %{$params{statuses_params} || {}},
        statuses => {},
        users    => {},
    };

    my $consumer_key    = $params{consumer_key};
    my $consumer_secret = $params{consumer_secret};
    my @accounts = grep { $_->{service} eq 'twitter' } @{$params{accounts}};
    for my $account (@accounts) {
        $self->{twitter}{$account->{id}} = {
            client => AnyEvent::Twitter->new(
                consumer_key    => $consumer_key,
                consumer_secret => $consumer_secret,
                %$account,
            ),
            id       => $account->{id},
            friends  => [],
            mentions => [],
        };
    }

    return bless $self, $class;
}

sub start {
    my $self = shift;
    $log->store('start');

    for my $tw (values %{$self->{twitter}}) {
        my $w; $w = $tw->{client}->reg_cb(
            error => sub {
                my ($twitter, $error) = @_;
                $log->store("error: $error");
                # 401が返ってきた場合のみ中断
                if ($error =~ /401/) {
                    undef $w;
                }
            },
            statuses_friends => sub {
                my ($twitter, @statuses) = @_;
                $log->store("get friends_timeline ($twitter->{id})");
                $self->_add($tw->{friends}, @statuses);
                if (defined $self->{update_cb} &&
                        defined $self->{delegate}) {
                    &{$self->{update_cb}}($self->{delegate});
                }
            },
            statuses_mentions => sub {
                my ($twitter, @statuses) = @_;
                $log->store("get mentions ($twitter->{id})");
                $self->_add($tw->{mentions}, @statuses);
                if (defined $self->{update_cb} &&
                        defined $self->{delegate}) {
                    &{$self->{update_cb}}($self->{delegate});
                }
            },
        );
        # friends_timeline : mentions = 3 : 1
        $tw->{client}->receive_statuses_friends(3);
        $tw->{client}->receive_statuses_mentions(1);
        $tw->{client}->start;
        # 起動時はすべてのタイムラインを取得する
        # 3:1 なら最初は friends_timeline になるので手動で mentions を取得
        $tw->{client}->_fetch_status_update('mentions', sub {});
    }
}

sub update {
    my ($self, $status, $reply_id) = @_;
    $self->{twitter}->update_status(
        $status, sub {
            my ($twitty, $js_status, $error) = @_;
            if (defined $error) {
                $log->store("update error: $error");
            } else {
                my $text = $js_status->{text};
                $log->store(qq/update success! "$text"/);
            }
            if (defined $self->{update_cb} &&
                    defined $self->{delegate}) {
                &{$self->{update_cb}}($self->{delegate});
            }
        },
        $reply_id,
    );
}

sub favorite {
    my $self = shift;
    my $id   = shift;
    my $favorited = $self->status($id)->{favorited};
    my $action    = $favorited ? 'destroy' : 'create';
    # 暫定的に内部データを変更しておく
    $self->{statuses}{$id}{favorited} = !$favorited;
    # 実際のリクエスト
    $log->store($action);
    $self->{twitter}->favorite_status(
        $action, $id, sub {
            my ($twitty, $js_status, $error) = @_;
            if (defined $error) {
                $log->store("favorite error: $error");
            } else {
                if (defined $js_status) {
                    my $text = $js_status->{text};
                    $log->store(qq/$action favorite success! "$text"/);
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

    my @ids = reverse @{$self->{twitter}{$id}{friends}};
    return @{$self->{statuses}}{@ids};
}

sub mentions {
    my ($self, $id) = @_;
    my @ids = reverse @{$self->{twitter}{$id}{mentions}};
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
            screen_name => $status->[0]{screen_name},
            created_at  => $status->[0]{timestamp},
            text        => $text,
            source      => $source,
            id          => $raw_data->{id},
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
    my ($self, $id) = @_;
    return $self->{users}{$id};
}

sub status {
    my ($self, $id) = @_;
    return $self->{statuses}{$id};
}

1;
