# Python环境配置

## 1. Python3安装pip和ipython
```
apt-get install python3-pip
pip install ipython
```

## virtualEnv环境配置

* 安装virtualenv
```
pip install virtualenv
```

* 创建虚拟环境
```
virtualenv --no-site-packages -p /usr/bin/python2.7 ~/env
```
* 启动和退出虚拟环境
```
#启动
source ~/env/bin/activate
#退出
deactivate
```