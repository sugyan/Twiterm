package Twiterm::PageState;

use Log::Message;

my $log = new Log::Message(
    tag => __PACKAGE__,
);

sub new {
    my $class = shift;
    my $self = {
        pages => [],
        index => 0,
    };

    return bless $self, $class;
}

sub addPage {
    my $self = shift;
    my $config = shift;

    my $page = {
        name       => 'NO NAME',
        account_id => '',
        %$config,
        offset => 0,
        select => 0,
        disp_mode => 0,
    };
    push @{$self->{pages}}, $page;
    $log->store("addPage ($page->{name})");
}

sub timeline {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{timeline};
}

sub offset {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{offset};
}

sub disp_mode {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{disp_mode};
}

sub change_mode {
    my $self = shift;
    my $page = $self->{pages}->[$self->{index}];
    $page->{disp_mode} = !$page->{disp_mode};
}

sub select {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{select};
}

sub position {
    my $self = shift;
    return $self->offset + $self->select;
}

sub name {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{name};
}

sub account_id {
    my $self = shift;
    return $self->{pages}->[$self->{index}]->{account_id};
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

sub index {
    my $self = shift;
    return $self->{index};
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

1;
