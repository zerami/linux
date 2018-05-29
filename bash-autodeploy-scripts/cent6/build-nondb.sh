#!/bin/bash

if [ $(id -u) != "0" ]; then
    printf "Erorr: you are not a root user!\n"
    exit
fi


#define variable
pine_auto_version="1.0"
script_path="."

yum -y install gawk bc
cp $script_path/bin/calc /bin/calc && chmod +x /bin/calc

clear
printf "============================================================\n"
printf " We will check Server info to apply the best configuration  \n"
printf "============================================================\n"

cpuname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo )
cpucores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
cpufreq=$( awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo )
svram=$( free -m | awk 'NR==2 {print $2}' )
svhdd=$( df -h | awk 'NR==2 {print $2}' )
svswap=$( free -m | awk 'NR==4 {print $2}' )

if [ -f "/proc/user_beancounters" ]; then
svip=$(ifconfig venet0:0 | grep 'inet addr:' | awk -F'inet addr:' '{ print $2}' | awk '{ print $1}')
else
svip=$(ifconfig eth0 | grep 'inet addr:' | awk -F'inet addr:' '{ print $2}' | awk '{ print $1}')
fi


printf "=========================================================================\n"
printf "SERVER INFOMATION \n"
printf "=========================================================================\n"
echo "CPU : $cpuname"
echo "Number of CPU core : $cpucores"
echo "Core speed : $cpufreq MHz"
echo "RAM capacity: $svram MB"
echo "Swap : $svswap MB"
echo "Hard disk capacity : $svhdd GB"
echo "IP address : $svip"
printf "=========================================================================\n"
printf "=========================================================================\n"
sleep 3


clear
printf "=========================================================================\n"
printf " Installation preparing... \n"
printf "=========================================================================\n"

printf "Please choose version PHP for installation:\n"
prompt="Input your option [1-3]: "
options=("PHP 5.6" "PHP 5.5" "PHP 5.4")
PS3="$prompt"
select opt in "${options[@]}"; do 

    case "$REPLY" in
    1) php_version="5.6"; break;;
    2) php_version="5.5"; break;;
    3) php_version="5.4"; break;;
    $(( ${#options[@]}+1 )) ) printf "\nGoodbye....!\n"; break;;
    *) echo "invalid value...!";continue;;
    esac
    
done

printf "\nInput your Domain name and press [ENTER]: " 
read svdomain
if [ "$svdomain" = "" ]; then
	svdomain="dev-auto.pinetech.vn"
echo "Wrong input, Script will using default domain dev-auto.pinetech.vn"
fi

printf "\nInput port number for private_html and press [ENTER]: " 
read svport
if [ "$svport" = "" ] || [ "$svport" = "80" ] || [ "$svport" = "443" ] || [ "$svport" = "22" ] || [ "$svport" = "3306" ] || [ "$svport" = "25" ] || [ "$svport" = "465" ] || [ "$svport" = "587" ]; then
	svport="8888"
echo "PhpMyAdmin port invalid"
echo "Script will use port: 8888"
fi

printf "\nInput your email [ENTER]: " 
read umail
if [ "$umail" = "" ]; then
	umail="dangphong2404@gmail.com"
echo "Wrong input, Script will using default email dangphong2404@gmail.com"
fi

printf "=========================================================================\n"
printf "Preparing Finished ... \n"
printf "=========================================================================\n"


rm -f /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime

if [ -s /etc/selinux/config ]; then
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
fi

#Remi Repo
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/6/remi/x86_64/remi-release-6.8-1.el6.remi.noarch.rpm

#Nginx Repo
rpm -Uvh http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm

service sendmail stop
chkconfig sendmail off
service xinetd stop
chkconfig xinetd off
service saslauthd stop
chkconfig saslauthd off
service rsyslog stop
chkconfig rsyslog off
service postfix stop
chkconfig postfix off

yum -y remove mysql*
yum -y remove php*
yum -y remove httpd*
yum -y remove sendmail*
yum -y remove postfix*
yum -y remove rsyslog*

#yum -y update

clear
printf "=========================================================================\n"
printf "Installation's starting... \n"
printf "=========================================================================\n"
sleep 7

#Install Nginx, PHP-FPM and modules
if [ "$php_version" = "5.6" ]; then
	yum -y --enablerepo=remi,remi-php56 install nginx php-fpm php-devel pcre-devel php-common php-gd php-mysql php-pecl-mongo php-pecl-geoip php-pdo php-pecl-memcached php-pecl-redis php-pecl-memcache php-oauth php-xml php-mbstring php-mcrypt php-curl php-pecl-zendopcache unzip gcc make exim syslog-ng cronie nano wget rsync
elif [ "$php_version" = "5.5" ]; then
	yum -y --enablerepo=remi,remi-php55 install nginx php-fpm php-devel pcre-devel php-common php-gd php-mysql php-pecl-mongo php-pecl-geoip php-pdo php-pecl-memcached php-pecl-redis php-pecl-memcache php-oauth php-xml php-mbstring php-mcrypt php-curl php-pecl-zendopcache unzip gcc make exim syslog-ng cronie nano wget rsync
else
	yum -y --enablerepo=remi install nginx php-fpm php-common php-devel pcre-devel php-gd php-mysql php-pecl-mongo php-pecl-geoip php-pdo php-pecl-memcached php-pecl-redis php-pecl-memcache php-oauth php-xml php-mbstring php-mcrypt php-curl php-pecl-zendopcache unzip gcc make exim syslog-ng cronie nano wget rsync
fi

clear
printf "=========================================================================\n"
printf "Finished, start configuring... \n"
printf "=========================================================================\n"
sleep 3


ramforother=$(calc $svram/10*6)
ramforphpnginx=$(calc $svram-$ramforother)
max_children=$(calc $ramforphpnginx/30)
memory_limit=$(calc $ramforphpnginx/5*3)M
buff_size=$(calc $ramforother/10*8)M
log_size=$(calc $ramforother/10*2)M

mkdir /www
mkdir -p /www/$svdomain/public_html
mkdir /www/$svdomain/private_html
mkdir /www/$svdomain/logs
chmod 777 /www/$svdomain/logs


mkdir -p /var/log/nginx
chown -R nginx:nginx /var/log/nginx
chown -R nginx:nginx /var/lib/php/session

rm -f /etc/nginx/nginx.conf
    cat > "/etc/nginx/nginx.conf" <<END

user  nginx;
worker_processes  $cpucores;
worker_rlimit_nofile 65536;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
	worker_connections  2048;
}


http {
	include       /etc/nginx/mime.types;
	default_type  application/octet-stream;

	log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
	              '\$status \$body_bytes_sent "\$http_referer" '
	              '"\$http_user_agent" "\$http_x_forwarded_for"';

	access_log  off;
	sendfile on;
	tcp_nopush on;
	tcp_nodelay off;
	types_hash_max_size 2048;
	server_tokens off;
	server_names_hash_bucket_size 128;
	client_max_body_size 20m;
	client_body_buffer_size 256k;
	client_body_in_file_only off;
	client_body_timeout 60s;
	client_header_buffer_size 256k;
	client_header_timeout  20s;
	large_client_header_buffers 8 256k;
	keepalive_timeout 10;
	keepalive_disable msie6;
	reset_timedout_connection on;
	send_timeout 60s;
	gzip on;
	gzip_static on;
	gzip_disable "msie6";
	gzip_vary on;
	gzip_proxied any;
	gzip_comp_level 6;
	gzip_buffers 16 8k;
	gzip_http_version 1.1;
	gzip_types text/plain text/css application/json text/javascript application/javascript text/xml application/xml application/xml+rss;

	include /etc/nginx/conf.d/*.conf;
}
END

rm -rf /etc/nginx/conf.d
mkdir -p /etc/nginx/conf.d

svdomain_redirect="www.$svdomain"
if [[ $svdomain == *www* ]]; then
    svdomain_redirect=${svdomain/www./''}
fi

cat > "/usr/share/nginx/html/403.html" <<END
<html>
<head><title>403 Forbidden</title></head>
<body bgcolor="white">
<center><h1>403 Forbidden</h1></center>
<hr><center>pineauto-nginx</center>
</body>
</html>
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
END

cat > "/usr/share/nginx/html/404.html" <<END
<html>
<head><title>404 Not Found</title></head>
<body bgcolor="white">
<center><h1>404 Not Found</h1></center>
<hr><center>pineauto-nginx</center>
</body>
</html>
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
END

cat > "/etc/nginx/conf.d/$svdomain.conf" <<END
server {
	server_name $svdomain_redirect;
	rewrite ^(.*) http://$svdomain\$1 permanent;
    	}
server {
	listen   80 default_server;
	access_log off;
	error_log off;
    # error_log /www/$svdomain/logs/error.log;
    root /www/$svdomain/public_html;
	index index.php index.html index.htm;
    	server_name $svdomain;
 
    	location / {
		try_files \$uri \$uri/ /index.php?\$args;
	}
 
    	location ~ \.php$ {
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
        include /etc/nginx/fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        #fastcgi_pass   unix:/var/run/php-fpm.sock;
        fastcgi_index index.php;
		fastcgi_connect_timeout 60;
		fastcgi_send_timeout 180;
		fastcgi_read_timeout 180;
		fastcgi_buffer_size 256k;
		fastcgi_buffers 4 256k;
		fastcgi_busy_buffers_size 256k;
		fastcgi_temp_file_write_size 256k;
		fastcgi_intercept_errors on;
        	fastcgi_param SCRIPT_FILENAME /www/$svdomain/public_html\$fastcgi_script_name;
    	}
	location /php_status {
		fastcgi_pass 127.0.0.1:9000;
		#fastcgi_pass   unix:/var/run/php-fpm.sock;
		fastcgi_index index.php;
		fastcgi_param SCRIPT_FILENAME  /www/$svdomain/public_html\$fastcgi_script_name;
		include /etc/nginx/fastcgi_params;
    	}
	location ~ /\. {
		deny all;
	}
        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }
       location = /robots.txt {
              allow all;
              log_not_found off;
              access_log off;
       }
	location ~* \.(3gp|gif|jpg|jpeg|png|ico|wmv|avi|asf|asx|mpg|mpeg|mp4|pls|mp3|mid|wav|swf|flv|exe|zip|tar|rar|gz|tgz|bz2|uha|7z|doc|docx|xls|xlsx|pdf|iso|eot|svg|ttf|woff)$ {
	        gzip_static off;
		add_header Pragma public;
		add_header Cache-Control "public, must-revalidate, proxy-revalidate";
		access_log off;
		expires 30d;
		break;
        }

        location ~* \.(txt|js|css)$ {
	        add_header Pragma public;
		add_header Cache-Control "public, must-revalidate, proxy-revalidate";
		access_log off;
		expires 30d;
		break;
        }
	
        #error_page 403 /403.html;
        location = /403.html {
                root /usr/share/nginx/html;
                allow all;
        }
	
        #error_page 404 /404.html;
        location = /404.html {
                root /usr/share/nginx/html;
                allow all;
        }
		location /nginx_status {
			stub_status on;    # activate stub_status module
			access_log off;    
			allow 127.0.0.1;   # restrict access to local only
			deny all;
		}
    }

server {
	listen   $svport;
 	access_log        off;
	log_not_found     off;
 	error_log         off;
    	root /www/$svdomain/private_html;
	index index.php index.html index.htm;
    	server_name $svdomain;
 
     	location / {
		try_files \$uri \$uri/ /index.php;
	}
    	location ~ \.php$ {
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
        include /etc/nginx/fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        #fastcgi_pass   unix:/var/run/php-fpm.sock;
        fastcgi_index index.php;
		fastcgi_connect_timeout 60;
		fastcgi_send_timeout 180;
		fastcgi_read_timeout 180;
		fastcgi_buffer_size 256k;
		fastcgi_buffers 4 256k;
		fastcgi_busy_buffers_size 256k;
		fastcgi_temp_file_write_size 256k;
		fastcgi_intercept_errors on;
        	fastcgi_param SCRIPT_FILENAME /www/$svdomain/private_html\$fastcgi_script_name;
    	}
        location ~* \.(bak|back|bk)$ {
		deny all;
	}
}
END


rm -f /etc/php-fpm.d/www.conf
    cat > "/etc/php-fpm.d/www.conf" <<END
[www]
listen = 127.0.0.1:9000
;listen = /var/run/php-fpm.sock
listen.allowed_clients = 127.0.0.1
user = nginx
group = nginx
pm = dynamic
pm.max_children = $max_children
pm.start_servers = 3
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.max_requests = 500 
pm.status_path = /php_status
request_terminate_timeout = 120s
request_slowlog_timeout = 4s
slowlog = /www/$svdomain/logs/php-fpm-slow.log
rlimit_files = 131072
rlimit_core = unlimited
catch_workers_output = yes
env[HOSTNAME] = \$HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
php_admin_value[error_log] = /www/$svdomain/logs/php-fpm-error.log
php_admin_flag[log_errors] = on
php_value[session.save_handler] = files
php_value[session.save_path] = /var/lib/php/session
END

touch /www/$svdomain/logs/php-fpm-slow.log
touch /www/$svdomain/logs/php-fpm-error.log
chmod -R 777 /www/$svdomain/logs/php-fpm-slow.log
chmod -R 777 /www/$svdomain/logs/php-fpm-error.log

rm -f /etc/php.ini
    cat > "/etc/php.ini" <<END
[PHP]
engine = On
short_open_tag = Off
asp_tags = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = 17
disable_functions = escapeshellarg,escapeshellcmd,exec,ini_alter,parse_ini_file,passthru,pcntl_exec,proc_close,proc_get_status,proc_nice,proc_open,proc_terminate,show_source,shell_exec,symlink,system
disable_classes =
zend.enable_gc = On
expose_php = On
max_execution_time = 30
max_input_time = 60
memory_limit = $memory_limit
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = On
display_startup_errors = Off
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
track_errors = Off
html_errors = On
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 180M
auto_prepend_file =
auto_append_file =
default_mimetype = "text/html"
default_charset = "UTF-8"
doc_root =
user_dir =
enable_dl = Off
cgi.fix_pathinfo=0
file_uploads = On
upload_max_filesize = 200M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60
cli_server.color = On

[Date]
date.timezone = Asia/Bangkok

[filter]

[iconv]

[intl]

[sqlite]

[sqlite3]

[Pcre]

[Pdo]

[Pdo_mysql]
pdo_mysql.cache_size = 2000
pdo_mysql.default_socket=

[Phar]

[mail function]
SMTP = localhost
smtp_port = 25
sendmail_path = /usr/sbin/sendmail -t -i
mail.add_x_header = On

[SQL]
sql.safe_mode = Off

[ODBC]
odbc.allow_persistent = On
odbc.check_persistent = On
odbc.max_persistent = -1
odbc.max_links = -1
odbc.defaultlrl = 4096
odbc.defaultbinmode = 1

[Interbase]
ibase.allow_persistent = 1
ibase.max_persistent = -1
ibase.max_links = -1
ibase.timestampformat = "%Y-%m-%d %H:%M:%S"
ibase.dateformat = "%Y-%m-%d"
ibase.timeformat = "%H:%M:%S"

[MySQL]
mysql.allow_local_infile = On
mysql.allow_persistent = On
mysql.cache_size = 2000
mysql.max_persistent = -1
mysql.max_links = -1
mysql.default_port =
mysql.default_socket =
mysql.default_host =
mysql.default_user =
mysql.default_password =
mysql.connect_timeout = 60
mysql.trace_mode = Off

[MySQLi]
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.cache_size = 2000
mysqli.default_port = 3306
mysqli.default_socket =
mysqli.default_host =
mysqli.default_user =
mysqli.default_pw =
mysqli.reconnect = Off

[mysqlnd]
mysqlnd.collect_statistics = On
mysqlnd.collect_memory_statistics = Off

[OCI8]

[PostgreSQL]
pgsql.allow_persistent = On
pgsql.auto_reset_persistent = Off
pgsql.max_persistent = -1
pgsql.max_links = -1
pgsql.ignore_notice = 0
pgsql.log_notice = 0

[Sybase-CT]
sybct.allow_persistent = On
sybct.max_persistent = -1
sybct.max_links = -1
sybct.min_server_severity = 10
sybct.min_client_severity = 10

[bcmath]
bcmath.scale = 0

[browscap]

[Session]
session.save_handler = files
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain =
session.cookie_httponly =
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.bug_compat_42 = Off
session.bug_compat_warn = Off
session.referer_check =
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.hash_function = 0
session.hash_bits_per_character = 5
url_rewriter.tags = "a=href,area=href,frame=src,input=src,form=fakeentry"

[MSSQL]
mssql.allow_persistent = On
mssql.max_persistent = -1
mssql.max_links = -1
mssql.min_error_severity = 10
mssql.min_message_severity = 10
mssql.compatability_mode = Off

[Assertion]

[mbstring]

[gd]

[exif]

[Tidy]
tidy.clean_output = Off

[soap]
soap.wsdl_cache_enabled=1
soap.wsdl_cache_dir="/tmp"
soap.wsdl_cache_ttl=86400
soap.wsdl_cache_limit = 5

[sysvshm]

[ldap]
ldap.max_links = -1

[mcrypt]

[dba]

END

rm -f /etc/php-fpm.conf
    cat > "/etc/php-fpm.conf" <<END
include=/etc/php-fpm.d/*.conf

[global]
pid = /var/run/php-fpm/php-fpm.pid
error_log = /www/$svdomain/logs/php-fpm.log
emergency_restart_threshold = 10
emergency_restart_interval = 60s
process_control_timeout = 10s
daemonize = yes
END

    cat >> "/etc/security/limits.conf" <<END
* soft nofile 65536
* hard nofile 65536
nginx soft nofile 65536
nginx hard nofile 65536
END

ulimit  -n 65536

#Autostart
service nginx start
chkconfig nginx on
service php-fpm start
chkconfig php-fpm on
chkconfig --levels 235 exim on
chkconfig --add syslog-ng
chkconfig --levels 235 syslog-ng on
chkconfig iptables off

service exim start
service syslog-ng start

mkdir -p /etc/pineauto/menu
mkdir -p /etc/pineauto/update

rm -f /etc/pineauto/scripts.conf
    cat > "/etc/pineauto/scripts.conf" <<END
mainsite="$svdomain"
priport="$svport"
email="$umail"
serverip="$svip"
END

clear


    cat > "/tmp/sendmail.sh" <<END
#!/bin/bash

echo -e 'Subject: Cai dat thanh cong server!\nChao ban!\n\nChuc mung ban da hoan thanh qua trinh cai dat va cau hinh server voi script cua pineauto, neu ban co bat ky cau hoi hay gop y nao, vui long truy cap http://pineauto.com/\n\nSau day la thong tin server moi cua ban, vui long doc can than va luu giu cung nhu bao mat nhung thong tin sau day\nTen website chinh: http://$svdomain/\nLink phpMyAdmin: http://$svdomain:$svport/ (or http://$svip:$svport/)\nUpload source len : /www/$svdomain/public_html/\n\nDe quan ly server, ban hay dung lenh "pineauto" khi SSH.\n\n !' | exim  $umail
END
chmod +x /tmp/sendmail.sh
/tmp/sendmail.sh
rm -f /tmp/sendmail.sh

clear
printf "=========================================================================\n"
printf "Configuration completed, start adding pine-auto... \n"
printf "=========================================================================\n"
cp bin/pineauto  /bin/pineauto && chmod +x /bin/pineauto
cp -rf component/* /etc/pineauto/menu/ && chmod +x -R /etc/pineauto/menu/

echo "<?php phpinfo(); ?>" > /www/$svdomain/private_html/info.php
cd /www/$svdomain/private_html/
wget https://raw.github.com/rlerdorf/opcache-status/master/opcache.php
wget https://gist.github.com/ck-on/4959032/raw/0b871b345fd6cfcd6d2be030c1f33d1ad6a475cb/ocp.php

printf "=========================================================================\n"
printf "Scripts pineauto process completed... \n"
printf "=========================================================================\n"
printf "You can view server info below:\n"
printf "Main website name: http://$svdomain/ (or http://$svip/) \nLink Private for admin tools: http://$svdomain:$svport/ (or http://$svip:$svport/) \nUpload source code to: /www/$svdomain/public_html/\n"
printf "You can view Opcache Status follow: http://$svdomain:$svport/opcache.php (or http://$svip:$svport/opcache.php)\n"
printf "=========================================================================\n"

printf "To mange your server, please use command \"pineauto\" \n"
printf "=========================================================================\n"
printf "Server will auto reboot after 5s.... \n\n"
sleep 5
reboot
exit