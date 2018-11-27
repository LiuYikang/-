## 环境
```shell
[root@master1 ~]# kubectl get nodes
NAME               STATUS    ROLES     AGE       VERSION
master1   Ready     master    1d        v1.11.0
node1     Ready     <none>    1d        v1.11.0
```

## 安装nfs
```shell
yum install nfs-utils
```

## 搭建nfs服务端
1. 在另外一塔服务器192.168.233.8上搭建nfs共享目录
    ```
    mkdir -p /opt/share_nfs
    mkdir -p /opt/share_nfs/mysql-pv
    ```
2. 默认配置文件：/etc/export, **这里需要设置no_root_squash，否则无法启动mysql的pod，提示chown: changing ownership of '/var/lib/mysql/': Operation not permitted**
    ```
    /opt/share_nfs 192.168.233.0/24(rw,sync,no_root_squash)
    ```
3. 把NFS共享目录赋予 NFS默认用户nfsnobody用户和用户组权限
    ```
    chown -R nfsnobody.nfsnobody /opt/share_nfs
    ```
4. 启动服务
    ```
    systemctl start nfs
    systemctl start rpcbind
    ```
## 创建pv和pvc
### mysql-pv
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    path: /opt/share_nfs/mysql-pv
    server: 192.168.233.8
```

kubectl apply -f mysql-pv.yml

### mysql-pvc
```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: nfs
```

kubectl apply -f mysql-pvc.yml

## 创建pod
### mysql
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  ports:
  - port: 3306
  selector:
    app: mysql

---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: mysql
spec:
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - image: docker:30001/k8ss/mysql:5.7
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: 123456
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      nodeSelector:
        kubernetes.io/hostname: node1  #指定部署节点
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
```

## 启动pod验证

1. 部署在master1
    ```shell
    [root@master1 test_nfs]# kubectl apply -f mysql.yml
    service/mysql unchanged
    deployment.apps/mysql created
    [root@master1 test_nfs]# kubectl get pod -o wide
    NAME                     READY     STATUS    RESTARTS   AGE       IP            NODE
    mysql-5d87b69bcc-c6bqn   1/1       Running   0          15s       172.18.1.19   master1
    ```
2. 连上mysql，添加数据
    ```shell
    [root@master1 test_nfs]# kubectl run -it --rm --image=docker:30001/k8ss/mysql:5.7 --restart=Never mysql-clinet -- mysql -h172.18.1.19 -uroot -p123456
    If you don't see a command prompt, try pressing enter.

    mysql> use mysql
    Reading table information for completion of table and column names
    You can turn off this feature to get a quicker startup with -A

    Database changed
    mysql> create table my_id(id int(4));
    Query OK, 0 rows affected (0.06 sec)

    mysql> insert my_id values(111)
        -> ;
    Query OK, 1 row affected (0.01 sec)

    mysql> select * from my_id;
    +------+
    | id   |
    +------+
    |  111 |
    +------+
    1 row in set (0.00 sec)

    mysql> \q
    Bye
    ```
3. 部署在node1
    ```shell
    [root@master1 test_nfs]# kubectl get pod -o wide
    NAME                     READY     STATUS    RESTARTS   AGE       IP            NODE
    mysql-6ffb48bc99-b2zfw   1/1       Running   0          42s       172.18.0.15   node1
    ```
4. 验证数据
    ```shell
    [root@master1 test_nfs]# kubectl run -it --rm --image=docker.cloud:30001/k8ss/mysql:5.7 --restart=Never mysql-clinet -- mysql -h172.18.0.15 -uroot -p123456
    If you don't see a command prompt, try pressing enter.

    mysql> use mysql;
    Reading table information for completion of table and column names
    You can turn off this feature to get a quicker startup with -A

    Database changed
    mysql> select * from my_id;
    +------+
    | id   |
    +------+
    |  111 |
    +------+
    1 row in set (0.00 sec)

    mysql> \q
    Bye
    ```

## nfs动态存储分配

### nfs-client-provisioner
nfs-client-provisioner 是一个Kubernetes的简易NFS的外部provisioner，本身不提供NFS，需要现有的NFS服务器提供存储

* PV以 ${namespace}-${pvcName}-${pvName}的命名格式提供（在NFS服务器上）
* PV回收的时候以 archieved-${namespace}-${pvcName}-${pvName} 的命名格式（在NFS服务器上）

#### 1. 准备nfs-client-provisioner镜像
下载nfs-client-provisioner的镜像，导入到本地的harbor上
```shell
docker pull quay.io/external_storage/nfs-client-provisioner:latest
```

#### 2. 下载nfs-client的deploy文件
在github上下载相关的deploy文件，需要https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client/deploy路径下的所有文件

#### 3. 部署rbac
对于开启了rbac的环境，需要部署rbac，可以根据需要修改rbac.yaml中的namespace
```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
```

#### 4. 部署NFS-Client provisioner
使用deploy/deployment.yaml来部署(会同时部署serviceaccount和pod)，需要修改其中的nfs的server和path为需要接入的nfs存储
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: nfs-client-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: docker.cloud:30001/k8ss/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: fuseim.pri/ifs
            - name: NFS_SERVER
              value: 192.168.233.8  #nfs server
            - name: NFS_PATH
              value: /opt/share_nfs #nfs share path
      volumes:
        - name: nfs-client-root
          nfs:
            server: 192.168.233.8  #nfs server
            path: /opt/share_nfs   #nfs share path
```

#### 5. 部署storageclass
使用deploy/class.yaml来部署storageclass，用来支持pv的动态创建
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
provisioner: fuseim.pri/ifs # or choose another name, must match deployment's env PROVISIONER_NAME'
parameters:
  archiveOnDelete: "false"
```

#### 6. 测试
1. 创建pvc
    ```yaml
    kind: PersistentVolumeClaim
    apiVersion: v1
    metadata:
      name: test-claim
      annotations:
        volume.beta.kubernetes.io/storage-class: "managed-nfs-storage"
    spec:
      accessModes:
        - ReadWriteMany
      resources:
        requests:
          storage: 1Mi
    ```
2. 查看pvc和pv
    ```shell
    # kubectl get pv
    NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM                                                     STORAGECLASS          REASON    AGE
    pvc-7f76d44c-cc32-11e8-a135-fa163e6c79e5   1Mi        RWX            Delete           Bound     default/test-claim                                        managed-nfs-storage             48m
    # kubectl get pvc
    NAME         STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          AGE
    test-claim   Bound     pvc-7f76d44c-cc32-11e8-a135-fa163e6c79e5   1Mi        RWX            managed-nfs-storage   48m
    ```
3. 测试pod
    ```yaml
    kind: Pod
    apiVersion: v1
    metadata:
      name: test-pod
    spec:
      containers:
      - name: test-pod
        image: docker:30001/k8ss/busybox:1.25.0
        command:
          - "/bin/sh"
        args:
          - "-c"
          - "touch /mnt/SUCCESS && exit 0 || exit 1"
        volumeMounts:
          - name: nfs-pvc
            mountPath: "/mnt"
      restartPolicy: "Never"
      volumes:
        - name: nfs-pvc
          persistentVolumeClaim:
            claimName: test-claim
    ```
4. 查看nfs存储
    ```shell
    [root@master3 share_nfs]# ls
    default-test-claim-pvc-7f76d44c-cc32-11e8-a135-fa163e6c79e5
    [root@master3 share_nfs]# cd default-test-claim-pvc-7f76d44c-cc32-11e8-a135-fa163e6c79e5/
    [root@master3 default-test-claim-pvc-7f76d44c-cc32-11e8-a135-fa163e6c79e5]# ls
    SUCCESS
    ```
