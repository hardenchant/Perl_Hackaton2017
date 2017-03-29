#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;

system('git pull origin master');

my $git_mess = `git log -n 1 --pretty=oneline`;
die "Unknown git format $git_mess" unless $git_mess =~ /^([0-9a-f]+)/;
my $id = $1;

my $server_bin = "$FindBin::Bin/../server/bin/server";
my $file_id;
open($file_id, '+<', '/tmp/last_git_id_chat.txt') or open($file_id, '+>', '/tmp/last_git_id_chat.txt') or die "$!";
my $old_id = <$file_id>||'';
if ($id ne $old_id) {
    my $ps = `ps xa | grep bin/server | grep -v "grep"`;
    if ($ps && $ps =~/^(\d+)/){
        my $pid = $1;
        system('kill -KILL '.$pid);
    }
    system('nohup '.$server_bin.' > /tmp/chat_server.log 2>&1 &');
    seek($file_id, 0, 0);
    print $file_id $id;
}
close($file_id);

