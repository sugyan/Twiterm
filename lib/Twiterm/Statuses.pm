package Twiterm::Statuses;

use AnyEvent::Twitter;
use Date::Parse 'str2time';
use HTML::Entities;
use Mouse;

has 'username' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'password' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'delegate' => (
    is  => 'ro',
    isa => 'Object',
);
has 'update_cb' => (
    is  => 'ro',
    isa => 'CodeRef',
);

no Mouse;

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $self = shift;
    $self->{twitter} = AnyEvent::Twitter->new(
        username => $self->{username},
        password => $self->{password},
        bandwidth=> 0.1,
    );
    $self->{friends}  = {};
    $self->{mentions} = {};
    $self->{users}    = {};
    my $w; $w = $self->{twitter}->reg_cb(
        error => sub {
            my ($twitter, $error) = @_;
            #TODO エラー時の処理はどうする？
            warn "error\n";
            undef $w;
        },
        statuses_friends => sub {
            my ($twitter, @statuses) = @_;
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
        my $data = $status->[1];
        # データのカスタマイズ
        $data->{created_at} = $status->[0]->{timestamp};
        $data->{text} = $status->[0]->{text};
        $data->{text} =~ s/[\x00-\x1F]/ /xmsg;
        if ($data->{source} =~ m!<a .*? >(.*)</a>!xms) {
            $data->{source} = $1;
        }
        $data->{id} = $status->[1]->{id};
        $self->{users}{$data->{user}{id}} = $data->{user};

        $timeline->{$data->{id}} = $data;
    }
}

sub user {
    my ($self, $id) = @_;
    return $self->{users}{$id};
}

sub _sorted {
    my ($self, @statuses) = @_;
    return reverse sort {
        $a->{created_at} <=> $b->{created_at}
    } @statuses;
}

1;
