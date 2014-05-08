#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::DOM;
use Digest::SHA1 qw(sha1);
use Data::Dumper;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

get '/' => sub {
    my $self = shift;
    my $echostr = $self->param('echostr');
    my $pass = checkSignature($self);
    if($pass){
        say $echostr;
        say 'pass';
        $self->render(test => $echostr);
    }
    else{
        say $echostr;
        say 'no pass';
        $self->render(text => $pass);
    }
};

post '/' => sub {
    my $self = shift;
    my $xml = $self->req->body;
    my $dom = Mojo::DOM->new('<xml><Content>wowo</Content><xml>');
    say $xml;
    say $dom;
    say $dom->at('Content')->text;
};

sub checkSignature{
    my $self = shift;
    my $signature = $self->param('signature');
    my $timestamp = $self->param('timestamp');
    my $nonce = $self->param('nonce');

    my $token = 'tadetoken';
    my $array = [$token, $timestamp, $nonce];
    $array = [sort @$array];
    my $str = join '', @$array;
    $str = sha1($str);
    if($signature eq $str){
        return 1;
    }
    return 0;
}

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
Welcome to the Mojolicious real-time web framework!
SBUS is a weixin Bus robot
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
