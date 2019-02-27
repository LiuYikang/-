## python垃圾回收机制
引用计数

### python 内存泄漏场景
1. 对象被另一个生命周期特别长的对象所引用，比如网络服务器，可能存在一个全局的单例ConnectionManager，管理所有的连接Connection，如果当Connection理论上不再被使用的时候，没有从ConnectionManager中删除，那么就造成了内存泄露。
2. 循环引用中的对象定义了__del__函数，这个在[程序员必知的Python陷阱与缺陷列表](http://www.cnblogs.com/xybaby/p/7183854.html)一文中有详细介绍，简而言之，如果定义了__del__函数，那么在循环引用中Python解释器无法判断析构对象的顺序，因此就不错处理。

## python闭包

## 迭代器和生成器

## 重写__new__函数会出现什么问题

## python描述符

## map的底层实现

## 多线程GIL
GIL是全局线程锁，因为GIL的存在，python无法实现真正的多线程。

如果是CPU密集型操作，GIL导致多线程无法提高效率；如果是IO密集型操作，多线程可以根据任务的IO等待进行CPU工作的切换。

多核CPU也无法解决GIL导致的线程问题，在多核的情况下，使用多进程是提高CPU利用的方法。
