#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::DOM;
use Digest::SHA1 qw(sha1);
use Data::Dumper;
use Encode;
use utf8;
use Text::CSV;
use Data::Dumper;
use Unicode::GCString;
use UserState;
binmode(STDOUT, ":utf8");
# Documentation browser under "/perldoc"
plugin 'PODRenderer';

my $schedule_file = 'schedule.csv';
my $schedule_hash = load_schedule($schedule_file);
my $user_hash     = {};
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
    my $user_name = $dom->at('FromUserName')->text;
    say $user_name;
    my $time = $dom->at('CreateTime')->text;
    my $response = response($content, $user_name);
    $self->stash(response => $response);
    $self->stash(to_user_name => $user_name);
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
    my $user_name = shift;
    my $user;
    my $response;
    if(exists $user_hash->{$user_name}){
        $user = $user_hash->{$user_name};
    }
    else{
        $user = UserState->new(username => $user_name);
        $user_hash->{$user_name} = $user;
    }
    my $state = $user->get_state();
    $content = Encode::decode("utf8", $content);
    if ($state eq 'init'){
        if($content =~ /帮助|帮|\?|？|help|h/){
            $response = get_help();
            $user->stay();
            return $response;
        }
        if($content =~ /张江|龙阳|花园/){
            $content =~ s/.*(张江|龙阳|花园).*/$1/g;
            $user->to_target();
            $user->set_target($content);
            $response = get_more_info($content);
            return $response;
        }
        $response = get_help();
        $user->stay();
        return $response;
    }
    if ($state eq 'target'){
        my $target = $user->get_target();
        if($content =~ /帮助|帮|\?|？|help|h/){
            $response = get_help();
            $user->stay();
            return $response;
        }
        if($content =~ /张江|龙阳|花园/){
            $content = s/.*(张江|龙阳|花园).*/$1/g;
            $user->stay();
            $response = get_more_info($content);
            return $response;
        }
        if($content =~ /^[1234]$/){
            say $content;
            $user->stay();
            $response = get_schedule($target, $content);
            return $response;
        }
        $response = get_help();
        $user->stay();
        return $response;
    }
}

sub get_help{
    return qq/
输入：
张江 -- 张江科苑路地铁站
龙阳 -- 龙阳路地铁站
花园 -- 中芯花园
帮助  -- 查询更多帮助
目前只支持时刻查询
目前只支持张江科苑路地铁，龙阳路地铁，中芯花园 三个地方的查询，其他地点会陆续补充
/;
}
sub get_welcome{
    return qq/
欢迎订阅--他的跟班!
这是我个人空闲时间做的小玩具，主要是为了方便自己，方便大家随时的查询公司的班车信息
不妨输入“张江”试试？
目前只支持张江科苑路地铁，龙阳路地铁，中芯花园 三个地方的查询，其他地点会陆续补充
还可以输入：
帮助  -- 查询更多帮助
/;
}

sub get_more_info{
    my $target = shift;
    say $target;
    return qq/
[工作日]公司 到 $target，请输入 1
[工作日]$target 到 公司，请输入 2
[节假日]公司 到 $target，请输入 3
[节假日]$target 到 公司，请输入 4
更多，您可以输入其他地点来查询其他信息
------------
或输入：帮助，查看帮助
/;
}
sub get_schedule{
    my $station = shift;
    my $choise = shift;
    my $timing;
    my $from;
    my $to;
    if ($choise == 1){
        $timing = 'workday';
        $from   = '公司'   ;
        $to     = $station ;
    }
    if ($choise == 2){
        $timing = 'workday';
        $from   = $station   ;
        $to     = '公司' ;
    }
    if ($choise == 3){
        $timing = 'weekend';
        $from   = '公司'   ;
        $to     = $station ;
    }
    if ($choise == 4){
        $timing = 'weekend';
        $from   = $station ;
        $to     = '公司' ;
    }
    my $response = parse_schedule($schedule_hash, $timing, $station, $from, $to);
    # .to be finished
    if($station eq "花园"){
        return '中芯花苑班车信息，还未录入，近期更新';
    }
    return $response;
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
            $hash->{$timing}->{$station_A}->{$station_B} = [] unless exists $hash->{$timing}->{$station_A}->{$station_B};
            $hash->{$timing}->{$station_B}->{$station_A} = [] unless exists $hash->{$timing}->{$station_B}->{$station_A};
            $flag_head = 0;
            next;
        }
        if($flag_head == 0){
            push $hash->{$timing}->{$station_A}->{$station_B}, $row->[0] unless $row->[0] =~ '~~:~~';
            push $hash->{$timing}->{$station_B}->{$station_A}, $row->[1] unless $row->[1] =~ '~~:~~';
            next;
        }
    }
    return $hash;
}
sub parse_schedule{
    my ($schedule_hash, $timing, $from, $to) = @_;
    my $array = $schedule_hash->{$timing}->{$from}->{$to};
    my $response;
    my $timing_zh;
    if($timing eq 'workday'){
        $timing_zh = "工作日";
    }
    else{
        $timing_zh = "节假日";
    }
    my $head = qq/
---------------------
[$timing_zh]$from 到$to
---------------------
/;
    my $body = '';
    foreach my $time(@$array){
        if($time eq '='){
            $body .= qq/
=======
休   息
=======
/;
        }
        else{
            $body .= $time."\n";
        }
    }
    my $tail = qq/
------------
【$timing_zh】$from 到 $to，请输入 1
【$timing_zh】$from 到 $to，请输入 2
【$timing_zh】$from 到 $to，请输入 3
【$timing_zh】$from 到 $to，请输入 4
-------------------
更多，您可以输入其他地点来查询其他信息
或输入：帮助，查看帮助

/;
    $response = $head.$body.$tail;
    say $response;
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
