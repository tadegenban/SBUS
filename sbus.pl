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
    my $dom = Mojo::DOM->new();
    $dom->xml(1);
    $dom->parse($xml);
    my $content = $dom->at('Content')->text;
    my $to_user_name   = $dom->at('ToUserName')->text;
    my $from_user_name = $dom->at('FromUserName')->text;
    say $content;
    say $to_user_name;
    say $from_user_name;
    return;
    if($content eq '?'){
        my $response = "hello weixin";
        $self->stash(response => $response);
        $self->stash(to_user_name => $to_user_name);
        $self->stash(from_user_name => $from_user_name);
        $self->render('text');
    }
    else{
        my $result = eval($content);
        $self->render('text');
    }
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

@@ text.html.ep
<xml>
<ToUserName><![CDATA[<%= $to_user_name %>]]></ToUserName>
<FromUserName><![CDATA[<%= $from_user_name %>]]></FromUserName>
<CreateTime>12345678</CreateTime>
<MsgType><![CDATA[text]]></MsgType>
<Content><![CDATA[<%= $response %>]]></Content>
</xml>
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
