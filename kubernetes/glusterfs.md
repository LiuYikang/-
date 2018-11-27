## 安装部署glusterfs

### 环境
三个master节点，同时也是3个node节点：
* 192.168.233.2 master1
* 192.168.233.3 master2
* 192.168.233.8 master3

### rpm包
所有节点都要安装
```
yum install glusterfs glusterfs-server glusterfs-api glusterfs-cli glusterfs-fuse
```

### 启动gluster
所有节点都要执行
```shell
systemctl enable glusterd
systemctl start glusterd
```

## 添加节点
在master1上执行：
```shell
gluster peer probe master2
gluster peer probe master3
```

查看节点状态：
```shell
[root@master1 glusterfs]# gluster peer status
Number of Peers: 2

Hostname: master2
Uuid: 657c91df-0130-46cf-bb9d-6a2dd62a72b5
State: Peer in Cluster (Connected)

Hostname: master3
Uuid: 53fe861e-25b4-4705-87ee-3d05eba11f02
State: Peer in Cluster (Connected)
```

## glusterfs本地挂载
创建glusterfs卷
```shell
[root@host-192-168-145-2 ~]# gluster peer probe etcd2
peer probe: success.
[root@host-192-168-145-2 ~]# gluster volume create etcd replica 2 etcd1:/opt/etcd etcd2:/opt/etcd force
volume create: etcd: success: please start the volume to access data
[root@host-192-168-145-2 ~]# gluster volume info
Volume Name: etcd
Type: Replicate
Volume ID: 17a28e06-6105-4202-9608-545399e2228a
Status: Created
Snapshot Count: 0
Number of Bricks: 1 x 2 = 2
Transport-type: tcp
Bricks:
Brick1: etcd1:/opt/etcd
Brick2: etcd2:/opt/etcd
Options Reconfigured:
transport.address-family: inet
performance.readdir-ahead: on
nfs.disable: on
[root@host-192-168-145-2 ~]# gluster volume start etcd
volume start: etcd: success
```

glusterfs服务端挂载glusterfs卷，需要在/etc/fstab中增加配置：
```

#
# /etc/fstab
# Created by anaconda on Wed Sep  5 14:40:09 2018
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
UUID=cd3c222a-cf76-4bab-954e-396419880dd0 /                       ext4    defaults        1 1
UUID=1593e64f-8686-44b3-b33a-58aed4349ea0 /boot                   ext4    defaults        1 2
UUID=6afea0bc-c742-458c-93ac-b402cecb303e swap                    swap    defaults        0 0
127.0.0.1:/etcd    /opt/test_mount  glusterfs defaults,_netdev  0  0     #增加配置内容
```

mount -a，使挂载生效，该挂载方式需要每一个服务端节点上都进行配置

## 部署使用gluster的harbor

### 部署gluster的volume
* 在三个节点上创建目录，用于创建glusterfs的volume
    ```
    /opt/glusterfs/harbor-adminserver-pv
    /opt/glusterfs/harbor-database-pv
    /opt/glusterfs/harbor-registry-pv
    ```
* 在节点master1上执行以下命令（以下步骤均以在该节点执行为例，也可在其他节点执行），创建glusterfs的volume：
    ```shell
    [root@master1 ~]# gluster volume create harbor-adminserver replica 3 master1:/opt/glusterfs/harbor-adminserver-pv master2:/opt/glusterfs/harbor-adminserver-pv master3:/opt/glusterfs/harbor-adminserver-pv force
    [root@master1 ~]# gluster volume create harbor-database replica 3 master1:/opt/glusterfs/harbor-database-pv master2:/opt/glusterfs/harbor-database-pv master3:/opt/glusterfs/harbor-database-pv force
    [root@master1 ~]# gluster volume create harbor-registry replica 3 master1:/opt/glusterfs/harbor-registry-pv master2:/opt/glusterfs/harbor-registry-pv master3:/opt/glusterfs/harbor-registry-pv force
    ```
* 查看创建的volume
    ```shell
    [root@master1 glusterfs]# gluster volume info

    Volume Name: harbor-adminserver
    Type: Replicate
    Volume ID: b69f73a9-ae92-4c62-baa9-7a3c133129d8
    Status: Created
    Snapshot Count: 0
    Number of Bricks: 1 x 3 = 3
    Transport-type: tcp
    Bricks:
    Brick1: master1:/opt/glusterfs/harbor-adminserver-pv
    Brick2: master2:/opt/glusterfs/harbor-adminserver-pv
    Brick3: master3:/opt/glusterfs/harbor-adminserver-pv
    Options Reconfigured:
    transport.address-family: inet
    performance.readdir-ahead: on
    nfs.disable: on

    Volume Name: harbor-database
    Type: Replicate
    Volume ID: 56d77275-6690-4391-9f0e-af9e5cd3436e
    Status: Created
    Snapshot Count: 0
    Number of Bricks: 1 x 3 = 3
    Transport-type: tcp
    Bricks:
    Brick1: master1:/opt/glusterfs/harbor-database-pv
    Brick2: master2:/opt/glusterfs/harbor-database-pv
    Brick3: master3:/opt/glusterfs/harbor-database-pv
    Options Reconfigured:
    transport.address-family: inet
    performance.readdir-ahead: on
    nfs.disable: on

    Volume Name: harbor-registry
    Type: Replicate
    Volume ID: c885c6d6-20fd-4961-9857-fa0786b07372
    Status: Created
    Snapshot Count: 0
    Number of Bricks: 1 x 3 = 3
    Transport-type: tcp
    Bricks:
    Brick1: master1:/opt/glusterfs/harbor-registry-pv
    Brick2: master2:/opt/glusterfs/harbor-registry-pv
    Brick3: master3:/opt/glusterfs/harbor-registry-pv
    Options Reconfigured:
    transport.address-family: inet
    performance.readdir-ahead: on
    nfs.disable: on
    ```

* 启动volume
    ```shell
    gluster volume start harbor-registry
    gluster volume start harbor-database
    gluster volume start harbor-adminserver
    ```
### 部署glusterfs的endpoint和service

* endpoint的yaml如下：
    ```yaml
    apiVersion: v1
    kind: Endpoints
    metadata:
      name: glusterfs-cluster
    subsets:
    - addresses:
      - ip: 192.168.233.2
      ports:
      - port: 23333
    - addresses:
      - ip: 192.168.233.3
      ports:
      - port: 23333
    - addresses:
      - ip: 192.168.233.8
      ports:
      - port: 23333
    ```

* service的yaml：
    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: glusterfs-cluster
    spec:
      ports:
      - port: 23333
    ```

* 部署endpoint和service：
    ```shell
    kubectl apply -f glusterfs-endpoints.yaml -n kube-system
    kubectl apply -f glusterfs-service.yaml -n kube-system

    #查看
    [root@master1 ~]# kubectl get ep glusterfs-cluster -n kube-system -o wide
    NAME                ENDPOINTS                                                     AGE
    glusterfs-cluster   192.168.233.2:23333,192.168.233.3:23333,192.168.233.8:23333   3h

    [root@master1 ~]# kubectl get service glusterfs-cluster -o wide -n kube-system
    NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE       SELECTOR
    glusterfs-cluster   ClusterIP   172.19.15.110   <none>        23333/TCP   3h        <none>
    ```

### 修改harbor的配置

* 修改pv配置,修改storageclass的名称和引用，删除pv的hostPath，增加glusterfs的配置，示例如下：
    ```yaml
    ---
    kind: StorageClass
    apiVersion: storage.k8s.io/v1
    metadata:
      name: glusterfs-storage
    provisioner: kubernetes.io/no-provisioner
    volumeBindingMode: WaitForFirstConsumer
    reclaimPolicy: Retain
    ---
    kind: PersistentVolume
    apiVersion: v1
    metadata:
      name: harbor-database-pv
      labels:
        type: glusterfs
        pvctype: database-pv
    spec:
      storageClassName: glusterfs-storage
      capacity:
        storage: 2Gi
      accessModes:
        - ReadWriteOnce
      glusterfs:
        endpoints: "glusterfs-cluster"
        path: "harbor-database"
        readOnly: false
    ```

    其中harbor-database-pv、harbor-adminserver-pv、harbor-registry-pv都要修改

* 修改harbor配置，将配置中的local-storage修改为glusterfs-storage即可。

### 验证harbor可用
* 在master1部署
    ```shell
    kubectl apply -f harbor/ -n kube-system
    ```
* 查看
    ```shell
    [root@master3 ~]# kubectl get pod -n kube-system -o wide
    NAME                                        READY     STATUS              RESTARTS   AGE       IP              NODE
    harbor-adminserver-0                    1/1       Running             1          2h        172.18.1.24     master1
    harbor-mysql-0                          1/1       Running             0          2h        172.18.1.26     master1
    harbor-registry-0                       1/1       Running             0          2h        172.18.1.25     master1
    harbor-ui-7c649db8-fsj6z                1/1       Running             3          2h        172.18.2.13     master3
    ```
* 验证，**上传镜像前，先确认项目是否存在，不存在先创建项目**
    ```shell
    [root@master1 ~]# docker login docker.cloud:30001 -u admin -p Harbor12345
    Login Succeeded

    [root@master1 temp]# docker push docker.cloud:30001/liuyikang/busybox:1.25.0
    The push refers to a repository [docker.cloud:30001/liuyikang/busybox]
    8ac8bfaff55a: Pushed
    1.25.0: digest: sha256:c77a342df99a77947a136951e51a2d8ab2c8d5e0af90b56239f45ffd647a4ecb size: 527
    ```

### 切换harbor部署节点
* 修改harbor配置，nodeAffinity中的master1修改为master2，然后重新部署
    ```shell
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                - 'master1'
    ```
* 查看
    ```shell
    [root@master1 temp]# kubectl get pod -n kube-system -o wide
    NAME                                        READY     STATUS    RESTARTS   AGE       IP              NODE
    harbor-adminserver-0                    1/1       Running   0          16s       172.18.0.14     master2
    harbor-mysql-0                          1/1       Running   0          16s       172.18.0.15     master2
    harbor-registry-0                       1/1       Running   0          16s       172.18.0.16     master2
    harbor-ui-7c649db8-q59ts                1/1       Running   0          16s       172.18.2.14     master3
    ```

* 验证仓库数据
    ```shell
    [root@master2 ~]# docker pull docker.cloud:30001/liuyikang/busybox:1.25.0
    1.25.0: Pulling from liuyikang/busybox
    Digest: sha256:c77a342df99a77947a136951e51a2d8ab2c8d5e0af90b56239f45ffd647a4ecb
    Status: Downloaded newer image for docker.cloud:30001/liuyikang/busybox:1.25.0
    ```


## glusterfs的限速方法

glusterfs可以针对volume进行限速，针对volume的TCP端口限制同步的速度。

以下针对replica的卷进行限速，使用tc和iptables工具配合使用。

```shell
# 查询volume的端口，此处端口是49153
[root@host-192-168-145-4 ~]# ps -ef | grep glusterfs
root      1948     1  0 17:04 ?        00:00:03 /usr/sbin/glusterfsd -s etcd3 --volfile-id etcd.etcd3.opt-etcd -p /var/lib/glusterd/vols/etcd/run/etcd3-opt-etcd.pid -S /var/run/gluster/9826adf2d6b086c4e2f8858d13f3ad12.socket --brick-name /opt/etcd -l /var/log/glusterfs/bricks/opt-etcd.log --xlator-option *-posix.glusterd-uuid=67b8e4c6-2fc1-4386-a237-6949f9989478 --brick-port 49153 --xlator-option etcd-server.listen-port=49153

# 创建tc限速规则，限制通信速度为1Mbps
tc qdisc add dev eth0 root handle 1: htb
tc class add dev eth0 parent 1: classid 1:5 htb rate 1Mbps ceil 1Mbps prio 1
tc filter add dev eth0 parent 1:0 protocol ip handle 5 fw flowid 1:5

# 创建iptables规则，将匹配的网络流转发到tc的限制规则里
iptables -A OUTPUT -t mangle -p tcp --dport 49153 -j MARK --set-mark 5
```

