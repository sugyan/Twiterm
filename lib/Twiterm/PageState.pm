package Twiterm::PageState;

use Mouse;

no Mouse;

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $self = shift;
    $self->{pages} = [];
    $self->{index} = 0;
}

sub addPage {
    my $self = shift;
    my $config = shift;

    push @{$self->{pages}}, {
        %$config,
        offset => 0,
        select => 0,
        disp_mode => 0,
    };
}

sub timeline {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{timeline};
}

sub offset {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{offset};
}

sub select {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{select};
}

sub position {
    my $self = shift;
    return $self->offset + $self->select;
}

sub incr_select {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{select}++;
}

sub decr_select {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{select}--;
}

sub incr_offset {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{offset}++;
}

sub decr_offset {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{offset}--;
}

sub prev {
    my $self = shift;
    $self->{index}--;
    $self->{index} = $#{$self->{pages}} if $self->{index} < 0;
}

sub next {
    my $self = shift;
    $self->{index}++;
    $self->{index} = 0 if $self->{index} > $#{$self->{pages}};
}

# my @pages;

# has 'timeline' => (
#     is       => 'ro',
#     isa      => 'CodeRef',
#     required => 1,
# );

# has 'offset' => (
#     is      => 'rw',
#     isa     => 'Int',
#     default => 0,
# );

# has 'select' => (
#     is      => 'rw',
#     isa     => 'Int',
#     default => 0,
# );

# has 'disp_mode' => (
#     is      => 'rw',
#     isa     => 'Int',
#     default => 0,
# );

# sub position {
#     my $self = shift;
#     return $self->{offset} + $self->{select};
# }

1;
