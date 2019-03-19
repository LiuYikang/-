## tui模式
tui模式下分为两个窗口，上面窗口为scr窗口，下面窗口为cmd窗口，焦点默认设置在scr窗口上。
```gdb
# 切换窗口焦点
(gdb) info win
        SRC     (27 lines)  <has focus>
        CMD     (14 lines)
(gdb) fs next
Focus set to CMD window.
(gdb) info win
        SRC     (27 lines)
        CMD     (14 lines)  <has focus>
```

## 调试子进程
follow-fork-mode  detach-on-fork    说明
    parent              on          GDB默认的调试模式：只调试主进程
    child               on          只调试子进程
    parent              off         同时调试两个进程，gdb跟主进程，子进程block在fork位置
    child               off         同时调试两个进程，gdb跟子进程，主进程block在fork位置

```
# eg:
(gdb) set follow-fork-mode child
(gdb) show follow-fork-mode
Debugger response to a program call of fork or vfork is "child".
(gdb) show detach-on-fork
Whether gdb will detach the child of a fork is on.
```
