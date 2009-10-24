package AnyEvent::Wassr;

use base 'Object::Event';
use Carp 'croak';
use Scalar::Util 'weaken';

sub new {
   my $class = shift;
   my $self  = $class->SUPER::new(
       @_,
   );

   if (!defined($self->{username})) {
       croak "no 'username' given to AnyEvent::Wassr\n";
   }
   if (!defined($self->{password})) {
       croak "no 'password' given to AnyEvent::Wassr\n";
   }

   return $self;
}

sub receive_statuses_friends {
    my ($self, $weight) = @_;

    weaken $self;
    $self->{schedule}{statuses_friends} = {
        wait    => 0,
        weight  => $weight || 1,
        request => sub {},
    };
}

sub receive_statuses_replies {
    my ($self, $weight) = @_;

    weaken $self;
    $self->{schedule}{statuses_replies} = {
        wait    => 0,
        weight  => $weight || 1,
        request => sub {},
    };
}

sub start {
    my $self = shift;

    $self->_tick;
}

sub _tick {
    my $self = shift;

    my $max_task;
    for my $schedule (keys %{$self->{schedule}}) {
        my $task = $self->{schedule}{$schedule};
        $task->{wait} += $task->{weight};

        $max_task = $task if !defined $max_task;
        $max_task = $task if $max_task->{wait} <= $task->{wait};
    }

    return if !defined $max_task;

    weaken $self;
    $max_task->{request}(
        sub { $self->_schedule_next_tick(shift) }, $max_task,
    );
    $max_task->{wait} = 0;
}

1;
