#! /system/bin/sh
#***********************************************************
#** Copyright (C), 2008-2016, OPPO Mobile Comm Corp., Ltd.
#** OPLUS_FEATURE_WIFI_MINIDUMP
#**
#** Version: 1.0
#** Date : 2019/10/18
#** Author: JiaoBo@CONNECTIVITY.BASIC.LOG.1162004, 2019/10/18
#** Add for: mtk coredump related log collection and DCS handle
#**
#** ---------------------Revision History: ---------------------
#**  <author>    <data>       <version >       <desc>
#**  Bo.Jiao    2019/10/18     1.0        build this module
#****************************************************************/

config="$1"

#ifdef OPLUS_FEATURE_WIFI_DUMP
#JiaoBo@CONNECTIVITY.WIFI.BASIC.LOG.1162003, 2018/7/02
#add for wifi dump related log collection and DCS handle, dynamic enable/disable wifi core dump, offer trigger wifi dump API.
DUMP_MONITOR_FILE_PATH="/data/misc/wifi/wifidump/dumpfinishfile"
MTK_DCS_WIFI_LOG_ZIP_PATH=/data/oppo/log/DCS/de/network_logs/stp_dump/wifi
MTK_DCS_WIFI_LOG_DE_PATH=/data/oppo/log/DCS/de/network_logs/stp_dump
MTK_DCS_WIFI_LOG_EN_PATH=/data/oppo/log/DCS/en/network_logs/stp_dump
QCOM_DCS_WIFI_LOG_ZIP_PATH=/data/oppo/log/DCS/de/network_logs/wifi/wifi
QCOM_DCS_WIFI_LOG_DE_PATH=/data/oppo/log/DCS/de/network_logs/wifi
QCOM_DCS_WIFI_LOG_EN_PATH=/data/oppo/log/DCS/en/network_logs/wifi
function enablewifidump(){
    platform=`getprop ro.board.platform`
    if [[ $platform == *"mt"* ]] || [[ $platform == *"Mt"*  ]] || [[ $platform == *"MT"*  ]];then
        echo "enable mtk coredump, set sys.oplus.wifi.dump.mode to 2"
        setprop sys.oplus.wifi.dump.mode "2"
    else
        echo "enable qcom minidump"
        if [ "x${platform}" == "xkona" ];then
            #enable wlan SSR
            echo related > /sys/bus/msm_subsys/devices/subsys9/restart_level
            #enable wlan minidump
            #echo mini > /sys/kernel/dload/dload_mode
            #echo 1 > /sys/module/subsystem_restart/parameters/enable_ramdumps
        else
            echo dynamic_feature_mask 0x01 > /d/icnss/fw_debug
            echo 0x01 > /sys/module/icnss/parameters/dynamic_feature_mask
        fi
    fi
}

function disablewifidump(){
    platform=`getprop ro.board.platform`
    if [[ $platform == *"mt"* ]] || [[ $platform == *"Mt"*  ]] || [[ $platform == *"MT"*  ]];then
        echo "disable mtk coredump, set sys.oplus.wifi.dump.mode to 0"
        setprop sys.oplus.wifi.dump.mode "0"
    else
        echo "disable qcom minidump"
        if [ "x${platform}" == "xkona" ];then
            #enable wlan SSR
            echo related > /sys/bus/msm_subsys/devices/subsys9/restart_level
            #enable wlan minidump
            #echo full > /sys/kernel/dload/dload_mode
            #echo 0 > /sys/module/subsystem_restart/parameters/enable_ramdumps
        else
            echo dynamic_feature_mask 0x11 > /d/icnss/fw_debug
            echo 0x11 > /sys/module/icnss/parameters/dynamic_feature_mask
        fi
    fi
}

function  touchwifidumpfinishfile(){
    setprop sys.oplus.wifi.dump.failureDesc "${null}"
    platform=`getprop ro.board.platform`
    local dcs_wifi_zip_path
    local dcs_wifi_de_path
    # sleep 1s wait wifi dump complete
    sleep 1
    # check dcs dir exist
    if [[ $platform == *"mt"* ]] || [[ $platform == *"Mt"*  ]] || [[ $platform == *"MT"*  ]];then
        dcs_wifi_zip_path=$MTK_DCS_WIFI_LOG_ZIP_PATH
        dcs_wifi_de_path=$MTK_DCS_WIFI_LOG_DE_PATH
    else
        dcs_wifi_zip_path=$QCOM_DCS_WIFI_LOG_ZIP_PATH
        dcs_wifi_de_path=$QCOM_DCS_WIFI_LOG_DE_PATH
    fi
    if [ ! -d ${dcs_wifi_zip_path} ];then
        mkdir -p ${dcs_wifi_zip_path}
        chown -R system:system ${dcs_wifi_zip_path}
        chmod -R 777 ${dcs_wifi_zip_path}
        echo "touch wifi dump dcs_wifi_zip_path = $dcs_wifi_zip_path"
    fi

    chmod 777 ${dcs_wifi_de_path}
    sleep 1
    touch ${dcs_wifi_zip_path}/kernel_log.kinfo
    sleep 1
    chown system:system ${dcs_wifi_zip_path}/kernel_log.kinfo
    sleep 1
    chmod 777 ${dcs_wifi_zip_path}/kernel_log.kinfo
    sleep 1

    echo "got crash reason."
    setprop ctl.start collectwifidmesgrooot

}

function collectwifidmesg(){
    local dcs_wifi_zip_path
    local dcs_wifi_de_path
    local dcs_wifi_en_path
    local dewifidumpcount
    local enwifidumpcount
    platform=`getprop ro.board.platform`
    needUpload=`getprop sys.oplus.wifi.dump.needupload`
    name_head=`getprop sys.oplus.wifi.dump.nameheader`
    name_ota=`getprop ro.build.version.ota`
    name_time=$(date "+%Y-%m-%d_%H-%M-%S")
    zip_name="${name_head}@${name_ota}@${name_time}"
    echo $zip_name

    kinfo_name="kernel_log"
    echo "platform:  ${platform}"
    if [[ $platform == *"mt"* ]] || [[ $platform == *"Mt"*  ]] || [[ $platform == *"MT"*  ]];then
        dcs_wifi_zip_path=$MTK_DCS_WIFI_LOG_ZIP_PATH
        dcs_wifi_de_path=$MTK_DCS_WIFI_LOG_DE_PATH
        dcs_wifi_en_path=$MTK_DCS_WIFI_LOG_EN_PATH
        dewifidumpcount=`ls -l $dcs_wifi_de_path  | grep "connsys_core_dump" | wc -l`
        enwifidumpcount=`ls -l $dcs_wifi_en_path  | grep "connsys_core_dump" | wc -l`
        echo "mtk coredump"
    else
        dcs_wifi_zip_path=$QCOM_DCS_WIFI_LOG_ZIP_PATH
        dcs_wifi_de_path=$QCOM_DCS_WIFI_LOG_DE_PATH
        dcs_wifi_en_path=$QCOM_DCS_WIFI_LOG_EN_PATH
        dewifidumpcount=`ls -l $dcs_wifi_de_path  | grep "wifi_minidump" | wc -l`
        enwifidumpcount=`ls -l $dcs_wifi_en_path  | grep "wifi_minidump" | wc -l`
        echo "qcom minidump"
    fi

    if [ ! -d ${dcs_wifi_en_path} ];then
        mkdir -p ${dcs_wifi_en_path}
        echo "mkdir dec en path: ${dcs_wifi_en_path}"
        chown -R system:system ${dcs_wifi_en_path}
        chmod -R 777 ${dcs_wifi_en_path}
    fi

    echo "dcs_wifi_zip_path=${dcs_wifi_zip_path}"
    echo "dcs_wifi_de_path=${dcs_wifi_de_path}"
    echo "dcs_wifi_en_path=${dcs_wifi_en_path}"


    echo "enwifidumpcount=${enwifidumpcount},dewifidumpcount=${dewifidumpcount},needUpload=$needUpload"
    if [ $dewifidumpcount -lt 10 ] && [ $enwifidumpcount -lt 10 ] && [ $needUpload -eq 1 ];then

        tar -czvf  ${dcs_wifi_de_path}/${zip_name}.tar.gz -C ${dcs_wifi_zip_path} ${dcs_wifi_zip_path}
    else
        rm -rf ${dcs_wifi_zip_path}/kernel_log.kinfo
    fi
    chown -R system:system ${dcs_wifi_zip_path}
    chmod -R 777 ${dcs_wifi_zip_path}
    chown -R system:system ${dcs_wifi_de_path}
    chmod -R 777 ${dcs_wifi_de_path}
    rm -rf ${dcs_wifi_zip_path}
    setprop sys.oplus.wifi.dump.logcollect "0"
}

function collectwifidmesgrooot(){
        platform=`getprop ro.board.platform`
        dmesg -T > ${QCOM_DCS_WIFI_LOG_ZIP_PATH}/kernel_log.kinfo
        #dmesg > /data/oppo/log/DCS/de/network_logs/wifi/kernel_log.kinfo
        sleep 3

        if [[ $platform == *"mt"* ]] || [[ $platform == *"Mt"*  ]] || [[ $platform == *"MT"*  ]];then
            echo "mtk reason key got"
        else
            if [ "x${platform}" == "lito" ];then
                echo "lito got from pdmapper"
                reason=`dmesg | grep PD_ERR | sed -n '$p'`
                reason=`echo ${reason#*PD_ERR] }`
            else
                echo "QC knona and lihaha crash reason key got"
                reason=`dmesg | grep mhi_process_sfr | sed -n '$p'`
                reason=`echo ${reason#*mhi_process_sfr] }`
            fi
            if [ "w${reason}" == "w" ];then
                echo "qca6750 crash reason key got"
                reason=`dmesg | grep "wpss subsystem failure reason" | sed -n '$p'`
                reason=`echo ${reason#*wpss subsystem failure reason\:}`
            fi
        fi

        echo "failureDesc : ${reason}"
        setprop sys.oplus.wifi.dump.failureDesc "${reason}"

        echo "touch wifi dump finish file."
        touch $DUMP_MONITOR_FILE_PATH
        sleep 5
        rm -rf $DUMP_MONITOR_FILE_PATH
}

#endif /* OPLUS_FEATURE_WIFI_DUMP */

#ifdef OPLUS_FEATURE_WIFI_SWITCH
#JiaoBo@CONNECTIVITY.WIFI.BASIC.SWITCH.1069763, 2020/02/20, Add for collect wifi switch log
function collectWifiSwitchLog() {
    boot_completed=`getprop sys.boot_completed`
    while [ x${boot_completed} != x"1" ];do
        sleep 2
        boot_completed=`getprop sys.boot_completed`
    done

    wifiSwitchLogPath="/data/oppo_log/wifi_switch_log"
    if [ ! -d  ${wifiSwitchLogPath} ];then
        mkdir -p ${wifiSwitchLogPath}
		chmod 777 /data/oppo_log/wifi_switch_log
    fi
    setprop ctl.start collectwifidmesgroootwifiswitch
    #dmesg > ${wifiSwitchLogPath}/dmesg.txt
    /system/bin/logcat -b main -b system -b events -f ${wifiSwitchLogPath}/android.txt -r10240 -v threadtime *:V
}


function collectwifidmesgroootwifiswitch(){
	dmesg > /data/oppo_log/wifi_switch_log/dmesg.txt
	chown system:system /data/oppo_log/wifi_switch_log/dmesg.txt
	chmod 777 /data/oppo_log/wifi_switch_log/dmesg.txt
	sleep 2
}

function packWifiSwitchLog() {
    wifiSwitchLogPath="/data/oppo_log/wifi_switch_log"
    DCS_WIFI_LOG_PATH="/data/oppo/log/DCS/de/network_logs/wifiSwitch"
    DCS_WIFI_LOG_EN_PATH="/data/oppo/log/DCS/en/network_logs/wifiSwitch"
    logReason=`getprop sys.oplus.wifi.switch.log.reason`
    logFid=`getprop sys.oplus.wifi.switch.log.fid`
    version=`getprop ro.build.version.ota`
    if [ "w${logReason}" == "w" ];then
        return
    fi

    if [ ! -d ${DCS_WIFI_LOG_PATH} ];then
        mkdir -p ${DCS_WIFI_LOG_PATH}
        chown system:system ${DCS_WIFI_LOG_PATH}
        chmod -R 777 ${DCS_WIFI_LOG_PATH}
    fi

    if [ ! -d ${DCS_WIFI_LOG_EN_PATH} ];then
        mkdir -p ${DCS_WIFI_LOG_EN_PATH}
        chown -R system:system ${DCS_WIFI_LOG_EN_PATH}
        chmod -R 777 ${DCS_WIFI_LOG_EN_PATH}
    fi

    if [ ! -d  ${wifiSwitchLogPath} ];then
        return
    fi
    tar -czvf  ${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz -C ${wifiSwitchLogPath} ${wifiSwitchLogPath}
    abs_file=${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz

    fileName="wifi_turn_on_failed@${logFid}@${version}@${logReason}.tar.gz"
    mv ${abs_file} ${DCS_WIFI_LOG_PATH}/${fileName}
    chown system:system ${DCS_WIFI_LOG_PATH}/${fileName}
    rm -rf ${wifiSwitchLogPath}

    setprop sys.oplus.wifi.switch.log.ctl "0"
}
#endif /* OPLUS_FEATURE_WIFI_SWITCH */

#ifdef OPLUS_FEATURE_WIFI_SNIFFER
#LiangXiao@CONNECTIVITY.WIFI.BASIC.Sniffer.7267, 2020/09/20, Add for collect wifi sniffer log
function copysnifferlog() {
    SDCARD_WIFI_SNIFFER_LOG_PATH="/sdcard/Android/data/com.oplus.wifisniffer/files/sniffer_log"
    DATA_WIFI_SNIFFER_LOG_PATH="/data/oppo_log/snifferlog.tar.gzip"
    CURRENT_TIME=$(date "+%H-%M-%S")
    echo ${SDCARD_WIFI_SNIFFER_LOG_PATH}snifferlog-${CURRENT_TIME}.tar.gzip
    if [ -s ${DATA_WIFI_SNIFFER_LOG_PATH} ];then
        echo "Copy log start"
        mv ${DATA_WIFI_SNIFFER_LOG_PATH} ${SDCARD_WIFI_SNIFFER_LOG_PATH}/snifferlog-${CURRENT_TIME}.tar.gzip
    fi
}
#endif /* OPLUS_FEATURE_WIFI_SNIFFER */

case "$config" in
    #ifdef OPLUS_FEATURE_WIFI_DUMP
    #JiaoBo.Wang@CONNECTIVITY.WIFI.BASIC.LOG.1162003, 2018/7/02
    #add for wifi dump related log collection and DCS handle, dynamic enable/disable wifi core dump, offer trigger wifi dump API.
        "collectWifiCoredumpLog")
        collectWifiCoredumpLog
    ;;
        "enablewifidump")
        enablewifidump
    ;;
        "disablewifidump")
        disablewifidump
    ;;
        "collectwifidmesg")
        collectwifidmesg
    ;;
        "collectwifidmesgrooot")
        collectwifidmesgrooot
    ;;
        "touchwifidumpfinishfile")
        touchwifidumpfinishfile
    ;;
    #endif /* OPLUS_FEATURE_WIFI_DUMP */
    #ifdef OPLUS_FEATURE_WIFI_SWITCH
    #JiaoBo@CONNECTIVITY.WIFI.BASIC.SWITCH.1069763, 2020/02/20, Add for collect wifi switch log
        "collectWifiSwitchLog")
        collectWifiSwitchLog
    ;;
        "packWifiSwitchLog")
        packWifiSwitchLog
    ;;
        "collectwifidmesgroootwifiswitch")
        collectwifidmesgroootwifiswitch
    ;;
    #endif /* OPLUS_FEATURE_WIFI_SWITCH */
    #ifdef OPLUS_FEATURE_WIFI_SNIFFER
    #LiangXiao@CONNECTIVITY.WIFI.BASIC.Sniffer.7267, 2020/09/20, Add for collect wifi sniffer log
        "copysnifferlog")
        copysnifferlog
    ;;
    #endif /* OPLUS_FEATURE_WIFI_SNIFFER */
esac
