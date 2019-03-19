## 查看当前系统版本
    cat etc/os-release

## centOS最小化安装没有ifconfig解决办法
    yum install net-tools

## 标准输入的文件结束符EOF
Windows下为组合键Ctrl+Z，Unix/Linux下为组合键Ctrl+D

## 配置远程root的ssh登录
    a. 修改 /etc/ssh/sshd_config
    b. 注释掉 #PermitRootLogin without-password，添加 PermitRootLogin yes
    c. 重启ssh服务：systemctl restart sshd.service

## 配置代理
    export http_proxy="http://127.0.0.1:1080"
    export https_proxy="http://127.0.0.1:1080"

    #解除代理
    unset http_proxy
    unset https_proxy

## apt安装
    sudo DEBIAN_FRONTEND=noninteractive http_proxy=http://127.0.0.1:1080 https_proxy=http://127.0.0.1:1080 no_proxy= apt-get --option Dpkg::Options::=--force-confold --assume-yes --allow-unauthenticated install python-virtualenv

## grep
    a. 查看某个文件夹下的所有文件中是否包含某个字符串
    grep -rn "remove_floating_ip" *

## 创建rpm包
    a. 安装rpm包制作工具：
    yum install -y rpm-build rpmdevtools
    b. 运行 rpmdev-setuptree 来生成一个 rpm 包的骨架目录：
    rpmdev-setuptree
    c. 进入到生成的rpmbuild目录里，拷贝一份源代码到SOURCE目录下，然后打包源代码：
    tar zcvf xxxxxx.tar.gz xxxxxx
    d. rpmbuild/SPECS 目录下用 rpmdev-newspec 来生成一个 spec 骨架文件
    rpmdev-newspec helloworld.spec
    e. 编辑spec文件，示例查看hikgit里面的configfile工程spec文件
    f. 生成rpm包：
    rpmbuild -ba SPECS/xxxx.spec
    可以在生成之前进行一下测试：
        -bp                           依据 <specfile> 从 %prep (解压缩源代码并应用补丁) 开始构建
        -bc                           依据 <specfile> 从 %build (%prep 之后编译) 开始构建
        -bi                           依据 <specfile> 从 %install (%prep、%build 后安装) 开始构建
        -bl                           依据 <specfile> 检验 %files 区域
        -ba                           依据 <specfile> 构建源代码和二进制软件包
        -bb                           依据 <specfile> 构建二进制软件包
        -bs                           依据 <specfile> 构建源代码软件包
        -tp                           依据 <tarball> 从 %prep (解压源代码并应用补丁)开始构建
        -tc                           依据 <tarball> 从 %build (%prep，之后编译)开始构建
        -ti                           依据 <tarball> 从 %install (%prep、%build 然后安装)开始构建
        -ta                           依据 <tarball> 构建源代码和二进制软件包
        -tb                           依据 <tarball> 构建二进制软件包
        -ts                           依据 <tarball> 构建源代码软件包

## yum
### yum 下载安装包
    yumdownloader 包名
    yum install --downloadonly --downloaddir=./ 包名
### yum看安装的包
    yum list installed
###

## yum配置源的优先级
在.repo文件中加入：
```
priority=1 //优先级，yum-plugin-priorities会用到，优先级越小越高
```

## Linux启动
CentOS Linux启动回去执行/etc/rc.local，这是一个软链接，指向/etc/rc.d/rc.local，可以在该文件中写入自己需要的启动命令

## SELinux的三种模式
enforcing：自动实施模式，这是缺省模式，此时在系统上启用并实施 SELinux 安全策略。

Permissive：宽容模式，在该模式下，SELinux 是启用的，但不会实施安全策略，只会发出警告和记录行为。该模式在对 SELinux 排错时比较有用。

Disable：禁用模式，禁止 SELinux

## 查看硬件设备和系统信息
### 系统
```
# uname -a               # 查看内核/操作系统/CPU信息
# head -n 1 /etc/issue   # 查看操作系统版本
# cat /proc/cpuinfo      # 查看CPU信息
# hostname               # 查看计算机名
# lspci -tv              # 列出所有PCI设备
# lsusb -tv              # 列出所有USB设备
# lsusb --tree
# lsmod                  # 列出加载的内核模块
# env                    # 查看环境变量
 ```
### 资源
```
# free -m                # 查看内存使用量和交换区使用量
# df -h                  # 查看各分区使用情况
# du -sh <目录名>        # 查看指定目录的大小
# grep MemTotal /proc/meminfo   # 查看内存总量
# grep MemFree /proc/meminfo    # 查看空闲内存量
# uptime                 # 查看系统运行时间、用户数、负载
# cat /proc/loadavg      # 查看系统负载
```
### 磁盘和分区
```
# mount | column -t      # 查看挂接的分区状态
# fdisk -l               # 查看所有分区
# swapon -s              # 查看所有交换分区
# hdparm -i /dev/hda     # 查看磁盘参数(仅适用于IDE设备)
# dmesg | grep IDE       # 查看启动时IDE设备检测状况
```
### 网络
```
# ifconfig               # 查看所有网络接口的属性
# iptables -L            # 查看防火墙设置
# route -n               # 查看路由表
# netstat -lntp          # 查看所有监听端口
# netstat -antp          # 查看所有已经建立的连接
# netstat -s             # 查看网络统计信息
```
### 进程
```
# ps -ef                 # 查看所有进程
# top                    # 实时显示进程状态
```
### 用户
```
# w                      # 查看活动用户
# id <用户名>            # 查看指定用户信息
# last                   # 查看用户登录日志
# cut -d: -f1 /etc/passwd   # 查看系统所有用户
# cut -d: -f1 /etc/group    # 查看系统所有组
# crontab -l             # 查看当前用户的计划任务
```
### 服务
```
# chkconfig --list       # 列出所有系统服务
# chkconfig --list | grep on    # 列出所有启动的系统服务
```

## tar命令
```shell
tar czf xxxx.tar.gz xxx    #打包
tar xzvf xxx.tar.gz        #解包
```

## ipmitool命令
```shell
ipmitool lan print     # 查看bmc地址
```

## 添加用户并赋予root组权限
```shell
# 创建用户
useradd $USER_NAME

# 修改密码
passwd $USER_NAME

# 赋予root权限，修改/etc/sudoers文件，在root  ALL=(ALL)    ALL后增加一行
root  ALL=(ALL)    ALL
$USER_NAME  ALL=(ALL)    ALL
```

## 生成一个uuid
uuidgen

## 时间配置
### date
```shell
# 查看系统时间
date
# 设置系统时间
date --set “07/07/06 10:19" （月/日/年 时:分:秒）
```

### hwclock/clock
```shell
# 查看硬件时间
hwclock --show
# 或者
clock --show
# 设置硬件时间
hwclock --set --date="07/07/06 10:19" （月/日/年 时:分:秒）
# 或者
clock --set --date="07/07/06 10:19" （月/日/年 时:分:秒）
```

## 监控命令执行情况
watch命令
```shell
Usage:
 watch [options] command

Options:
  -b, --beep             beep if command has a non-zero exit
  -c, --color            interpret ANSI color and style sequences
  -d, --differences[=<permanent>]
                         highlight changes between updates
  -e, --errexit          exit if command has a non-zero exit
  -g, --chgexit          exit when output from command changes
  -n, --interval <secs>  seconds to wait between updates
  -p, --precise          attempt run command in precise intervals
  -t, --no-title         turn off header
  -x, --exec             pass command to exec instead of "sh -c"

 -h, --help     display this help and exit
 -v, --version  output version information and exit

# watch -n 1 -d -x $SHELL_SCRIPT
watch -n 1 -d -x iptables -nvL INPUT
```
## sysctl
sysctl可以配置一些内核参数，默认配置文件是/etc/sysctl.conf
sysctl命令所做的修改可以临时生效，如果要持久化，需要在/etc/sysctl.conf增加配置，并执行sysctl -p

## sed
```shell
# 截取文本
sed -n '20,30p' text.txt
```

## cp
* cp带权限：cp -p

## du
1. 要显示一个目录树及其每个子树的磁盘使用情况
```bash
du /home/linux
```
这在/home/linux目录及其每个子目录中显示了磁盘块数。

2. 要通过以1024字节为单位显示一个目录树及其每个子树的磁盘使用情况
```bash
du -k /home/linux
```
这在/home/linux目录及其每个子目录中显示了 1024 字节磁盘块数。

3. 以MB为单位显示一个目录树及其每个子树的磁盘使用情况
```bash
du -m /home/linux
```
这在/home/linux目录及其每个子目录中显示了 MB 磁盘块数。

4. 以GB为单位显示一个目录树及其每个子树的磁盘使用情况
```bash
du -g /home/linux
```
这在/home/linux目录及其每个子目录中显示了 GB 磁盘块数。

5. 查看当前目录下所有目录以及子目录的大小：
```bash
du -h .
```
“.”代表当前目录下。也可以换成一个明确的路径，-h表示用K、M、G的人性化形式显示

6. 查看当前目录下user目录的大小，并不想看其他目录以及其子目录：
```bash
du -sh user
```
-s表示总结的意思，即只列出一个总结的值
```bash
du -h --max-depth=0 user
```
--max-depth=n表示只深入到第n层目录，此处设置为0，即表示不深入到子目录。

7. 列出user目录及其子目录下所有目录和文件的大小：
```bash
du -ah user
```
-a表示包括目录和文件

8. 列出当前目录中的目录名不包括xyz字符串的目录的大小：
```bash
du -h --exclude='*xyz*'
```

9. 想在一个屏幕下列出更多的关于user目录及子目录大小的信息：
```bash
du -0h user
```
-0（杠零）表示每列出一个目录的信息，不换行，而是直接输出下一个目录的信息。

10. 只显示一个目录树的全部磁盘使用情况
```bash
du -s /home/linux
```

11. 查看各文件夹大小: du -h --max-depth=1
