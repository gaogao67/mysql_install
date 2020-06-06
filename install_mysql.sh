#/bin/bash
#========================================================#
# script for test enviorment to create mysql instance
# usage: sh install_mysql.sh --install --mysql_port=3307 --buffer_pool_size=10
#========================================================#
mysql_port=0
buffer_pool_size=0
mysql_rpm_package_name="mysql-5.7.29.el7.rpm"
mysql_rpm_name="mysql-5.7.29-1.x86_64"
mysql_server_path="/apps/mysql/server"
install_script_dir="$( cd "$( dirname "$0"  )" && pwd  )"
install_log="${install_script_dir}/install_mysql.log"
#========================================================#

function echo_info()
{
	message=$1
	echo -e "\033[;37;32m ${message} \033[0m"
}


function echo_error()
{
	message=$1
	echo -e "\033[;37;31m ${message} \033[0m"
}


function show_usage()
{	
	echo_info "#************************************************************************#"
	echo_info "usage:"
	echo_info "create mysql instance with the specified mysql port and buffer pool size."
	echo_info ""
	echo_info "paras:"
	echo_info "--mysql_port: the mysql port for the new instance"
	echo_info "--buffer_pool_size: the buffer pool size(GB) for the new instance"
	echo_info ""
	echo_info "example:"
	echo_info "sh install_mysql.sh --install --mysql_port=3307 --buffer_pool_size=10"
	echo_info "#************************************************************************#"
}


function check_paras()
{
	if [ $mysql_port -le 0 ]
	then
		echo_error "please set the mysql port"
		show_usage
		exit -1
	fi

	if [ $buffer_pool_size -le 0 ]
	then
		echo_error "please set the buffer pool size"
		show_usage
		exit -1
	fi
	echo_info "mysql_port:${mysql_port}"
	echo_info "buffer_pool_size:${buffer_pool_size}"
	mysql_data_path="/apps/mysql/data_${mysql_port}"
	mysql_cnf_path=${mysql_server_path}/etc/my_${mysql_port}.cnf

}


function check_env()
{
    mysql_count=`rpm -qa|grep "${mysql_rpm_name}" |grep -v grep |wc -l`
    if [ $mysql_count -eq 0 ]
    then
        echo_info 'check rpm install pass'
    else
        echo_info "mysql has been installed!!!"
    fi

    if [ ! -d "${mysql_server_path}" ]
    then
        echo_info "${mysql_server_path} not exist"
    else
        echo_info "${mysql_server_path} exist!!!"
    fi

    if [ ! -d "${mysql_data_path}" ]
    then
        echo_info "${mysql_data_path} not exist"
    else
        echo_error "${mysql_data_path} exist!!!"
        exit -1
    fi
}


function set_scheduler()
{
    echo_info "Please change io scheduler by yourself."
}


function set_memory_swap()
{
    echo_info "set memory swap"
    wc_count=`cat /etc/rc.local |grep "set_memory_swap_for_mysql" |grep -v grep |wc -l`
    if [ $wc_count -eq 0 ];then
    	echo "# set_memory_swap_for_mysql"  >> /etc/rc.local
        echo "echo '1' > /proc/sys/vm/swappiness" >> /etc/rc.local
        echo '1' > /proc/sys/vm/swappiness
    fi
}


function install_mysql_dependence()
{
    echo_info "install mysql dependence"
    # rpm -e mysql-devel > /dev/null 2>&1
    # rpm -e mysql > /dev/null 2>&1
    yum install -y bc ncurses ncurses-devel glibc gcc gcc-c++ libstdc++* libtool sysstat lrzsz cmake zlib > /dev/null 2>&1
    yum -y install perl perl-JSON perl-Time-HiRes > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo_info "insatll mysql dependence success"
    else
        echo_error "insatll mysql dependence faild"
        exit ${error_install_mysql_package}
    fi

}


function create_mysql_os_user()
{
    echo_info "create user mysql"
    groupadd  mysql 2> /dev/null || true
    useradd mysql -g mysql 2> /dev/null || true
    wc_count=`cat /etc/security/limits.conf |grep "config_file_limit_for_mysql" |grep -v grep |wc -l`
    if [ $wc_count -eq 0 ]
    then
	    echo "# config_file_limit_for_mysql" >> /etc/security/limits.conf
	    echo "mysql soft nofile 65536" >> /etc/security/limits.conf
	    echo "mysql hard nofile 65536" >> /etc/security/limits.conf
	    echo "mysql soft noproc 16384" >> /etc/security/limits.conf
	    echo "mysql hard noproc 16384" >> /etc/security/limits.conf
	fi
}


function install_mysql_package()
{	
	wc_count=`rpm -qa |grep "${mysql_rpm_name}" |grep -v grep |wc -l`
    if [ $wc_count -eq 1 ]
    then
    	echo_info "mysql rpm package has been installed"
	else
		cd "${install_script_dir}"
	    rpm -ivh "${install_script_dir}/${mysql_rpm_package_name}" 1>>${install_log} 2>&1
	    if [ $? -eq 0 ]; then
	        echo_info "insatll mysql rpm package success"
	    else
	        echo_error "insatll mysql rpm package faild"
	        exit ${error_install_mysql_package}
	    fi
	fi
}

function set_bash_profile()
{
	wc_count=`cat /home/mysql/.bash_profile |grep "set_bash_profile_for_mysql" |grep -v grep |wc -l`
    if [ $wc_count -eq 0 ]
    then
    	echo_info "set bash profile for user mysql and root. "
    	echo '## set_bash_profile_for_mysql' >> /home/mysql/.bash_profile
	    echo "export LANG=zh_CN.UTF-8" >> /home/mysql/.bash_profile
	    echo 'PATH=$PATH:'${mysql_server_path}'/bin' >> /home/mysql/.bash_profile
	    echo 'export PATH' >> /home/mysql/.bash_profile
	    echo "export LANG=zh_CN.UTF-8" >> /root/.bash_profile
	    echo 'PATH=$PATH:'${mysql_server_path}'/bin' >> /root/.bash_profile
	    echo 'export PATH' >> /root/.bash_profile
	else
		echo_info "bash profile has been set for user mysql and root."
	fi
}

function set_network_config()
{
	wc_count=`cat /etc/sysctl.conf |grep "set_mysql_bash_profile" |grep -v grep |wc -l`
    if [ $wc_count -eq 0 ]
    then
    	echo_info "config network for mysql" 
		echo "# config_network_for_mysql" >> /etc/sysctl.conf
		echo "
		net.ipv4.tcp_tw_reuse = 1
		net.ipv4.tcp_tw_recycle = 1
		net.ipv4.tcp_fin_timeout = 30
		" >>/etc/sysctl.conf
		sysctl -p 1>/dev/null 2>&1
	else
		echo_info "network for mysql has been set"
	fi

}


function create_my_cnf()
{
    echo_info "create mysql config"
    mkdir -p "${mysql_server_path}/etc/" >/dev/null

    server_id=$(ip a |grep 'inet'|grep 'brd'|grep -v '127.0.0.1' |head -n 1 | awk '{print $2}' |awk -F'/' '{print $1}' |awk -F. '{print $2$3$4}')
    dockerflag=`ps -ef|grep "sleep 99999"|grep -v grep|wc -l`
    if [ $dockerflag -gt 0 ];then
        dock_info=/etc/config_info
        if [ -f $dock_info ];then
            mem=`cat /etc/config_info|awk -F 'Memory":' '{print $2}'|awk -F '}' '{print $1}'|awk -F ',' '{print $1}'`
            mem_gb=`echo "$mem/1024/1024/1024"|bc`
        else
            echo "Error: Docker env,can't find $dock_info.."
            exit 1
        fi
    else
        mem=`cat /proc/meminfo |grep MemTotal|awk '{print $2}'`
        mem_gb=`echo "$mem/1024/1024"|bc`
    fi

    if [ $mem_gb -gt 128 ];then
        let pool_size=$mem_gb-30
    elif [ $mem_gb -gt 96 -a $mem_gb -le 128 ];then
        let pool_size=$mem_gb-20
    elif [ $mem_gb -gt 64 -a $mem_gb -le 96 ];then
        let pool_size=$mem_gb-15
    elif [ $mem_gb -gt 32 -a $mem_gb -le 64 ];then
        let pool_size=mem_gb-10
    elif [ $mem_gb -gt 16 -a $mem_gb -le 32 ];then
        let pool_size=$mem_gb-5
    elif [ $mem_gb -gt 8 -a $mem_gb -le 16 ];then
        let pool_size=$mem_gb-2
    elif [ $mem_gb -gt 4 -a $mem_gb -le 8 ];then
        let pool_size=$mem_gb-1
    else
        pool_size=1
    fi
	innodb_buffer_pool_gb=$buffer_pool_size
    echo_info  "innodb_buffer_pool_size: ${innodb_buffer_pool_gb}"

    cat > ${mysql_cnf_path} << EOF
[clent]
port            = ${mysql_port}
socket          = ${mysql_data_path}/tmp/mysql.sock


[mysqld]
port            = ${mysql_port}
socket          = ${mysql_data_path}/tmp/mysql.sock
datadir         = ${mysql_data_path}/data/


#--- GLOBAL ---#
log_timestamps          = SYSTEM
character-set-server    = utf8mb4
lower_case_table_names  = 1
log-output              = FILE
log-error               = ${mysql_data_path}/log/error.log
#general_log
#general_log_file       = ${mysql_data_path}/log/mysql.log
pid-file                = ${mysql_data_path}/mysql.pid
slow-query-log
slow_query_log_file     = ${mysql_data_path}/log/slow.log
tmpdir                  = ${mysql_data_path}/tmp
long_query_time         = 0.1
sync_binlog             = 1
log_timestamps          = SYSTEM
transaction_isolation    = READ-COMMITTED
default_storage_engine    = InnoDB
#--------------#

#thread_concurrency     = 16
thread_cache_size       = 512
table_open_cache        = 16384
table_definition_cache  = 16384
sort_buffer_size        = 4M
join_buffer_size        = 4M
read_buffer_size        = 4M
read_rnd_buffer_size    = 4M
key_buffer_size         = 64M
myisam_sort_buffer_size = 64M
tmp_table_size          = 32M
max_heap_table_size     = 32M
open_files_limit        = 65535
query_cache_size        = 0
query_cache_type        = 0
bulk_insert_buffer_size = 64M
binlog_rows_query_log_events =on
sql_mode                = ''
optimizer_switch        = 'index_merge=off,index_merge_union=off,index_merge_sort_union=off,index_merge_intersection=off'

#--- NETWORK ---#
back_log                = 1024
max_allowed_packet      = 256M
interactive_timeout     = 28800
wait_timeout            = 28800
skip-external-locking
max_connections         = 3000
max_connect_errors         = 10000
skip-name-resolve       = 1
read_only               = 0

#--- REPL ---#
server-id               = ${server_id}
log-bin                 = ${mysql_data_path}/log/mysql-bin
master_info_repository  = TABLE
binlog_format           = ROW
binlog_cache_size        = 4M
expire_logs_days        = 7
max_binlog_size			= 512M

replicate-ignore-db     = test
log_slave_updates       = 1

slave-parallel-workers  = 8
slave-parallel-type = LOGICAL_CLOCK
slave_preserve_commit_order = 0

skip-slave-start
gtid_mode                = on
enforce-gtid-consistency = true

relay-log               = ${mysql_data_path}/log/relay-log
relay_log_recovery      = ON
sync_relay_log          = 0
relay_log_info_repository = TABLE


#--- INNODB ---#
default-storage-engine          = INNODB
innodb_data_home_dir            = ${mysql_data_path}/data
innodb_data_file_path           = ibdata1:1024M:autoextend
innodb_file_per_table
innodb_log_group_home_dir       = ${mysql_data_path}/data
innodb_buffer_pool_size         = ${innodb_buffer_pool_gb}G
#innodb_additional_mem_pool_size = 128M
innodb_log_files_in_group       = 3
innodb_log_file_size            = 1024M
innodb_log_buffer_size          = 16M
innodb_flush_log_at_trx_commit  = 1
innodb_lock_wait_timeout        = 120
innodb_flush_method             = O_DIRECT
innodb_max_dirty_pages_pct      = 75
innodb_io_capacity              = 1000
innodb_open_files               = 65535
innodb_write_io_threads         = 4
innodb_read_io_threads          = 4
innodb_print_all_deadlocks      = 1
# innodb_undo_directory           = ${mysql_data_path}/data
innodb_purge_threads            = 4
innodb_purge_batch_size         = 400
innodb_stats_on_metadata        = 0
innodb_page_cleaners            = 4
innodb_purge_threads            = 4
innodb_buffer_pool_instances    = 8



[mysqldump]
#quick
max_allowed_packet = 256M

[mysql]
# auto-rehash
# Remove the next comment character if you are not familiar with SQL
# safe-updates
default-character-set=utf8mb4

[myisamchk]
key_buffer_size = 128M
sort_buffer_size = 128M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout


EOF
    echo_info "mysql config file is created"

}


function mysql_install_db()
{
    echo_info "run mysql_install_db"
    /bin/rm -rf ${mysql_data_path}
    mkdir -p ${mysql_data_path}/data/ ${mysql_data_path}/tmp/ ${mysql_data_path}/log/ ${mysql_data_path}/dumps/
    chown -R mysql:mysql ${mysql_server_path} ${mysql_data_path}
    echo_info "${mysql_server_path}/bin/mysqld --defaults-file=${mysql_cnf_path} --initialize --initialize-insecure"
    ${mysql_server_path}/bin/mysqld --defaults-file=${mysql_cnf_path} --initialize --initialize-insecure  1>>${install_log} 2>&1
    if [ $? -eq 0 ]; then
        echo_info "run mysql_install_db success"
    else
        echo_error "run mysql_install_db faild"
        exit ${error_mysql_install_db}
    fi
}



function start_mysql_service()
{
    echo_info "start mysql service"
	chown -R mysql:mysql ${mysql_server_path} ${mysql_data_path}
	echo_info "${mysql_server_path}/bin/mysqld_safe --defaults-file=${mysql_cnf_path} --user=mysql &"
    ${mysql_server_path}/bin/mysqld_safe --defaults-file=${mysql_cnf_path} --user=mysql 1>/dev/null 2>&1 &
    for i in {1..60};do [ -S ${mysql_data_path}/tmp/mysql.sock ] && echo_info "mysql service is OK" && break || echo -n ". ";sleep 2;done
    if [ ! -S ${mysql_data_path}/tmp/mysql.sock ];then
        echo_error "Start Faild,See ${mysql_data_path}/log/error.log";
        exit ${error_start_mysql_service};
    fi

}


function grant_mysql_user()
{
    echo_info "grant mysql user"
    "${mysql_server_path}/bin/mysql" --socket=${mysql_data_path}/tmp/mysql.sock -uroot -e "
##==============================================================================##
## DBA
GRANT ALL PRIVILEGES ON *.* TO 'mysql_test_admin'@'%' IDENTIFIED BY PASSWORD '*02074528A65BF33342CBCD09F17F769705B0E83A' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'mysql_test_admin'@'localhost' IDENTIFIED BY PASSWORD '*02074528A65BF33342CBCD09F17F769705B0E83A' WITH GRANT OPTION;


SET session binlog_format = statement;

DELETE
FROM mysql.user
WHERE user='';

DELETE
FROM mysql.user
WHERE authentication_string='';

SET session binlog_format = row;

RESET MASTER;

"


    if [ $? -eq 0 ]; then
        echo_info "grant mysql user success"
    else
        echo_error "grant mysql user  faild"
        exit ${error_grant_mysql_user}
    fi

}


#=============================================================================#
# get parameters
opt_temp=`getopt --long install,mysql_port:,buffer_pool_size:,ignore -- "$@"`

if [ $? != 0 ]
then
	echo_error "please set 'mysql port' and 'buffer pool size'"
	show_usage
	exit 1
fi

eval set -- "$opt_temp"

while true ; do
    case "$1" in
    		--install) 
					echo_info "install mysql instance "; shift ;;
            --mysql_port) 
					mysql_port=$2 ; shift 2 ;;
            --buffer_pool_size)
                    buffer_pool_size=$2 ; shift 2 ;;
            --ignore)
                    IGNRFLAG="ignr"; shift
                    ;;
            --) shift ; break ;;
            *) echo_error "Internal error!" ; exit 1 ;;
    esac
done

#=============================================================================#
check_paras
check_env
set_scheduler
set_memory_swap
set_network_config
install_mysql_dependence
create_mysql_os_user
install_mysql_package
set_bash_profile
create_my_cnf
mysql_install_db
start_mysql_service
grant_mysql_user
