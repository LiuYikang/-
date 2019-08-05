## python垃圾回收机制

Python GC主要使用引用计数（reference counting）来跟踪和回收垃圾。在引用计数的基础上，通过“标记-清除”（mark and sweep）解决容器对象可能产生的循环引用问题，通过“分代回收”（generation collection）以空间换时间的方法提高垃圾回收效率。

1. 引用计数
PyObject是每个对象必有的内容，其中ob_refcnt就是做为引用计数。当一个对象有新的引用时，它的ob_refcnt就会增加，当引用它的对象被删除，它的ob_refcnt就会减少.引用计数为0时，该对象生命就结束了。

优点:简单、实时性

缺点:维护引用计数消耗资源、循环引用

2. 标记-清除机制
基本思路是先按需分配，等到没有空闲内存的时候从寄存器和程序栈上的引用出发，遍历以对象为节点、以引用为边构成的图，把所有可以访问到的对象打上标记，然后清扫一遍内存空间，把所有没标记的对象释放。

3. 分代技术
分代回收的整体思想是：将系统中的所有内存块根据其存活时间划分为不同的集合，每个集合就成为一个“代”，垃圾收集频率随着“代”的存活时间的增大而减小，存活时间通常利用经过几次垃圾回收来度量。

Python默认定义了三代对象集合，索引数越大，对象存活时间越长。

举例： 当某些内存块M经过了3次垃圾收集的清洗之后还存活时，我们就将内存块M划到一个集合A中去，而新分配的内存都划分到集合B中去。当垃圾收集开始工作时，大多数情况都只对集合B进行垃圾回收，而对集合A进行垃圾回收要隔相当长一段时间后才进行，这就使得垃圾收集机制需要处理的内存少了，效率自然就提高了。在这个过程中，集合B中的某些内存块由于存活时间长而会被转移到集合A中，当然，集合A中实际上也存在一些垃圾，这些垃圾的回收会因为这种分代的机制而被延迟。

### python 内存泄漏场景
1. 对象被另一个生命周期特别长的对象所引用，比如网络服务器，可能存在一个全局的单例ConnectionManager，管理所有的连接Connection，如果当Connection理论上不再被使用的时候，没有从ConnectionManager中删除，那么就造成了内存泄露。
2. 循环引用中的对象定义了__del__函数，这个在[程序员必知的Python陷阱与缺陷列表](http://www.cnblogs.com/xybaby/p/7183854.html)一文中有详细介绍，简而言之，如果定义了__del__函数，那么在循环引用中Python解释器无法判断析构对象的顺序，因此就不错处理。

## python闭包

闭包(closure)是函数式编程的重要的语法结构。闭包也是一种组织代码的结构，它同样提高了代码的可重复使用性。

当一个内嵌函数引用其外部作作用域的变量,我们就会得到一个闭包. 总结一下,创建一个闭包必须满足以下几点:
* 必须有一个内嵌函数
* 内嵌函数必须引用外部函数中的变量
* 外部函数的返回值必须是内嵌函数

[一步一步教你认识Python闭包](https://foofish.net/python-closure.html)

## 迭代器和生成器
生成器也是迭代器的一种,但是你只能迭代它们一次.原因很简单,因为它们不是全部存在内存里,它们只在要调用的时候在内存里生成

生成器和迭代器的区别就是用()代替[],还有你不能用for i in mygenerator第二次调用生成器:首先计算0,然后会在内存里丢掉0去计算1,直到计算完4

Yield的用法和关键字return差不多,返回一个生成器

当for语句第一次调用函数里返回的生成器对象,函数里的代码就开始运作,直到碰到yield,然后会返回本次循环的第一个返回值.所以下一次调用也将运行一次循环然后返回下一个值,直到没有值可以返回.

一旦函数运行并且没有碰到yeild语句就认为生成器已经为空了.原因有可能是循环结束或者没有满足if/else之类的.

## __new__和__init__的区别

* __new__是一个静态方法,而__init__是一个实例方法.
* __new__方法会返回一个创建的实例,而__init__什么都不返回.
* 只有在__new__返回一个cls的实例时后面的__init__才能被调用.
* 当创建一个新实例时调用__new__,初始化一个实例时用__init__.

>  __metaclass__是创建类时起作用.所以我们可以分别使用__metaclass__,__new__和__init__来分别在类创建,实例创建和实例初始化的时候做一些小手脚.

## 重写__new__函数会出现什么问题

## python描述符

#### 什么是描述符
官方的定义：描述符是一种具有“捆绑行为”的对象属性。访问（获取、设置和删除）它的属性时，实际是调用特殊的方法（\_get_(),\_set_(),\_delete_()）。也就是说，如果一个对象定义了这三种方法的任何一种，它就是一个描述符。

更多的理解： 

通常情况下，访问一个对象的搜索链是怎样的？比如a.x,首先，应该是查询 a.\_dict_[‘x’]，然后是type(a).\_dict_[‘x’]，一直向上知道元类那层止（不包括元类）。如果这个属性是一个描述符呢？那python就会“拦截”这个搜索链，取而代之调用描述符方法（\_get_）。 

三个方法（协议）： 
* \_get_(self, instance, owner) —获取属性时调用，返回设置的属性值，通常是_set_中的value,或者附加的其他组合值。 
* \_set_(self, instance, value) — 设置属性时调用，返回None. 
* \_delete_(self, instance) — 删除属性时调用，返回None 
其中，instance是这个描述符属性所在的类的实体，而owner是描述符所在的类。

## map的底层实现

## 多线程GIL
GIL是全局线程锁，因为GIL的存在，python无法实现真正的多线程。

如果是CPU密集型操作，GIL导致多线程无法提高效率；如果是IO密集型操作，多线程可以根据任务的IO等待进行CPU工作的切换。

多核CPU也无法解决GIL导致的线程问题，在多核的情况下，使用多进程是提高CPU利用的方法。

[Python最难的问题](https://www.oschina.net/translate/pythons-hardest-problem)

## 协程

协程是进程和线程的升级版,进程和线程都面临着内核态和用户态的切换问题而耗费许多切换时间,而协程就是用户自己控制切换的时机,不再需要陷入系统的内核态.

## 单例模式
​单例模式是一种常用的软件设计模式。在它的核心结构中只包含一个被称为单例类的特殊类。通过单例模式可以保证系统中一个类只有一个实例而且该实例易于外界访问，从而方便对实例个数的控制并节约系统资源。如果希望在系统中某个类的对象只能存在一个，单例模式是最好的解决方案。

\_\_new\_\_()在__init__()之前被调用，用于生成实例对象。利用这个方法和类的属性的特点可以实现设计模式的单例模式。单例模式是指创建唯一对象，单例模式设计的类只能实例 这个绝对常考啊.绝对要记住1~2个方法,当时面试官是让手写的.

1. 使用__new__方法
```python
class Singleton(object):
    def __new__(cls, *args, **kw):
        if not hasattr(cls, '_instance'):
            orig = super(Singleton, cls)
            cls._instance = orig.__new__(cls, *args, **kw)
        return cls._instance

class MyClass(Singleton):
    a = 1
```

2. 共享属性
创建实例时把所有实例的__dict__指向同一个字典,这样它们具有相同的属性和方法.
```python
class Borg(object):
    _state = {}
    def __new__(cls, *args, **kw):
        ob = super(Borg, cls).__new__(cls, *args, **kw)
        ob.__dict__ = cls._state
        return ob

class MyClass2(Borg):
    a = 1
```

3. 装饰器版本
```python
def singleton(cls):
    instances = {}
    def getinstance(*args, **kw):
        if cls not in instances:
            instances[cls] = cls(*args, **kw)
        return instances[cls]
    return getinstance

@singleton
class MyClass:
  ...
```

4. import方法
作为python的模块是天然的单例模式
```python
# mysingleton.py
class My_Singleton(object):
    def foo(self):
        pass

my_singleton = My_Singleton()

# to use
from mysingleton import my_singleton

my_singleton.foo()
```

## 面向切面编程AOP和装饰器

装饰器是一个很著名的设计模式，经常被用于有切面需求的场景，较为经典的有插入日志、性能测试、事务处理等。装饰器是解决这类问题的绝佳设计，有了装饰器，就可以抽离出大量函数中与函数功能本身无关的雷同代码并继续重用。概括的讲，装饰器的作用就是为已经存在的对象添加额外的功能。


## 元类
[深刻理解Python中的元类(metaclass)以及元类实现单例模式](https://www.cnblogs.com/tkqasn/p/6524879.html) \
[What are metaclasses in Python?](https://stackoverflow.com/questions/100003/what-are-metaclasses-in-python)