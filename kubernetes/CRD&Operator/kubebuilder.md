# kubebuilder

## install
1. 直接下载
```shell
os=$(go env GOOS)
arch=$(go env GOARCH)

# download kubebuilder and extract it to tmp
curl -sL https://go.kubebuilder.io/dl/2.0.0-beta.0/${os}/${arch} | tar -xz -C /tmp/

# move to a long-term location and put it on your path
# (you'll need to set the KUBEBUILDER_ASSETS env var if you put it somewhere else)
sudo mv /tmp/kubebuilder_2.0.0-beta.0_${os}_${arch} /usr/local/kubebuilder
export PATH=$PATH:/usr/local/kubebuilder/bin
```

2. 源码编译
```shell
mkdir sigs.k8s.io

cd sigs.k8s.io/

git clone https://github.com/kubernetes-sigs/kubebuilder.git

cd kubebuilder/

make install
# will install to GOPATH/bin
```

## Reference
[kubebuilder](https://book.kubebuilder.io/)