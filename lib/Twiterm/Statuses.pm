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

has 'friends'  => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);
has 'mentions' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

sub BUILD {
    my $self = shift;
    $self->{twitter} = AnyEvent::Twitter->new(
        username => $self->{username},
        password => $self->{password},
        bandwidth=> 0.1,
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
            if (defined $self->{update_cb} &&
                    defined $self->{delegate}) {
                &{$self->{update_cb}}($self->{delegate});
            }
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
        unshift @{$self->friends}, $status;
    }
}

__PACKAGE__->meta->make_immutable;

no Mouse;

1;
