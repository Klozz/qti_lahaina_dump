#! /vendor/bin/sh

#Xiao.Liang@PSW.CN.WiFi.Basic.Log.1072015, 2018/10/22, Add for collecting wifi driver log

DATA_LOG_PATH=/data/vendor/wifi/logs
option="$1"


function defaultaction(){
     echo Something wrong!!!
}

function prepacketlog(){
    panicstate=`getprop persist.sys.assert.panic`
    packetlogstate=`getprop persist.sys.wifipacketlog.state`
    packetlogbuffsize=`getprop persist.sys.wifipktlog.buffsize`
    timeout=0

    if [ "${panicstate}" = "true" ] && [ "${packetlogstate}" = "true" ];then
        echo Disable it before we set the size...
        setprop ctl.start setiwprivpkt0
        while [ $? -ne "0" ];do
            echo wait util the file system is built.
            sleep 2
            if [ $timeout -gt 30 ];then
                echo less than the numbers  we want...
                echo can not finish prepacketlog... > ${DATA_LOG_PATH}/pktlog_error.txt
                setprop ctl.start setiwprivpkt0 >> ${DATA_LOG_PATH}/pktlog_error.txt
                exit
            fi
            let timeout+=1;
            setprop ctl.start setiwprivpkt0
        done
        if [ "${packetlogbuffsize}" = "1" ];then
            echo Set the pktlog buffer size to 100MB...
            pktlogconf -s 100000000 -a cld
        else
            echo Set the pktlog buffer size to 20MB...
            pktlogconf -s 20000000 -a cld
        fi

        echo Enable the pktlog...
        setprop ctl.start setiwprivpkt1
    fi
}

function wifipktlogtransf(){
    LOGTIME=`getprop persist.sys.com.oppo.debug.time`
    ROOT_SDCARD_LOG_PATH=/data/vendor/wifi/logs/${LOGTIME}/wlan_logs
    echo $ROOT_SDCARD_LOG_PATH
    packetlogstate=`getprop persist.sys.wifipacketlog.state`

    setprop ctl.start setiwprivpkt0
    while [ $? -ne "0" ];do
        echo wait util the file system is built.
        sleep 2
        if [ $timeout -gt 30 ];then
            echo less than the numbers  we want...
            echo can not finish prepacketlog... > ${DATA_LOG_PATH}/pktlog_error.txt
            setprop ctl.start setiwprivpkt0 >> ${DATA_LOG_PATH}/pktlog_error.txt
            exit
        fi
        let timeout+=1;
        setprop ctl.start setiwprivpkt0
    done
    if [ "${packetlogstate}" = "true" ];then
        echo transfer start...

        if [ ! -d ${ROOT_SDCARD_LOG_PATH} ];then
            echo "${ROOT_SDCARD_LOG_PATH} not exist."
            mkdir -p ${ROOT_SDCARD_LOG_PATH}
        fi

        cat /proc/ath_pktlog/cld > ${ROOT_SDCARD_LOG_PATH}/pktlog.dat
        setprop ctl.start setiwprivpkt4
        echo transfer end...
    fi
    pktlogconf -s 10000000 -a cld
    setprop ctl.start setiwprivpkt1
}

function switchWiFiIniForRoam() {
    platform=`getprop ro.board.platform`
    if [ "x${platform}" == "xkona" ];then
        dstFile="/mnt/vendor/persist/wlan/WCNSS_qcom_cfg.ini"
    else
        # Notice that /storage/persist is link of /mnt/vendor/persist
        dstFile="/mnt/vendor/persist/wlan/WCNSS_qcom_cfg.ini"
    fi

    wifiRoamEnable=`getprop oppo.wifi.roaming.enabled`
    # if property is empty, indicate this is the first time of call, set the property
    if [ -z "$wifiRoamEnable" ]; then
        if [ -f "$dstFile" ]; then
            wifiRoamEnable=$(cat "$dstFile" | grep "gEnableImps=" | awk -F "=" '{print $2}')
            if [ "$wifiRoamEnable" -ne "1" ]; then
                wifiRoamEnable=0
            fi
            echo "oppo.wifi.roaming.enabled is empty, set value to $wifiRoamEnable"
            setprop oppo.wifi.roaming.enabled "$wifiRoamEnable"
            exit
        fi
    fi

    if [ "0" == "$wifiRoamEnable" ]; then
        srcFile="/my_product/vendor/etc/wifi/WCNSS_qcom_cfg_cmcc.ini"
    else
        srcFile="/my_product/vendor/etc/wifi/WCNSS_qcom_cfg.ini"
    fi

    # check whether file have been modified, should this can happen?
    srcMd5=`md5sum $srcFile`
    dstMd5=`md5sum $dstFile`
    if [ "$srcMd5" == "$dstMd5" ]; then
        echo "source file and dest file is same, ignore it"
        exit
    fi

    cp -f "$srcFile" "$dstFile"
}

function WifibdfVersion() {
    wcnbdfFile="/mnt/vendor/persist/bdwlan.bin"
    qcabdfFile="/mnt/vendor/persist/bdwlan.elf"
    wcnbdfMd5=`md5sum $wcnbdfFile`
    qcabdfMd5=`md5sum $qcabdfFile`
    if [ "x$wcnbdfMd5" != "x" ];then
        setprop ro.vendor.oplus.wifi.bdfver "$wcnbdfMd5"
    elif [ "x$qcabdfMd5" != "x" ];then
        setprop ro.vendor.oplus.wifi.bdfver "$qcabdfMd5"
    else
        setprop ro.vendor.oplus.wifi.bdfver "123456789"
    fi
}

function dumpon(){
    platform=`getprop ro.board.platform`

    echo full > /sys/kernel/dload/dload_mode
    echo 0 > /sys/kernel/dload/emmc_dload
#yanghao@BSP.Kernel.Stability, 2019/11/22, add root version meet apdp mimi caused part ramdump can't parse
    full_update=`getprop persist.root.fulldump.update`

    if [ x"${full_update}" == x"1" ]; then
        setprop persist.root.fulldump.update 0
    fi
#Chunbo.Gao@ANDROID.DEBUG.1974273, 2019/4/22, Add for dumpon
    dump_log_dir="/sys/bus/msm_subsys/devices"

    modem_crash_not_reboot_to_dump=`getprop persist.sys.modem.crash.noreboot`
    adsp_crash_not_reboot_to_dump=`getprop persist.sys.adsp.crash.noreboot`
    wlan_crash_not_reboot_to_dump=`getprop persist.sys.wlan.crash.noreboot`
    cdsp_crash_not_reboot_to_dump=`getprop persist.sys.cdsp.crash.noreboot`
    slpi_crash_not_reboot_to_dump=`getprop persist.sys.slpi.crash.noreboot`
    ap_crash_only=`getprop persist.sys.ap.crash.only`

    if [ -d ${dump_log_dir} ]; then
        ALL_FILE=`ls -t ${dump_log_dir}`
        for i in $ALL_FILE;
        do
            echo ${i}
            if [ -d ${dump_log_dir}/${i} ]; then
                echo ${dump_log_dir}/${i}/restart_level
                chmod 0666 ${dump_log_dir}/${i}/restart_level
                subsys_name=`cat /sys/bus/msm_subsys/devices/${i}/name`
                if [ "${ap_crash_only}" = "true" ] ; then
                    echo related > ${dump_log_dir}/${i}/restart_level
                else
                    if [ "${subsys_name}" = "modem" ] && [ "${modem_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir}/${i}/restart_level
                    elif [ "${subsys_name}" = "adsp" ] && [ "${adsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir}/${i}/restart_level
                    elif [ "${subsys_name}" = "wlan" ] && [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir}/${i}/restart_level
                    elif [ "${subsys_name}" = "cdsp" ] && [ "${cdsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir}/${i}/restart_level
                    elif [ "${subsys_name}" = "slpi" ] && [ "${slpi_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir}/${i}/restart_level
                    else
                        echo system > ${dump_log_dir}/${i}/restart_level
                    fi
                fi
            fi
        done
    fi
}

function dumpoff(){
    platform=`getprop ro.board.platform`


    echo mini > /sys/kernel/dload/dload_mode
    echo 1 > /sys/kernel/dload/emmc_dload

#Chunbo.Gao@ANDROID.DEBUG.1974273, 2019/4/22, Add for dumpoff
    dump_log_dir="/sys/bus/msm_subsys/devices"
    if [ -d ${dump_log_dir} ]; then
        ALL_FILE=`ls -t ${dump_log_dir}`
        for i in $ALL_FILE;
        do
            echo ${i}
            if [ -d ${dump_log_dir}/${i} ]; then
               echo ${dump_log_dir}/${i}/restart_level
               echo related > ${dump_log_dir}/${i}/restart_level
            fi
        done
    fi

}

#ifdef OPLUS_DEBUG_QMI_LOG
#Wankang.Zhang@TECH.NW.OppoDebug.LogKit.1968962, 2020/4/20, Add for qmi log
function qrtrlookup() {
    echo "qrtrlookup begin"
    if [ -d "/d/ipc_logging" ]; then
        path="data/vendor/oppo/log/"
        echo ${path}
        /vendor/bin/qrtr-lookup > ${path}/qrtr-lookup_info.txt
    fi
    echo "qrtrlookup end"
}
#endif /*OPLUS_DEBUG_QMI_LOG*/

case "$option" in
    "prepacketlog")
        prepacketlog
        ;;
    "wifipktlogtransf")
        wifipktlogtransf
        ;;
        #end
    "switchWiFiIniForRoam")
        switchWiFiIniForRoam
        ;;
    "WifibdfVersion")
        WifibdfVersion
        ;;
        #end
    "dumpon")
        dumpon
        ;;
        #end
    "dumpoff")
        dumpoff
        ;;
        #end
#ifdef OPLUS_DEBUG_QMI_LOG
#Wankang.Zhang@TECH.NW.OppoDebug.LogKit.1968962, 2020/4/20, Add for qmi log
    "qrtrlookup")
        qrtrlookup
    ;;
#endif /*OPLUS_DEBUG_QMI_LOG*/
       *)
    defaultaction
      ;;
esac
