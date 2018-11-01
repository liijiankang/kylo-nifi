#!/bin/bash
#

source ./all_config.properties

yes_no="^[yYnN]{1}$"
INSTALL_HOME="/opt/kylo"
old_pwd=`pwd`

function install_mysql_opt(){
    echo "start install mysql mysql-server mysql-devel ...."
    # systemctl stop mysql.service
    #yum remove -y mysql mysql-server mysql-devel

    yum install -y mysql mysql-server mysql-devel  mariadb-server

    yum install -y mariadb-server
    # centos7 开启mysql 服务
    echo "    start msyql.service..."
    sleep 1.0s
    systemctl start mariadb.service
    systemctl enable mariadb.service
    echo "   INSTALL COMPLETE"
    echo "mysql初始化为空"
    echo " "
    echo " "
    echo "设置root命令可用 : mysqladmin -uroot password \"123456\""
}

# function for determining way to handle startup scripts
function get_linux_type (){
    # redhat
    which chkconfig > /dev/null && echo "chkonfig" && return 0
    # ubuntu sysv
    which update-rc.d > /dev/null && echo "update-rc.d" && return 0
    echo "Couldn't recognize linux version, after installation you need to do these steps manually:"
    echo " * add proper header to /etc/init.d/{kylo-ui,kylo-services,kylo-spark-shell} files"
    echo " * set them to autostart"
}


function install_JDK (){

  setup_home=/opt/java

  JAVA_TAR=jdk-8u171-linux-x64.tar.gz

  mkdir -p $setup_home

  env_java=jdk1.8.0_171
    
    echo "开始解压jdk1.8"
    echo ""
    tar -xzvf $JAVA_TAR -C $setup_home
    echo ""
    echo "解压完成"

    if [ $? -eq 0 ]
        then
        echo "-->[`date +"%Y-%m-%d %H:%M.%S"`] Successfully Installed $JAVA_TAR"
        else
        echo "-->[`date +"%Y-%m-%d %H:%M.%S"`] Failed to install $JAVA_TAR"
        exit 0
    fi
    
    java_home=`sed '/^export JAVA_HOME=/!d;s/.*=//' /etc/profile`
    
    # if [ -z $JAVA_HOME ];then
        
    
    # Step2.Config jdk-envrionment 
    
    if [ -z $java_home ]
            then
    
            echo "# For jdk1.8.0_171 JAVA_HOME" >> /etc/profile
            echo "export JAVA_HOME=$setup_home/jdk1.8.0_171" >> /etc/profile
            echo "export CLASSPATH=.:$setup_home/lib/dt.jar:$setup_home/lib/tools.jar" >> /etc/profile
            echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile
            echo " " >> /etc/profile
        else
            # echo "需要用sed修改配置JAVA_HOME"
            echo " " >> /etc/profile
            
            # sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$setup_home/jdk1.8.0_171|" /etc/profile
            # export JAVA_HOME=/usr/local/env/jdk1.8.0_171
            # echo "# For jdk1.8.0_171 JAVA_HOME" >> /etc/profile
            echo "export JAVA_HOME=$setup_home/jdk1.8.0_171" >> /etc/profile
            echo "export CLASSPATH=.:$setup_home/lib/dt.jar:$setup_home/lib/tools.jar" >> /etc/profile
            echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile
            echo " " >> /etc/profile
    fi
    
    #Step3  source /etc/profile
    
    if [ $? -eq 0 ]
    then
      source /etc/profile
      source /etc/profile
      echo "-->[`date +"%Y-%m-%d %H:%M.%S"`] JDK environment has been successed set in /etc/profile."
      echo "-->[`date +"%Y-%m-%d %H:%M.%S"`] java -version"
      java -version
    fi

}

function install_jce_policy (){

    yum install -y unzip
    

    sec_dir=$JAVA_HOME/jre/lib/security
    
    if [[ -d $sec_dir  ]]; then
       mkdir -p $JAVA_HOME/jre/lib/security
    fi
    
    echo "Installing jce_policy into $sec_dir"
    
    cd $sec_dir
    
    curl -L -O -H  "Cookie: oraclelicense=accept-securebackup-cookie" -k "http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip"
    
    if ! [ -f jce_policy-8.zip ]
    then
        echo "Working in offline mode and file not found... exiting"
        exit 1
    fi
    
    cp local_policy.jar local_policy.jar$(date "+-%FT%T")
    cp US_export_policy.jar US_export_policy.jar$(date "+-%FT%T")
    unzip -oj jce_policy-8.zip
    rm -f jce_policy-8.zip
    echo ""
    echo "Installing Java 8 Java Cryptography Extension  compelete ....."

}


function install_activemq_opt(){

      if [[ -z $JAVA_HOME ]]; then
      	echo "请先安装jdk8，并设置JAVA_HOME环境变量后继续..."
      	exit 1
      fi

      # 先创建activemq用户

      useradd -r -m -s /bin/bash $ACTIVEMQ_USER

      # 添加activemq用户组

      groupadd -f $ACTIVEMQ_GROUP  

      mkdir -p $ACTIVEMQ_INSTALL_HOME
      
      tar -xzvf apache-activemq-$ACTIVEMQ_INSTALL_VERSION-bin.tar.gz -C $ACTIVEMQ_INSTALL_HOME

      cd $ACTIVEMQ_INSTALL_HOME
      # rm -f apache-activemq-$ACTIVEMQ_INSTALL_VERSION-bin.tar.gz
      ln -s apache-activemq-$ACTIVEMQ_INSTALL_VERSION current


      echo "Installing as a service"
      # http://activemq.apache.org/unix-shell-script.html

      chown -R $ACTIVEMQ_USER:$ACTIVEMQ_GROUP $ACTIVEMQ_INSTALL_HOME
      cp $ACTIVEMQ_INSTALL_HOME/current/bin/env /etc/default/activemq

      if [ -z "$ACTIVEMQ_JAVA_HOME" ] || [ "$ACTIVEMQ_JAVA_HOME" == "SYSTEM_JAVA" ]
      then
       echo "No Java home has been specified for ActiveMQ. Using the system Java home"
      else
        sed -i "/\#\!\/bin\/sh/a export JAVA_HOME=$ACTIVEMQ_JAVA_HOME" /etc/default/activemq
      fi

      sed -i "~s|^ACTIVEMQ_USER=\"\"|ACTIVEMQ_USER=\"$ACTIVEMQ_USER\"|" /etc/default/activemq
      chmod 644 /etc/default/activemq
      ln -snf  $ACTIVEMQ_INSTALL_HOME/current/bin/activemq /etc/init.d/activemq

      echo "activemq 安装完成"

      if [ "$linux_type" == "chkonfig" ]; then
          chkconfig --add activemq
          chkconfig activemq on
      elif [ "$linux_type" == "update-rc.d" ]; then
          update-rc.d activemq defaults 95 10
      fi

      service activemq start


}


function install_elasticsearch_opt(){

      echo "Installing Elasticsearch"

      if [[ -z $JAVA_HOME ]]; then
        echo "请先安装jdk8，并设置JAVA_HOME环境变量后继续..."
        exit 1
      fi


      linux_type=$(get_linux_type)


      
      

      cd elasticsearch

      if [ "$linux_type" == "chkonfig" ]; then

          echo "download elasticsearch ..."
          curl -O -k https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-5.5.0.rpm  
          echo "Executing RPM"
          rpm -ivh elasticsearch-5.5.0.rpm
          echo "Setup elasticsearch as a service"
          sudo chkconfig --add elasticsearch

      elif [ "$linux_type" == "update-rc.d" ]; then

          echo "download elasticsearch ..."
          # curl -O -k https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-5.5.0.deb  
          echo "Executing DEB"
          dpkg -i elasticsearch-5.5.0.deb
          echo "Setup elasticsearch as a service"
          update-rc.d elasticsearch defaults 95 10
      fi



      sed -i "s|#cluster.name: my-application|cluster.name: demo-cluster|" /etc/elasticsearch/elasticsearch.yml
      sed -i "s|#network.host: 192.168.0.1|network.host: 0.0.0.0|" /etc/elasticsearch/elasticsearch.yml


      echo "JAVA_HOME=$JAVA_HOME" >> /etc/sysconfig/elasticsearch


      echo "Starting Elasticsearch"
      sudo service elasticsearch start

      echo "Elasticsearch install complete"

      SERVICE='elasticsearch'

      function check_service {
              if service $SERVICE status | grep running > /dev/null
              then
                #echo "$SERVICE is running"
                      retval=0
              else
                #echo "$SERVICE is NOT running"
                      retval=1
              fi
      }

      retval=1
      numtries=1
      maxtries=10

      echo "Waiting for $SERVICE service to start ..."
      while [ "$retval" != 0 ]
      do
              echo "."
              sleep 1s
              check_service
              ((numtries++))

              if [ "$numtries" -gt "$maxtries" ]
              then
                      echo "Timeout reached"
                      break
              fi
      done

      if [ "$retval" == 0 ]
      then
              echo "Waiting for 10 seconds for the engine to start up, and then will create Kylo indexes in Elasticsearch."
              echo "NOTE: If they already exist, an index_already_exists_exception will be reported. This is OK."
              sleep 10s
              $INSTALL_HOME/bin/create-kylo-indexes-es.sh 127.0.0.1 9200 1 1
      else
              echo "$SERVICE service did not start within a reasonable time. Please check and start it. Then, execute this script manually before starting Kylo."
              echo "This script will create Kylo indexes in Elasticsearch."
              echo "NOTE: If they already exist, an index_already_exists_exception will be reported. This is OK."
              echo "$INSTALL_HOME/bin/create-kylo-indexes-es.sh 127.0.0.1 9200 1 1"
      fi

      echo "Elasticsearch index creation complete"
      
      # 这里追加不好，要改
      # echo "vm.max_map_count=855360" >> /etc/sysctl.conf

      # # sed -i "s|vm.max_map_count=.*|vm.max_map_count=855360|" /etc/sysctl.conf

      # # 这里追加不好，要改
      # echo "*        hard    nofile           65536" >>/etc/security/limits.conf
      # # 这里追加不好，要改
      # echo "*        soft    nofile           65536" >>/etc/security/limits.conf

      # sysctl -p 

}

function install_kylo_opt(){
      INSTALL_HOME=/opt/kylo
      INSTALL_USER=kylo
      INSTALL_GROUP=kylo
      LOG_DIRECTORY_LOCATION=/var/log

      if [[ -z $JAVA_HOME ]]; then
      	#statements

      	echo "请先安装jdk8，并设置JAVA_HOME环境变量后继续..."
      	exit 1
      fi


      if [[ ! -d "$INSTALL_HOME" ]]; then
        mkdir -p $INSTALL_HOME
      fi


      useradd -r -m -s /bin/bash $INSTALL_USER
      groupadd -f $INSTALL_GROUP


      # function for determining way to handle startup scripts
      function get_linux_type {
      # redhat
      which chkconfig > /dev/null && echo "chkonfig" && return 0
      # ubuntu sysv
      which update-rc.d > /dev/null && echo "update-rc.d" && return 0
      echo "Couldn't recognize linux version, after installation you need to do these steps manually:"
      echo " * add proper header to /etc/init.d/{kylo-ui,kylo-services} files"
      echo " * set them to autostart"
      }

      linux_type=$(get_linux_type)
      echo "Type of init scripts management tool determined as $linux_type"

      tar -xzvf kylo-*.tar -C $INSTALL_HOME

      cd $INSTALL_HOME

      chown -R $INSTALL_USER:$INSTALL_GROUP $INSTALL_HOME

      pgrepMarkerKyloUi=kylo-ui-pgrep-marker
      pgrepMarkerKyloServices=kylo-services-pgrep-marker
      rpmLogDir=$LOG_DIRECTORY_LOCATION

      echo "    - Install kylo-ui application"

      jwtkey=$(head -c 64 /dev/urandom | md5sum |cut -d' ' -f1)
      sed -i "s/security\.jwt\.key=<insert-256-bit-secret-key-here>/security\.jwt\.key=${jwtkey}/" $INSTALL_HOME/kylo-ui/conf/application.properties
      echo "   - Installed kylo-ui to '$INSTALL_HOME/kylo-ui'"

      if ! [ -f $INSTALL_HOME/encrypt.key ]
      then
          head -c64 < /dev/urandom | base64 > $INSTALL_HOME/encrypt.key
          chmod 400 $INSTALL_HOME/encrypt.key
          chown $INSTALL_USER:$INSTALL_GROUP $INSTALL_HOME/encrypt.key
      fi

      cat << EOF > $INSTALL_HOME/kylo-ui/bin/run-kylo-ui.sh
      #!/bin/bash
      export JAVA_HOME=$JAVA_HOME
      export PATH=\$JAVA_HOME/bin:\$PATH
      export KYLO_UI_OPTS=-Xmx512m
      [ -f $INSTALL_HOME/encrypt.key ] && export ENCRYPT_KEY="\$(cat $INSTALL_HOME/encrypt.key)"
      java \$KYLO_UI_OPTS -cp $INSTALL_HOME/kylo-ui/conf:$INSTALL_HOME/kylo-ui/lib/*:$INSTALL_HOME/kylo-ui/plugin/* com.thinkbiganalytics.KyloUiApplication --static.path=$INSTALL_HOME/kylo-ui/plugin/static/ --pgrep-marker=$pgrepMarkerKyloUi > $LOG_DIRECTORY_LOCATION/kylo-ui/std.out 2>$LOG_DIRECTORY_LOCATION/kylo-ui/std.err &
      
EOF
      
      cat << EOF > $INSTALL_HOME/kylo-ui/bin/run-kylo-ui-with-debug.sh
        #!/bin/bash
      export JAVA_HOME=$JAVA_HOME
      export PATH=\$JAVA_HOME/bin:\$PATH
      export KYLO_UI_OPTS=-Xmx512m
      [ -f $INSTALL_HOME/encrypt.key ] && export ENCRYPT_KEY="\$(cat $INSTALL_HOME/encrypt.key)"
      JAVA_DEBUG_OPTS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=9997
      java \$KYLO_UI_OPTS \$JAVA_DEBUG_OPTS -cp $INSTALL_HOME/kylo-ui/conf:$INSTALL_HOME/kylo-ui/lib/*:$INSTALL_HOME/kylo-ui/plugin/* com.thinkbiganalytics.KyloUiApplication  --static.path=$INSTALL_HOME/kylo-ui/plugin/static/ --pgrep-marker=$pgrepMarkerKyloUi > $LOG_DIRECTORY_LOCATION/kylo-ui/std.out 2>$LOG_DIRECTORY_LOCATION/kylo-ui/std.err &
EOF
      chmod +x $INSTALL_HOME/kylo-ui/bin/run-kylo-ui.sh
      chmod +x $INSTALL_HOME/kylo-ui/bin/run-kylo-ui-with-debug.sh
      echo "   - Created kylo-ui script '$INSTALL_HOME/kylo-ui/bin/run-kylo-ui.sh'"

      # header of the service file depends on system used
      if [ "$linux_type" == "chkonfig" ]; then
      cat << EOF > /etc/init.d/kylo-ui
      #! /bin/sh
      # chkconfig: 345 98 22
      # description: kylo-ui
      # processname: kylo-ui
EOF
      elif [ "$linux_type" == "update-rc.d" ]; then
      cat << EOF > /etc/init.d/kylo-ui
      #! /bin/sh
      ### BEGIN INIT INFO
      # Provides:          kylo-ui
      # Required-Start:    $local_fs $network $named $time $syslog
      # Required-Stop:     $local_fs $network $named $time $syslog
      # Default-Start:     2 3 4 5
      # Default-Stop:      0 1 6
      # Description:       kylo-ui
      ### END INIT INFO
EOF
      fi

      cat << EOF >> /etc/init.d/kylo-ui
      RUN_AS_USER=$INSTALL_USER

      debug() {
          if pgrep -f kylo-ui-pgrep-marker >/dev/null 2>&1
            then
              echo Already running.
            else
              echo Starting kylo-ui in debug mode...
              grep 'address=' $INSTALL_HOME/kylo-ui/bin/run-kylo-ui-with-debug.sh
              su - \$RUN_AS_USER -c "$INSTALL_HOME/kylo-ui/bin/run-kylo-ui-with-debug.sh"
          fi
      }

      start() {
          if pgrep -f $pgrepMarkerKyloUi >/dev/null 2>&1
            then
              echo Already running.
            else
              echo Starting kylo-ui ...
              su - \$RUN_AS_USER -c "$INSTALL_HOME/kylo-ui/bin/run-kylo-ui.sh"
          fi
      }

      stop() {
          if pgrep -f $pgrepMarkerKyloUi >/dev/null 2>&1
            then
              echo Stopping kylo-ui ...
              pkill -f $pgrepMarkerKyloUi
            else
              echo Already stopped.
          fi
      }

      status() {
          if pgrep -f $pgrepMarkerKyloUi >/dev/null 2>&1
            then
                echo Running.  Here are the related processes:
                pgrep -lf $pgrepMarkerKyloUi
            else
              echo Stopped.
          fi
      }

      case "\$1" in
          debug)
              debug
          ;;
          start)
              start
          ;;
          stop)
              stop
          ;;
          status)
              status
          ;;
          restart)
             echo "Restarting kylo-ui"
             stop
             sleep 2
             start
             echo "kylo-ui started"
          ;;
      esac
      exit 0
EOF
      chmod +x /etc/init.d/kylo-ui
      echo "   - Created kylo-ui script '/etc/init.d/kylo-ui'"

      mkdir -p $rpmLogDir/kylo-ui/
      echo "   - Created Log folder $rpmLogDir/kylo-ui/"

      if [ "$linux_type" == "chkonfig" ]; then
          chkconfig --add kylo-ui
          chkconfig kylo-ui on
      elif [ "$linux_type" == "update-rc.d" ]; then
          update-rc.d kylo-ui defaults
      fi
      echo "   - Added service 'kylo-ui'"
      echo "    - Completed kylo-ui install"

      echo "    - Install kylo-services application"

      sed -i "s/security\.jwt\.key=<insert-256-bit-secret-key-here>/security\.jwt\.key=${jwtkey}/" $INSTALL_HOME/kylo-services/conf/application.properties
      echo "   - Installed kylo-services to '$INSTALL_HOME/kylo-services'"

      cat << EOF > $INSTALL_HOME/kylo-services/bin/run-kylo-services.sh
      #!/bin/bash
      export JAVA_HOME=$JAVA_HOME
      export PATH=\$JAVA_HOME/bin:\$PATH
      export KYLO_SERVICES_OPTS=-Xmx768m
      export KYLO_SPRING_PROFILES_OPTS=
      [ -f $INSTALL_HOME/encrypt.key ] && export ENCRYPT_KEY="\$(cat $INSTALL_HOME/encrypt.key)"
      PROFILES=\$(grep ^spring.profiles. $INSTALL_HOME/kylo-services/conf/application.properties)
      KYLO_NIFI_PROFILE="nifi-v1"
      if [[ \${PROFILES} == *"nifi-v1.1"* ]];
       then
       KYLO_NIFI_PROFILE="nifi-v1.1"
      elif [[ \${PROFILES} == *"nifi-v1.2"* ]] || [[ \${PROFILES} == *"nifi-v1.3"* ]] || [[ \${PROFILES} == *"nifi-v1.4"* ]];
      then
       KYLO_NIFI_PROFILE="nifi-v1.2"
      fi
      echo "using NiFi profile: \${KYLO_NIFI_PROFILE}"

      java \$KYLO_SERVICES_OPTS \$KYLO_SPRING_PROFILES_OPTS -cp $INSTALL_HOME/kylo-services/conf:$INSTALL_HOME/kylo-services/lib/*:$INSTALL_HOME/kylo-services/lib/\${KYLO_NIFI_PROFILE}/*:$INSTALL_HOME/kylo-services/plugin/* com.thinkbiganalytics.server.KyloServerApplication --pgrep-marker=$pgrepMarkerKyloServices > $LOG_DIRECTORY_LOCATION/kylo-services/std.out 2>$LOG_DIRECTORY_LOCATION/kylo-services/std.err &
EOF
      cat << EOF > $INSTALL_HOME/kylo-services/bin/run-kylo-services-with-debug.sh
      #!/bin/bash
      export JAVA_HOME=$JAVA_HOME
      export PATH=\$JAVA_HOME/bin:\$PATH
      export KYLO_SERVICES_OPTS=-Xmx768m
      [ -f $INSTALL_HOME/encrypt.key ] && export ENCRYPT_KEY="\$(cat $INSTALL_HOME/encrypt.key)"
      JAVA_DEBUG_OPTS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=9998
      PROFILES=\$(grep ^spring.profiles. $INSTALL_HOME/kylo-services/conf/application.properties)
      KYLO_NIFI_PROFILE="nifi-v1"

      if [[ \${PROFILES} == *"nifi-v1.1"* ]];
       then
       KYLO_NIFI_PROFILE="nifi-v1.1"
      elif [[ \${PROFILES} == *"nifi-v1.2"* ]] || [[ \${PROFILES} == *"nifi-v1.3"* ]] || [[ \${PROFILES} == *"nifi-v1.4"* ]];
      then
       KYLO_NIFI_PROFILE="nifi-v1.2"
      fi
      echo "using NiFi profile: \${KYLO_NIFI_PROFILE}"
      java \$KYLO_SERVICES_OPTS \$JAVA_DEBUG_OPTS -cp $INSTALL_HOME/kylo-services/conf:$INSTALL_HOME/kylo-services/lib/*:$INSTALL_HOME/kylo-services/lib/\${KYLO_NIFI_PROFILE}/*:$INSTALL_HOME/kylo-services/plugin/* com.thinkbiganalytics.server.KyloServerApplication --pgrep-marker=$pgrepMarkerKyloServices > $LOG_DIRECTORY_LOCATION/kylo-services/std.out 2>$LOG_DIRECTORY_LOCATION/kylo-services/std.err &
EOF
      chmod +x $INSTALL_HOME/kylo-services/bin/run-kylo-services.sh
      chmod +x $INSTALL_HOME/kylo-services/bin/run-kylo-services-with-debug.sh
      echo "   - Created kylo-services script '$INSTALL_HOME/kylo-services/bin/run-kylo-services.sh'"

      # header of the service file depends on system used
      if [ "$linux_type" == "chkonfig" ]; then
      cat << EOF > /etc/init.d/kylo-services
      #! /bin/sh
      # chkconfig: 345 98 21
      # description: kylo-services
      # processname: kylo-services
      
EOF
      elif [ "$linux_type" == "update-rc.d" ]; then
      cat << EOF > /etc/init.d/kylo-services
      #! /bin/sh
      ### BEGIN INIT INFO
      # Provides:          kylo-services
      # Required-Start:    $local_fs $network $named $time $syslog
      # Required-Stop:     $local_fs $network $named $time $syslog
      # Default-Start:     2 3 4 5
      # Default-Stop:      0 1 6
      # Description:       kylo-services
      ### END INIT INFO
EOF
      fi

      cat << EOF >> /etc/init.d/kylo-services
      RUN_AS_USER=$INSTALL_USER

      debug() {
          if pgrep -f kylo-services-pgrep-marker >/dev/null 2>&1
            then
              echo Already running.
            else
              echo Starting kylo-services in debug mode...
              grep 'address=' $INSTALL_HOME/kylo-services/bin/run-kylo-services-with-debug.sh
              su - \$RUN_AS_USER -c "$INSTALL_HOME/kylo-services/bin/run-kylo-services-with-debug.sh"
          fi
      }

      start() {
          if pgrep -f $pgrepMarkerKyloServices >/dev/null 2>&1
            then
              echo Already running.
            else
              echo Starting kylo-services ...
              su - \$RUN_AS_USER -c "$INSTALL_HOME/kylo-services/bin/run-kylo-services.sh"
          fi
      }

      stop() {
          if pgrep -f $pgrepMarkerKyloServices >/dev/null 2>&1
            then
              echo Stopping kylo-services ...
              pkill -f $pgrepMarkerKyloServices
            else
              echo Already stopped.
          fi
      }

      status() {
          if pgrep -f $pgrepMarkerKyloServices >/dev/null 2>&1
            then
                echo Running.  Here are the related processes:
                pgrep -lf $pgrepMarkerKyloServices
            else
              echo Stopped.
          fi
      }

      case "\$1" in
          debug)
              debug
          ;;
          start)
              start
          ;;
          stop)
              stop
          ;;
          status)
              status
          ;;
          restart)
             echo "Restarting kylo-services"
             stop
             sleep 2
             start
             echo "kylo-services started"
          ;;
      esac
      exit 0
EOF
      chmod +x /etc/init.d/kylo-services
      echo "   - Created kylo-services script '/etc/init.d/kylo-services'"

      mkdir -p $rpmLogDir/kylo-services/
      echo "   - Created Log folder $rpmLogDir/kylo-services/"

      if [ "$linux_type" == "chkonfig" ]; then
          chkconfig --add kylo-services
          chkconfig kylo-services on
      elif [ "$linux_type" == "update-rc.d" ]; then
          update-rc.d kylo-services defaults
      fi
      echo "   - Added service 'kylo-services'"


      echo "    - Completed kylo-services install"

      cat << EOF > $INSTALL_HOME/kylo-services/bin/run-kylo-spark-shell.sh
      #!/bin/bash

      if ! which spark-submit >/dev/null 2>&1; then
      	>&2 echo "ERROR: spark-submit not on path.  Has spark been installed?"
      	exit 1
      fi

      SPARK_PROFILE="v"\$(spark-submit --version 2>&1 | grep -o "version [0-9]" | grep -o "[0-9]" | head -1)
      KYLO_DRIVER_CLASS_PATH=$INSTALL_HOME/kylo-spark-shell-pgrep-marker:$INSTALL_HOME/kylo-services/conf:$INSTALL_HOME/kylo-services/lib/mariadb-java-client-1.5.7.jar
      if [[ -n \$SPARK_CONF_DIR ]]; then
              if [ -r \$SPARK_CONF_DIR/spark-defaults.conf ]; then
      		CLASSPATH_FROM_SPARK_CONF=\$(grep -E '^spark.driver.extraClassPath' \$SPARK_CONF_DIR/spark-defaults.conf | awk '{print \$2}')
      		if [[ -n \$CLASSPATH_FROM_SPARK_CONF ]]; then
      			KYLO_DRIVER_CLASS_PATH=\${KYLO_DRIVER_CLASS_PATH}:\$CLASSPATH_FROM_SPARK_CONF
      		fi
      	fi
      fi
      spark-submit --master local --conf spark.driver.userClassPathFirst=true --class com.thinkbiganalytics.spark.SparkShellApp --driver-class-path \$KYLO_DRIVER_CLASS_PATH --driver-java-options -Dlog4j.configuration=log4j-spark.properties $INSTALL_HOME/kylo-services/lib/app/kylo-spark-shell-client-\${SPARK_PROFILE}-*.jar --pgrep-marker=kylo-spark-shell-pgrep-marker
EOF
      cat << EOF > $INSTALL_HOME/kylo-services/bin/run-kylo-spark-shell-with-debug.sh
      #!/bin/bash

      if ! which spark-submit >/dev/null 2>&1; then
      	>&2 echo "ERROR: spark-submit not on path.  Has spark been installed?"
      	exit 1
      fi

      JAVA_DEBUG_OPTS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=9998
      SPARK_PROFILE="v"\$(spark-submit --version 2>&1 | grep -o "version [0-9]" | grep -o "[0-9]" | head -1)
      KYLO_DRIVER_CLASS_PATH=$INSTALL_HOME/kylo-spark-shell-pgrep-marker:$INSTALL_HOME/kylo-services/conf:$INSTALL_HOME/kylo-services/lib/mariadb-java-client-1.5.7.jar
      if [[ -n \$SPARK_CONF_DIR ]]; then
              if [ -r \$SPARK_CONF_DIR/spark-defaults.conf ]; then
      		CLASSPATH_FROM_SPARK_CONF=\$(grep -E '^spark.driver.extraClassPath' \$SPARK_CONF_DIR/spark-defaults.conf | awk '{print \$2}')
      		if [[ -n \$CLASSPATH_FROM_SPARK_CONF ]]; then
      			KYLO_DRIVER_CLASS_PATH=\${KYLO_DRIVER_CLASS_PATH}:\$CLASSPATH_FROM_SPARK_CONF
      		fi
      	fi
      fi
      spark-submit --master local --conf spark.driver.userClassPathFirst=true --class com.thinkbiganalytics.spark.SparkShellApp --driver-class-path \$KYLO_DRIVER_CLASS_PATH --driver-java-options "-Dlog4j.configuration=log4j-spark.properties \$JAVA_DEBUG_OPTS" $INSTALL_HOME/kylo-services/lib/app/kylo-spark-shell-client-\${SPARK_PROFILE}-*.jar --pgrep-marker=kylo-spark-shell-pgrep-marker
EOF
      chmod +x $INSTALL_HOME/kylo-services/bin/run-kylo-spark-shell.sh
      chmod +x $INSTALL_HOME/kylo-services/bin/run-kylo-spark-shell-with-debug.sh

      {
      echo "    - Create an RPM Removal script at: $INSTALL_HOME/remove-kylo.sh"
      touch $INSTALL_HOME/remove-kylo.sh
      if [ "$linux_type" == "chkonfig" ]; then
          lastRpm=$(rpm -qa | grep kylo)
          echo "rpm -e $lastRpm " > $INSTALL_HOME/remove-kylo.sh
      elif [ "$linux_type" == "update-rc.d" ]; then
          echo "apt-get remove kylo" > $INSTALL_HOME/remove-kylo.sh
      fi
      chmod +x $INSTALL_HOME/remove-kylo.sh

      }

      chown -R $INSTALL_USER:$INSTALL_GROUP $INSTALL_HOME

      chmod 755 $rpmLogDir/kylo*

      chown $INSTALL_USER:$INSTALL_GROUP $rpmLogDir/kylo*

      # Setup kylo-service command
      cp $INSTALL_HOME/bin/kylo-service /usr/bin/kylo-service



      chown root:root /usr/bin/kylo-service
      chmod 755 /usr/bin/kylo-service

      # Setup kylo-tail command
      mkdir -p /etc/kylo/


      echo "   - The command kylo-service can be used to control and check the Kylo services as well as optional services. Use the command kylo-service help to find out more information. "
      echo "   - Please configure the application using the property files and scripts located under the '$INSTALL_HOME/kylo-ui/conf' and '$INSTALL_HOME/kylo-services/conf' folder.  See deployment guide for details."
      echo "   - To remove kylo run $INSTALL_HOME/remove-kylo.sh "
      echo "   INSTALL COMPLETE"

}

function config_kylo_opt(){
    kylo_home_folder=/opt/kylo
    CONFIG_HOME="/opt/kylo/kylo-services/conf"
    spark_file="/opt/kylo/kylo-services/conf/spark.properties"
    KYLO_SERVICEES_FOLDER="/opt/kylo/kylo-services"


      hive_site="/etc/hive/conf/hive-site.xml"
      
      if [[ ! -f "$hive_site" ]]; then
        #statements
        cp /etc/hive/conf/hive-site.xml /etc/spark/conf/hive-site.xml
      
      fi

      echo "spark.io.compression.codec=lz4" >> /etc/spark/conf/spark-defaults.conf


      sed -i "s|spring.datasource.url=.*|spring.datasource.url=jdbc:mysql://$mysql_kylo_db_host:3306/kylo|"  $CONFIG_HOME/application.properties

      sed -i "s|spring.datasource.username=.*|spring.datasource.username=$mysql_kylo_db_user|" $CONFIG_HOME/application.properties

      sed -i "s|spring.datasource.password=.*|spring.datasource.password=$mysql_kylo_db_password|" $CONFIG_HOME/application.properties




      sed -i "s|#security.auth.file.users=file:///opt/kylo/users.properties|security.auth.file.users=file:///opt/kylo/users.properties|" $CONFIG_HOME/application.properties

      sed -i "s|#metadata.datasource.username=\${spring.datasource.username}|metadata.datasource.username=\${spring.datasource.username}|" $CONFIG_HOME/application.properties

      sed -i "s|#metadata.datasource.password=\${spring.datasource.password}|metadata.datasource.password=\${spring.datasource.password}|" $CONFIG_HOME/application.properties


      sed -i "s|#modeshape.datasource.username=\${spring.datasource.username}|modeshape.datasource.username=\${spring.datasource.username}|" $CONFIG_HOME/application.properties

      sed -i "s|#modeshape.datasource.password=\${spring.datasource.password}|modeshape.datasource.password=\${spring.datasource.password}|" $CONFIG_HOME/application.properties


      sed -i "s|nifi.rest.host.*|nifi.rest.host=$kylo_local_ip|" $CONFIG_HOME/application.properties

      sed -i "s|hive.userImpersonation.enabled=.*|hive.userImpersonation.enabled=true|" $CONFIG_HOME/application.properties
      sed -i "s|hive.metastore.datasource.username=.*|hive.metastore.datasource.username=$hive_metastore_datasource_username|"  $CONFIG_HOME/application.properties
      sed -i "s|hive.metastore.datasource.password=.*|hive.metastore.datasource.password=$hive_metastore_datasource_password|" $CONFIG_HOME/application.properties
      
      sed -i "s|nifi.service.mysql.database_user=.*|nifi.service.mysql.database_user=$mysql_kylo_db_user|" $CONFIG_HOME/application.properties

      sed -i "s|nifi.service.mysql.password=.*|nifi.service.mysql.password=$mysql_kylo_db_password|" $CONFIG_HOME/application.properties


      sed -i "s|nifi.service.kylo_mysql.database_user=.*|nifi.service.kylo_mysql.database_user=$mysql_kylo_db_user|" $CONFIG_HOME/application.properties


      sed -i "s|nifi.service.kylo_mysql.password=.*|nifi.service.kylo_mysql.password=$mysql_kylo_db_password|" $CONFIG_HOME/application.properties




       echo " ";

      USERS_FILE_CREATED=false;
      if [ ! -f $kylo_home_folder/users.properties ]; then
          echo "dladmin=$dladmin_password" >> $kylo_home_folder/users.properties
          sed -i "s|nifi.service.kylo_metadata_service.rest_client_password.*|nifi.service.kylo_metadata_service.rest_client_password=$dladmin_password|" $kylo_home_folder/kylo-services/conf/application.properties
          sed -i "s|#security.auth.file.users=file:\/\/\/opt\/kylo\/users.properties|security.auth.file.users=file:\/\/$kylo_home_folder\/users.properties|" $kylo_home_folder/kylo-services/conf/application.properties
          sed -i "s|#security.auth.file.users=file:\/\/\/opt\/kylo\/users.properties|security.auth.file.users=file:\/\/$kylo_home_folder\/users.properties|" $kylo_home_folder/kylo-ui/conf/application.properties
          USERS_FILE_CREATED=true

          if [ ! -f $kylo_home_folder/groups.properties ]; then
              touch $kylo_home_folder/groups.properties
              sed -i "s|#security.auth.file.users=file:\/\/\/opt\/kylo\/groups.properties|security.auth.file.users=file:\/\/$kylo_home_folder\/groups.properties|" $kylo_home_folder/kylo-services/conf/application.properties
              sed -i "s|#security.auth.file.users=file:\/\/\/opt\/kylo\/groups.properties|security.auth.file.users=file:\/\/$kylo_home_folder\/groups.properties|" $kylo_home_folder/kylo-ui/conf/application.properties
          fi
      fi



    #   echo " ";
    #   while [[ ! $create_es_index =~ $yes_no ]]; do
    #       read -p "Would you like to create kylo indexes for es ? Please enter y/n: " create_es_index
    #   done 


    #   echo " ";
    #   if [ "$create_es_index" == "y"  ] || [ "$create_es_index" == "Y" ] ; then
          
    #   fi



      # --------------# ---------------


      sed -i "s|config.spark.validateAndSplitRecords.extraJars=.*|config.spark.validateAndSplitRecords.extraJars=$validateAndSplitRecords_extraJars|" $CONFIG_HOME/application.properties

      echo " ";
      while [[ ! $enable_kerberos =~ $yes_no ]]; do
          read -p "Would you enable kerberos ? Please enter y/n: " enable_kerberos
      done 



      # 配置sparkhome
      sed -i "s|nifi.executesparkjob.sparkhome=.*|nifi.executesparkjob.sparkhome=$spark_home|" $CONFIG_HOME/application.properties
      sed -i "s|#nifi.executesparkjob.sparkhome=.*|nifi.executesparkjob.sparkhome=$spark_home|"  $CONFIG_HOME/application.properties
      sed -i "s|#spark.shell.sparkHome=.*|spark.shell.sparkHome=$spark_home|"  $CONFIG_HOME/spark.properties

      # Enable Kerberos for Kylo ----------------- start 


      # 配置hive2

      sed -i "s|hive.metastore.datasource.url=.*|hive.metastore.datasource.url=jdbc:mysql://$hive_metastore_datasource_url:3306/hive|" $CONFIG_HOME/application.properties
      sed -i "s|hive.metastore.datasource.username.*|hive.metastore.datasource.username=$hive_metastore_datasource_username|" $CONFIG_HOME/application.properties
      sed -i "s|hive.metastore.datasource.password.*|hive.metastore.datasource.password=$hive_metastore_datasource_password|" $CONFIG_HOME/application.properties


      

      sed -i "s|#config.hive.schema=metastore|config.hive.schema=metastore|" $CONFIG_HOME/application.properties

      sed -i "s|nifi.service.standardtdchconnectionservice.hive_conf_path.*|nifi.service.standardtdchconnectionservice.hive_conf_path=\/etc\/hive\/conf|" $CONFIG_HOME/application.properties

      sed -i "s|#nifi.service.hive_thrift_service.hadoop_configuration_resources=\/etc\/hadoop\/conf/core-site.xml,\/etc\/hadoop\/conf\/hdfs-site.xml|nifi.service.hive_thrift_service.hadoop_configuration_resources=$hadoopConfigurationResources|" $CONFIG_HOME/application.properties

      sed -i "s|nifi.service.standardtdchconnectionservice.hive_lib_path.*|nifi.service.standardtdchconnectionservice.hive_lib_path=$hive_lib_path|" $CONFIG_HOME/application.properties

      # config.metadata.url

      sed -i "s|config.metadata.url.*|config.metadata.url=http://$kylo_local_ip:8400/proxy/v1/metadata|" $CONFIG_HOME/application.properties



      echo " ";
      if [ "$enable_kerberos" == "N"  ] || [ "$enable_kerberos" == "n" ] ; then
          # This property will default the URL when importing a template using the thrift connection
          sed -i "s|nifi.service.hive_thrift_service.database_connection_url=.*|nifi.service.hive_thrift_service.database_connection_url=jdbc:hive2:\/\/$hive_server2_host:10000\/default|" $CONFIG_HOME/application.properties

       # This property is for the hive thrift connection used by kylo-services
          sed -i "s|hive.datasource.url=.*|hive.datasource.url=jdbc:hive2:\/\/$hive_server2_host:10000\/default|"  $CONFIG_HOME/application.properties

      fi




      echo " ";
      if [ "$enable_kerberos" == "y"  ] || [ "$enable_kerberos" == "Y" ] ; then

          # This property is for the hive thrift connection used by kylo-services
          sed -i "s|hive.datasource.url=.*|hive.datasource.url=jdbc:hive2:\/\/$hive_server2_host:10000\/default;principal=$hive_service_principal|"  $CONFIG_HOME/application.properties

          # This property will default the URL when importing a template using the thrift connection
          sed -i "s|nifi.service.hive_thrift_service.database_connection_url=.*|nifi.service.hive_thrift_service.database_connection_url=jdbc:hive2:\/\/$hive_server2_host:10000\/default;principal=$hive_service_principal|" $CONFIG_HOME/application.properties

          # Set Kerberos to true for the kylo-services application and set the 3 required properties
          sed -i "s|kerberos.hive.kerberosEnabled.*|kerberos.hive.kerberosEnabled=true|"  $CONFIG_HOME/application.properties

          sed -i "s|#kerberos.hive.kerberosPrincipal.*|kerberos.hive.kerberosPrincipal=$hive_service_principal|" $CONFIG_HOME/application.properties

          sed -i "s|#kerberos.hive.keytabLocation.*|kerberos.hive.keytabLocation=$hive_service_kerberos_keytab|" $CONFIG_HOME/application.properties

          # uncomment these 3 properties to default all NiFi processors that have these fields. Saves time when importing a template
          # 配置这里的nifi
          sed -i "s|#nifi.all_processors.kerberos_principal.*|nifi.all_processors.kerberos_principal=$nifi_user_principal|" $CONFIG_HOME/application.properties
          #mark
          sed -i "s|#nifi.all_processors.kerberos_keytab.*|nifi.all_processors.kerberos_keytab=$nifi_user_kerberos_keytab|" $CONFIG_HOME/application.properties

          sed -i "s|#nifi.all_processors.hadoop_configuration_resources.*|nifi.all_processors.hadoop_configuration_resources=\/etc\/hadoop\/conf\/core-site.xml,\/etc\/hadoop\/conf\/hdfs-site.xml|" $CONFIG_HOME/application.properties
          sed -i "s|#kerberos.hive.hadoopConfigurationResources.*|kerberos.hive.hadoopConfigurationResources=$hadoopConfigurationResources|" $CONFIG_HOME/application.properties

          # Modify the kylo-spark-shell configuration
          sed -i "/spark.shell.sparkHome/ a kerberos.spark.kerberosEnabled = true" $CONFIG_HOME/spark.properties


          sed -i "/kerberos.spark.kerberosEnabled/ a kerberos.spark.keytabLocation = $kylo_user_kerberos_keytab" $CONFIG_HOME/spark.properties

          sed -i "/kerberos.spark.keytabLocation/ a kerberos.spark.kerberosPrincipal = $kylo_user_principal" $CONFIG_HOME/spark.properties

          sed  -i "/^spark-submit.*/ d" $KYLO_SERVICEES_FOLDER/bin/run-kylo-spark-shell.sh
          echo ""
          echo ""
          echo "spark-submit --principal "$kylo_user_principal" --keytab $kylo_user_kerberos_keytab --master local --conf spark.driver.userClassPathFirst=true --class com.thinkbiganalytics.spark.SparkShellApp --driver-class-path $KYLO_DRIVER_CLASS_PATH --driver-java-options -Dlog4j.configuration=log4j-spark.properties /opt/kylo/kylo-services/lib/app/kylo-spark-shell-client-${SPARK_PROFILE}-*.jar --pgrep-marker=kylo-spark-shell-pgrep-marker" >>  $KYLO_SERVICEES_FOLDER/bin/run-kylo-spark-shell.sh


          sed -i "s|#nifi.service.hive_thrift_service.kerberos_principal.*|nifi.service.hive_thrift_service.kerberos_principal=$nifi_service_principal|" $CONFIG_HOME/application.properties

          sed -i "s|#nifi.service.hive_thrift_service.kerberos_keytab.*|nifi.service.hive_thrift_service.kerberos_keytab=$nifi_service_kerberos_keytab|" $CONFIG_HOME/application.properties

      fi
      echo "config complete kylo !!!"
}

function stop_kylo_nifi(){
      # 停止kylo
      kylo-service stop
      echo "kylo 服务已关闭"
      # 停止nifi
      service nifi stop
      echo "nifi 服务已关闭"


      # 删除 nifi 的日志文件

      rm -rf /var/log/nifi/*

      echo "删除nifif日志文件"

      # 删除 kylo-servic e的日志文件 
      rm -rf /var/log/kylo-services/*

      echo "删除kylo日志文件"

      echo " ";
      while [[ ! $rm_nifi =~ $yes_no ]]; do
          read -p "Would you like to remove nifi ? Please enter y/n: " rm_nifi
      done 

      echo " ";
      if [ "$rm_nifi" == "y"  ] || [ "$rm_nifi" == "Y" ] ; then
            # 删除nifi安装目录
            rm -rf /opt/nifi/*
            echo "已删除nifi"
      fi

}


# kylo菜单页面
# `echo -e "\033[35m 2） create-kylo-indexes-es ..........\033[0m"`
function kyloMenu (){
  cat << EOF
    ----------------------------------------
    |***************kylo主页***************|
    ----------------------------------------
  `echo -e "\033[35m 1） 安装kylo ..........\033[0m"`
  `echo -e "\033[35m 2） 配置kylo ..........\033[0m"`
  `echo -e "\033[35m 3） 导入模板  ...........\033[0m"`
  `echo -e "\033[35m 4)  拷贝userdata1.csv.......\033[0m"`
  `echo -e "\033[35m 5） 为kylo创建elastechsearch索引  ..........\033[0m"`
  `echo -e "\033[35m 0)  返回主菜单..........\033[0m"`
  
  `echo -e "\033[35m q) 退出\033[0m"`
  `echo ""`
  `echo ""`
  `echo ""`
EOF

  read -p "请选择kylo菜单功能：" num1

  case $num1 in
    1)
      
      echo "开始安装kylo !!"
      install_kylo_opt
      echo "kylo安装完成"
      echo ""
      kyloMenu
      ;;
    2)
      
      echo "Welcome to 配置kylo !!"
      config_kylo_opt
      echo "配置kylo完成..."
      echo ""
      kyloMenu
      ;;
    3)
      sh $INSTALL_HOME/setup/data/install-templates-locally.sh
      echo " "
      echo "模板导入完成"
      echo ""
      kyloMenu
      ;;
    4)
      echo ""
      copy_userdata_2_dropzone
      echo ""
      kyloMenu
      ;;
    5)
      echo ""
      $kylo_home_folder/bin/create-kylo-indexes-es.sh 127.0.0.1 9200 1 1
      echo ""
      mainMenu
      ;;
    0) 
       echo ""
       mainMenu
       echo ""
       ;;
    q)
       echo ""
       echo "bye!!"
       echo ""
       exit
       ;;
    * )
        echo ""
        echo "您的输入有误，请重新输入"
        kyloMenu
        echo ""
        ;;
  esac
}



function install_nifi_opt (){

     
    echo "Installing NiFI"

    if [[ ! -d NIFI_INSTALL_HOME ]]; then
         #statements
        mkdir -p $NIFI_INSTALL_HOME
    fi

    useradd -r -m -s /bin/bash $NIFI_USER
    groupadd -f $NIFI_GROUP
    echo " ";
    echo " ";
    while [[ ! $enable_krb =~ $yes_no ]]; do
        read -p "Would you like to enabled kerberos ? Please enter y/n: " enable_krb
    done 

    echo "开始解压nifi"
    tar -xzvf nifi-${NIFI_VERSION}-bin.tar.gz -C $NIFI_INSTALL_HOME
    echo "解压 nifi 完成"

    cd $NIFI_INSTALL_HOME

    ln -s nifi-${NIFI_VERSION} current

    echo "Externalizing NiFi data files and folders to support upgrades"
    mkdir -p $NIFI_DATA/conf
    mv $NIFI_INSTALL_HOME/current/conf/authorizers.xml $NIFI_DATA/conf
    mv $NIFI_INSTALL_HOME/current/conf/login-identity-providers.xml $NIFI_DATA/conf


    echo "Changing permissions to the nifi user"
    chown -R $NIFI_USER:$NIFI_GROUP $NIFI_INSTALL_HOME
    echo "NiFi installation complete"

    echo "Modifying the nifi.properties file"
    sed -i "s|nifi.flow.configuration.file=.\/conf\/flow.xml.gz|nifi.flow.configuration.file=$NIFI_INSTALL_HOME\/data\/conf\/flow.xml.gz|" $NIFI_INSTALL_HOME/current/conf/nifi.properties
    sed -i "s|nifi.flow.configuration.archive.dir=.\/conf\/archive\/|nifi.flow.configuration.archive.dir=$NIFI_INSTALL_HOME\/data\/conf\/archive\/|" $NIFI_INSTALL_HOME/current/conf/nifi.properties
    sed -i "s|nifi.authorizer.configuration.file=.\/conf\/authorizers.xml|nifi.authorizer.configuration.file=$NIFI_INSTALL_HOME\/data\/conf\/authorizers.xml|" $NIFI_INSTALL_HOME/current/conf/nifi.properties
    sed -i "s|nifi.templates.directory=.\/conf\/templates|nifi.templates.directory=$NIFI_INSTALL_HOME\/data\/conf\/templates|" $NIFI_INSTALL_HOME/current/conf/nifi.properties
    sed -i "s|nifi.flowfile.repository.directory=.\/flowfile_repository|nifi.flowfile.repository.directory=$NIFI_INSTALL_HOME\/data\/flowfile_repository|" $NIFI_INSTALL_HOME/current/conf/nifi.properties
    sed -i "s|nifi.content.repository.directory.default=.\/content_repository|nifi.content.repository.directory.default=$NIFI_INSTALL_HOME\/data\/content_repository|" $NIFI_INSTALL_HOME/current/conf/nifi.properties
    sed -i "s|nifi.content.repository.archive.enabled=true|nifi.content.repository.archive.enabled=false|" $NIFI_INSTALL_HOME/current/conf/nifi.properties
    sed -i "s|nifi.provenance.repository.directory.default=.\/provenance_repository|nifi.provenance.repository.directory.default=$NIFI_INSTALL_HOME\/data\/provenance_repository|" $NIFI_INSTALL_HOME/current/conf/nifi.properties
    sed -i "s|nifi.web.http.port=8080|nifi.web.http.port=8079|" $NIFI_INSTALL_HOME/current/conf/nifi.properties
    sed -i "s|nifi.provenance.repository.implementation=org.apache.nifi.provenance.PersistentProvenanceRepository|nifi.provenance.repository.implementation=com.thinkbiganalytics.nifi.provenance.repo.KyloPersistentProvenanceEventRepository|" $NIFI_INSTALL_HOME/current/conf/nifi.properties

    echo "Updating the log file path"
    sed -i 's/NIFI_LOG_DIR=\".*\"/NIFI_LOG_DIR=\"\/var\/log\/nifi\"/' $NIFI_INSTALL_HOME/current/bin/nifi-env.sh

    linux_type=$(get_linux_type)

    NIFI_SETUP_DIR=$KYLO_INSTALL_HOME/setup/nifi

    echo -e "\n\n# Set kylo nifi configuration file directory path" >> $NIFI_INSTALL_HOME/current/conf/bootstrap.conf
    echo -e "java.arg.15=-Dkylo.nifi.configPath=$NIFI_INSTALL_HOME/ext-config" >> $NIFI_INSTALL_HOME/current/conf/bootstrap.conf

    echo "Installing the kylo libraries to the NiFi lib"
    mkdir $NIFI_INSTALL_HOME/current/lib/app
    mkdir -p $NIFI_INSTALL_HOME/data/lib/app
    cp $NIFI_SETUP_DIR/*.nar $NIFI_INSTALL_HOME/data/lib
    cp $NIFI_SETUP_DIR/kylo-spark-*.jar $NIFI_INSTALL_HOME/data/lib/app

    echo "Creating symbolic links to jar files"
    $NIFI_SETUP_DIR/create-symbolic-links.sh $NIFI_INSTALL_HOME $NIFI_USER $NIFI_GROUP

    echo "Copy the mysql lib from a lib folder to $NIFI_INSTALL_HOME/mysql"
    
    mkdir $NIFI_INSTALL_HOME/mysql
    cp $KYLO_INSTALL_HOME/kylo-services/lib/mariadb-java-client-*.jar $NIFI_INSTALL_HOME/mysql

    echo "Copy the activeMQ required jars for the JMS processors to $NIFI_INSTALL_HOME/activemq"
    mkdir $NIFI_INSTALL_HOME/activemq
    cp $NIFI_SETUP_DIR/activemq/*.jar $NIFI_INSTALL_HOME/activemq

    echo "setting up temporary database in case JMS goes down"
    mkdir $NIFI_INSTALL_HOME/h2
    mkdir $NIFI_INSTALL_HOME/ext-config
    cp $NIFI_SETUP_DIR/config.properties $NIFI_INSTALL_HOME/ext-config
    chown -R $NIFI_USER:$NIFI_GROUP $NIFI_INSTALL_HOME

    echo "Creating flow file cache directory"
    mkdir $NIFI_INSTALL_HOME/feed_flowfile_cache/
    chown $NIFI_USER:$NIFI_GROUP $NIFI_INSTALL_HOME/feed_flowfile_cache/

    mkdir /var/log/nifi
    chown $NIFI_USER:$NIFI_GROUP /var/log/nifi

    echo "Install the nifi service"
    cp $NIFI_SETUP_DIR/nifi /etc/init.d

    echo "Updating the home folder for the init.d script"
    sed -i "s|dir=\"\/opt\/nifi\/current\/bin\"|dir=\"$NIFI_INSTALL_HOME\/current\/bin\"|" /etc/init.d/nifi
    sed -i "s|RUN_AS_USER=nifi|RUN_AS_USER=$NIFI_USER|" /etc/init.d/nifi

    echo "Updating the provenance cache location"
    sed -i "s|kylo.provenance.cache.location=\/opt\/nifi\/feed-event-statistics.gz|kylo.provenance.cache.location=$NIFI_INSTALL_HOME\/feed-event-statistics.gz|" $NIFI_INSTALL_HOME/ext-config/config.properties


    echo " ";
    if [ "$enable_krb" == "y"  ] || [ "$enable_krb" == "Y" ] ; then

    	sed -i "s|nifi.kerberos.krb5.file=.*|nifi.kerberos.krb5.file=/etc/krb5.conf|" $NIFI_INSTALL_HOME/nifi-1.6.0/conf/nifi.properties
    fi

    if [ "$linux_type" == "chkonfig" ]; then
        chkconfig nifi on
    elif [ "$linux_type" == "update-rc.d" ]; then
        update-rc.d nifi defaults 98 10
    fi

    cp /opt/nifi/mysql/mariadb-java-client-1.5.7.jar /opt/kylo/lib

    echo "Installation  nifi Complete"


}

function copy_userdata_2_dropzone() {
    drop_folder="/var/dropzone"
    if [[ ! -d "$drop_folder" ]]; then
        mkdir -p $drop_folder
        chmod 777 -R $drop_folder
    fi 
        chmod 777 -R $drop_folder
        cp /opt/kylo/setup/data/sample-data/csv/userdata1.csv $drop_folder
        cp /opt/kylo/setup/data/sample-data/csv/userdata1.csv /root/
        echo "文件拷贝完成"
        kyloMenu
}

function rebuild_kylo_db() {

    mysql -h$mysql_kylo_db_host -u$mysql_kylo_db_user -p$mysql_kylo_db_password -e "drop database kylo;"

    cd $kylo_home_folder/setup/sql/mysql

    sh setup-mysql.sh $mysql_kylo_db_host $mysql_kylo_db_user $mysql_kylo_db_password

    sleep 1.2s

    TARGET=kylo-db-update-script.sql
    PROPS=$kylo_home_folder/kylo-services/conf/application.properties

    echo "Reading configuration properties from ${PROPS}"

    USERNAME=`grep "^spring.datasource.username=" ${PROPS} | cut -d'=' -f2`
    PASSWORD=`grep "^spring.datasource.password=" ${PROPS} | cut -d'=' -f2`
    DRIVER=`grep "^spring.datasource.driverClassName=" ${PROPS} | cut -d'=' -f2`
    
    URL=`grep "^spring.datasource.url=" ${PROPS} | cut -d'=' -f2`

    CP="$kylo_home_folder/kylo-services/lib/liquibase-core-3.5.3.jar.jar:$kylo_home_folder/kylo-services/lib/*"
    echo "Loading classpath: ${CP}"

    echo "Generating ${TARGET} for ${URL}, connecting as ${USERNAME}"

    cd $kylo_home_folder/setup/sql

    java -cp ${CP} \
        liquibase.integration.commandline.Main \
         --changeLogFile=com/thinkbiganalytics/db/master.xml \
         --driver=${DRIVER} \
         --url=${URL} \
         --username=${USERNAME} \
         --password=${PASSWORD} \
         updateSQL > ${TARGET}

    echo "Replacing delimiter placeholders"
    sed -i.bac "s/-- delimiter placeholder //g" ${TARGET}
    
    mysql -u$mysql_kylo_db_user -p$mysql_kylo_db_password -h$mysql_kylo_db_host -e "use kylo ;source $kylo_home_folder/setup/sql/kylo-db-update-script.sql;"

    echo "数据库更新完成"
}

function mainMenu (){
  cat << EOF
  ----------------------------------------
  |***************功能主页****************|
  ----------------------------------------
  `echo -e "\033[35m 1)  安装mysql\033[0m"`
  `echo -e "\033[35m 2)  安装JAVA \033[0m"`
  `echo -e "\033[35m 3)  安装ActiveMQ\033[0m"`
  `echo -e "\033[35m 4)  安装eslasticsearch\033[0m"`
  `echo -e "\033[35m 5)  kylo主页菜单 \033[0m"`
  `echo -e "\033[35m 6)  安装nifi\033[0m"`
  `echo -e "\033[35m 7)  清除日志文件\033[0m"`
  `echo -e "\033[35m 8)  更新kylo数据库\033[0m"`
  `echo -e "\033[35m 9)  安装jce_policy\033[0m"`
  `echo -e "\033[35m 10) 停止kylo 、 nifi 、删除nifi[可选].......\033[0m"`

  `echo -e "\033[35m q) 退出\033[0m"`
  `echo ""`
  `echo ""`
  `echo ""`
EOF

  cd $old_pwd

  read -p "请选择功能：" num2
  case $num2 in
      1)

        echo "安装mysql"
        install_mysql_opt
        echo ""
        mainMenu

        ;; 
      2)
        echo ""
        cd java
        install_JDK
        echo ""
        mainMenu
        ;;
      3)
        echo ""
        cd activemq
        install_activemq_opt
        echo ""
        echo "安装 ActimeMQ完成 !!"
        mainMenu

        ;;
      4)


        echo ""
        cd elasticsearch
        install_elasticsearch_opt
        echo "安装 elasticsearch 完成"
        mainMenu
        ;;
      5)
        echo ""
        cd kylo
        kyloMenu
        ;;
  
      6)
        cd nifi
        
        echo ""
        install_nifi_opt
        echo ""
        echo "安装 nifi 完成"
        mainMenu
        ;;
      7)

        echo ""
        rm -rf /var/log/nifi/*
        rm -rf  /var/log/kylo-services/*
        echo "清空日志完成"
        mainMenu
        ;;

      8)
        echo ""
        rebuild_kylo_db
        echo "kylo数据库更新完成"
        mainMenu
        ;;
      9)
        echo ""
        echo "开始安装jce_policy"
        install_jce_policy
        echo "jce_policy 安装完成"
        mainMenu
        ;;
      10)
        echo ""
        echo "关闭服务并删除日志"
        stop_kylo_nifi
        echo ""
        mainMenu
        ;;
      q)
        echo ""
        echo "bye!!"
        echo ""
        exit
        ;;

      *)
        echo ""
        echo "您的输入有误，请重新输入"
        mainMenu
        ;;
  esac
}

mainMenu
