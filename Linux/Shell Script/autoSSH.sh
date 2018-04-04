#!/usr/bin/expect

set timeout 5

set host [lindex $argv 0]
set user [lindex $argv 1]
set pw [lindex $argv 2]
set command [lindex $argv 3]

spawn ssh -p 22 $user@$host

expect {
    "Connection refused" exit
    "Name or service not known" exit
    "continue connecting" {send "yes\r";exp_continue}
    "password:" {send "$pw\r"}
}
# 停留在远端服务器上
#interact

# 执行命令后退出
expect "#*"
send "$command\r"
send  "exit\r"
expect eof
