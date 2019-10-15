## CRD开发的三种方式
* 使用原生k8s的code-generator生成client代码
* 直接使用kubebuilder，生成controller框架的同时自动生成client代码
* 使用coreos和redhat提供的operator framework（有点类似于第二种）

## 参考资料

[client-go under the hood](https://github.com/kubernetes/sample-controller/blob/master/docs/controller-client-go.md)

[深入浅出kubernetes之client-go的Indexer](https://blog.csdn.net/weixin_42663840/article/details/81530606)

[深入浅出kubernetes之client-go的DeltaFIFO](https://blog.csdn.net/weixin_42663840/article/details/81626789)

[深入浅出kubernetes之client-go的SharedInformer](https://blog.csdn.net/weixin_42663840/article/details/81699303) 
[深入浅出kubernetes之client-go的SharedInformerFactory](https://blog.csdn.net/weixin_42663840/article/details/81980022)

[解读 kubernetes client-go 官方 examples - Part Ⅰ](https://www.cnblogs.com/guangze/p/10753929.html)