﻿#!/bin/bash

PORT=8080
HOME_HAPROXY_WI=haproxy-wi

echo "Choose DB: (1)Sqlite or (2)Mysql? Default: Sqlite"
read DB
if [[ $DB == 2 ]];then
   echo "Mysql server is (1)remote  or (2)local?"
   read REMOTE
   if [[ $REMOTE == 1 ]];then
        echo "Enter IP remote Mysql server"
        read IP
   else
        MINSTALL=1
   fi
fi
echo "Choose Haproxy-WI port. Default: [$PORT]"
read CHPORT
echo "Enter Haproxy-wi home dir. Default: /var/www/[$HOME_HAPROXY_WI]"
read CHHOME_HAPROXY

if [[ -z $HAPROXY ]];then	
	HAPROXY="no"
fi

if [[ -n $CHPORT ]];then
        PORT=$CHPORT
fi
if [[ -n "$CHHOME_HAPROXY" ]];then
        HOME_HAPROXY_WI=$CHHOME_HAPROXY
fi


echo -e "Installing Required Software"

if [[ $MINSTALL == 1 ]];then
   yum -y install mariadb mariadb-server mysql-devel
fi

yum -y install epel-release && yum -y install git ncat net-tools lshw python34 python34-pip  httpd mod_ssl gcc python34-devel 

if [ $? -eq 1 ]
then
   echo "Unable to install Required Packages Please check Yum config"
   exit 1
fi

echo -e "Updating Apache config and Configuring Virtual Host"

if [[ $(cat /etc/httpd/conf/httpd.conf |grep "Listen 80") == "Listen 80" ]];then
   sed -i '0,/Listen 80/s//Listen 8080/' /etc/httpd/conf/httpd.conf
fi


echo -e "Checking for Apache Vhost config"

touch /etc/httpd/conf.d/haproxy-wi.conf
/bin/cat /etc/httpd/conf.d/haproxy-wi.conf

if [ $? -eq 1 ]
then
   echo "Didnt Sense exisitng installation Proceeding ...."

exit 1

else

echo -e "Creating VirtulHost for Apache"

cat << EOF > /etc/httpd/conf.d/haproxy-wi.conf
<VirtualHost *:$PORT>
        ServerName haprox-wi.example.com
        ErrorLog /var/log/httpd/haproxy-wi.error.log
        CustomLog /var/log/httpd/haproxy-wi.access.log combined

        DocumentRoot /var/www/$HOME_HAPROXY_WI
        ScriptAlias "/cgi-bin/ /var/www/"$HOME_HAPROXY_WI/cgi-bin/"


        <Directory $HOME_HAPROXY_WI>
                Options +ExecCGI
                AddHandler cgi-script .py
                Order deny,allow
                Allow from all
        </Directory>
</VirtualHost>
EOF

fi
echo -e " Testing config"

/usr/sbin/apachectl configtest 

if [ $? -eq 1 ]
then
   echo "apache Configuration Has failed, Please verify Apache Config"
   exit 1
fi

echo -e "Getting Latest software from The repository"

mkdir /var/www/$HOME_HAPROXY_WI
/usr/bin/git clone https://github.com/Aidaho12/haproxy-wi.git /var/www/$HOME_HAPROXY_WI

if [ $? -eq 1 ]
then
   echo "Unable to clone The repository Please check connetivity to Github"
   exit 1
fi

echo -e "Installing required Python Packages"

/usr/bin/pip3 install -r /var/www/$HOME_HAPROXY_WI/requirements.txt

if [ $? -eq 1 ]
then
   echo "Unable to install Required Packages, Please check Pip error log and Fix the errors and Rerun the script"
   exit 1
else 

   echo -e "Installation Succesful"

fi

if [[ $MINSTALL = 1 ]];then
  echo -e "starting databse and applying config"

  systemctl enable mariadb
  systemctl start mariadb

  if [ $? -eq 1 ]
  then
     echo "Can't start Mariadb"
     exit 1
  fi

  if [ $? -eq 1 ]
  then
     echo "Unable to start Mariadb Service Please check logs"
     exit 1
  else 

      mysql -u root -e "create database haproxywi";
      mysql -u root -e "grant all on haproxywi.* to 'haproxy-wi'@'%' IDENTIFIED BY 'haproxy-wi';"
      mysql -u root -e "grant all on haproxywi.* to 'haproxy-wi'@'localhost' IDENTIFIED BY 'haproxy-wi';"
      mysql -u root -e "flush privileges;"
 

  echo -e "Databse has been created Succesfully and User permissions added"

  fi
fi


if [[ $DB == 2 ]];then
  echo -e "Setting Application to use Mysql As a backend"

      sed -i '0,/enable = 0/s//enable = 1/' /var/www/$HOME_HAPROXY_WI/cgi-bin/haproxy-webintarface.config
fi
if [[ -n $IP ]];then
	sed -i "0,/mysql_host = 127.0.0.1/s//mysql_host = $IP/" /var/www/$HOME_HAPROXY_WI/cgi-bin/haproxy-webintarface.config
fi

echo -e " Starting Services"

          systemctl enable httpd ; systemctl restart httpd
          systemctl enable haproxy ; systemctl start haproxy


if [ $? -eq 1 ]
then
   echo "Services Has Not  been started, Please check error logs"

  else 

     echo -e "Services have been started, Please Evaluate the tool by adding a host / DNS ectry for  /etc/hosts file. \n This can be done by adding an entry like this \n 192.168.1.100 haprox-wi.example.com"

fi 

 sed -i "s|^fullpath = .*|fullpath = /var/www/$HOME_HAPROXY_WI|g" /var/www/$HOME_HAPROXY_WI/cgi-bin/haproxy-webintarface.config

echo -e " Thank You for Evaluating Haproxy-wi"

echo "Edit firewalld"
firewall-cmd --zone=public --add-port=$PORT/tcp --permanent
firewall-cmd --reload

chmod +x /var/www/$HOME_HAPROXY_WI/cgi-bin/*.py
chown -R apache:apache /var/www/$HOME_HAPROXY_WI/

setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 

exit 0