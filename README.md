# docker-hbase
利用docker创建一个分布式HBase环境，以学习Docker和分布式

** 首先创建一个image，通过以下命令 **
docker build -f base-distributed-hbase.df -t local/base-distributed-hbase --rm .
生成新的image的tag就是local/base-distributed-hbase

** 其次利用新生成的image创建5个container **
注意：在创建image时已经固化了配置，这5个container的hostname、ip地址都是确定的了。
因此要先新建一个docker network，子网是172.18.0.0/16，，命令是：
docker network create --subnet 172.18.0.0/16 mynet

5个节点规划如下
[ node-101: 172.18.0.101 ]
Zookeeper JournalNode NameNode DFSZKFailoverController DataNode HMaster RegionServer
[ node-102: 172.18.0.102 ]
Zookeeper JournalNode NameNode DFSZKFailoverController DataNode HMaster(StandBy) RegionServer
[ node-103: 172.18.0.103 ]
Zookeeper JournalNode DataNode RegionServer 
[ node-104: 172.18.0.104 ]
Zookeeper DataNode RegionServer
[ node-105: 172.18.0.105 ]
Zookeeper DataNode RegionServer

[ 创建container的命令如下 ]
docker run --add-host=node-102:172.18.0.102 --add-host=node-103:172.18.0.103 --add-host=node-104:172.18.0.104 --add-host=node-105:172.18.0.105 --network=mynet -d --name=node-101 --hostname=node-101 --ip=172.18.0.101 -p 21811:2181 -p 16031:16030 -p 50175:50075 -p 16011:16010 -p 50170:50070 -p 8088:8088 -p 8042:8042 -p 19888:19888 --env "MYID=101" local/base-distributed-hbase
docker run --add-host=node-101:172.18.0.101 --add-host=node-103:172.18.0.103 --add-host=node-104:172.18.0.104 --add-host=node-105:172.18.0.105 --network=mynet -d --name=node-102 --hostname=node-102 --ip=172.18.0.102 -p 21812:2181 -p 16032:16030 -p 50275:50075 -p 16012:16010 -p 50270:50070 --env "MYID=102" local/base-distributed-hbase
docker run --add-host=node-102:172.18.0.102 --add-host=node-101:172.18.0.101 --add-host=node-104:172.18.0.104 --add-host=node-105:172.18.0.105 --network=mynet -d --name=node-103 --hostname=node-103 --ip=172.18.0.103 -p 21813:2181 -p 16033:16030 -p 50375:50075 --env "MYID=103" local/base-distributed-hbase
docker run --add-host=node-102:172.18.0.102 --add-host=node-103:172.18.0.103 --add-host=node-101:172.18.0.101 --add-host=node-105:172.18.0.105 --network=mynet -d --name=node-104 --hostname=node-104 --ip=172.18.0.104 -p 21814:2181 -p 16034:16030 -p 50475:50075 --env "MYID=104" local/base-distributed-hbase
docker run --add-host=node-102:172.18.0.102 --add-host=node-103:172.18.0.103 --add-host=node-104:172.18.0.104 --add-host=node-101:172.18.0.101 --network=mynet -d --name=node-105 --hostname=node-105 --ip=172.18.0.105 -p 21815:2181 -p 16035:16030 -p 50575:50075 --env "MYID=105" local/base-distributed-hbase

1、--add-host 参数是为了防止hbase启动后，每一个节点（除master即node-101）都会有两个regionserver，例如node-102和node-102.mynet，加了这几个参数后就可以消除这种现象了，否则貌似hbase启动故障比较多
2、--network=mynet 参数指定加入我们新建的network中
3、--host-name 这些参数不能动，配置文件已经固化了
4、-p 2181x:2181 这是映射的Zookeeper客户端连接端口，因为后面编程需要连接，因此映射5个不同的端口
5、-p 1601x:16010 这是映射的HBase的master的http server端口
6、-p 50x70:50070 这是映射的NameNode的http server端口
7、--env "MYID=xxx"这是让初始化脚本去生成Zookeeper的myid文件的

** 然后分别进入这5个container ** 
docker exec -it node-101 /bin/bash
docker exec -it node-102 /bin/bash
docker exec -it node-103 /bin/bash
docker exec -it node-104 /bin/bash
docker exec -it node-105 /bin/bash

** 首次初始化需要的步骤 **
1、免密码ssh到其他节点，以下命令分别在node-101和node-102上运行
ssh localhost "pwd"
ssh 0.0.0.0 "pwd"
ssh node-101 "pwd"
ssh node-102 "pwd"
ssh node-103 "pwd"
ssh node-104 "pwd"
ssh node-105 "pwd"

2、运行Zookeeper，以下命令需要在5个节点上都运行
zkServer.sh start
完成后，不出意外的话，会选出一个leader来，可以通过命令查看确认zk启动无误
zkServer.sh status

3、启动journalnode，因为只配置了前三个节点运行journalnode，只需要在node-101、node-102、node-103上运行即可
hadoop-daemon.sh start journalnode

4、格式化namenode，只需要在node-101上运行
hdfs namenode -format
hdfs zkfc -formatZK
完成后启动该节点的namenode
hadoop-daemon.sh start namenode

5、初始化standby namenode，只需要在node-102上运行
hdfs namenode -bootstrapStandby
hadoop-daemon.sh start namenode

6、启动所有datanode，在node-101上运行即可
hadoop-daemons.sh start datanode

7、启动zkfc，只需要在node-101、node-102上运行即可
hadoop-daemon.sh start zkfc

8、启动hbase，在node-101上运行即可
start-hbase.sh

9、验证一下，通过hbase shell命令进入hbase，运行list语句看看正常与否。

10、可选的ResourceManager，NodeManager，JobHistoryServer，在node-101上运行
start-yarn.sh
mr-jobhistory-daemon.sh start historyserver

11、停止这些服务的话，按照相反顺序停止即可
node-101上运行：
mr-jobhistory-daemon.sh stop historyserver
stop-yarn.sh
stop-hbase.sh

node-101/102上运行
hadoop-daemon.sh stop zkfc

node-101:
hadoop-daemons.sh stop datanode

node-101/102:
hadoop-daemon.sh stop namenode

node-101:
hadoop-daemon.sh stop journalnode

node-101/102/103/104/105:
zkServer.sh stop

*** 不是首次启动服务的话就可以简单进行了 **
1、运行Zookeeper，以下命令需要在5个节点上都运行
zkServer.sh start
2、node-101：
start-dfs.sh
start-yarn.sh
mr-jobhistory-daemon.sh start historyserver
start-hbase.sh

停止命令也是一样反过来即可
1、node-101
stop-hbase.sh
mr-jobhistory-daemon.sh stop historyserver
stop-yarn.sh
stop-dfs.sh
2、5个节点上停止zk
zkServer.sh stop

** 集群运行成成功后，可以通过访问宿主主机的相应端口上的http服务**
1、http://host-ip:16011这是HBase Master节点
2、http://host-ip:50170这是node-101的namenode web页面
http://host-ip:50270这是node-102的namenode web页面
3、http://host-ip:8088这是node-101的resourcemanager web页面

