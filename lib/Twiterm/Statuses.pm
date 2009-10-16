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
            bandwidth => 0.1,
        ),
        %{$params{statuses_params}},
        friends  => {},
        mentions => {},
        users    => {},
    };

    return bless $self, $class;
}

sub start {
    my $self = shift;
    $log->store('start');

    my $w; $w = $self->{twitter}->reg_cb(
        error => sub {
            my ($twitter, $error) = @_;
            $log->store('error');
            undef $w;
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
    );
    $self->{twitter}->receive_statuses_friends;
    $self->{twitter}->start;
}

sub update {
    my $self = shift;
    my $status = shift;
    $self->{twitter}->update_status(
        $status,
        sub {
            my ($twitty, $status, $js_status, $error) = @_;
            $status =~ s/[\x00-\x1F]/ /xmsg;
            $log->store("update status: $status");
            if (defined $error) {
                $log->store("update error: $error");
            } else {
                $log->store('update success');
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
    return $self->_sorted(values %{$self->{friends}});
}

sub mentions {
    my $self = shift;
    return $self->_sorted(values %{$self->{mentions}});
}

sub _add {
    my ($self, $timeline, @statuses) = @_;

    for my $status (@statuses) {
        # データのカスタマイズ
        my $raw_data = $status->[1];
        my $text = $status->[0]{text};
        $text =~ s/[\x00-\x1F]/ /xmsg;
        my $source = $raw_data->{source};
        if ($source =~ m!<a \s href.*?>(.*)</a>!xms) {
            $source = $1;
        }
        # statusの追加
        $timeline->{$raw_data->{id}} = {
            screen_name => $status->[0]{screen_name},
            created_at  => $status->[0]{timestamp},
            text        => $text,
            source      => $source,
            user_id     => $raw_data->{user}{id},
            in_reply_to_screen_name => $raw_data->{in_reply_to_screen_name},
            in_reply_to_status_id   => $raw_data->{in_reply_to_status_id},
        };
        # userの追加
        $self->{users}{$raw_data->{user}{id}} = $raw_data->{user};
    }
}

sub user {
    my ($self, $id) = @_;
    return $self->{users}{$id};
}

sub status {
    my ($self, $id) = @_;
    return $self->{friends}{$id} || $self->{mentions}{$id};
}

sub _sorted {
    my ($self, @statuses) = @_;
    return reverse sort {
        $a->{created_at} <=> $b->{created_at}
    } @statuses;
}

1;
