# Benchmark汇总

## fio测试
### 使用方法
```shell
# 测试随机写IOPS：
fio -direct=1 -iodepth=128 -rw=randwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Write_Testing

# 测试随机读IOPS：
fio -direct=1 -iodepth=128 -rw=randread -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Read_Testing

# 测试写吞吐量：
fio -direct=1 -iodepth=64 -rw=randwrite -ioengine=libaio -bs=64k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Write_PPS_Testing

# 测试读吞吐量：
fio -direct=1 -iodepth=64 -rw=randread -ioengine=libaio -bs=64k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Read_PPS_Testing
```

### 参数说明
```
-direct=1   测试时忽略 IO 缓存，数据直写。
-rw=randwrite   测试时的读写策略，可选值 randread （随机读）、 randwrite（随机写）、 read（顺序读）、 write（顺序写）、 randrw （混合随机读写）。
-ioengine=libaio    测试方式使用 libaio （Linux AIO，异步 IO）。 应用使用 IO 通常有二种方式：同步和异步。同步的 IO 一次只能发出一个 IO 请求，等待内核完成才返回。这样对于单个线程 iodepth 总是小于 1，但是可以透过多个线程并发执行来解决。通常会用 16-32 根线程同时工作把 iodepth 塞满。 异步则通常使用 libaio 这样的方式一次提交一批 IO 请求，然后等待一批的完成，减少交互的次数，会更有效率。
-bs=4k  单次 IO 的块文件大小为 4k。未指定该参数时的默认大小也是 4k。
-size=1G    测试文件大小为 1G。
-numjobs=1  测试线程数为 1。
-runtime=1000   测试时间为 1000 秒。如果未配置则持续将前述 -size 指定大小的文件，以每次 -bs 值为分块大小写完。
-group_reporting    测试结果显示模式，group_reporting 表示汇总每个进程的统计信息，而非以不同 job 汇总展示信息。
-filename=iotest    测试时的输出文件路径和名称。测试完成后请记得删除相应文件，以免占用磁盘空间。
-name=Rand_Write_Testing    测试任务名称。
```
