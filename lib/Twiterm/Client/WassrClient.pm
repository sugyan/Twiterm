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
    my $self  = {
        @_,
        accounts => {},
        statuses => {},
    };

    return bless $self, $class;
}

sub add_account {
    my ($self, $id, $params) = @_;

    $self->{accounts}{$id} = {
        client   => AnyEvent::Wassr->new(
            %$params,
        ),
        friends  => [],
        mentions => [],
    };
}

sub start {
    my $self = shift;
    $log->store('start');

    while (my ($id, $account) = each %{$self->{accounts}}) {
        my $w; $w = $account->{client}->reg_cb(
            error => sub {
                my ($wassr, $error) = @_;
                $log->store("error: $error");
                # 401が返ってきた場合のみ中断
                undef $w if $error =~ /401/;
            },
            friends_timeline => sub {
                my ($wassr, @statuses) = @_;
                $log->store("get friends_timeline ($id)");
                $self->_add($account->{friends}, @statuses);
                if (defined $self->{update_cb} && defined $self->{delegate}) {
                    &{$self->{update_cb}}($self->{delegate});
                }
            },
            replies => sub {
                my ($wassr, @statuses) = @_;
                $log->store("get replies ($id)");
                $self->_add($account->{mentions}, @statuses);
                if (defined $self->{update_cb} && defined $self->{delegate}) {
                    &{$self->{update_cb}}($self->{delegate});
                }
            },
        );
        # friends_timeline : mentions = 3 : 1
        $account->{client}->receive_statuses_friends(3);
        $account->{client}->receive_statuses_replies(1);
        $account->{client}->start;
        # 起動時はすべてのタイムラインを取得する
        # 3:1 なら最初は friends_timeline になるので手動で mentions を取得
        $account->{client}->_fetch_status_update('replies', sub {});
    }
}

sub update {
    my $self = shift;
    my %params = (@_);

    my $status = $params{text};
    return if $status eq '';

    my $account_id = $params{account};
    $log->store('request update...');
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
        $params{reply_to},
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
                    my $text = $status->{text};
                    $log->store(qq/$account_id $action favorite success! "$text"/);
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
        # statusの追加
        $self->{statuses}{$status->{rid}} = {
            id          => $status->{rid},
            screen_name => $status->{user_login_id},
            created_at  => $status->{epoch},
            text        => $status->{text},
            user_id     => $status->{user}{screen_name},
            user_name   => $status->{user_login_id},
            protected   => $status->{user}{protected},
            reply_message       => $status->{reply_message},
            reply_user_nick     => $status->{reply_user_nick},
            reply_user_login_id => $status->{reply_user_login_id},
        };
        # id のみtimelineに追加
        push @$timeline, $status->{rid};
    }
}

sub reply {
    my $self = shift;
    my %params = @_;

    my $status = $params{status};
    my $text = $params{edit}->();
    $self->update(
        account  => $params{account},
        text     => $text,
        reply_to => $status->{id}
    );
}

sub retweet {
}

sub detail_info {
    my ($self, $status) = @_;

    my $user_name = ($status->{protected} ? '(protected) ' : '')
        . sprintf "%s / %s", ($status->{user_name}, $status->{user_id});
    my $reply_to;
    if (defined $status->{reply_user_login_id}) {
        $reply_to = sprintf "%s(%s)",
            ($status->{reply_user_nick}, $status->{reply_user_login_id});
    }
    my $reply_text = $status->{reply_message} || 'private message';

    #TODO reply
    return {
        date => scalar localtime $status->{created_at},
        user => $user_name,
        text => $status->{text},
        reply_to   => $reply_to,
        reply_text => $reply_text,
        user_info  => [],
    };
}

1;
