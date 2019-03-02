# 容器实现的原理-namespace
namespace是linux提供的一种内核级别环境隔离的方法，针对于一下资源进行了隔离。

|        分类        |   系统调用    | 相关内核版本 |         隔离内容         |
|:------------------:|:-------------:|:------------:|:------------------------:|
|  Mount namespaces  |  CLONE_NEWNS  | Linux 2.4.19 |    挂载点（文件系统）    |
|   UTS namespaces   | CLONE_NEWUTS  | Linux 2.6.19 |       主机名和域名       |
|   IPC namespaces   | CLONE_NEWIPC  | Linux 2.6.19 | 信号量/消息队列/共享内存 |
|   PID namespaces   | CLONE_NEWPID  | Linux 2.6.24 |         进程编号         |
| Network namespaces | CLONE_NEWNET  | Linux 2.6.29 | 网络设备、网络栈、端口等 |
|  User namespaces   | CLONE_NEWUSER |  Linux 3.8   |       用户和用户组       |

使用namespace主要是使用一下三个系统调用：
* clone() – 实现线程的系统调用，用来创建一个新的进程，并可以通过设计上述参数达到隔离。
* unshare() – 使某进程脱离某个namespace
* setns() – 把某进程加入到某个namespace

使用上述三个系统调用的时候可以通过指定六个常数来实现，六个参数分别是CLONE_NEWIPC、CLONE_NEWNS、CLONE_NEWNET、CLONE_NEWPID、CLONE_NEWUSER和CLONE_NEWUTS。

以下程序便是一个UTS隔离的例子。
```c
#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/wait.h>
#include <stdio.h>
#include <sched.h>
#include <signal.h>
#include <unistd.h>

/* 定义一个给 clone 用的栈，栈大小1M */
#define STACK_SIZE (1024 * 1024)
static char container_stack[STACK_SIZE];

char* const container_args[] = {
    "/bin/bash",
    NULL
};

int container_main(void* arg)
{
    printf("Container - inside the container!\n");
    sethostname("container",10); /* 设置hostname */
    /* 直接执行一个shell，以便我们观察这个进程空间里的资源是否被隔离了 */
    execv(container_args[0], container_args);
    printf("Something's wrong!\n");
    return 1;
}

int main()
{
    printf("Parent - start a container!\n");
    /* 调用clone函数，其中传出一个函数，还有一个栈空间的（为什么传尾指针，因为栈是反着的） */
    int container_pid = clone(container_main, container_stack+STACK_SIZE,
            CLONE_NEWUTS | SIGCHLD, NULL); /*启用CLONE_NEWUTS Namespace隔离 */
    /* 等待子进程结束 */
    waitpid(container_pid, NULL, 0);
    printf("Parent - container stopped!\n");
    return 0;
}
```
保存成文件namespace.c，运行示例如下：
```shell
root@ubuntu:~/namespace# gcc -c clone.c
root@ubuntu:~/namespace# ls
clone.c  clone.o
root@ubuntu:~/namespace# gcc -o clone clone.o
root@ubuntu:~/namespace# ls
clone  clone.c  clone.o
root@ubuntu:~/namespace# ./clone
Parent - start a container!
Container - inside the container!
root@container:~/namespace# hostname
container
root@container:~/namespace# uname -n
container
root@container:~/namespace# exit
exit
Parent - container stopped!
```
从3.8版本的内核开始，用户就可以在/proc/[pid]/ns文件下看到指向不同namespace号的文件，效果如下所示，形如[4026531835]者即为namespace号。
```shell
root@ubuntu:~# ls -l /proc/$$/ns    <<-- $$ 表示应用的PID
total 0
lrwxrwxrwx 1 root root 0 Jul 10 19:31 cgroup -> cgroup:[4026531835]
lrwxrwxrwx 1 root root 0 Jul 10 19:31 ipc -> ipc:[4026531839]
lrwxrwxrwx 1 root root 0 Jul 10 19:31 mnt -> mnt:[4026531840]
lrwxrwxrwx 1 root root 0 Jul 10 19:31 net -> net:[4026531957]
lrwxrwxrwx 1 root root 0 Jul 10 19:31 pid -> pid:[4026531836]
lrwxrwxrwx 1 root root 0 Jul 10 19:31 user -> user:[4026531837]
lrwxrwxrwx 1 root root 0 Jul 10 19:31 uts -> uts:[4026531838]
```

# 容器实现的原理-cgroups
​Cgroup 可让您为系统中所运行任务（进程）的用户定义组群分配资源 — 比如 CPU 时间、系统内存、网络带宽或者这些资源的组合。您可以监控您配置的 cgroup，拒绝 cgroup 访问某些资源，甚至在运行的系统中动态配置您的 cgroup。

主要提供了如下功能：
* Resource limitation: 限制资源使用，比如内存使用上限以及文件系统的缓存限制。
* Prioritization: 优先级控制，比如：CPU利用和磁盘IO吞吐。
* Accounting: 一些审计或一些统计，主要目的是为了计费。
* Control: 挂起进程，恢复执行进程。

​使用 cgroup，系统管理员可更具体地控制对系统资源的分配、优先顺序、拒绝、管理和监控。可更好地根据任务和用户分配硬件资源，提高总体效率。

ubuntu系统下查看cgroup:
```shell
root@ubuntu:~# mount -t cgroup
cgroup on /sys/fs/cgroup/systemd type cgroup (rw,nosuid,nodev,noexec,relatime,xattr,release_agent=/lib/systemd/systemd-cgroups-agent,name=systemd)
cgroup on /sys/fs/cgroup/cpu,cpuacct type cgroup (rw,nosuid,nodev,noexec,relatime,cpu,cpuacct)
cgroup on /sys/fs/cgroup/hugetlb type cgroup (rw,nosuid,nodev,noexec,relatime,hugetlb)
cgroup on /sys/fs/cgroup/perf_event type cgroup (rw,nosuid,nodev,noexec,relatime,perf_event)
cgroup on /sys/fs/cgroup/net_cls,net_prio type cgroup (rw,nosuid,nodev,noexec,relatime,net_cls,net_prio)
cgroup on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
cgroup on /sys/fs/cgroup/freezer type cgroup (rw,nosuid,nodev,noexec,relatime,freezer)
cgroup on /sys/fs/cgroup/pids type cgroup (rw,nosuid,nodev,noexec,relatime,pids)
cgroup on /sys/fs/cgroup/cpuset type cgroup (rw,nosuid,nodev,noexec,relatime,cpuset)
cgroup on /sys/fs/cgroup/devices type cgroup (rw,nosuid,nodev,noexec,relatime,devices)
cgroup on /sys/fs/cgroup/blkio type cgroup (rw,nosuid,nodev,noexec,relatime,blkio)
```

cgourp的术语:
1. **任务（Tasks）**：就是系统的一个进程。
2. **控制组（Control Group）**：一组按照某种标准划分的进程，比如官方文档中的Professor和Student，或是WWW和System之类的，其表示了某进程组。Cgroups中的资源控制都是以控制组为单位实现。一个进程可以加入到某个控制组。而资源的限制是定义在这个组上，就像上面示例中用的haoel一样。简单点说，cgroup的呈现就是一个目录带一系列的可配置文件。
3. **层级（Hierarchy）**：控制组可以组织成hierarchical的形式，既一颗控制组的树（目录结构）。控制组树上的子节点继承父结点的属性。简单点说，hierarchy就是在一个或多个子系统上的cgroups目录树。
4. **子系统（Subsystem）**：一个子系统就是一个资源控制器，比如CPU子系统就是控制CPU时间分配的一个控制器。子系统必须附加到一个层级上才能起作用，一个子系统附加到某个层级以后，这个层级上的所有控制族群都受到这个子系统的控制。Cgroup的子系统可以有很多，也在不断增加中。

cgroup的子系统:
1. **blkio** — 这个子系统为块设备设定输入/输出限制，比如物理设备（磁盘，固态硬盘，USB 等等）。
2. ​**cpu** — 这个子系统使用调度程序提供对 CPU 的 cgroup 任务访问。
3. ​**cpuacct** — 这个子系统自动生成 cgroup 中任务所使用的 CPU 报告。
4. ​**cpuset** — 这个子系统为 cgroup 中的任务分配独立 CPU（在多核系统）和内存节点。
5. ​**devices** — 这个子系统可允许或者拒绝 cgroup 中的任务访问设备。
6. ​**freezer** — 这个子系统挂起或者恢复 cgroup 中的任务。
7. ​**memory** — 这个子系统设定 cgroup 中任务使用的内存限制，并自动生成内存资源使用报告。
8. ​**net_cls** — 这个子系统使用等级识别符（classid）标记网络数据包，可允许 Linux 流量控制程序（tc）识别从具体 cgroup 中生成的数据包。
9. **net_prio** — 这个子系统用来设计网络流量的优先级
10. **hugetlb** — 这个子系统主要针对于HugeTLB系统进行限制，这是一个大页文件系统。

一个使用cgroup限制cpu资源的例子。
```c
//deadloop.c
int main(void)
{
    int i = 0;
    for(;;) i++;
    return 0;
}
```
在/sys/fs/cgroup/cpu目录下创建一个目录为 haoel 。运行deadloop的程序之后，top命令可以看到该程序占用CPU达到了100%。然后针对于haoel目录下的几个文件进行修改：
```shell
echo 20000 > cpu.cfs_quota_us
echo $PID > tasks
```
在使用top命令查看该进程的cpu占用率，已经下降到了20%。

# Dockerfile创建docker镜像

## Dockerfile指令简介

* **FROM，指定基础镜像**
```dockerfile
# scratch是一个空白的基础镜像
FROM scratch
```

* **RUN，执行命令**
```dockerfile
# shell格式，RUN <命令>
# shell格式的指令会在shell里面使用命令包装器"/bin/sh -c"来执行
# 以下格式命令实际执行过程中会被解析成
# RUN ["/bin/sh", "-c", "echo '<h1>Hello, Docker!</h1>' > /var/www/html/index.html"]
RUN echo '<h1>Hello, Docker!</h1>' > /var/www/html/index.html

# exec格式，RUN ["可执行文件", "参数1", "参数2"]
# 可以在不支持shell的平台或者不想用shell的情况下使用
RUN ["apt-get", "install", "-y", "nginx"]
```

* **COPY，复制文件**

COPY 指令将从构建上下文目录中 <源路径> 的文件/目录复制到新的一层的镜像内的 <目标路径> 位置

<源路径>可以是多个，也可以是通配符

<目标路径>可以是容器内的绝对路径，也可以是相对于工作目录的相对路径
```dockerfile
# COPY <源路径>... <目标路径>
# COPY ["<源路径1>",... "<目标路径>"]
COPY package.json /usr/src/app/
```

* **ADD，比COPY更加高级的复制命令**

<源路径> 可以是一个 URL ，这种情况下，Docker 引擎会试图去下载这个链接的文件放到 <目标路径>

<源路径> 为一个 tar 压缩文件的话，压缩格式为 gzip , bzip2 以及xz 的情况下， ADD 指令将会自动解压缩这个压缩文件到 <目标路径>

```dockerfile
ADD ubuntu-xenial-core-cloudimg-amd64-root.tar.gz /
```

* **CMD，容器启动命令**

CMD命令指定容器启动时执行的命令，和RUN命令类似，支持shell格式和exec格式，另外CMD命令可以用来给ENTRYPOINT提供参数。CMD命令可以在容器运行的时候被替换。
* shell 格式： CMD <命令>
* exec 格式： CMD ["可执行文件", "参数1", "参数2"...]
* 参数列表格式： CMD ["参数1", "参数2"...] 。在指定了 ENTRYPOINT 指令后，用 CMD 指定具体的参数
```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

* **ENTRYPOINT，入口点**

ENTRYPOINT 的格式和 RUN 指令格式一样，分为 exec 格式和 shell 格式。

ENTRYPOINT 的目的和 CMD 一样，都是在指定容器启动程序及参数。 ENTRYPOINT 在运行时也可以替代，不过比 CMD 要略显繁琐，需要通过docker run 的参数 --entrypoint 来指定。

当指定了 ENTRYPOINT 后， CMD 的含义就发生了改变，不再是直接的运行其命令，而是将 CMD 的内容作为参数传给 ENTRYPOINT 指令。

容器在启动的时候也可以替换掉默认的CMD，以其他的CMD参数运行容器。PS：注意这里的替换和没有ENTRYPOINT的时候的替换CMD的区别。

```dockerfile
# <ENTRYPOINT> "<CMD>"
ENTRYPOINT ["docker-entrypoint.sh"]
CMD [ "redis-server" ]
```

* **ENV，设置环境变量**
```dockerfile
# ENV <key> <value>
# ENV <key1>=<value1> <key2>=<value2>...
ENV VERSION=1.0 DEBUG=on NAME="Happy Feet"
```

* **ARG 构建参数**

构建参数和 ENV 的效果一样，都是设置环境变量。所不同的是， ARG 所设置的构建环境的环境变量，在将来容器运行时是不会存在这些环境变量的。
Dockerfile 中的 ARG 指令是定义参数名称，以及定义其默认值。该默认值可以在构建命令 docker build 中用 --build-arg <参数名>=<值> 来覆盖。
```dockerfile
# ARG <参数名>[=<默认值>]
ARG LOCAL=10
```

* **VOLUME，定义匿名卷**

容器运行时应该尽量保持容器存储层不发生写操作，对于数据库类需要保存动态数据的应用，其数据库文件应该保存于卷(volume)中。为了防止运行时用户忘记将动态文件所保存目录挂载为卷，在 Dockerfile 中，我们可以事先指定某些目录挂载为匿名卷，这样在运行时如果用户不指定挂载，其应用也可以正常运行，不会向容器存储层写入大量数据。
```dockerfile
# VOLUME ["<路径1>", "<路径2>"...]
# VOLUME <路径>
VOLUME /data
```

这里的 /data 目录就会在运行时自动挂载为匿名卷，任何向 /data 中写入的信息都不会记录进容器存储层，从而保证了容器存储层的无状态化。当然，运行时可以覆盖这个挂载设置。比如：
```shell
docker run -d -v mydata:/data xxxx
```

* **EXPOSE，声明端口**
```dockerfile
# EXPOSE <端口1> [<端口2>...]
EXPOSE 80 22
```

* **WORKDIR，指定工作目录**

指定的工作目录会影响每一层的镜像创建时的工作目录，上一层镜像修改的工作目录不会影响到当前层级的镜像；如果工作目录不存在，则会创建该目录。
```dockerfile
# WORKDIR <工作目录路径>
WORKDIR /home/liuyikang
```

* **USER，指定当前用户**

USER 指令和 WORKDIR 相似，都是改变环境状态并影响以后的层。 WORKDIR是改变工作目录， USER 则是改变之后层的执行 RUN , CMD 以及ENTRYPOINT 这类命令的身份。
```dockerfile
# USER <用户名>
RUN groupadd -r redis && useradd -r -g redis redis
USER redis
```

* **HEALTHCHECK，健康检查**

该指令指定一行命令，用这行命令来判断容器主进程的服务状态是否还正常，从而比较真实的反应容器实际状态。

当在一个镜像指定了 HEALTHCHECK 指令后，用其启动容器，初始状态会为starting ，在 HEALTHCHECK 指令检查成功后变为 healthy ，如果连续一定次数失败，则会变为 unhealthy 。

HEALTHCHECK支持的选项：
- interval=<间隔> ：两次健康检查的间隔，默认为 30 秒；
- timeout=<时长> ：健康检查命令运行超时时间，如果超过这个时间，本次健康检查就被视为失败，默认 30 秒；
- retries=<次数> ：当连续失败指定次数后，则将容器状态视为unhealthy ，默认 3 次。

HEALTHCHECK命令的返回值：

命令的返回值决定了该次健康检查的成功与否： 0 ：成功； 1 ：失败； 2 ：保留

```dockerfile
# HEALTHCHECK [选项] CMD <命令> ：设置检查容器健康状况的命令
# HEALTHCHECK NONE ：如果基础镜像有健康检查指令，使用这行可以屏蔽掉其健康检查指令
FROM nginx
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
HEALTHCHECK --interval=5s --timeout=3s CMD curl -fs http://localhost/ || exit 1
```

* **ONBUILD，镜像作为基础镜像的时候执行的命令**

ONBUILD 是一个特殊的指令，它后面跟的是其它指令，比如 RUN , COPY 等，而这些指令，在当前镜像构建时并不会被执行。只有当以当前镜像为基础镜像，去构建下一级镜像的时候才会被执行。
```dockerfile
# ONBUILD <其它指令>
FROM node:slim
RUN "mkdir /app"
WORKDIR /app
ONBUILD COPY ./package.json /app
ONBUILD RUN [ "npm", "install" ]
ONBUILD COPY . /app/
CMD [ "npm", "start" ]
```

## Dockerfile示例和使用

创建docker镜像的命令：
```
docker build -t myimage:liuyikang .
```

dockerfile示例：
```dockerfile
FROM ubuntu:16.04

MAINTAINER Lyiker "Lyiker@outlook.com"

#设置环境变量
ENV VERSION=1.0 DEBUG=on NAME="Happy Feet"

RUN sed -i s@/archive.ubuntu.com/@/mirrors.163.com/@g /etc/apt/sources.list \
&& apt-get clean \
&& apt-get update \
&& apt-get install -y net-tools \
&& apt-get install -y iputils-ping \
&& apt-get install -y nginx \
&& apt-get install -y openssh-server

#挂载匿名卷
VOLUME /data

#指定工作目录
WORKDIR /home/liuyikang

#拷贝文件
COPY index.html /var/www/html/index.html
COPY start.sh /home/liuyikang

#入口点
ENTRYPOINT ["sh", "start.sh"]

#容器启动的默认执行命令
CMD ["bash"]

#容器打算开放的端口
EXPOSE 80 22
```

创建完成后，便可以在docker的images中看到相关的镜像了。
```shell
root@ubuntu:~# docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
myimage             liuyikang           b39c1b25586e        46 hours ago        265MB
ubuntu              16.04               d355ed3537e9        2 weeks ago         119MB
```

## 其他创建镜像的方式

* commit命令

容器在运行的时候，对容器数据产生的修改会全部保存在容器的存储层也就是可读写层里，docker针对于容器的这种特性，提供了commit命令来将容器的存储层镜像保存下来作为一个新的镜像。也就是说，在原有镜像的基础上，叠加上容器的存储层，便可以构成一个新的镜像，该镜像共享之前容器所使用镜像的文件。

```shell
docker commit [选项] <容器ID或容器名> [<仓库名>[:<标签>]]
```

慎用commit命令：
1. 运行的容器会产生大量的无关内容，如果不小心清理，会造成容器镜像的臃肿；
2. commit镜像很难完全获知所有的容器的操作，会导致镜像很难维护；
3. docker容器在运行的时候所作的修改都不会修改前面层级镜像的内容，只会在当前镜像层做标记、修改和添加，因此用commit来创建镜像会让以后的每一次维护都更加臃肿。

* import命令

docker提供了import命令可以从压缩文件中导入一个镜像。压缩文件可以是本地文件，也可以是一个url链接。

```shell
# docker import [选项] <文件>|<URL>|- [<仓库名>[:<标签>]]
docker import http://download.openvz.org/template/precreated/ubuntu-14.04-x86_64-minimal.tar.gz  openvz/ubuntu:14.04
```

# Docker镜像

## Docker镜像的结构

上一个章节，介绍了关于如何使用dockerfile来创建容器的镜像，


## 查看Docker镜像的层级结构

Docker的镜像数据存储的路径在/var/lib/docker/aufs目录下，当仅有ubuntu镜像的时候该目录下的内容如下：
```shell
root@ubuntu:/var/lib/docker/aufs# tree -L 2
.
├── diff    #描述每层镜像新增和修改的数据
│   ├── 2c7fd8e0b5de0f19021819f7dd18be5382180625d453046adbc2003b40bcd043
│   ├── 39162ef03996e5081d9f3db96dfceca92824ca7b775def0081f5cbaba87ce7d0
│   ├── 4dc288c2a12b53c80ab208a9570f5a16375b11169503bb936f3dac0cbd9a16bf
│   ├── d92fcec50fe94a7e11863eb7fe3d2274d393c4ad58b12391c3767368bd879786
│   └── fbf127ad54acd260782ea286ed0ca9a69fd05a90cc4b9d6536ff46f8fee895fd
├── layers  #描述各镜像的层级关系
│   ├── 2c7fd8e0b5de0f19021819f7dd18be5382180625d453046adbc2003b40bcd043
│   ├── 39162ef03996e5081d9f3db96dfceca92824ca7b775def0081f5cbaba87ce7d0
│   ├── 4dc288c2a12b53c80ab208a9570f5a16375b11169503bb936f3dac0cbd9a16bf
│   ├── d92fcec50fe94a7e11863eb7fe3d2274d393c4ad58b12391c3767368bd879786
│   └── fbf127ad54acd260782ea286ed0ca9a69fd05a90cc4b9d6536ff46f8fee895fd
└── mnt     #挂载点，有容器运行时里面有数据(容器数据实际存储的地方,包含整个文件系统数据)，退出时里面为空
    ├── 2c7fd8e0b5de0f19021819f7dd18be5382180625d453046adbc2003b40bcd043
    ├── 39162ef03996e5081d9f3db96dfceca92824ca7b775def0081f5cbaba87ce7d0
    ├── 4dc288c2a12b53c80ab208a9570f5a16375b11169503bb936f3dac0cbd9a16bf
    ├── d92fcec50fe94a7e11863eb7fe3d2274d393c4ad58b12391c3767368bd879786
    └── fbf127ad54acd260782ea286ed0ca9a69fd05a90cc4b9d6536ff46f8fee895fd
```
这里是ubuntu16.04镜像的目录结构，其中的layer目录描述了各个层级的镜像关系，该目录的层级镜像是：
```shell
fbf127ad54acd260782ea286ed0ca9a69fd05a90cc4b9d6536ff46f8fee895fd
4dc288c2a12b53c80ab208a9570f5a16375b11169503bb936f3dac0cbd9a16bf
2c7fd8e0b5de0f19021819f7dd18be5382180625d453046adbc2003b40bcd043
39162ef03996e5081d9f3db96dfceca92824ca7b775def0081f5cbaba87ce7d0
d92fcec50fe94a7e11863eb7fe3d2274d393c4ad58b12391c3767368bd879786
```

/var/lib/docker/image/aufs下各目录的功能：
```shell
root@ubuntu:/var/lib/docker/image/aufs# tree -L 2
.
├── distribution
│   ├── diffid-by-digest            #存放digest到diffid的对应关系
│   └── v2metadata-by-diffid        #存放diffid到digest的对应关系
├── imagedb
│   ├── content                     #存放镜像的config文件
│   └── metadata                    #里面存放的是本地image的一些信息，从服务器上pull下来的image不会存数据到这个目录
├── layerdb
│   ├── mounts                      #创建container时，docker会为每个container在image的基础上创建一层新的layer，里面主要包含/etc/hosts、/etc/hostname、/etc/resolv.conf等文件
│   ├── sha256                      #存放layer层的信息
|       ├── cb11ba6054003d39da5c681006ea346e04fb3444086331176bf57255f149c670    #layer的chainid
|       │   ├── cache-id            #docker下载layer的时候在本地生成的一个随机uuid，指向layer真正存放的位置
|       │   ├── diff                #存放layer的diffid
|       │   ├── parent              #当前layer的父layer的diffid
|       │   ├── size                #当前layer的大小
|       │   └── tar-split.json.gz   #layer压缩包的split文件，通过这个文件可以还原layer的tar包，在docker save导出image的时候会用到
|       └── └── tmp
└── repositories.json
```

distribution目录内容：
```shell
root@ubuntu:/var/lib/docker/image/aufs/distribution/v2metadata-by-diffid/sha256# cat cb11ba6054003d39da5c681006ea346e04fb3444086331176bf57255f149c670 | python -mjson.tool
[
    {
        "Digest": "sha256:75c416ea735c42a4a0b2c8f31946a1918adc7853373c411abbec424391fb989c",
        "HMAC": "",
        "SourceRepository": "docker.io/library/ubuntu"
    }
]
root@ubuntu:/var/lib/docker/image/aufs/distribution/v2metadata-by-diffid/sha256# cd -
/var/lib/docker/image/aufs/distribution/diffid-by-digest/sha256
root@ubuntu:/var/lib/docker/image/aufs/distribution/diffid-by-digest/sha256# cat 75c416ea735c42a4a0b2c8f31946a1918adc7853373c411abbec424391fb989c
sha256:cb11ba6054003d39da5c681006ea346e04fb3444086331176bf57255f149c670
```

Docker容器镜像的层级结构的信息保存在/var/lib/docker/image/aufs/imagedb/content/sha256目录下，针对于之前创建的容器镜像记录，都可以在该目录下看到：
```shell
root@ubuntu:~# docker history b39
IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
b39c1b25586e        47 hours ago        /bin/sh -c #(nop)  EXPOSE 22/tcp 80/tcp         0B
698adb2a6dee        47 hours ago        /bin/sh -c #(nop)  CMD ["bash"]                 0B
f0254284f07e        47 hours ago        /bin/sh -c #(nop)  ENTRYPOINT ["sh" "start...   0B
70fe6a05ad22        47 hours ago        /bin/sh -c #(nop) COPY file:dfe284f0f8d737...   118B
33ec967089b5        47 hours ago        /bin/sh -c #(nop) COPY file:c95633f653136f...   24B
1b9aa9f99fa7        47 hours ago        /bin/sh -c #(nop) WORKDIR /home/liuyikang       0B
2d9b437964d6        47 hours ago        /bin/sh -c #(nop)  VOLUME [/data]               0B
36c54d4063be        47 hours ago        /bin/sh -c sed -i s@/archive.ubuntu.com/@/...   146MB
74360c1f6451        2 days ago          /bin/sh -c #(nop)  ENV VERSION=1.0 DEBUG=o...   0B
3e8b9e9c81aa        2 days ago          /bin/sh -c #(nop)  MAINTAINER liuyikang "l...   0B
d355ed3537e9        2 weeks ago         /bin/sh -c #(nop)  CMD ["/bin/bash"]            0B
<missing>           2 weeks ago         /bin/sh -c mkdir -p /run/systemd && echo '...   7B
<missing>           2 weeks ago         /bin/sh -c sed -i 's/^#\s*\(deb.*universe\...   2.76kB
<missing>           2 weeks ago         /bin/sh -c rm -rf /var/lib/apt/lists/*          0B
<missing>           2 weeks ago         /bin/sh -c set -xe   && echo '#!/bin/sh' >...   745B
<missing>           2 weeks ago         /bin/sh -c #(nop) ADD file:c251a21fbe3a651...   119MB


root@ubuntu:/var/lib/docker/image/aufs/imagedb/content/sha256# tree -L 2
.
├── 1b9aa9f99fa783b3e3c9669a6ded3de1b0e00969deb9e2883d80bc6ab1dad075
├── 2d9b437964d625492edc45fd9d9c0b7275a76262446841fc81cacf25c6a9c5d6
├── 33ec967089b57138d1b63ce764f62e25eb657a4f3073d099b383dc04ff2a647d
├── 36c54d4063be6ffa78df335ecdc1b9631010ab94fdf70842d1e902ae20a81511
├── 3e8b9e9c81aa1f02fac364f6f1fa5cf20bb7b3e0f6bbdc87dc18411bcc044774
├── 698adb2a6deee961fd33b9420c842f52f45b05a3f78b6b79ef601f0ffc9e2910
├── 70fe6a05ad22155cdcc4c9c3e960e70f5d232e9807401b122b0c261024b6f90c
├── 74360c1f645155d575c42a98be7a01ddf2ce41e5f368715f39bb11fb6eaef32d
├── b39c1b25586e0135b06264ff97a516984a7642edce0ea24f8b4fa2f0db85f4b4
├── d355ed3537e94e76389fd78b77241eeba58a11b8faa501594bc82d723eb1c7f2
└── f0254284f07e5cabacadc151a88b2739a79d669a1ff4044d67801653c62504ae
```
在使用dockerfile创建了新的容器镜像之后，/var/lib/docker/aufs目录的内容发生了变化，增加了4个镜像的数据：
```shell
root@ubuntu:/var/lib/docker/aufs/layers# tree -L 2
.
├── 08eb1c030fedf257db2d6d0ccd2c5f803a7aac5a10d5eb041376a251566448b4
├── 2654ceac242642ca946c4422a2adff3e187ecebe441eae04dd5e342a3d90e0db
├── 2c7fd8e0b5de0f19021819f7dd18be5382180625d453046adbc2003b40bcd043
├── 39162ef03996e5081d9f3db96dfceca92824ca7b775def0081f5cbaba87ce7d0
├── 4dc288c2a12b53c80ab208a9570f5a16375b11169503bb936f3dac0cbd9a16bf
├── 96abcdab37fee34c216baab3f51f398edc987c3d310fcc5a20d1e4c71c534f66
├── d6c86d71bd859e045a9b847f3e0c0056068240e1d314b321e86a0f9fd95de194
├── d92fcec50fe94a7e11863eb7fe3d2274d393c4ad58b12391c3767368bd879786
└── fbf127ad54acd260782ea286ed0ca9a69fd05a90cc4b9d6536ff46f8fee895fd

```

/var/lib/docker/image/aufs/imagedb/content/sha256目录内文件内容包含了diff_id，用来与前面提到的diff_id对应，下面以ubuntu镜像为例：
```shell
root@ubuntu:/var/lib/docker/image/aufs/imagedb/content/sha256# cat d355ed3537e94e76389fd78b77241eeba58a11b8faa501594bc82d723eb1c7f2 | python -mjson.tool
...
...
"rootfs": {
    "diff_ids": [
        "sha256:cb11ba6054003d39da5c681006ea346e04fb3444086331176bf57255f149c670",
        "sha256:5a4c2c9a24fc72cc78b3dabee0ae32be12ab197732df433ecb81cef8a00b5f87",
        "sha256:182d2a55830d06a1f25899b81a3fc83dfc4e30eb5c8cad164e0024657dba7528",
        "sha256:6f9cf951edf547ab4895ee15110108dd6659952b1479a95bd348c204035da461",
        "sha256:0566c118947e4983e51c1deddc184238cb372d4318c75a15f9a143a89797c04a"
    ],
    "type": "layers"
}
```

# Docker容器的使用

- **启动容器**

    启动容器有两种方式，一种使用run命令创建并启动一个新的容器，另一种是使用start命令启动一个处于非运行状态的容器。
    ```shell
    root@ubuntu:~# docker run ubuntu:16.04 echo "hello,world"
    hello,world
    root@ubuntu:~# docker ps -a
    CONTAINER ID        IMAGE               COMMAND              CREATED             STATUS                     PORTS               NAMES
    4e0f45560e0d        ubuntu:16.04        "echo hello,world"   10 seconds ago      Exited (0) 9 seconds ago                       stoic_heyrovsky
    ```
    这里创建并启动了一个新的容器来打印hello,world信息。可以详细看一下容器的信息。
    如果希望和容器进行交互，可以指定run的参数：*-t*，可以让docker分配一个伪终端并绑定到容器的标准输入上；*-i*，可以让容器的标准输入保持打开。

    除了run命令之外，也可以使用start命令启动一个非运行态的容器。
    ```shell
    root@ubuntu:~# docker create ubuntu:16.04 echo "hello,world"
    ae50392c300012498dbdf4b132cb2d7b64db36c7e1c1431bc83b89574b37d67b
    root@ubuntu:~# docker start ae5
    ae5
    root@ubuntu:~# docker ps -a
    CONTAINER ID        IMAGE               COMMAND              CREATED             STATUS                     PORTS               NAMES
    ae50392c3000        ubuntu:16.04        "echo hello,world"   21 seconds ago      Exited (0) 3 seconds ago                       peaceful_lovelace
    root@ubuntu:~# docker start -a ae5
    hello,world
    ```

    也可以在创建容器的时候指定-t，-i参数。
    ```shell
    root@ubuntu:~# docker create -ti ubuntu:16.04
    dd55315c8a80f4405b4c276cb044e03bf3163ecfaa47dc77e72ec5542f739f38
    root@ubuntu:~# docker ps -a
    CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
    dd55315c8a80        ubuntu:16.04        "/bin/bash"         3 seconds ago       Created                                 angry_spence
    root@ubuntu:~# docker start -i dd5
    root@dd55315c8a80:/# ls
    bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
    ```

- **后台运行**

    容器的运行的时候可以指定-d参数来让容器保持后台运行。
    ```shell
    #不指定-d参数
    root@ubuntu:~# docker run ubuntu:16.04 /bin/sh -c "while true; do echo hello world;sleep 1;done"
    hello world
    hello world
    hello world
    hello world

    #指定-d参数
    root@ubuntu:~# docker run -d ubuntu:16.04 /bin/sh -c "while true; do echo hello world;sleep 1;done"
    7fc7909cbeffba7eef69e21e276eda03ee709dbfc944bf78e4a050077e2de325
    root@ubuntu:~# docker ps -a
    CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                      PORTS               NAMES
    7fc7909cbeff        ubuntu:16.04        "/bin/sh -c 'while..."   2 seconds ago       Up 2 seconds                                    distracted_kirch

    #可以使用logs查看输出情况
    root@ubuntu:~# docker logs 7fc
    hello world
    hello world
    hello world
    hello world
    hello world

    #也可以使用attach进入容器主进程
    root@ubuntu:~# docker attach 7fc
    hello world
    hello world
    hello world
    hello world
    ```

- **终止和删除容器**

    终止容器使用stop命令，删除容器使用rm命令。

- **进入容器**

    进入容器有多种不同的方式，这里介绍两种通过docker命令进入容器的方式：一种是使用attach方式进入容器主进程，一种是exec重新打开一个终端进程。
    ```shell
    #attach方式，该方式使用exit或者ctrl-C退出都会终止主线程的执行，可以使用Ctrl+p+q的方式退出
    root@ubuntu:~# docker attach 7fc
    hello world
    hello world
    hello world

    #exec方式，该方式退出不会影响主进程的执行
    root@ubuntu:~# docker exec -ti 7fc /bin/bash
    root@7fc7909cbeff:/# ls
    bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
    ```

- **导入和导出**

    容器的保存可以使用export命令进行容器的导出。
    ```shell
    root@ubuntu:~# docker run --name test ubuntu:16.04
    root@ubuntu:~# docker ps -a
    CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                     PORTS               NAMES
    3d7dba437dde        ubuntu:16.04        "/bin/bash"         2 seconds ago       Exited (0) 2 seconds ago                       test
    root@ubuntu:~# docker export 3d7 > test.tar
    root@ubuntu:~# ls
    devstack.tar  instance  myImage  myredis  namespace  test.sh  test.tar
    ```

    导出的文件可以使用import命令重新导入成一个新的镜像文件。
    ```shell
    root@ubuntu:~# docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
    myimage             liuyikang           b39c1b25586e        5 days ago          265MB
    ubuntu              16.04               d355ed3537e9        2 weeks ago         119MB
    root@ubuntu:~# cat test.tar | docker import - test/ubuntu:v1.0
    sha256:2f87cec008f884acc91189bfcd9796fd7bbd810ad8b24bc21753a3e046666c88
    root@ubuntu:~# docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
    test/ubuntu         v1.0                2f87cec008f8        5 seconds ago       97.7MB
    myimage             liuyikang           b39c1b25586e        5 days ago          265MB
    ubuntu              16.04               d355ed3537e9        2 weeks ago         119MB
    ```

# 创建本地的容器仓库

仓库（Repository）是集中存放镜像的地方。

一个容易混淆的概念是注册服务器（Registry）。实际上注册服务器是管理仓库的具体服务器，每个服务器上可以有多个仓库，而每个仓库下面有多个镜像。从这方面来说，仓库可以被认为是一个具体的项目或目录。例如对于仓库地址dl.dockerpool.com/ubuntu 来说， dl.dockerpool.com 是注册服务器地址， ubuntu 是仓库名。

- **Docker官方仓库Docker Hub**

    Docker 官方维护了一个公共仓库 Docker Hub，其中已经包括了超过 15,000 的镜像，大部分的镜像都可以直接从Docker Hub下载。

- **本地仓库**
    Docker官方提供了docker-registry工具用来搭建本地的私人仓库。
    ```shell
    docker pull registry
    ```

    也可以使用源安装的方式：
    ```shell
    apt-get install -y build-essential python-dev libevent-dev python-pip liblzma-dev
    pip install docker-registry
    ```


# 问题记录
* Docker的Ubuntu镜像安装的容器无ifconfig命令和ping命令
```shell
    apt install net-tools       # ifconfig
    apt install iputils-ping     # ping
```

* Docker1.10以上版本可以使用/etc/docker/daemon.json配置文件配置Docker相关参数

官方配置文件：
```json
{
    "api-cors-header": "",
    "authorization-plugins": [],
    "bip": "",
    "bridge": "",
    "cgroup-parent": "",
    "cluster-store": "",
    "cluster-store-opts": {},
    "cluster-advertise": "",
    "debug": true,
    "default-gateway": "",
    "default-gateway-v6": "",
    "default-runtime": "runc",
    "default-ulimits": {},
    "disable-legacy-registry": false,
    "dns": [],
    "dns-opts": [],
    "dns-search": [],
    "exec-opts": [],
    "exec-root": "",
    "fixed-cidr": "",
    "fixed-cidr-v6": "",
    "graph": "",
    "group": "",
    "hosts": [],
    "icc": false,
    "insecure-registries": [],
    "ip": "0.0.0.0",
    "iptables": false,
    "ipv6": false,
    "ip-forward": false,
    "ip-masq": false,
    "labels": [],
    "live-restore": true,
    "log-driver": "",
    "log-level": "",
    "log-opts": {},
    "max-concurrent-downloads": 3,
    "max-concurrent-uploads": 5,
    "mtu": 0,
    "oom-score-adjust": -500,
    "pidfile": "",
    "raw-logs": false,
    "registry-mirrors": [],
    "runtimes": {
        "runc": {
            "path": "runc"
        },
        "custom": {
            "path": "/usr/local/bin/my-runc-replacement",
            "runtimeArgs": [
                "--debug"
            ]
        }
    },
    "selinux-enabled": false,
    "storage-driver": "",
    "storage-opts": [],
    "swarm-default-advertise-addr": "",
    "tls": true,
    "tlscacert": "",
    "tlscert": "",
    "tlskey": "",
    "tlsverify": true,
    "userland-proxy": false,
    "userns-remap": ""
}
```
