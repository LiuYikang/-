# cni-geine多网络的支持

cni-genie是一个开源的多cni网络支持的插件。

这里演示calico+flannel配置的cni插件的使用。

## 1. flannel网络的配置
这里使用默认的[flannel.yaml](./cni-genie/flannel.yaml)文件配置flannel网络。
```shell
kubectl apply -f flannel.yaml
```

配置完成后查看：
```shell
# ps -ef | grep flannel
root      1616  1597  0 Feb16 ?        00:17:39 /opt/bin/flanneld --ip-masq --kube-subnet-mgr

# ll /etc/cni/net.d/10-flannel.conflist
-rw-r--r-- 1 root root 403 Feb 19 11:33 /etc/cni/net.d/10-flannel.conflist
```

## 2. calico网络的配置
使用修改后的的[calico.yaml](./cni-genie/calico.yaml)文件配置calico网络

因为是多网络模型，flannel已经使用了kube-controller-manager默认的pod网络，因此calico只能使用etcd配置自己的网络。
```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: calico-config
  namespace: kube-system
data:
  # Configure this with the location of your etcd cluster.
  etcd_endpoints: "https://127.0.0.1:2379"

  # If you're using TLS enabled etcd uncomment the following.
  # You must also populate the Secret below with these files.
  etcd_ca: "/etc/kubernetes/pki/etcd/ca.crt"   # "/calico-secrets/etcd-ca"
  etcd_cert: "/etc/kubernetes/pki/apiserver-etcd-client.crt" # "/calico-secrets/etcd-cert"
  etcd_key: "/etc/kubernetes/pki/apiserver-etcd-client.key"  # "/calico-secrets/etcd-key"
  # Typha is disabled.
  typha_service_name: "none"
  # Configure the Calico backend to use.
  calico_backend: "bird"

  # Configure the MTU to use
  veth_mtu: "1440"

  # The CNI network configuration to install on each node.  The special
  # values in this config will be automatically populated.
  cni_network_config: |-
    {
      "name": "k8s-pod-network",
      "cniVersion": "0.3.0",
      "plugins": [
        {
          "type": "calico",
          "log_level": "info",
          "etcd_endpoints": "__ETCD_ENDPOINTS__",
          "etcd_key_file": "__ETCD_KEY_FILE__",
          "etcd_cert_file": "__ETCD_CERT_FILE__",
          "etcd_ca_cert_file": "__ETCD_CA_CERT_FILE__",
          "mtu": __CNI_MTU__,
          "ipam": {
              "type": "calico-ipam"
          },
          "policy": {
              "type": "k8s"
          },
          "kubernetes": {
              "kubeconfig": "__KUBECONFIG_FILEPATH__"
          }
        },
        {
          "type": "portmap",
          "snat": true,
          "capabilities": {"portMappings": true}
        }
      ]
    }
```

另外，这里使用calico的bgp模式进行网络路由，因此需要关闭pip。
```yaml
# Enable IPIP
- name: CALICO_IPV4POOL_IPIP
  value: "Never"   # "Always"
```

指定calico使用的网卡，增加一个环境变量IP_AUTODETECTION_METHOD
```yaml
- name: IP_AUTODETECTION_METHOD
  value: interface=eth0
```

修改calico使用的网络地址
```yaml
- name: CALICO_IPV4POOL_CIDR
  value: "172.120.0.0/16"
```

以上配置全部完成之后，便可以部署calico
```shell
kubectl apply -f calico.yaml
```

查看calico部署后的信息：
```
# ps -ef | grep calico
root      8851  8847  0 Feb20 ?        00:00:38 calico-node -confd
root      8854  8850  2 Feb20 ?        01:28:00 calico-node -felix
root      8991  8848  0 Feb20 ?        00:01:58 bird -R -s /var/run/calico/bird.ctl -d -c /etc/calico/confd/config/bird.cfg
root      8992  8849  0 Feb20 ?        00:02:21 bird6 -R -s /var/run/calico/bird6.ctl -d -c /etc/calico/confd/config/bird6.cfg

# ll /etc/cni/net.d/
total 28
-rw-r--r-- 1 root root  697 Feb 20 13:52 10-calico.conflist
-rw-r--r-- 1 root root  403 Feb 19 11:33 10-flannel.conflist
-rw------- 1 root root 2566 Feb 20 13:52 calico-kubeconfig
drwxr-xr-x 2 root root 4096 Feb 20 13:52 calico-tls
```

其中10-calico.conflist的配置如下：
```json
{
  "name": "k8s-pod-network",
  "cniVersion": "0.3.0",
  "plugins": [
    {
      "type": "calico",
      "log_level": "info",
      "etcd_endpoints": "https://127.0.0.1:2379",
      "etcd_key_file": "/etc/cni/net.d/calico-tls/etcd-key",
      "etcd_cert_file": "/etc/cni/net.d/calico-tls/etcd-cert",
      "etcd_ca_cert_file": "/etc/cni/net.d/calico-tls/etcd-ca",
      "mtu": 1440,
      "ipam": {
          "type": "calico-ipam"
      },
      "policy": {
          "type": "k8s"
      },
      "kubernetes": {
          "kubeconfig": "/etc/cni/net.d/calico-kubeconfig"
      }
    },
    {
      "type": "portmap",
      "snat": true,
      "capabilities": {"portMappings": true}
    }
  ]
}
```

## 3. 配置cni-geine
修改genie-plugin的daemonset中的tolerations，增加以下内容：
```yaml
- effect: NoSchedule
  key: node-role.kubernetes.io/master
```

修改configmap，增加默认plugin的配置：
```yaml
"default_plugin": "flannel"
```

使用[genie-plugin.yaml](./cni-genie/genie-plugin.yaml)部署cni-geine。
```shell
kubectl apply -f genie-plugin.yaml
```

部署完成之后，查看相关信息：
```shell
# ls /opt/cni/bin/
bridge  calico  calico-ipam  dhcp  flannel  genie  host-local  ipvlan  loopback  macvlan  multus  portmap  ptp  sample  tuning  vlan

ll /etc/cni/net.d/
total 28
-rw-r--r-- 1 root root 1308 Feb 19 11:39 00-genie.conf
-rw-r--r-- 1 root root  697 Feb 20 13:52 10-calico.conflist
-rw-r--r-- 1 root root  403 Feb 19 11:33 10-flannel.conflist
-rw-r--r-- 1 root root  339 Feb 19 14:58 10-macvlan.conf
-rw------- 1 root root 2566 Feb 20 13:52 calico-kubeconfig
drwxr-xr-x 2 root root 4096 Feb 20 13:52 calico-tls
-rw-r--r-- 1 root root  271 Feb 19 11:39 genie-kubeconfig
```

其中00-genie.conf里的信息如下：
```json
{
    "name": "k8s-pod-network",
    "type": "genie",
    "log_level": "info",
    "datastore_type": "kubernetes",
    "hostname": "master",
    "policy": {
        "type": "k8s",
        "k8s_auth_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJnZW5pZS1wbHVnaW4tdG9rZW4tbXRzbWsiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZ2VuaWUtcGx1Z2luIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiMDI3ZjIzMWQtMzNmOC0xMWU5LWI4NTYtZmExNjNlNmExODAzIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmdlbmllLXBsdWdpbiJ9.dMn-B-gyhrrH8mZAxwAP6j9vSoATnatOho_jA8sdb-f0WibqvDGVm8Z22kESWaHIx305TuRCH9rh9Pqzco96KrET8-eoV-dafCcV25A4nIUYe5JHTgyMAnd9zsJ3ova9urkwz9LI7xTxxo4OSda1TlIJz56rNYA8aI1zGoKEdNUb_bd7JpvapoOFTx4YGbzLRKL9bdTAzcwOUYLdHn8a75qa9PO_lyl-RuPvAismsmX5nKT8EWGf8McU-s4iJBzOxU1n3LRsAX9CCij2RgXCEhI71Qovfl67iZo5YvF3F_W4oWR_LB2-mNlDHoM5uMgqnJoCdl0vDCJdBkkxezFE-g"
    },
    "kubernetes": {
        "k8s_api_root": "https://172.16.0.1:443",
        "kubeconfig": "/etc/cni/net.d/genie-kubeconfig"
    },
    "romana_root": "http://:",
    "segment_label_name": "romanaSegment"
}
```

## 4. 重启kubelet
重启kubelet，此时kubelet默认使用的cni文件是00-genie.conf
```shell
systemctl restart kubelet
```

## 5. 测试网络分配
使用[busybox1.yaml](./cni-genie/busybox1.yaml)和[busybox2.yaml](./cni-genie/busybox2.yaml)来测试网络分配。
```yaml
# busybox1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox1
  labels:
    app: busybox1
  annotations:
    cni: calico
spec:
  containers:
  - image: busybox:1.25.0
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
    name: busybox2
  restartPolicy: Always

# busybox2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox2
  labels:
    app: busybox2
  annotations:
    cni: flannel
spec:
  containers:
  - image: busybox:1.25.0
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
    name: busybox2
  restartPolicy: Always
```

部署成功后，查看busybox1和busybox2的ip：
```shell
# kubectl get pod
NAME          READY     STATUS    RESTARTS   AGE
busybox1      1/1       Running   54         2d
busybox2      1/1       Running   54         2d
nginx-canal   1/1       Running   0          2d

# kubectl exec busybox1 -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if95: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1440 qdisc noqueue
    link/ether a2:85:16:bf:15:18 brd ff:ff:ff:ff:ff:ff
    inet 172.120.126.128/32 scope global eth0
       valid_lft forever preferred_lft forever
       
# kubectl exec busybox2 -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if97: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 0a:58:ac:60:00:3e brd ff:ff:ff:ff:ff:ff
    inet 172.96.0.62/24 scope global eth0
       valid_lft forever preferred_lft forever
```
