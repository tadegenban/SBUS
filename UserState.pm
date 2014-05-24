#-*-encode: utf8-*-
package UserState;
use 5.014;
use Moo;
use namespace::clean;

has username => is => 'ro';
has state    => is => 'rw', default => 'init';
has target   => is => 'rw';

sub get_state{
    my $self = shift;
    $self->state;
}
sub stay{
    my $self = shift;
    my $state = $self->get_state;
    $self->state($state);
}
sub to_target{
    my $self = shift;
    $self->state('target');
}
sub to_init{
    my $self = shift;
    $self->state('init');
}
sub get_target{
    my $self = shift;
    $self->target;
}
sub set_target{
    my $self = shift;
    my $target = shift;
    $self->target($target);
}


1;
