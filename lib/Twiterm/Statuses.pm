package Statuses;

use HTML::Entities;
use Date::Parse 'str2time';
use AnyEvent::Twitter;
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

has 'update_cb' => (
    is  => 'ro',
    isa => 'CodeRef',
);

has 'statuses' => (is => 'ro', isa => 'ArrayRef');

sub BUILD {
    my $self = shift;
    $self->{statuses} = [];
    $self->{twitter} = AnyEvent::Twitter->new(
        username => $self->{username},
        password => $self->{password},
    );
    my $w; $w = $self->{twitter}->reg_cb(
        error => sub {
            my ($twitter, $error) = @_;
            #TODO エラー時の処理はどうする？
            undef $w;
        },
        statuses_friends => sub {
            my ($twitter, @statuses) = @_;
            $self->add(map { $_->[1] } reverse @statuses);
            &{$self->{update_cb}}();
        },
    );
    $self->{twitter}->receive_statuses_friends;
    $self->{twitter}->start;
}

sub add {
    my $self = shift;
    my @args = @_;

    for my $status (@args) {
        # データのカスタマイズ
        $status->{created_at} = str2time $status->{created_at};
        $status->{text} = decode_entities $status->{text};
        $status->{text} =~ s/[\x00-\x1F]/ /xmsg;
        if ($status->{source} =~ m!<a .*? >(.*)</a>!xms) {
            $status->{source} = $1;
        }
        unshift @{$self->{statuses}}, $status;
    }
}

__PACKAGE__->meta->make_immutable;

no Mouse;

1;
