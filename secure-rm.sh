#!/bin/bash

#脚本作用说明:
#     1.mv替代rm  
#         支持rm所有参数,rm的文件自动移动到文件的顶层目录下的.trash文件夹下，保留1小时
#
#     2.支持文件恢复,使用rm -l
#


#回收站路径
trash_path=""

#回收站日志文件路径
trash_log_path=""

#脚本第一个参数副本
arg1_copy=$1

#随机数,防止回收站文件重名
random=""

#回收文件的绝对路径
real_file_path=""


#生成随机数
function rand(){
	random=`cat /proc/sys/kernel/random/uuid | awk -F "-" '{print $1}'`
}

#获取回收站路径,路径为删除文件目录的顶层目录
function getTrashPath(){

	#判断文件是否存在
	real_file_path=`realpath $1 2>/dev/null`
	if [[ ! -e $real_file_path ]] ; then
		echo "No such file or dir: "$1
		exit 1
	fi

	#判断回收站路径
	backslash_num=`echo $real_file_path | egrep -o "/" | wc -m`

	if [[ $backslash_num -eq 2 ]] ; then
	#如果反斜杠只有一个,则回收站位于根目录
		trash_path="/.trash"
	else
		input_file_top_dir=`echo $real_file_path | grep -Po "/.*?/"`
		trash_path=$input_file_top_dir".trash/"
	fi

	trash_log_path=$trash_path"trash.log"
}

#创建回收站
function createTrash(){
	#回收站若不存在，则新建之
        if [ ! -e $trash_path ];then
                mkdir -p $trash_path
                chmod 755 $trash_path
        fi
}

#把被rm的文件移动到回收站
function moveToTrash(){
	#生成回收后的文件名,并去除目录最后的反斜杠
        trash_file_name=`echo $1 | sed 's/\/$//' | awk -F '/' '{print $NF}'`-`date +%Y%m%d%H%M%S`-$random

	#回收文件
        mv $1 "$trash_path""$trash_file_name"
	if [[ $? -eq 1 ]] ; then
		exit 1
	fi
	
	#回收信息写入日志文件
        echo `date +%Y-%m-%d_%H:%m:%S`"    "$real_file_path"-`date +%Y%m%d%H%M%S`-$random    "  >> $trash_log_path	
}

#普通文件删除
function safeRemoveNormalFile(){
	#获取待删除文件的绝对路径
	file_real_path=`realpath $1`
	if [ -d "$file_real_path" ];then
		echo "rm: cannot remove "$1": Is a directory"
		exit 1
	fi

	getTrashPath $1		
	createTrash
	moveToTrash $1		
	#回收成功后,输出提示
	echo -e "info: file \033[31m$1\033[0m was moved to \033[31m $trash_path \033[0m which will be deleted by the system in an hour. use rm -l to restore"
}

#普通文件删除 rm带参数-i
function safeRemoveNormalFile_i(){
	file_real_path=`realpath $1`
        if [ -d "$file_real_path" ];then
                echo "rm: cannot remove "$1": Is a directory"
                exit 1
        fi

        getTrashPath $1
        createTrash

	echo -n "rm: remove regular file $1? [y/n]  "
	read answer
	if [ "$answer" = 'y' -o "$answer" = 'Y' ];then
		moveToTrash $1
		echo -e "info: file \033[31m$1\033[0m was moved to \033[31m $trash_path \033[0m which will be deleted by the system in an hour. use rm -l to restore"
	fi
}

#普通文件删除 rm带参数-f
function safeRemoveNormalFile_f(){
	safeRemoveNormalFile $1
}

#目录删除
function safeRemoveDir(){
        file_real_path=`realpath $1`

        getTrashPath $1
        createTrash

	#禁止删除".",".."
	if [ "$1" = "." -o "$1" = ".." ];then
		echo "rm: cannot remove directory: '$1'"
                exit 1
	fi

	if [ -d "$1" ];then
		filetype=dir
	else
		filetype=file
	fi

	moveToTrash $1	
	echo -e "info: $filetype \033[31m$1\033[0m was moved to \033[31m $trash_path \033[0m which will be deleted by the system in an hour. use rm -l to restore"
}


#目录删除 rm带参数-f
function safeRemoveDir_f(){
	safeRemoveDir $1
}

#目录删除 rm带参数-i
function safeRemoveDir_i(){
        file_real_path=`realpath $1`
        getTrashPath $1
        createTrash

	if [ -d "$1" ];then
		echo -n "rm: remove directory '$1'? [y/n]"
		if [ "$1" = "." -o "$1" = ".." ];then
			echo "rm: cannot remove directory: '$1'"
			exit 1
		fi
		filetype=dir
	else
		echo -n "rm: remove regular file '$1'? [y/n]"
		filetype=file
	fi

	read answer
	if [ "$answer" = 'y' -o "$answer" = 'Y' ];then
		moveToTrash $1
		echo -e "info: $filetype \033[31m$1\033[0m was moved to \033[31m $trash_path \033[0m which will be deleted by the system in an hour. use rm -l to restore"
	fi
}

#禁止删除系统目录
function system_dir_protect(){
    system_dir_list=( boot data dev etc home media mnt opt proc root run srv sys tmp usr var web )
    for dir in ${system_dir_list[@]};
    do
	if [ "$1" == "/${dir}" ] || [ "$1" == "/${dir}/" ] ;then
	  echo -e " Warning:The directory ${dir} can not be deleted " 
	  exit 1
	else
	   :
	fi
    done
}

#清除回收站
function cleanTrash(){
	current_dir=`pwd`
	backslash_num=`echo $current_dir | egrep -o "/" | wc -m`

	if [[ $current_dir == "/" ]] ; then
		trash_path="/.trash"
	elif [[ $backslash_num -eq 2 ]] ; then
		trash_path=$current_dir"/.trash"
	else
		getTrashPath $current_dir
	fi

	
	if [[ $trash_path =~ \.trash$ ]] ; then
		rm -rf $trash_path
		if [[ $? -eq 0 ]] ; then
			echo "The trash is cleaned up success!"
		fi
	else
		echo "warning: trash path error"	
	fi
}
function restore(){
	clear
	
	#获取回收站路径
	current_dir=`pwd`
        backslash_num=`echo $current_dir | egrep -o "/" | wc -m`

        if [[ $current_dir == "/" ]] ; then
                trash_path="/.trash"
		trash_log_path=$trash_path"/trash.log"
        elif [[ $backslash_num -eq 2 ]] ; then
                trash_path=$current_dir"/.trash"
		trash_log_path=$trash_path"/trash.log"
        else
                getTrashPath $current_dir
        fi
	
	#打印日志	
	cat -n $trash_log_path | awk '{print "FileNum: "$1,  "    Time: "$2,"    FileName:"$3}'
	echo
	#等待用户输入要恢复的文件编号
	echo "[FileNum] Please enter the FileNum you want to restore "
	printf "FileNum: "
	read answer
	if [ "$answer" = 'q' -o "$answer" = 'Q' -o "$answer" = "" ];then
		:
	else
		printf "Please confirm (y/n): "
		read answer1
		if [ "$answer1" = 'y' -o "$answer1" = 'Y' ];then
			#文件在回收站的路径	
			trash_file_path=$trash_path"/"`sed -n "$answer p" $trash_log_path | awk '{print $2}'| awk -F '/' '{print $NF}'`
			#文件原来的路径
			origin_file_path=`sed -n "$answer p" $trash_log_path | awk '{print $2}' | awk -F "-" '{print $1}'`
			#恢复
			mv  $trash_file_path $origin_file_path
			if [[ $? -eq 0 ]] ; then
				sed -i "$answer d" $trash_log_path
			fi
			echo "restore success!"
			sleep 0.5
		fi
	fi
}

#打印帮助信息
function usage(){
	rm --help
}

#打印版本
function version(){
	rm --version
}


##################       脚本开始      #######################

#生成随机数
rand

#根据输入参数调用不同函数

if [ "$#" -eq 0 ];then
	usage
fi

if [ "$#" -eq 1 ];then
	case "$1" in
		-i| -f | -r | -R)
		usage
		;;
		--version )
		version
		;;
		-ir|-ri|-iR|-Ri|-if|-fi|-rf|-fr|-Rf|-fR)
		usage
		;;
		-c)
		cleanTrash
		;;
		-l)
		restore
		;;
		--help)
		usage
		;;
		-*)
		usage
		;;
		*) 
		safeRemoveNormalFile $1
		;;
	esac
fi

if [ "$#" -ge 2 ];then
	while  [ ! "$2" = "" ]
	do
		case "$arg1_copy" in
			-i)
			safeRemoveNormalFile_i $2
			;;
			-f)
			safeRemoveNormalFile_f $2
			;;
			-r|-R)
			system_dir_protect $2 && safeRemoveDir $2
			;;
			-rf|-Rf|-fr|-fR)
			system_dir_protect $2 && safeRemoveDir_f $2
			;;
			-ir|-ri|-iR|-Ri)
			system_dir_protect $2 && safeRemoveDir_i $2
			;;
			-if|-fi)
			safeRemoveNormalFile_f $2
			;;
			--help)
			usage
			;;
			-*)
			usage
			;;
			*)
			{
				while [ ! "$1" = "" ]
				do
					safeRemoveNormalFile $1
					shift
				done
			}
			;;
		esac
		shift
	done
fi
