# multus多网络的支持

multus是intel开源，用于支持kubernetes的pod多网卡配置的cni插件。

以下配置在单节点的kubernetes集群中完成。

## 1. 多flannel网络multus的支持

目标：测试多flannel网络是否在multus的管理下进行pod的多网卡配置。

> flannel是coreos开源的，使用overlay模式的网络模型。

### flannel1配置：kube-subnet-mgr模式

flannel1使用了kube-subnet-mgr模式，因此会使用kube-controller-manager启动参数中指定的cluster-cidr=172.96.0.0/16作为网络地址。

使用[kube-flannel-eth0.yaml](./multus/kube-flannel-eth0.yaml)来配置flannel1的flanneld。

yaml改动如下：
1. 在该配置文件中，注释掉了cni-conf.json和initcontainer的配置。在使用multus支持多flannel的接入的时候，cni的配置文件需要使用multus的配置，因此这里将initcontainer生成flannel-cni配置文件的流程注释，仅保留启动flanneld的操作。
2. 增加指定网卡的flanneld启动参数：--iface=eth0，指定flanneld使用eth0进行网络通信和配置。

启动flannel1：
```shell
kubectl apply -f kube-flannel-eth0.yaml
```

### flannel2配置：etcd模式

因为flannel1使用了kube-subnet-mgr的模式，因此，为了保证flannel1和flannel2配置的网络不冲突，需要指定flannel2使用etcd作为存储网络配置的后端存储，手动配置网络和配置文件。

在启动flannel2之前，需要进行一下操作：
1. 创建存放flannel2网络配置的路径
```shell
mkdir -p /var/run/flannel/network
```
2. 仿照/var/run/flannel/subnets.env文件，在/var/run/flannel/network下创建配置文件subnets.env
```shell
FLANNEL_NETWORK=172.112.0.0/16
FLANNEL_SUBNET=172.112.88.1/24
FLANNEL_MTU=1500
FLANNEL_IPMASQ=true
```
3. 创建flannel数据存储目录，存储subnets.env网络相关的数据
```shell
mkdir -p /var/lib/cni/flannel/network2
```
4. 在etcd中注册flannel的网络段：
```shell
etcdctl --ca-file=/etc/kubernetes/pki/etcd/ca.crt --cert-file=/etc/kubernetes/pki/apiserver-etcd-client.crt --key-file=/etc/kubernetes/pki/apiserver-etcd-client.key --endpoint https://127.0.0.1:2379 set /k8s/network2/config '{ "Network": "172.112.0.0/16", "Backend": { "Type": "host-gw" } }'
```

使用[kube-flannel-eth1.yaml](./multus/kube-flannel-eth1.yaml)来配置flannel2的flanneld。

yaml改动如下：
1. 在该配置文件中，注释掉了cni-conf.json和initcontainer的配置。在使用multus支持多flannel的接入的时候，cni的配置文件需要使用multus的配置，因此这里将initcontainer生成flannel-cni配置文件的流程注释，仅保留启动flanneld的操作。
2. 修改net-conf.json中的"Network"为"172.112.0.0/16"。
3. 增加指定网卡的flanneld启动参数：--iface=eth0，指定flanneld使用eth1进行网络通信和配置。
4. 增加了flanneld启动中关于etcd的配置
    ```shell
    - --etcd-prefix=/k8s/network2
    - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
    - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
    - --etcd-endpoints=https://127.0.0.1:2379
    - --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
    ```
5. 指定flanneld中subnet-file的路径，避免使用和flannel1相同的文件：
    ```shell
    - --subnet-file=/run/flannel/network/subnet2.env
    ```

启动flannel1：
```shell
kubectl apply -f kube-flannel-eth1.yaml
```

### 查看flannel进程
```shell
# ps -ef | grep flannel
root      1616  1597  0 Feb16 ?        00:17:39 /opt/bin/flanneld --ip-masq --kube-subnet-mgr --iface=eth0
root     13001 12979  0 Feb16 ?        00:14:29 /opt/bin/flanneld --subnet-file=/run/flannel/network/subnet2.env --etcd-prefix=/k8s/network2 --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt --etcd-endpoints=https://127.0.0.1:2379 --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key --ip-masq --iface=eth1
```

## 2. multus的配置

### 编译multus
1. 下载multus-cni的源码
2. 在multus-cni的目录下执行 ./build
3. 拷贝 multus-cni/bin/multus 到 /opt/cni/bin 路径下

### 启动multus daemonset

使用[multus-daemonset.yml](.\multus\multus-daemonset.yml)文件启动multus daemonset

```shell
kubectl apply -f multus-daemonset.yml
```

### 配置cni的配置文件
将[30-multus.conf](.\multus\30-multus.conf)到/etc/cni/net.d/路径下，拷贝之前将该路径下文件清空。

该文件中在delegates参数中指定了multus的默认网络为flannel.1，改默认网络在下文会进行说明。

### 重启kubelet

重启kubelet，是cni的配置生效。
```shell
systemctl restart kubelet
```

## 3. 配置NetworkAttachmentDefinition
为了能够单独分配网络到pod中，需要定义NetworkAttachmentDefinition的CustomResourceDefinition，作为用户定义的资源，可以在pod部署文件的annotations中去声明需要使用哪一个网络进行配置。

NetworkAttachmentDefinition在multus-daemonset.yml文件中声明，并且在部署multus-daemonset.yml的时候一同部署。
```shell
]# kubectl get crd
NAME                                             CREATED AT
network-attachment-definitions.k8s.cni.cncf.io   2019-02-19T03:08:02Z
```

### 部署NetworkAttachmentDefinition
使用[flannel1-conf.yaml](.\multus\flannel1-conf.yaml)部署flannel1-conf。

使用[flannel2-conf.yaml](.\multus\flannel2-conf.yaml)部署flannel2-conf。

这两个文件在subnetFile、dataDir、bridge参数中进行了区分。
```shell
# kubectl get net-attach-def
NAME            AGE
flannel1-conf   3d
flannel2-conf   3d
```

## 4. pod网络配置
使用busybox进行网络配置的测试。
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  labels:
    app: busybox
  annotations:
    k8s.v1.cni.cncf.io/networks: flannel2-conf
spec:
  containers:
  - image: busybox:1.25.0
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
    name: busybox1
  restartPolicy: Always
```

在以上配置文件的annotations中，声明了需要使用的网络配置k8s.v1.cni.cncf.io/networks。

1. k8s.v1.cni.cncf.io/networks: flannel2-conf
```shell
# kubectl exec busybox -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if73: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 0a:58:ac:60:00:19 brd ff:ff:ff:ff:ff:ff
    inet 172.96.0.25/24 scope global eth0
       valid_lft forever preferred_lft forever
5: net1@if74: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 0a:58:ac:70:58:0c brd ff:ff:ff:ff:ff:ff
    inet 172.112.88.12/24 scope global net1
       valid_lft forever preferred_lft forever
```
2. k8s.v1.cni.cncf.io/networks: flannel1-conf
```shell
# kubectl exec busybox -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if71: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 0a:58:ac:60:00:17 brd ff:ff:ff:ff:ff:ff
    inet 172.96.0.23/24 scope global eth0
       valid_lft forever preferred_lft forever
5: net1@if72: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 0a:58:ac:60:00:18 brd ff:ff:ff:ff:ff:ff
    inet 172.96.0.24/24 scope global net1
       valid_lft forever preferred_lft forever
```

在以上部署的pod中，我们可以看到，pod中会出现两张网卡，第二张网卡对应的便是annotations指定的网络地址。原因如下：
1. multus默认一定需要配置一个默认网络，pod中的第一张网卡便是默认网络的配置，这个配置是提供给kubernetes使用的，pod对应的podIP也是第一张网卡的ip
```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    k8s.v1.cni.cncf.io/networks: flannel2-conf
    k8s.v1.cni.cncf.io/networks-status: |-
      [{
          "name": "flannel.1",
          "ips": [
              "172.96.0.25"
          ],
          "default": true,
          "dns": {}
      },{
          "name": "flannel.2",
          "interface": "net1",
          "ips": [
              "172.112.88.12"
          ],
          "mac": "0a:58:ac:70:58:0c",
          "dns": {}
      }]
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Pod","metadata":{"annotations":{"k8s.v1.cni.cncf.io/networks":"flannel2-conf"},"labels":{"app":"busybox2"},"name":"busybox2","namespace":"default"},"spec":{"containers":[{"command":["sleep","3600"],"image":"docker.hikcloud:30001/k8ss/busybox:1.25.0","imagePullPolicy":"IfNotPresent","name":"busybox1"}],"restartPolicy":"Always"}}
  creationTimestamp: 2019-02-18T08:36:48Z
  labels:
    app: busybox2
  name: busybox2
  namespace: default
  resourceVersion: "571569"
  selfLink: /api/v1/namespaces/default/pods/busybox2
  uid: 54c4e6d8-3358-11e9-b856-fa163e6a1803
spec:
  containers:
  - command:
    - sleep
    - "3600"
    image: busybox:1.25.0
    imagePullPolicy: IfNotPresent
    name: busybox1
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: default-token-6xw9r
      readOnly: true
  dnsPolicy: ClusterFirst
  nodeName: master10-33-46-241
  priority: 0
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext: {}
  serviceAccount: default
  serviceAccountName: default
  terminationGracePeriodSeconds: 30
  tolerations:
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
  volumes:
  - name: default-token-6xw9r
    secret:
      defaultMode: 420
      secretName: default-token-6xw9r
status:
  conditions:
  - lastProbeTime: null
    lastTransitionTime: 2019-02-18T08:36:48Z
    status: "True"
    type: Initialized
  - lastProbeTime: null
    lastTransitionTime: 2019-02-19T01:37:10Z
    status: "True"
    type: Ready
  - lastProbeTime: null
    lastTransitionTime: null
    status: "True"
    type: ContainersReady
  - lastProbeTime: null
    lastTransitionTime: 2019-02-18T08:36:48Z
    status: "True"
    type: PodScheduled
  containerStatuses:
  - containerID: docker://de3895fe2dcc633825bc0dce0cf1b931afbd5a5dd3adfd2e77c28664cdd46106
    image: busybox:1.25.0
    imageID: docker-pullable://library/busybox@sha256:c77a342df99a77947a136951e51a2d8ab2c8d5e0af90b56239f45ffd647a4ecb
    lastState:
      terminated:
        containerID: docker://51082964d1be057fc29b3740e169cc52cf66f78b4449386b5b7974346317c574
        exitCode: 0
        finishedAt: 2019-02-19T01:37:08Z
        reason: Completed
        startedAt: 2019-02-19T00:37:08Z
    name: busybox1
    ready: true
    restartCount: 17
    state:
      running:
        startedAt: 2019-02-19T01:37:09Z
  hostIP: 10.33.46.241
  phase: Running
  podIP: 172.96.0.25
  qosClass: BestEffort
  startTime: 2019-02-18T08:36:48Z
```
2. crd配置pod网络，也是需要存在一个默认的网络配置，当不声明annotations的时候，crd默认会去找/etc/cni/net.d路径下的第一个配置文件，配置该文件对应的cni网络到pod中，如果不存在任何文件，则pod无法启动。
