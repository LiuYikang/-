## docker网络namespace映射到主机上
1. 查看docker容器的PID：docker inspect container_id |grep Pid
2. 查看该pid下的net namespace：ll /proc/$PID/ns/net
3. 将该PID的net ns映射到主机上： ln -s /proc/$PID/ns/net /var/run/netns/$PID
4. 查看该container的ns：ip netns