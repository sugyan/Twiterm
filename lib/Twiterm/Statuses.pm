#!/opt/local/bin/perl
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

has 'statuses' => (is => 'ro', isa => 'ArrayRef');

sub BUILD {
    my $self = shift;
    $self->{statuses} = [];
    $self->{twitter} = AnyEvent::Twitter->new(
        username => $self->{username},
        password => $self->{password},
    );
}

sub add {
    my $self = shift;
    my @args = @_;

    # idで重複チェック
    my %ids;
    for my $id (map { $_->{id} } @{$self->{statuses}}) {
        $ids{$id}++;
    }
    for my $status (@args) {
        next if defined $ids{$status->{id}};
        # データのカスタマイズ
        $status->{created_at} = str2time $status->{created_at};
        $status->{text} = decode_entities $status->{text};
        if ($status->{source} =~ m!<a .*? >(.*)</a>!xms) {
            $status->{source} = $1;
        }

        push @{$self->{statuses}}, $status;
    }
    # created_at順に並べ替える
    $self->{statuses} = [sort {
        $b->{created_at} <=> $a->{created_at}
    } @{$self->{statuses}}];
}

sub update {
    my $self = shift;
    my $callback = shift;

    my $w; $w = $self->{twitter}->reg_cb(
        error => sub {
            my ($twitter, $error) = @_;
            #TODO エラー時の処理はどうする？
            undef $w;
        },
        statuses_friends => sub {
            my ($twitter, @statuses) = @_;

            $self->add(map { $_->[1] } @statuses);
            &$callback();
        },
    );
    $self->{twitter}->receive_statuses_friends;
    $self->{twitter}->start;
}

__PACKAGE__->meta->make_immutable;

no Mouse;

1;
