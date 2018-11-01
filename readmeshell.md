# kylo安装脚本

[脚本使用视频](https://asciinema.org/a/rWVZLp6aoIa1iRZV3hlJfBkaQ)

首先确认安装资源情况如下，根据实际情况配置修改all_config.properties中的配置

```
├── activemq
│   └── apache-activemq-5.15.4-bin.tar.gz
├── all_config.properties
├── elasticsearch
│   └── elasticsearch-6.3.1.tar.gz
├── java
│   └── jdk-8u171-linux-x64.tar.gz
├── kylo
│   └── kylo-0.9.1.tar
├── nifi
│   └── nifi-1.6.0-bin.tar.gz
└── setup_kylo.sh
```
### all_config.properties配置文件详情
```
##########################👇这里不要修改#################################
ACTIVEMQ_INSTALL_VERSION=5.15.4
ACTIVEMQ_INSTALL_HOME=/opt/activemq
ACTIVEMQ_USER=activemq
ACTIVEMQ_GROUP=activemq
ACTIVEMQ_JAVA_HOME=$JAVA_HOME

NIFI_INSTALL_HOME=/opt/nifi
NIFI_USER=nifi
NIFI_GROUP=nifi
NIFI_VERSION=1.6.0
NIFI_DATA=/opt/nifi/data

KYLO_INSTALL_HOME=/opt/kylo
kylo_home_folder="/opt/kylo"

spark_home="/opt/cloudera/parcels/CDH/lib/spark"
validateAndSplitRecords_extraJars="/opt/cloudera/parcels/CDH/lib/hive-hcatalog/share/hcatalog/hive-hcatalog-core.jar"
hadoopConfigurationResources="/etc/hadoop/conf/core-site.xml,/etc/hadoop/conf/hdfs-site.xml"
hive_lib_path="/opt/cloudera/parcels/CDH/lib/hive/lib"

#########################👆上面不要修改##################################

#kylo需要的mysql数据库，用户名，密码
mysql_kylo_db_host="127.0.0.1"
mysql_kylo_db_user="kylo"
mysql_kylo_db_password="kylo"

#kylo 安装主机IP
kylo_local_ip="10.88.88.121"
#kylo UI 用户密码 ,默认用户名是dladmin
dladmin_password="thinkbig"

#hive2 主机IP
hive_server2_host="10.88.88.120"
hive_metastore_datasource_url="10.88.88.120"

#下面两个没有可以不写
hive_metastore_datasource_username=""
hive_metastore_datasource_password=""


hive_service_principal="hive/kylo1.hypers.cc@KYLO.CC"
# kerberos.hive.kerberosPrincipal=$hive_service_principal
hive_service_kerberos_keytab="/etc/security/keytabs/hive.service.keytab"
# kerberos.hive.keytabLocation=$hive_service_kerberos_keytab

nifi_service_principal="nifi/kylo2.hypers.cc@KYLO.CC"
# nifi.service.hive_thrift_service.kerberos_principal=$nifi_service_principal

nifi_service_kerberos_keytab="/etc/security/keytabs/nifi.service.keytab"
# nifi.service.hive_thrift_service.kerberos_keytab=nifi_service_kerberos_keytab

nifi_user_principal="nifi/kylo2.hypers.cc@KYLO.CC"
# nifi.all_processors.kerberos_principal=$nifi_user_principal

nifi_user_kerberos_keytab="/etc/security/keytabs/nifi.service.keytab"
# nifi.all_processors.kerberos_keytab="nifi_user_kerberos_keytab"


# 配置spark.properties需要用到的配置
# kerberos.spark.kerberosPrincipal
kylo_user_principal="kylo@KYLO.CC"
# kerberos.spark.keytabLocation
kylo_user_kerberos_keytab="/etc/security/keytabs/kylo.user.keytab"

```
### hdfs创建目录

```
[root]# su - hdfs

kinit -kt /etc/security/keytabs/hdfs.service.keytab [hdfs_principal_name]

hdfs dfs -mkdir /user/kylo
hdfs dfs -chown kylo:kylo /user/kylo
hdfs dfs -mkdir /user/nifi
hdfs dfs -chown nifi:nifi /user/nifi

hdfs dfs -mkdir /etl
hdfs dfs -chown nifi:nifi /etl
hdfs dfs -mkdir /model.db
hdfs dfs -chown nifi:nifi /model.db
hdfs dfs -mkdir /archive
hdfs dfs -chown nifi:nifi /archive
hdfs dfs -mkdir -p /app/warehouse
hdfs dfs -chown nifi:nifi /app/warehouse
```
### 创建用户和组

在安装nifi,kylo, activemq的主机上创建用户

```
useradd -r -m -s /bin/bash nifi
useradd -r -m -s /bin/bash kylo
useradd -r -m -s /bin/bash activemq

groupadd -f kylo
groupadd -f nifi
groupadd -f activemq
```

### 创建kylo,nifi,hive的principal

```
[root@kylo1 ~]# mkdir -p /etc/security/keytabs

[root@kylo1 ~]# kadmin.local

kadmin.local: addprinc -randkey hive_service_principal

kadmin.local: addprinc -randkey nifi_service_principal

kadmin.local: addprinc -randkey nifi_user_principal

kadmin.local: addprinc -randkey kylo_user_principal

```
### 导出principal

```
[root@kylo1 ~]#  kadmin.local

kadmin.local: xst -norandkey -k /etc/security/keytabs/hive.service.keytab $hive_service_principal

kadmin.local: xst -norandkey -k /etc/security/keytabs/nifi.service.keytab $nifi_service_principal

kadmin.local: xst -norandkey -k /etc/security/keytabs/nifi.user.keytab $nifi_user_principal

kadmin.local: xst -norandkey -k /etc/security/keytabs/kylo.user.keytab $kylo_user_principal

kadmin.local: q


```
把导出的principal拷贝到kylo安装的主机上并执行如下操作

```
[root@kylo2 ~]# chmod 440 /etc/security/keytabs/hive.service.keytab

[root@kylo2 ~]# chown kylo:kylo /etc/security/keytabs/hive.service.keytab

[root@kylo2 ~]# chown nifi:nifi /etc/security/keytabs/nifi.service.keytab

[root@kylo2 ~]# chmod 440 /etc/security/keytabs/nifi.service.keytab

[root@kylo2 ~]# chown nifi:nifi /etc/security/keytabs/nifi.user.keytab

[root@kylo2 ~]# chmod 440 /etc/security/keytabs/nifi.user.keytab

[root@kylo2 ~]# chown kylo:kylo /etc/security/keytabs/kylo.user.keytab

[root@kylo2 ~]# chmod 440 /etc/security/keytabs/kylo.user.keytab

```
#脚本功能预览
![](http://p2ehgqigv.bkt.clouddn.com/18-9-30/98706552.jpg)



# 安装mysql
## 创建kylo用户数据库
登录mysql创建kylo用户，密码为kylo

```
CREATE USER 'kylo'@'%' IDENTIFIED BY 'kylo';
```
### 授权可以远程登录

```
GRANT ALL PRIVILEGES ON *.* TO 'kylo'@'%' IDENTIFIED BY 'kylo' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO 'kylo'@'127.0.0.1' IDENTIFIED BY 'kylo' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO 'kylo'@'localhost' IDENTIFIED BY 'kylo' WITH GRANT OPTION;

GRANT ALL PRIVILEGES ON *.* TO 'kylo'@'本机IP' IDENTIFIED BY 'kylo' WITH GRANT OPTION;

FLUSH PRIVILEGES; 

```

### 安装JDK8 

配置JAVA_HOME


### 安装ActiveMQ
安装ActiveMQ之前需要配置JAVA_HOME环境变量

### 安装eslasticsearch
安装eslasticsearch 也需要JAVA_HOME环境变量

```
Enter your userName for elastechsearch , hit Enter for 'esadmin': 

hello esadmin

Enter your group for esadmin , hit Enter with esadmin:

```

**手动启动eslasticsearch**

```
[root@kylo2 soft]# cd /opt/elastechsearch/elasticsearch-6.3.1/bin/
[root@kylo2 bin]# su esadmin
[esadmin@kylo2 bin]$ 
[esadmin@kylo2 bin]$ ./elasticsearch -d

```
关闭elasticsearch 用kill



##安装kylo

![](http://p2ehgqigv.bkt.clouddn.com/18-9-30/44466322.jpg)


####配置kylo

询问用户是否启用kerberos

```
Would you enable kerberos ? Please enter y/n: 
```

####为kylo创建elastechesarch索引

需要启动elastechearch


### 启动/停止kylo

kylo启动前，需要先启动activemq , elastechearch ,nifi

```
[root@kylo2 ~]# kylo-service start
[root@kylo2 ~]# kylo-service stop
```

#### Check the logs for errors.

```
/var/log/kylo-services.log
/var/log/kylo-ui/kylo-ui.log
/var/log/kylo-services/kylo-spark-shell.log
```
### Login to the Kylo UI.

```
http://kylo_host:8400
username:dladmin
password:thinkbig
```


### 导入模板

**特别说明**请在 **kylo和nifi正常启动**后执行

导入模板后，UI上可以看到如下界面

![](http://p2ehgqigv.bkt.clouddn.com/18-9-30/9532863.jpg)

##安装nifi
需要用户选择是否启用kerberos

![](http://p2ehgqigv.bkt.clouddn.com/18-9-30/26064863.jpg)

#### Start/Stop NiFi
```
[root@kylo2 ~]# service nifi start
[root@kylo2 ~]# service nifi stop

```
#### Tail the logs to look for errors.

```
tail -f /var/log/nifi/nifi-app.log
```

#### nifi UI 

```
http://nifi_host:8079/nifi/
```

###  更新kylo数据库
相当于初始化kylo环境。如果已经导入模板，需要删除nifi并重新安装nifi


###  安装jce_policy

**依赖JAVA_HOME**

This extension is required to allow encrypted property values in the Kylo configuration files. If you already have a Java 8 installed on the system, you can install the Java Cryptographic Extension by this.


### 停止kylo 、 nifi 、删除nifi[可选]

为恢复kylo环境准备



-------
### 最后预览一下kylo界面
![](http://p2ehgqigv.bkt.clouddn.com/18-9-30/51973953.jpg)


<!--
create time: 2018-09-30 09:52:00
Author: Alfred

This file is created by Marboo<http://marboo.io> template file $MARBOO_HOME/.media/starts/default.md
本文件由 Marboo<http://marboo.io> 模板文件 $MARBOO_HOME/.media/starts/default.md 创建
-->

