#!/usr/bin/expect

set timeout 5

set host [lindex $argv 0]
set user [lindex $argv 1]
set pw [lindex $argv 2]
set local_file [lindex $argv 3]
set remote_dir [lindex $argv 4]

spawn scp -r $local_file $user@$host:$remote_dir

expect {
    "Connection refused" exit
    "Name or service not known" exit
    "continue connecting" {send "yes\r";exp_continue}
    "password:" {send "$pw\r"}
}

expect eof
