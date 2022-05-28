#!/bin/bash

PAR=$(dirname $(readlink -f "$0"))
id=$(basename $PAR)
appid="/usr/local/uninstall/${id}"
versionid="/usr/local/version/${id}"
update_path=$PAR
update_json="/tmp/databack/json-${id}"
app_config_back="/tmp/databack/app-config-${id}.bz2"

update_step="0"
update_errs=""
update_boot="0"
update_oooo=`find $update_path/ -type f | wc -l`
update_cccc="0"
update_over="0"

killpc_list=""
remove_list=""
back_list=""
skip_list="$PAR/skip_list"
[ -e $PAR/kill_list ] && killpc_list="`cat $PAR/kill_list`"
[ -e $PAR/remove_list ] && remove_list="`cat $PAR/remove_list`"
[ -e $PAR/back_list ] && back_list="`cat $PAR/back_list`"
execute=""
modulepage=""

kill_process(){
	if [ "X${killpc_list}" = "X" ]; then
		[ -e /etc/init.d/$id ] && /etc/init.d/$id stop
	else
		for name in $killpc_list; do
			echo "kill $name"
            local pid=`pidof $name`
            [ ! -z "$pid" ] && kill -9 $pid > /dev/null 2>&1
		done
	fi
}

clean_base_space(){
	update_step="clean base space"
	echo $update_step
	echo '{"now":"'$update_cccc'","total":"'$update_oooo'","complete":"'$update_over'","reboot":"'$update_boot'","error":"'$update_errs'","step":"'$update_step'","description":""}' > $update_json
	local backarr=($back_list)
	[ ${#backarr[@]} -gt 0 ] && tar -jcvf $app_config_back $back_list
	echo -e "$remove_list" | while read line
	do
		[ "${line}x" = "x" ] && continue
		echo "clean ${line}"
		rm -fr "$line"
		if [ ! -e $appid ]; then
			echo "$line" > $appid
		else
			echo "$line" >> $appid
		fi
	done
	rm -fr /.log* /etc/init.d/.log*
    [ ! -d /usr/local/version ] && mkdir /usr/local/version
}

record_file_db(){
	local file_path=$1
	if [ ! -e $appid ]; then
        	echo "$file_path" > $appid
        else
			echo "$file_path" >> $appid
	fi
}

get_hash(){
    local file=$1
    local hash=$(which ter_md5)
    [ -z "$hash" ] && hash=md5sum
    [ ! -e "$file" ] && return 1
    if [ "$hash" = "md5sum" ]; then
        local md5=`md5sum "${file}" | awk {'print $1'}`
        echo $md5
    else
        echo `$hash $file`
    fi
    return 0
}

update_cpy(){
	local sys_file=$1 #old file path
	local file=$2 # new file path
	local file_dir=`dirname "$sys_file"`
	local md5_new=`get_hash "${file}"`
    local i=0
    local total=3
    while [ 1 ]; do
        cp "${file}" "${file_dir}/" -a
        sync
        local md5_cpy=`get_hash "$sys_file"`
        [ "${md5_cpy}" = "${md5_new}" ] && break
        [ $i -ge $total ] && break
        let i=i+1
    done
    [ $i -ge $total ] && $buzzerexe &
}

update_sys_app(){
	local update_step="update sys app"
	echo $update_step
	
	for file in $1/*; do
		local basefile=$(basename "$file")
        local file_dir=$(dirname "$file")
		local file_dir=${file_dir#$update_path}
		local sys_file="${file_dir}/${basefile}"
		if [ -f "${file}" -o -h "${file}" ]; then			
			[ "${file_dir}X" = "X" ] && continue
            [ ! -h "${file}" ] && let update_cccc=update_cccc+1
			echo '{"now":"'$update_cccc'","total":"'$update_oooo'","complete":"'$update_over'","reboot":"'$update_boot'","error":"'$update_errs'","step":"'$update_step'","description":""}' > $update_json
			mkdir -p "${file_dir}" > /dev/null 2>&1
			[ "${file_dir}" = "/etc/init.d" ] && execute="${basefile}"
			[ "${file_dir}" = "/usr/www/mod/4.Application" ] && modulepage="${basefile}"
			# if skip file exists...
			local skip=0
			if [ -e $skip_list ]; then
				grep -E "${file_dir}/${basefile}$" $skip_list >/dev/null
				[ $? -eq 0 ] && skip=1
			fi            
			# record the file list for remove...
			[ $skip -eq 0 ] && record_file_db "${file_dir}/${basefile}"
			if [ ! -e "$sys_file" -o -h "$sys_file" ]; then
				cp "${file}" "$sys_file" -a
				sync
				continue
			fi
			if [ -e "$sys_file" ]; then
				update_cpy "$sys_file" "${file}"
			fi
		elif [ -d "${file}" ]; then
			[ -h "$file" ] && continue
            if [ -d "$file_dir" ]; then
                cd "$file_dir"
                [ ! -e "./${basefile}" ] && mkdir "${basefile}"
            fi
			update_sys_app "$file"
		fi
	done
}

update_all_done(){
	update_cccc=$update_oooo
	update_over=1

	# exec install.sh
	[ -x "${update_path}/install.sh" ] && ${update_path}/install.sh

	# extend install app...
	[ -x "${update_path}/makeinstall" ] && ${update_path}/makeinstall
    touch $versionid
	
	# set json data
	echo '{"now":"'$update_cccc'","total":"'$update_oooo'","complete":"'$update_over'","reboot":"'$update_boot'","error":"'$update_errs'","step":"'$update_step'","description":""}' > $update_json
	# restore the config
	if [ -f $app_config_back ]; then
		tar -jxvf $app_config_back -C /
		rm -fr $app_config_back
	fi
}

# make json dir
mkdir -p /tmp/databack/ > /dev/null 2>&1

# kill some process
kill_process

# update prepare
clean_base_space

# update app
update_sys_app $update_path
[ "X${flag}" != "X" ] && mount -o ro,remount /

# finish
update_all_done

echo "install complete!!!"
