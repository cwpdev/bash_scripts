#!/bin/bash
########################################################################
# Use of code or any part of it is strictly prohibited. File protected by copyright law and provided under license.
# To Use any part of this code you need to get a writen approval from the code owner: info@centos-webpanel.com
########################################################################
#
#
clear
echo "#################################################################"
echo "#             CentOS Web Panel (CWP)   Installer                #"
echo "#################################################################"
echo ""
echo "visit www.centos-webpanel.com"
echo ""

if [ ! -e "/etc/redhat-release" ]; then
echo "You need to have CentOS, RedHat or CloudLinux system!"
exit 0
fi

CHKDATE=`date +%Y`
if [ "$CHKDATE" -le "2014" ];then
        echo "You have incorrect date set on your server!"
        echo `date`
        exit 0
fi

type mysql && MYSQLCHK="on" || MYSQLCHK="off"


# MySQL checker
if [ "$MYSQLCHK" = "on" ]; then
	#check pwd if works
	while [ "$check" != "Database" ]
	do
		echo "Enter MySQL root Password: "
		read -p "MySQL root password []:" password
		check=`mysql -u root -p$password -e "show databases;" -B|head -n1`
		if [ "$check" = "Database" ]; then
			echo "Password OK!!"
		else
			echo "MySQL root passwordis invalid!!!"
			echo "You can remove MySQL server using command: yum remove mysql"
			echo "after mysql is removed run installer again."
			echo ""
			echo "if exists you can check your mysql password in file: /root/.my.cnf"
			echo ""
			if [ -e "/root/.my.cnf" ]; then
				echo ""
				cat /root/.my.cnf
				echo ""
			fi
		fi
	done
	
	
else
	password=$(</dev/urandom tr -dc A-Za-z0-9 | head -c12)
fi


service httpd stop
service mysql stop
yum -y install wget chkconfig

# Check if version el5
centosversion=`rpm -qa \*-release | grep -Ei "oracle|redhat|centos|cloudlinux" | cut -d"-" -f3`

if [ $centosversion -eq "5" ]; then
echo 
echo "#######################################"
echo "# el5 version detected"
echo "#######################################"
echo
echo
echo "We recommend you to use CentOS 6 servers for full functionality!"
echo "Press ENTER to continue with CentOS 5 installation"
read CENTOS5CONFIRM
fi

if [ $centosversion -eq "6" ]; then
echo 
echo "#######################################"
echo "# el6 version detected"
echo "#######################################"
echo
fi

# Check /tmp
if [[ `cat /etc/fstab | grep -E 'tmp.*noexec'` != "" ]]; then mount -o remount,exec /tmp >/dev/null 2>&1 ; fi

#Umask Fix
sed -ie "s/umask\=002/umask=022/g" /etc/bashrc >/dev/null 2>&1

# Install RPMforge repo
cd /tmp
rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt
wget -q http://dl1.centos-webpanel.com/files/repos/rpmforge-release-0.5.3-1.el$centosversion.rf.$(uname -m).rpm
rpm -i rpmforge-release-0.5.3-1.el*.rpm
rm -f rpmforge-release-0.5.3-1.el*

#Install dependecies
yum -y install bzip2-devel gcc libxml2-devel openssl-devel pcre-devel sqlite-devel curl-devel libc-client-devel libmcrypt-devel libxslt-devel libpng-devel automake autoconf gcc-c++ freetype-devel libjpeg-devel
yum -y install make rsync mysql-server at mysql-devel bzip2-devel zip git pure-ftpd unzip cronie perl-libwww-perl
yum -y remove apr

yum -y install rsync cpulimit nano links bzip2-devel
yum -y install postfix dovecot dovecot-mysql
yum -y install bind bind-utils bind-libs

pubip=`curl -s http://centos-webpanel.com/webpanel/main.php?app=showip`
fqdn=`/bin/hostname`
echo ""
echo "PREPARING THE SERVER"
echo "##########################"

if [ -e "/etc/selinux/config" ]; then
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
fi

if [ -e "/etc/init.d/sendmail" ]
then
chkconfig --levels 235 sendmail off
/etc/init.d/sendmail stop
fi
 
service iptables save
service iptables stop

## PACKAGE INSTALLER
#yum -y install make zip unzip git ld-linux.so.2 libbz2.so.1 libdb-4.7.so libgd.so.2 vsftpd

echo
echo "#############################################"
echo "Please wait... installing web server files..."
echo "#############################################"
echo



#FTPD configuration
if [ ! -e "/etc/pure-ftpd/pure-ftpd.conf" ]
then
echo "Installation FAILED at pure-ftpd"
yum -y install pure-ftpd
touch /etc/pure-ftpd/pure-ftpd.passwd
pure-pw mkdb /etc/pure-ftpd/pureftpd.pdb -f /etc/pure-ftpd/pure-ftpd.passwd -m
fi

#FTPD configuration
if [ ! -e "/etc/pure-ftpd/pure-ftpd.conf" ]
then
echo "Installation FAILED at pure-ftpd"
exit 0
fi

#echo "chroot_local_user=YES" >> /etc/vsftpd/vsftpd.conf
#sed -i "s|anonymous_enable=YES|anonymous_enable=NO|" /etc/vsftpd/vsftpd.conf
#sed -i "s|userlist_enable=YES|userlist_enable=NO|" /etc/vsftpd/vsftpd.conf
sed -i 's|.*pureftpd.pdb.*|PureDB /etc/pure-ftpd/pureftpd.pdb|g' /etc/pure-ftpd/pure-ftpd.conf


## APACHE INSTALLER ##
mkdir -p /usr/local/src
cd /usr/local/src
wget -q http://dl1.centos-webpanel.com/files/c_scripts/apache-2.2.27-cwp.sh
wget -q http://dl1.centos-webpanel.com/files/c_scripts/php-5.4-cwp.sh
wget -q http://dl1.centos-webpanel.com/files/c_scripts/apache-2.2.27.sh
wget -q http://dl1.centos-webpanel.com/files/c_scripts/php-5.4.sh


sh /usr/local/src/apache-2.2.27.sh
if [ ! -e "/usr/local/apache/bin/httpd" ]
then
echo
echo "Compiler requires 512 MB RAM + SWAP"
echo "Installation FAILED at httpd"
echo "Installation FAILED at httpd" > /tmp/cwp.log
curl http://dl1.centos-webpanel.com/files/s_scripts/sinfo.sh|sh 2>&1 >> /tmp/cwp.log
curl -F"operation=upload" -F"file=@/tmp/cwp.log" http://dl1.centos-webpanel.com/post/post.php
exit 0
fi
rm -f /usr/local/src/apache-2.2.27.sh

sh /usr/local/src/php-5.4.sh
if [ ! -e "/usr/local/bin/php" ]
then
echo
echo "Compiler requires 512 MB RAM + SWAP"
echo "Installation FAILED at php"
echo "Installation FAILED at php" > /tmp/cwp.log
curl http://dl1.centos-webpanel.com/files/s_scripts/sinfo.sh|sh 2>&1 >> /tmp/cwp.log
curl -F"operation=upload" -F"file=@/tmp/cwp.log" http://dl1.centos-webpanel.com/post/post.php
exit 0
fi
rm -f /usr/local/src/php-5.4.sh

if [ -e "/usr/local/bin/php-config" ]
then
CHKEXTENSIONTDIR=`/usr/local/bin/php-config --extension-dir`;grep ^extension_dir /usr/local/php/php.ini || echo "extension_dir='$CHKEXTENSIONTDIR'" >> /usr/local/php/php.ini
fi

sh /usr/local/src/apache-2.2.27-cwp.sh
if [ ! -e "/usr/local/cwpsrv/bin/cwpsrvd" ]
then
echo
echo "Compiler requires 512 MB RAM + SWAP"
echo "Installation FAILED at cwpsrvd"
echo "Installation FAILED at cwpsrvd" > /tmp/cwp.log
curl http://dl1.centos-webpanel.com/files/s_scripts/sinfo.sh|sh 2>&1 >> /tmp/cwp.log
curl -F"operation=upload" -F"file=@/tmp/cwp.log" http://dl1.centos-webpanel.com/post/post.php
exit 0
fi
rm -f /usr/local/src/apache-2.2.27-cwp.sh

sh /usr/local/src/php-5.4-cwp.sh
if [ ! -e "/usr/local/cwp/php54/bin/php" ]
then
echo
echo "Compiler requires 512 MB RAM + SWAP"
echo "Installation FAILED at cwp php"
echo "Installation FAILED at cwp php" > /tmp/cwp.log
curl http://dl1.centos-webpanel.com/files/s_scripts/sinfo.sh|sh 2>&1 >> /tmp/cwp.log
curl -F"operation=upload" -F"file=@/tmp/cwp.log" http://dl1.centos-webpanel.com/post/post.php
exit 0
fi
rm -f /usr/local/src/php-5.4-cwp.sh


cat > /usr/local/cwpsrv/conf.d/server.conf <<EOF
#Timeout 300
TraceEnable Off
ServerSignature Off
ServerTokens ProductOnly
FileETag None
StartServers 1
<IfModule prefork.c>
MinSpareServers 1
MaxSpareServers 2
</IfModule>
<IfModule itk.c>
MinSpareServers 1
MaxSpareServers 2
</IfModule>
ServerLimit 35
MaxClients 25
MaxRequestsPerChild 10000
#KeepAlive Off
#KeepAliveTimeout 5
#MaxKeepAliveRequests 100
EOF


### ionCube Installer
########################
PHPVER=`/usr/local/bin/php -v| awk '{ print $2 }'|head -n 1|cut -c 1-3`
echo "zend_extension = /usr/local/ioncube/ioncube_loader_lin_$PHPVER.so" >> /usr/local/php/php.ini


# CONFIGURE MYSQL 
###################

cd /usr/local/src
echo "## CONFIGURE MYSQL"
echo "###################"
chkconfig --levels 235 mysqld on
sed -i "s|old_passwords=1|#old_passwords=1|" /etc/my.cnf
service mysqld start
mysqladmin -u root password $password
mysql -u root -p$password -e "DROP DATABASE test";
mysql -u root -p$password -e "DELETE FROM mysql.user WHERE User='root' AND Host!='localhost'";
mysql -u root -p$password -e "DELETE FROM mysql.user WHERE User=''";
mysql -u root -p$password -e "FLUSH PRIVILEGES";

cat > /root/.my.cnf <<EOF
[client]
password=$password
user=root
EOF
chmod 600 /root/.my.cnf


# CONFIGURE APACHE
####################
touch /usr/local/apache/conf.d/vhosts.conf
sed -i "s|#Include conf/extra/httpd-userdir.conf|Include conf/extra/httpd-userdir.conf|" /usr/local/apache/conf/httpd.conf


# Apache Server Status 
cat > /usr/local/apache/conf.d/server-status.conf <<EOF
<Location /server-status>
    SetHandler server-status
    Order deny,allow
    Allow from localhost
</Location>
EOF


# Set PHP Config
#sed -i "s|;date.timezone =|date.timezone = $tz|" /etc/php.ini 
#sed -i "s|extension=module.so|extension=mcrypt.so|" /etc/php.d/mcrypt.ini 

echo "127.0.0.1 "$fqdn >> /etc/hosts
chkconfig --levels 235 httpd on
service httpd restart

   
# named configuration


# Mail Server Config
sed -i "s|inet_interfaces = localhost|inet_interfaces = all|" /etc/postfix/main.cf
sed -i "s|mydestination = $myhostname, localhost.$mydomain, localhost|mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain, $domain|" /etc/postfix/main.cf
sed -i "s|#home_mailbox = Maildir/|home_mailbox = Maildir/|" /etc/postfix/main.cf

#install csf firewall
cd /tmp
rm -fv csf.tgz
wget -q http://www.configserver.com/free/csf.tgz
tar -xzf csf.tgz
cd csf
sh install.sh
sed -i "s|465,587,993,995|465,587,993,995,2030,2031|" /etc/csf/csf.conf
sed -i "s|80,110,113,443|80,110,113,443,2030,2031|" /etc/csf/csf.conf
sed -i 's|TESTING = "1"|TESTING = "0"|' /etc/csf/csf.conf
echo "# Run external commands before csf configures iptables" >> /usr/local/csf/bin/csfpre.sh
echo "# Run external commands after csf configures iptables" >> /usr/local/csf/bin/csfpost.sh
csf -x

cat >> /etc/csf/csf.pignore <<EOF
# CWP CUSTOM
exe:/usr/sbin/clamd
exe:/usr/sbin/opendkim
exe:/usr/libexec/mysqld
exe:/usr/libexec/dovecot/anvil
exe:/usr/libexec/dovecot/auth
exe:/usr/libexec/dovecot/imap-login
exe:/usr/libexec/dovecot/dict
exe:/usr/libexec/dovecot/pop3-login

exe:/usr/libexec/postfix/tlsmgr
exe:/usr/libexec/postfix/qmgr
exe:/usr/libexec/postfix/pickup
exe:/usr/libexec/postfix/smtpd
exe:/usr/libexec/postfix/anvil
exe:/usr/libexec/postfix/cleanup
exe:/usr/libexec/postfix/proxymap
exe:/usr/libexec/postfix/trivial-rewrite
exe:/usr/libexec/postfix/loca
exe:/usr/libexec/postfix/pipe
exe:/usr/libexec/postfix/spawn

exe:/usr/bin/perl
user:amavis
cmd:/usr/sbin/amavisd
EOF

# CWP BruteForce Protection
sed -i "s|CUSTOM1_LOG.*|CUSTOM1_LOG = \"/var/log/cwp_client_login.log\"|g" /etc/csf/csf.conf
cat > /usr/local/csf/bin/regex.custom.pm <<EOF
#!/usr/bin/perl
sub custom_line {
        my \$line = shift;
        my \$lgfile = shift;
# Do not edit before this point
if ((\$globlogs{CUSTOM1_LOG}{\$lgfile}) and (\$line =~ /^\S+\s+\S+\s+(\S+)\s+Failed Login from:\s+(\S+) on: (\S+)/)) {
               return ("Failed CWP-Login login for User: \$1 from IP: \$2 URL: \$3",\$2,"cwplogin","5","2030,2031","1");
}
# Do not edit beyond this point
        return 0;
}
1;
EOF

#Dovecot bug fix
touch /var/log/dovecot-debug.log
touch /var/log/dovecot-info.log
touch /var/log/dovecot.log
chmod 600 /var/log/dovecot-debug.log
chmod 600 /var/log/dovecot-info.log
chmod 600 /var/log/dovecot.log


# WebPanel Install
cd /usr/local/cwpsrv/htdocs
wget -q dl1.centos-webpanel.com/files/cwp/cwp_test_093.zip
unzip -o cwp_test_093.zip
rm -f cwp_test.zip
cd /usr/local/cwpsrv/htdocs/resources/admin/include
wget -q http://dl1.centos-webpanel.com/files/cwp/sql/db_conn.txt
mv db_conn.txt db_conn.php
cd /usr/local/cwpsrv/htdocs/resources/admin/modules
wget -q http://dl1.centos-webpanel.com/files/cwp/modules/example.txt
mv example.txt example.php


# phpMyAdmin Installer
cd /usr/local/apache/htdocs/
wget -q http://dl1.centos-webpanel.com/files/mysql/phpMyAdmin.zip
unzip -o phpMyAdmin.zip
rm -f phpMyAdmin.zip

# webFTP Installer
cd /usr/local/apache/htdocs/
wget -q dl1.centos-webpanel.com/files/cwp/addons/webftp_simple.zip
unzip -o webftp_simple.zip
rm -f webftp_simple.zip


# Default website setup
cp /usr/local/cwpsrv/htdocs/resources/admin/tpl/new_account_tpl/* /usr/local/apache/htdocs/.


# WebPanel Settings
mv /usr/local/apache/htdocs/phpMyAdmin/config.sample.inc.php /usr/local/apache/htdocs/phpMyAdmin/config.inc.php
ran_password=$(</dev/urandom tr -dc A-Za-z0-9 | head -c12)
sed -i "s|\['blowfish_secret'\] = ''|\['blowfish_secret'\] = '${ran_password}'|" /usr/local/apache/htdocs/phpMyAdmin/config.inc.php
ran_password2=$(</dev/urandom tr -dc A-Za-z0-9 | head -c12)
sed -i "s|\$crypt_pwd = ''|\$crypt_pwd = '${ran_password2}'|" /usr/local/cwpsrv/htdocs/resources/admin/include/db_conn.php
sed -i "s|\$db_pass = ''|\$db_pass = '$password'|" /usr/local/cwpsrv/htdocs/resources/admin/include/db_conn.php
chmod 600 /usr/local/cwpsrv/htdocs/resources/admin/include/db_conn.php
chmod 777 /var/lib/php/session/

# PHP Short tags fix
sed -i "s|short_open_tag = Off|short_open_tag = On|" /usr/local/cwp/php54/php.ini
sed -i "s|short_open_tag = Off|short_open_tag = On|" /usr/local/php/php.ini

# Setup Cron
cat > /etc/cron.daily/cwp <<EOF
/usr/local/cwp/php54/bin/php -d max_execution_time=1000000 -q /usr/local/cwpsrv/htdocs/resources/admin/include/cron.php
/usr/local/cwp/php54/bin/php -d max_execution_time=1000000 -q /usr/local/cwpsrv/htdocs/resources/admin/include/cron_backup.php
EOF
chmod +x /etc/cron.daily/cwp

# MySQL Database import
curl 'http://dl1.centos-webpanel.com/files/cwp/sql/root_cwp.sql'|mysql -uroot -p$password

mysql -u root -p$password << EOF
use root_cwp;
UPDATE settings SET shared_ip="$pubip";
EOF


# Disable named for antiDDoS security
chkconfig named on

# DNS Setup
if [ $centosversion -eq "5" ]; then
	ln -s /etc/named.rfc1912.zones /etc/named.conf
fi
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
sed -i "s|127.0.0.1|any|" /etc/named.conf
sed -i "s|localhost|any|" /etc/named.conf
sed -i 's/recursion yes/recursion no/g' /etc/named.conf

# MAIL SERVER INSTALLER

# clean yum
yum clean all


######## Replace and read from root foder
#if [ ! -e "/usr/local/cwpsrv/htdocs/mysql.txt" ]
#then
#echo "\"$password\"" > /etc/webpanel/mysql.txt
#fi

##########################################################
# MAIL SERVER
##########################################################


# check MySQL root password
mysql_root_password=$password
if [ -z "${mysql_root_password}" ]; then
  read -p "MySQL root password []:" mysql_root_password
fi

clear
echo "#########################################################"
echo "          CentOS Web Panel MailServer Installer          "
echo "#########################################################"
echo
echo "visit for help: www.centos-webpanel.com"
echo 

check=`mysql -u root -p$mysql_root_password -e "show databases;" -B|head -n1`
if [ "$check" = "Database" ]; then
    echo "Password OK!!"
else
	echo "MySQL root password is invalid!!!"
	echo "Check password and run this script again."
	exit 0

fi

## Needed to add password in root folder
mysql -u root -p$mysql_root_password -e "UPDATE mysql.user SET Password = PASSWORD('$mysql_root_password') WHERE user = 'root';"
mysql -u root -p$mysql_root_password -e "FLUSH PRIVILEGES;"

# password generator
postfix_pwd=$(</dev/urandom tr -dc A-Za-z0-9 | head -c12)
cnf_hostname=`/bin/hostname`

# create database and user
mysql -u root -p$mysql_root_password -e "CREATE DATABASE postfix;"
mysql -u root -p$mysql_root_password -e "CREATE USER postfix@localhost IDENTIFIED BY '$postfix_pwd';"
mysql -u root -p$mysql_root_password -e "GRANT ALL PRIVILEGES ON postfix . * TO postfix@localhost;" 

# MySQL Database import
curl 'http://centos-webpanel.com/webpanel/main.php?dl=postfix.sql'|mysql -uroot -p$mysql_root_password -h localhost postfix

yum -y remove sendmail exim
yum -y install postfix dovecot dovecot-mysql dovecot-pigeonhole cyrus-sasl-devel cyrus-sasl-sql subversion
yum -y install perl-MailTools perl-MIME-EncWords perl-MIME-Charset perl-Email-Valid perl-Test-Pod perl-TimeDate 
yum -y install perl-Mail-Sender perl-Log-Log4perl imapsync offlineimap
yum -y install perl-Razor-Agent perl-Convert-BinHex crypto-utils
yum -y install amavisd-new clamav clamd --disablerepo=rpmforge-webpanel

# GET MAIL configs
cd /
wget -q http://dl1.centos-webpanel.com/files/mail/mail_server.zip
unzip -o /mail_server.zip
rm -f /mail_server.zip

#User add
mkdir /var/vmail
chmod 770 /var/vmail
useradd -r -u 101 -g mail -d /var/vmail -s /sbin/nologin -c "Virtual mailbox" vmail
chown vmail:mail /var/vmail 

touch /etc/postfix/virtual_regexp

#vacation
useradd -r -d /var/spool/vacation -s /sbin/nologin -c "Virtual vacation" vacation
mkdir /var/spool/vacation
chmod 770 /var/spool/vacation 
cd /var/spool/vacation/
#ln -s /etc/postfix/vacation.pl /var/spool/vacation/vacation.pl
ln -s /etc/postfix/vacation.php /var/spool/vacation/vacation.php
chmod +x /etc/postfix/vacation.php

echo "autoreply.$cnf_hostname vacation:" > /etc/postfix/transport
postmap /etc/postfix/transport
chown -R vacation:vacation /var/spool/vacation
echo "127.0.0.1 autoreply.$cnf_hostname" >> /etc/hosts

#sieve
mkdir -p /var/sieve/
cat > /var/sieve/globalfilter.sieve <<EOF
require "fileinto";
if exists "X-Spam-Flag" {
if header :contains "X-Spam-Flag" "NO" {
} else {
fileinto "Spam";
stop;
}
}
if header :contains "subject" ["***SPAM***"] {
fileinto "Spam";
stop;
}
EOF
chown -R vmail:mail /var/sieve


#razor-admin -register -user=some_user -pass=somepas
freshclam
service clamd restart

##### SSL Certifikat START #####
# SSL Self signed certificate
cd /root
DOMAIN="$cnf_hostname"
if [ -z "$DOMAIN" ]; then
echo "Usage: $(basename $0) <domain>"
exit 11
fi
 
fail_if_error() {
[ $1 != 0 ] && {
unset PASSPHRASE
exit 10
}
}
 
# Generate a passphrase
export PASSPHRASE=$(head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128; echo)
 
# Certificate details; replace items in angle brackets with your own info
subj="
C=HR
ST=Zagreb
O=CentOS Web Panel
localityName=HR
commonName=$DOMAIN
organizationalUnitName=CentOS Web Panel
emailAddress=info@studio4host.com
"
 
# Generate the server private key
openssl genrsa -des3 -out $DOMAIN.key -passout env:PASSPHRASE 2048
fail_if_error $?
 
# Generate the CSR
openssl req \
-new \
-batch \
-subj "$(echo -n "$subj" | tr "\n" "/")" \
-key $DOMAIN.key \
-out $DOMAIN.csr \
-passin env:PASSPHRASE
fail_if_error $?
cp $DOMAIN.key $DOMAIN.key.org
fail_if_error $?
 
# Strip the password so we don't have to type it every time we restart Apache
openssl rsa -in $DOMAIN.key.org -out $DOMAIN.key -passin env:PASSPHRASE
fail_if_error $?
 
# Generate the cert (good for 10 years)
openssl x509 -req -days 3650 -in $DOMAIN.csr -signkey $DOMAIN.key -out $DOMAIN.crt
fail_if_error $?

mv /root/$cnf_hostname.key /etc/pki/tls/private/.
mv /root/$cnf_hostname.crt /etc/pki/tls/certs/.
echo " " > /etc/pki/tls/certs/$cnf_hostname.bundle
##### END SSL Certifikat START #####

# /etc/postfix/main.cf
sed -i "s|MY_HOSTNAME|$cnf_hostname|" /etc/postfix/main.cf
sed -i "s|MY_DOMAIN|$cnf_hostname|" /etc/postfix/main.cf
sed -i "s|MY_DOMAIN|$cnf_hostname|" /etc/postfix/main.cf

# MySQL PWD Fix for postfix
sed -i "s|MYSQL_PASSWORD|$postfix_pwd|" /etc/postfix/mysql-relay_domains_maps.cf
sed -i "s|MYSQL_PASSWORD|$postfix_pwd|" /etc/postfix/mysql-virtual_alias_maps.cf
sed -i "s|MYSQL_PASSWORD|$postfix_pwd|" /etc/postfix/mysql-virtual_domains_maps.cf
sed -i "s|MYSQL_PASSWORD|$postfix_pwd|" /etc/postfix/mysql-virtual_mailbox_limit_maps.cf
sed -i "s|MYSQL_PASSWORD|$postfix_pwd|" /etc/postfix/mysql-virtual_mailbox_maps.cf

# Postfix Web panel SQL setup
if [ ! -e "/usr/local/cwpsrv/htdocs/resources/admin/include/postfix.php" ]
then
cd /usr/local/cwpsrv/htdocs/resources/admin/include
wget -q http://centos-webpanel.com/webpanel/main.php?dl=postfix.txt
mv main.php?dl=postfix.txt postfix.php
fi
sed -i "s|\$db_pass_postfix = ''|\$db_pass_postfix = '$postfix_pwd'|" /usr/local/cwpsrv/htdocs/resources/admin/include/postfix.php
chmod 600 /usr/local/cwpsrv/htdocs/resources/admin/include/postfix.php

# Vacation fix
sed -i "s|MYSQL_PASSWORD|$postfix_pwd|" /etc/postfix/vacation.conf
sed -i "s|AUTO_REPLAY|autoreply.$cnf_hostname|" /etc/postfix/vacation.conf

# DOVECOT fix
sed -i "s|MYSQL_PASSWORD|$postfix_pwd|" /etc/dovecot/dovecot-dict-quota.conf
sed -i "s|MYSQL_PASSWORD|$postfix_pwd|" /etc/dovecot/dovecot-mysql.conf
sed -i "s|MY_DOMAIN|$cnf_hostname|" /etc/dovecot/dovecot.conf
sed -i "s|MY_DOMAIN|$cnf_hostname|" /etc/dovecot/dovecot.conf


##### ROUNDCUBE INSTALLER #####
if [ -z "${mysql_roundcube_password}" ]; then
  tmp=$(</dev/urandom tr -dc A-Za-z0-9 | head -c12)
  mysql_roundcube_password=${mysql_roundcube_password:-${tmp}}
  echo "MySQL roundcube: ${mysql_roundcube_password}" >> .passwords
fi

if [ -z "${mysql_root_password}" ]; then
  read -p "MySQL root password []:" mysql_root_password
fi

wget -P /usr/local/apache/htdocs http://dl1.centos-webpanel.com/files/mail/roundcubemail-0.8.5.tar.gz
tar -C /usr/local/apache/htdocs -zxvf /usr/local/apache/htdocs/roundcubemail-*.tar.gz
rm -f /usr/local/apache/htdocs/roundcubemail-*.tar.gz 
mv /usr/local/apache/htdocs/roundcubemail-* /usr/local/apache/htdocs/roundcube 
chown nobody:nobody -R /usr/local/apache/htdocs/roundcube 
chmod 777 -R /usr/local/apache/htdocs/roundcube/temp/ 
chmod 777 -R /usr/local/apache/htdocs/roundcube/logs/

# /usr/local/apache/conf.d/20-roundcube.conf ROUNDCUBE CONFIG FOR APACHE

sed -e "s|mypassword|${mysql_roundcube_password}|" <<'EOF' | mysql -u root -p"${mysql_root_password}"
USE mysql;
CREATE USER 'roundcube'@'localhost' IDENTIFIED BY 'mypassword';
GRANT USAGE ON * . * TO 'roundcube'@'localhost' IDENTIFIED BY 'mypassword';
CREATE DATABASE IF NOT EXISTS `roundcube`;
GRANT ALL PRIVILEGES ON `roundcube` . * TO 'roundcube'@'localhost';
FLUSH PRIVILEGES;
EOF

mysql -u root -p"${mysql_root_password}" 'roundcube' < /usr/local/apache/htdocs/roundcube/SQL/mysql.initial.sql

cp /usr/local/apache/htdocs/roundcube/config/main.inc.php.dist /usr/local/apache/htdocs/roundcube/config/main.inc.php

sed -i "s|^\(\$rcmail_config\['default_host'\] =\).*$|\1 \'localhost\';|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['smtp_server'\] =\).*$|\1 \'localhost\';|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['smtp_user'\] =\).*$|\1 \'%u\';|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['smtp_pass'\] =\).*$|\1 \'%p\';|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
#sed -i "s|^\(\$rcmail_config\['support_url'\] =\).*$|\1 \'mailto:${E}\';|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['quota_zero_as_unlimited'\] =\).*$|\1 true;|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['preview_pane'\] =\).*$|\1 true;|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['read_when_deleted'\] =\).*$|\1 false;|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['check_all_folders'\] =\).*$|\1 true;|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['display_next'\] =\).*$|\1 true;|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['top_posting'\] =\).*$|\1 true;|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['sig_above'\] =\).*$|\1 true;|" /usr/local/apache/htdocs/roundcube/config/main.inc.php
sed -i "s|^\(\$rcmail_config\['login_lc'\] =\).*$|\1 2;|" /usr/local/apache/htdocs/roundcube/config/main.inc.php

cp /usr/local/apache/htdocs/roundcube/config/db.inc.php.dist /usr/local/apache/htdocs/roundcube/config/db.inc.php

sed -i "s|^\(\$rcmail_config\['db_dsnw'\] =\).*$|\1 \'mysqli://roundcube:${mysql_roundcube_password}@localhost/roundcube\';|" /usr/local/apache/htdocs/roundcube/config/db.inc.php
rm -rf /usr/local/apache/htdocs/roundcube/installer
chown -R nobody:nobody /usr/local/apache/htdocs/roundcube
#mv /usr/local/apache/htdocs/roundcube /usr/local/cwpsrv/htdocs/admin/lib/.


# Setup Login Screen
[[ $(grep "bash_cwp" /root/.bash_profile) == "" ]] && echo "sh /root/.bash_cwp" >>  /root/.bash_profile

cat > /root/.bash_cwp <<EOF
echo ""
echo "********************************************"
echo "Welcome to CWP (CentOS WebPanel) server"
echo "Restart CWP using: service cwpsrv restart"
echo "********************************************"
echo ""
echo "if you can not access CWP try this command: service iptables stop"
echo ""
w
echo ""
df -h
echo ""
EOF


# FIX /etc/init.d links
yum -y remove httpd
cd /etc/init.d/
rm -f /etc/init.d/httpd
wget -q http://dl1.centos-webpanel.com/files/s_scripts/httpd
chmod +x /etc/init.d/httpd

cd /etc/init.d/
rm -f /etc/init.d/cwpsrv
wget -q http://dl1.centos-webpanel.com/files/s_scripts/cwpsrv
chmod +x /etc/init.d/cwpsrv

if [ ! -e "/scripts" ]
then
	cd /;ln -s /usr/local/cwpsrv/htdocs/resources/scripts /scripts
fi


# Chkconfig
# iptables -F
chkconfig iptables off
chkconfig httpd on
chkconfig cwpsrv on
chkconfig mysqld on
chkconfig pure-ftpd on
chkconfig postfix on
chkconfig dovecot on


# service restart
service httpd restart
service cwpsrvd restart

# Check /tmp
if [[ `cat /etc/fstab | grep -E 'tmp.*noexec'` != "" ]]; then mount -o remount /tmp >/dev/null 2>&1 ; fi

chown vmail.mail /var/log/dovecot*
chown -R nobody:nobody /usr/local/apache/htdocs/*
/usr/bin/chattr +i /usr/local/cwpsrv/htdocs/admin


clear
echo "#############################"
echo "#      CWP Installed        #"
echo "#############################"
echo ""
echo "go to CentOS WebPanel Admin GUI at http://SERVER_IP:2030/"
echo ""
echo "http://${pubip}:2030"
echo "SSL: https://${pubip}:2031"
echo -e "---------------------"
echo "Username: root"
echo "Password: ssh server root password"
echo "MySQL root Password: $password"
echo 
echo "#########################################################"
echo "          CentOS Web Panel MailServer Installer          "
echo "#########################################################"
#echo "Roundcube MySQL Password: ${mysql_roundcube_password}"
#echo "Postfix MySQL Password: ${postfix_pwd}"
echo "SSL Cert name (hostname): ${cnf_hostname}"
echo "SSL Cert file location /etc/pki/tls/ private|certs"
echo "#########################################################"
echo
echo "visit for help: www.centos-webpanel.com"
echo "Write down login details and press ENTER for server reboot!"
read -p "Press ENTER for server reboot!"
shutdown -r now


