## k8s 的 exec 是怎么实现的
https://k2r2bai.com/2018/06/25/kubernetes/k8x-exec-api/

System Design Primer

云原生相关:
Kubernetes Concepts 部分建议再看一遍，
源码部分推荐看 apiserver 中的 CRD 部分与 aggregation layer、kubelet 的 pod 状态同步、scheduler 的调度部分以及Sample Controller 如何写一个自己的

## k8s的pause
kubernetes中的pause容器主要为每个业务容器提供以下功能：
* 在pod中担任Linux命名空间共享的基础；
* 启用pid命名空间，开启init进程。
