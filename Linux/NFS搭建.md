## 简介
NFS(Network File System）即网络文件系统。它的主要功能是通过网络让不同主机系统之间可以共享文件或目录。

RPC（Remote Procedure Call Protocol）远程过程调用协议。它是一种通过网络从远程计算机程序上请求服务，而不需要了解底层网络技术的协议。

## 服务端配置
### 安装nfs
yum install nfs-utils rpcbind

### 配置
默认配置文件：/etc/export

配置格式：NFS共享目录绝对路径    NFS客户端地址（参数）

配置参数：
* rw             read-write   读写
* ro             read-only    只读
* sync           请求或写入数据时，数据同步写入到NFS server的硬盘后才返回。数据安全，但性能降低了
* async          优先将数据保存到内存，硬盘有空档时再写入硬盘，效率更高，但可能造成数据丢失。
* root_squash    当NFS 客户端使用root 用户访问时，映射为NFS 服务端的匿名用户
* no_root_squash 当NFS 客户端使用root 用户访问时，映射为NFS 服务端的root 用户
* all_squash     不论NFS 客户端使用任何帐户，均映射为NFS 服务端的匿名用户

eg：
```
/opt/share_nfs 192.168.233.0/24(rw,sync,root_squash)
```

### 添加目录权限
**把NFS共享目录赋予 NFS默认用户nfsnobody用户和用户组权限，如不设置，会导致NFS客户端无法在挂载好的共享目录中写入数据**
```shell
chown -R nfsnobody.nfsnobody /opt/share_nfs
```

### 启动服务
```shell
systemctl start nfs
systemctl start rpcbind
```

## 客户端
### 安装
yum install nfs-utils rpcbind

### 关闭防火墙
systemctl stop firewalld

### 发现远程服务器
showmount -e 192.168.233.8（远程服务器地址）

### 挂载目录
```shell
mkdir -p /sharedir
mount -t nfs 192.168.233.2:/opt/share_nfs /sharedir/
```
