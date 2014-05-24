#!/usr/bin/env perl
use Mojolicious::Lite;
# Documentation browser under "/perldoc"

my $user_scalar  = '';
get '/' => sub {
    my $self = shift;
    response();
};


sub response{
    say 'here';
    say $user_scalar;
    $user_scalar = 'b';
    return 1;
}

app->start;

