#!/opt/local/bin/perl
package Page;

use Mouse;

has 'offset' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'select' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'disp_mode' => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

sub position {
    my $self = shift;
    return $self->{offset} + $self->{select};
}

__PACKAGE__->meta->make_immutable;

no Mouse;

1;
