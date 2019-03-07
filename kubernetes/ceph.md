## 在所有的k8s节点上安装 ceph-common
```
yum install ceph-common
```

## ceph存储节点配置

1. 创建osd pool：kube
    ```shell
    ceph osd pool create kube 8 8
    ```
2. 创建kube用户
    ```shell
    ceph auth add client.kube mon 'allow r' osd 'allow rwx pool=kube'
    ```

## 部署动态分配ceph

下载https://github.com/kubernetes-incubator/external-storage，使用external-storage/ceph/rbd来部署动态分配ceph的k8s环境

### 1. 创建cephfs命名空间来部署ceph挂载
```shell
kubectl create ns cephfs
```

### 2. 部署secrets
1. 获取ceph服务器上admin和kube的key，key需要使用base64加密
    ```shell
    [root@CentOS nas]# ceph auth get-key client.admin | base64
    QVFDTi9MOWJvV0J6R3hBQVRqZUQxQUQwOGxOMWJEVGdnL3FXdVE9PQ==
    [root@CentOS nas]# ceph auth get-key client.kube | base64
    QVFCU1lzQmJBM1pVQ1JBQURSTHUyTnhHMW56eG52SGtRMDFyTmc9PQ==
    ```
2. 进入rbd/examples路径，使用secrets.yaml文件，替换掉其中的key和namespace
    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: ceph-admin-secret
      namespace: cephfs
    type: "kubernetes.io/rbd"
    data:
      # ceph auth get-key client.admin | base64
      key: QVFDTi9MOWJvV0J6R3hBQVRqZUQxQUQwOGxOMWJEVGdnL3FXdVE9PQ==
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: ceph-secret
      namespace: cephfs
    type: "kubernetes.io/rbd"
    data:
      # ceph auth add client.kube mon 'allow r' osd 'allow rwx pool=kube'
      # ceph auth get-key client.kube | base64
      key: QVFCU1lzQmJBM1pVQ1JBQURSTHUyTnhHMW56eG52SGtRMDFyTmc9PQ==
    ```
3. 部署secret
    ```shell
    [root@master1 examples]# kubectl apply -f secrets.yaml -n cephfs
    secret/ceph-admin-secret created
    secret/ceph-secret created
    [root@master1 examples]# kubectl get secret -n cephfs
    NAME                          TYPE                                  DATA      AGE
    ceph-admin-secret             kubernetes.io/rbd                     1         9s
    ceph-secret                   kubernetes.io/rbd                     1         8s
    ```

### 3. 部署rbac和rbd-provisioner
#### 更新rbd/deploy/rbac路径下的所有yaml

1. clusterrolebinding.yaml
    ```yaml
    kind: ClusterRoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: rbd-provisioner
    subjects:
      - kind: ServiceAccount
        name: rbd-provisioner
        namespace: cephfs  #注意替换
    roleRef:
      kind: ClusterRole
      name: rbd-provisioner
      apiGroup: rbac.authorization.k8s.io
    ```
2. clusterrole.yaml
    ```yaml
    kind: ClusterRole
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: rbd-provisioner
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
      - apiGroups: [""]
        resources: ["services"]
        resourceNames: ["kube-dns","coredns"]
        verbs: ["list", "get"]
    ```
3. deployment.yaml
    ```yaml
    apiVersion: extensions/v1beta1
    kind: Deployment
    metadata:
      name: rbd-provisioner
    spec:
      replicas: 1
      strategy:
        type: Recreate
      template:
        metadata:
          labels:
            app: rbd-provisioner
        spec:
          containers:
          - name: rbd-provisioner
            image: "quay.io/external_storage/rbd-provisioner:v2.1.1-k8s1.11"  #镜像文件
            env:
            - name: PROVISIONER_NAME
              value: ceph.com/rbd
          serviceAccount: rbd-provisioner
    ```
4. rolebinding.yaml
    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: rbd-provisioner
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: rbd-provisioner
    subjects:
    - kind: ServiceAccount
      name: rbd-provisioner
      namespace: cephfs    #注意替换
    ```
5. role.yaml
    ```yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: rbd-provisioner
    rules:
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["get"]
    - apiGroups: [""]
      resources: ["endpoints"]
      verbs: ["get", "list", "watch", "create", "update", "patch"]
    ```
6. serviceaccount.yaml
    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: rbd-provisioner
    ```
#### 部署
```shell
[root@master1 rbac]# kubectl -n cephfs apply -f ./rbac

[root@master1 examples]# kubectl get pod -n cephfs
NAME                               READY     STATUS      RESTARTS   AGE
rbd-provisioner-5b7f6b56dc-zfsdm   1/1       Running     0          2h
```

### 3. 部署storageclass
使用rbd/examples下的class.yaml来部署storageclass

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: rbd
provisioner: ceph.com/rbd
parameters:
  monitors: 192.168.0.181:6789   #替换ceph服务器  monitor的ip，可以配置多个，逗号分隔
  pool: kube                    #指定使用的ceph的pool
  adminId: admin
  adminSecretNamespace: cephfs  #替换命名空间
  adminSecretName: ceph-admin-secret
  userId: kube
  userSecretNamespace: cephfs   #替换命名空间
  userSecretName: ceph-secret
  imageFormat: "2"
  imageFeatures: layering
```

查看部署的storageclass
```shell
[root@master1 examples]# kubectl get storageclass -n cephfs
NAME                  PROVISIONER                    AGE
rbd                   ceph.com/rbd                   2h
```

### 4. 部署pvc和pv
1. 使用rbd/examples下的claim.yaml来部署pvc和pv

    ```yaml
    kind: PersistentVolumeClaim
    apiVersion: v1
    metadata:
      name: claim1
    spec:
      accessModes:
        - ReadWriteOnce
      storageClassName: rbd
      resources:
        requests:
          storage: 1Gi
    ```

2. 查看部署的pvc和pv
    ```shell
    [root@master1 examples]# kubectl get pvc -n cephfs
    NAME      STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
    claim1    Bound     pvc-708ba4fe-cdff-11e8-a135-fa163e6c79e5   1Gi        RWO            rbd            2h
    [root@master1 examples]# kubectl get pv -n cephfs
    NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS    CLAIM                                                     STORAGECLASS          REASON    AGE
    pvc-708ba4fe-cdff-11e8-a135-fa163e6c79e5   1Gi        RWO            Delete           Bound     cephfs/claim1                                             rbd                             2h
    ```

3. 查看pv对应的ceph的rbd
    ```shell
    [root@master1 examples]# kubectl describe pv pvc-708ba4fe-cdff-11e8-a135-fa163e6c79e5 -n cephfs
    Name:            pvc-708ba4fe-cdff-11e8-a135-fa163e6c79e5
    Labels:          <none>
    Annotations:     pv.kubernetes.io/provisioned-by=ceph.com/rbd
                     rbdProvisionerIdentity=ceph.com/rbd
    Finalizers:      [kubernetes.io/pv-protection]
    StorageClass:    rbd
    Status:          Bound
    Claim:           cephfs/claim1
    Reclaim Policy:  Delete
    Access Modes:    RWO
    Capacity:        1Gi
    Node Affinity:   <none>
    Message:
    Source:
        Type:          RBD (a Rados Block Device mount on the host that shares a pod's lifetime)
        CephMonitors:  [192.168.0.181:6789]
        RBDImage:      kubernetes-dynamic-pvc-70c96934-cdff-11e8-a9d0-0a58ac12022a   #对应为ceph的rbd
        FSType:
        RBDPool:       kube
        RadosUser:     kube
        Keyring:       /etc/ceph/keyring
        SecretRef:     &{ceph-secret cephfs}
        ReadOnly:      false
    Events:            <none>
    ```

4. 查看ceph的服务器上的rbd，该rbd在kube的pool里
    ```shell
    [root@HikvisionOS cephfs]# rbd list -p kube
    kubernetes-dynamic-pvc-70c96934-cdff-11e8-a9d0-0a58ac12022a
    ```
