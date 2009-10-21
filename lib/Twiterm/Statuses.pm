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
        twitter => AnyEvent::Twitter->new(
            %{$params{twitter_params}},
        ),
        %{$params{statuses_params}},
        statuses => {},
        users    => {},
        friends  => [],
        mentions => [],
    };

    return bless $self, $class;
}

sub start {
    my $self = shift;
    $log->store('start');

    my $w; $w = $self->{twitter}->reg_cb(
        error => sub {
            my ($twitter, $error) = @_;
            $log->store("error: $error");
            # 400台のレスポンスが返ってきた場合のみ中断
            if ($error =~ /4\d\d/) {
                undef $w;
            }
        },
        statuses_friends => sub {
            my ($twitter, @statuses) = @_;
            $log->store('get friends_timeline');
            $self->_add($self->{friends}, @statuses);
            if (defined $self->{update_cb} &&
                    defined $self->{delegate}) {
                &{$self->{update_cb}}($self->{delegate});
            }
        },
        statuses_mentions => sub {
            my ($twitter, @statuses) = @_;
            $log->store('get mentions');
            $self->_add($self->{mentions}, @statuses);
            if (defined $self->{update_cb} &&
                    defined $self->{delegate}) {
                &{$self->{update_cb}}($self->{delegate});
            }
        },
    );
    # friends_timeline : mentions = 3 : 1
    $self->{twitter}->receive_statuses_friends(3);
    $self->{twitter}->receive_statuses_mentions(1);
    $self->{twitter}->start;
    # 起動時はすべてのタイムラインを取得する
    # 3:1 なら最初は friends_timeline になるので手動で mentions を取得
    $self->{twitter}->_fetch_status_update('mentions', sub {});
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
    my $self = shift;
    return @{$self->{statuses}}{reverse @{$self->{friends}}};
}

sub mentions {
    my $self = shift;
    return @{$self->{statuses}}{reverse @{$self->{mentions}}};
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
