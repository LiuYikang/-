## defer、return、返回值

* 多个defer的执行顺序为“后进先出”；
* 所有函数在执行RET返回指令之前，都会先检查是否存在defer语句，若存在则先逆序调用defer语句进行收尾工作再退出返回；
* 匿名返回值是在return执行时被声明，有名返回值则是在函数声明的同时被声明，因此在defer语句中只能访问有名返回值，而不能直接访问匿名* 返回值；
* return其实应该包含前后两个步骤：第一步是给返回值赋值（若为有名返回值则直接赋值，若为匿名返回值则先声明再赋值）；第二步是调用RET返回指令并传入返回值，而RET则会检查defer是否存在，若存在就先逆序插播defer语句，最后RET携带返回值退出函数；

‍‍因此，‍‍defer、return、返回值三者的执行顺序应该是：return最先给返回值赋值；接着defer开始执行一些收尾工作；最后RET指令携带返回值退出函数。

参考：[Golang中defer、return、返回值之间执行顺序的坑](https://my.oschina.net/henrylee2cn/blog/505535)

## defer、panic、recover
1. defer 表达式的函数如果定义在 panic 后面，该函数在 panic 后就无法被执行到(defer还未压栈)

在defer前panic
```go
func main() {
    panic("a")
    defer func() {
        fmt.Println("b")
    }()
}
```
结果，b没有被打印出来：
```
panic: a

goroutine 1 [running]:
main.main()
    /xxxxx/src/xxx.go:50 +0x39
exit status 2
```

而在defer后panic
```go
func main() {
    defer func() {
        fmt.Println("b")
    }()
    panic("a")
}
```
结果，b被正常打印：
```
b
panic: a

goroutine 1 [running]:
main.main()
    /xxxxx/src/xxx.go:50 +0x39
exit status 2
```

2. F中出现panic时，F函数会立刻终止，不会执行F函数内panic后面的内容，但不会立刻return，而是调用F的defer，如果F的defer中有recover捕获，则F在执行完defer后正常返回，调用函数F的函数G继续正常执行
```go
func G() {
    defer func() {
        fmt.Println("c")
    }()
    F()
    fmt.Println("继续执行")
}

func F() {
    defer func() {
        if err := recover(); err != nil {
            fmt.Println("捕获异常:", err)
        }
        fmt.Println("b")
    }()
    panic("a")
}
```
结果：
```
捕获异常: a
b
继续执行
c
```
3. 如果F的defer中无recover捕获，则将panic抛到G中，G函数会立刻终止，不会执行G函数内后面的内容，但不会立刻return，而调用G的defer...以此类推
```go
func G() {
    defer func() {
        if err := recover(); err != nil {
            fmt.Println("捕获异常:", err)
        }
        fmt.Println("c")
    }()
    F()
    fmt.Println("继续执行")
}

func F() {
    defer func() {
        fmt.Println("b")
    }()
    panic("a")
}
```
结果：
```
b
捕获异常: a
c
```
4. 如果一直没有recover，抛出的panic到当前goroutine最上层函数时，程序直接异常终止
```go
func G() {
    defer func() {
        fmt.Println("c")
    }()
    F()
    fmt.Println("继续执行")
}

func F() {
    defer func() {
        fmt.Println("b")
    }()
    panic("a")
}
```
结果：
```
b
c
panic: a

goroutine 1 [running]:
main.F()
    /xxxxx/src/xxx.go:61 +0x55
main.G()
    /xxxxx/src/xxx.go:53 +0x42
exit status 2
```
5. recover都是在**当前的goroutine里**进行捕获的，这就是说，对于创建goroutine的外层函数，如果goroutine内部发生panic并且内部没有用recover，外层函数是无法用recover来捕获的，这样会造成程序崩溃
```go
func G() {
    defer func() {
        //goroutine外进行recover
        if err := recover(); err != nil {
            fmt.Println("捕获异常:", err)
        }
        fmt.Println("c")
    }()
    //创建goroutine调用F函数
    go F()
    time.Sleep(time.Second)
}

func F() {
    defer func() {
        fmt.Println("b")
    }()
    //goroutine内部抛出panic
    panic("a")
}
```
结果：
```
b
panic: a

goroutine 5 [running]:
main.F()
    /xxxxx/src/xxx.go:67 +0x55
created by main.main
    /xxxxx/src/xxx.go:58 +0x51
exit status 2
```
6、recover返回的是interface{}类型而不是go中的 error 类型，如果外层函数需要调用err.Error()，会编译错误，也可能会在执行时panic
```go
func main() {
    defer func() {
        if err := recover(); err != nil {
            fmt.Println("捕获异常:", err.Error())
        }
    }()
    panic("a")
}
```
编译错误，结果：
```
err.Error undefined (type interface {} is interface with no methods)
```

```go
func main() {
    defer func() {

        if err := recover(); err != nil {
            fmt.Println("捕获异常:", fmt.Errorf("%v", err).Error())
        }
    }()
    panic("a")
}
```
结果：
```
捕获异常: a
```

## golang内存分配
Go在程序启动时，会向操作系统申请一大块内存，之后自行管理。

Go内存管理的基本单元是mspan，它由若干个页组成，每种mspan可以分配特定大小的object。

mcache, mcentral, mheap是Go内存管理的三大组件，层层递进。mcache管理线程在本地缓存的mspan；mcentral管理全局的mspan供所有线程使用；mheap管理Go的所有动态分配内存。

极小对象会分配在一个object中，以节省资源，使用tiny分配器分配内存；一般小对象通过mspan分配内存；大对象则直接由mheap分配内存。