# Python配置

## Python3安装pip和ipython
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

## Python中文显示异常

Python出现Non-ASCII character '\xe7' in file 错误是对中文支持出错。解决办法如下：
```
1. 在文件头部添加如下注释码：
# coding=<encoding name> 
例如，可添加
# coding=utf-8
	
2. 在文件头部添加如下两行注释码：
#!/usr/bin/python
# -*- coding: <encoding name> -*- 
例如，可添加
#!/usr/bin/python
# -*- coding: utf-8 -*-
	
3. 在文件头部添加如下两行注释码：
#!/usr/bin/python
# vim: set fileencoding=<encoding name> : 
例如，可添加
#!/usr/bin/python
# vim: set fileencoding=utf-8 :
```