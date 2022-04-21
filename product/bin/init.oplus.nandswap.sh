#!/system/bin/sh

init=`getprop sys.oplus.nandswap.init`
[ "$init" == "true" ] && exit
setprop sys.oplus.nandswap.init true

mem_total_str=`cat /proc/meminfo |grep MemTotal`
mem_total=${mem_total_str:16:8}
swap_size_gb=`getprop persist.sys.oplus.nandswap.swapsize`
if [ ! $swap_size_gb ]; then
	if [ $mem_total -le 4194304 ]; then
		swap_size_gb=1
	elif [ $mem_total -le 6291456 ]; then
		swap_size_gb=2
	elif [ $mem_total -le 8388608 ]; then
		swap_size_gb=3
	elif [ $mem_total ]; then
		swap_size_gb=3
	fi
fi
swap_size=$(expr $swap_size_gb \* 1024 \* 1024 \* 1024)
setprop persist.sys.oplus.nandswap.swapsize.curr $swap_size_gb

total=`df |grep -E " /data$" |awk '{print $2}'`
avail=`df |grep -E " /data$" |awk '{print $4}'`
#64G > 4.5+x G, 128G > 7+x G, 256G > 7+x G
if [ $total -gt 146800640 ]; then
	threshold=7340032
elif [ $total -gt 73400320 ]; then
	threshold=7340032
#elif [ $total -gt 36700160 ]; then
#	threshold=5767168
else
	setprop persist.sys.oplus.nandswap.condition false
	threshold=$total
fi
swap_size_curr=0
[ -f "/data/nandswap/swapfile" ] && swap_size_curr=`ls -al /data/nandswap/swapfile |awk '{print $5}'`
threshold=$(expr $threshold + $swap_size / 1024 - $swap_size_curr / 1024)

dev_life=`getprop "persist.sys.oplus.nandswap.devlife"`
condition=`getprop "persist.sys.oplus.nandswap.condition"`
if [ "$dev_life" == "false" ]; then
	echo 1 > /proc/nandswap/dev_life
else
	if [ -f "/proc/nandswap/fn_enable" ] && [ $avail -gt $threshold ]; then
		[ "$condition" == "true" ] && fn_enable=`getprop "persist.sys.oplus.nandswap"`
		echo 0 > /proc/nandswap/dev_life
	fi
fi

data_type=`mount |grep -E " /data " |awk '{print $5}'`
[ $data_type == "f2fs" ] || [ $data_type == "ext4" ] || exit

function check_swapfile(){
	if [ "$data_type" == "f2fs" ]; then
		check_pin=`/product/bin/nandswap_tool -g /data/nandswap/swapfile |awk '{print $2}'`
		[ "$check_pin" == "pinned" ] || rm -rf /data/nandswap/swapfile
	fi

	check_size=`ls -al /data/nandswap/swapfile |awk '{print $5}'`
	[ "$check_size" == "$swap_size" ] || rm -rf /data/nandswap/swapfile
}

if [ "$fn_enable" == "true" ]; then
	[ -f "/data/nandswap/swapfile" ] && check_swapfile

	if [ ! -f "/data/nandswap/swapfile" ]; then
		touch /data/nandswap/swapfile
		[ "$data_type" == "f2fs" ] && /product/bin/nandswap_tool -s1 /data/nandswap/swapfile
		fallocate -l $swap_size /data/nandswap/swapfile
		check_swapfile
	fi

	if [ -f "/data/nandswap/swapfile" ]; then
		for i in {0..2} ; do
			losetup -f
			sleep 1
			loop_device=$(losetup -f -s /data/nandswap/swapfile 2>&1)
			loop_device_ret=`echo $loop_device |awk -Floop '{print $1}'`
			if [ "$loop_device_ret" == "/dev/block/" ]; then
				break
			fi
			sleep 1
		done
		[ "$loop_device_ret" != "/dev/block/" ] && rm -rf /data/nandswap/swapfile && exit

		set_dio=`/product/bin/nandswap_tool -l $loop_device |awk '{print $2}'`
		if [ "$set_dio" == "success" ]; then
			mkswap $loop_device
			# 2020 is just a magic number, must be consistent with the definition SWAP_NANDSWAP_PRIO in include/linux/swap.h
			swapon $loop_device -p 2020
			echo 1 > /proc/nandswap/fn_enable
		else
			losetup -d $loop_device
			rm -rf /data/nandswap/swapfile
		fi
	fi
else
	echo 0 > /proc/nandswap/fn_enable
	[ -f "/data/nandswap/swapfile" ] && rm -rf /data/nandswap/swapfile
fi
