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

1;
