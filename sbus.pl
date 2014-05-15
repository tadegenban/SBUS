#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::DOM;
use Digest::SHA1 qw(sha1);
use Data::Dumper;
use Encode;
use utf8;
use Text::CSV;
use Data::Dumper;
binmode(STDOUT, ":utf8");
# Documentation browser under "/perldoc"
plugin 'PODRenderer';

my $schedule_file = 'schedule.csv';
my $schedule_hash = load_schedule($schedule_file);
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
    my $me   = $dom->at('ToUserName')->text;
    my $user = $dom->at('FromUserName')->text;
    my $time = $dom->at('CreateTime')->text;
    my $response = response($content);
    $self->stash(response => $response);
    $self->stash(to_user_name => $user);
    $self->stash(from_user_name => $me);
    $self->stash(time => $time);
    $self->render('text');
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

sub response{
    my $content = shift;
    $content = Encode::decode("utf8", $content);
    say length $content;
    my $response = get_help();
    if($content eq '帮助'){
        $response = get_help();
        return $response;
    }
    else{
        $response = get_schedule($content);
        return $response;
    }
    return $response;
}

sub get_help{
    return 'have fun!宋代';
}
sub get_schedule{
    my $loc = shift;
    if($loc =~ /张江/){
        my $station = '张江';
        my $response = parse_schedule($schedule_hash, 'workday', $station);
        return $response;
    }
    if($loc =~ /龙阳/){
        my $station = '龙阳';
        my $response = parse_schedule($schedule_hash, 'workday', $station);
        return $response;
    }
}
sub load_schedule{
    my $file = shift;
    open my $fh, '<:encoding(utf8)', $file;
    my $csv = Text::CSV->new();
    my $hash = {};
    my $timing;
    my $station_A;
    my $station_B;
    my $flag_head = 0;
    while(my $row = $csv->getline($fh)){
        if($row->[0] eq '$'){
            $timing = $row->[1];
            $flag_head   = 1;
            next;
        }
        if(1 == @$row){
            $flag_head = 1;
            next;
        }
        if($flag_head == 1){
            $station_A = $row->[0];
            $station_B = $row->[1];
            $hash->{$timing}->{$station_A} = [$row] unless exists $hash->{$timing}->{$station_A};
            $flag_head = 0;
            next;
        }
        if($flag_head == 0){
            my $time_A = $row->[0];
            my $time_B = $row->[1];
            push $hash->{$timing}->{$station_A}, $row;
            next;
        }
    }
    return $hash;
}
sub parse_schedule{
    my ($schedule_hash, $timing, $station) = @_;
    my $array = $schedule_hash->{$timing}->{$station};
    my $response;
    foreach my $arr(@$array){
        if($arr->[0] eq '='){
            $response .= "==========\n";
        }
        else{
            $response .= sprintf("%-8s | %-8s", @$arr);
            $response .= "\n";
        }
    }
    return $response;
}
app->start;
__DATA__

@@ text.html.ep
<xml>
<ToUserName><![CDATA[<%= $to_user_name %>]]></ToUserName>
<FromUserName><![CDATA[<%= $from_user_name %>]]></FromUserName>
<CreateTime><%= $time %></CreateTime>
<MsgType><![CDATA[text]]></MsgType>
<Content><![CDATA[<%= $response %>]]></Content>
</xml>
@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
