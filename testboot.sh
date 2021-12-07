#!/bin/bash
#
# KTC boot check utility 

#set -e
#set -x

# CUSTOMIZE
run="make K1_BUILDROOT_DIR=/work1/obordes/linux_buildroot4/images reset attach"
#run="make  run"
#run="./ktc run"
v_initiator_connect="ssh root@192.168.122.157 nvme connect  -t rdma -a 10.3.0.1  -n nqn.0.0.0"
#v_initiator_connect="ssh root@192.168.122.168 nvme connect  -t rdma -a 10.3.0.1  -n nqn.0.0.0"
v_initiator_disconnect="ssh root@192.168.122.157 nvme disconnect --n nqn.0.0.0"
#v_initiator_disconnect="ssh root@192.168.122.168 nvme disconnect --n nqn.0.0.0"
log_file="/work1/obordes/testboot.log"
log_boot="/work1/obordes/testboot.boot"
# END CUSTOMIZE

v_pattern_search1="KTC: Clusters OK"
v_pattern_search2="KTC: Cluster boot FAIL"
v_pattern_search3="Welcome to Buildroot"
v_pattern_search4="Failed to write to /dev/nvme-fabrics"

log()
{
	echo -n "$(date)"
	echo " $*"
}

init()
{
	lock_file=/tmp/$(basename "$0").lock
	rm -f "$lock_file"
}

find_pattern()
{
	variable=$1
	pattern=$2

	v=${variable/${pattern}/}
	if [ ${#v} -eq  ${#variable} ]
	then
		echo "no"
	else
		echo "yes"
	fi
}

initiator_connect()
{
	while read line
	do
		v1=$(find_pattern "$line" "$v_pattern_search4")
		if [ "$v1" == "yes" ] ; then
			log "Initiator connect FAILED"
			exit
		fi
	done < <($v_initiator_connect 2>&1)
}

boot()
{
	while read line
	do

		if [ "$(find_pattern "$line" "$v_pattern_search1")" == "yes" ] ; then
			log "${v_pattern_search1} FOUND"
		fi
		if [ "$(find_pattern "$line" "$v_pattern_search2")" == "yes" ] ; then
			log "${v_pattern_search2} FOUND"
			exit -1
		fi

		if [ "$(find_pattern "$line" "$v_pattern_search3")" == "yes" ] ; then
			log "BOOT COMPLETE, Welcome to Builroot"
			touch "$lock_file"
		fi
		log "$line" >> "$log_boot"

	done < <($run 2>&1)
}

loop()
{
	killall k1-jtag-runner &> /dev/null

	boot &

	while [ ! -f "$lock_file"  ] ; do
		sleep 1
	done

	log "connecting initiator"
	initiator_connect
	log "initiator connect SUCCEED"
	while read line
	do
		log $line
	done < <($v_initiator_disconnect 2>&1)
}


while true
do
	init
	log "Starting run"
	loop
done &> ${log_file}


