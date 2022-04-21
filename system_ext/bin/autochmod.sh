#! /system/bin/sh

CURTIME=`date +%F_%H-%M-%S`
CURTIME_FORMAT=`date "+%Y-%m-%d %H:%M:%S"`

BASE_PATH=/sdcard
SDCARD_LOG_BASE_PATH=${BASE_PATH}/Android/data/com.coloros.logkit/files/Log
SDCARD_LOG_TRIGGER_PATH=${SDCARD_LOG_BASE_PATH}/trigger

DATA_DEBUGGING_PATH=/data/oppo_log
DATA_OPLUS_LOG_PATH=/data/oppo/log
ANR_BINDER_PATH=${DATA_DEBUGGING_PATH}/anr_binder_info
CACHE_PATH=${DATA_DEBUGGING_PATH}/cache

config="$1"

#================================== COMMON LOG =========================
#ifdef OPLUS_FEATURE_LOGKIT
function logObserver() {
    # 1, data free size
    boot_completed=`getprop sys.boot_completed`
    while [ x${boot_completed} != x"1" ];do
        traceTransferState "log observer:device don't boot completed"
        sleep 10
        boot_completed=`getprop sys.boot_completed`
    done

    FreeSize=`df /data | grep -v Mounted | awk '{print $4}'`
    traceTransferState "LOGOBSERVER:free size ${FreeSize}"

    # 2, count log size
    LOG_CONFIG_FILE="${DATA_OPLUS_LOG_PATH}/config/log_config.log"
    LOG_COUNT_SIZE=0
    if [ -f "${LOG_CONFIG_FILE}" ]; then
        while read -r ITEM_CONFIG
        do
            if [ "" != "${ITEM_CONFIG}" ];then
                #echo "${CURTIME_FORMAT} transfer log config: ${ITEM_CONFIG}"
                SOURCE_PATH=`echo ${ITEM_CONFIG} | awk '{print $2}'`
                if [ -d ${SOURCE_PATH} ];then
                    TEMP_SIZE=`du -s ${SOURCE_PATH} | awk '{print $1}'`
                    if [ "" != "${TEMP_SIZE}" ]; then
                        LOG_COUNT_SIZE=`expr ${LOG_COUNT_SIZE} + ${TEMP_SIZE}`
                    fi
                    traceTransferState "PATH: ${SOURCE_PATH}, ${TEMP_SIZE}/${LOG_COUNT_SIZE}"
                else
                    echo "${CURTIME_FORMAT} PATH: ${SOURCE_PATH}, No such file or directory"
                fi
            fi
        done < ${LOG_CONFIG_FILE}
    fi

    settings put global logkit_observer_size "${FreeSize}|${LOG_COUNT_SIZE}"
    # settings get global logkit_observer_size
    traceTransferState "LOGOBSERVER:data free and log size: ${FreeSize}|${LOG_COUNT_SIZE}"
}

function backup_unboot_log(){
    i=1
    while [ true ];do
        if [ ! -d /cache/unboot_$i ];then
            is_folder_empty=`ls $CACHE_PATH/*`
            if [ "$is_folder_empty" = "" ];then
                echo "folder is empty"
            else
                echo "mv /cache/admin /cache/unboot_"
                mv ${DATA_DEBUGGING_PATH}/cache ${DATA_DEBUGGING_PATH}/unboot_$i
            fi
            break
        else
            i=`$XKIT expr $i + 1`
        fi
        if [ $i -gt 5 ];then
            break
        fi
    done
}

function initcache(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    boot_completed=`getprop sys.boot_completed`
    if [ x"${panicenable}" = x"true" ] || [ x"${camerapanic}" = x"true" ] && [ x"${boot_completed}" != x"1" ]; then
        if [ ! -d /dev/log ];then
            mkdir -p /dev/log
            chmod -R 755 /dev/log
        fi
        is_admin_empty=`ls $CACHE_PATH | wc -l`
        if [ "$is_admin_empty" != "0" ];then
            echo "backup_unboot_log"
            backup_unboot_log
        fi
        traceTransferState "INITCACHE: mkdir ${CACHE_PATH}"
        mkdir -p ${CACHE_PATH}
        mkdir -p ${CACHE_PATH}/apps
        mkdir -p ${CACHE_PATH}/kernel
        mkdir -p ${CACHE_PATH}/netlog
        mkdir -p ${CACHE_PATH}/fingerprint
        chmod -R 777 ${CACHE_PATH}
        setprop sys.oplus.collectcache.start true
    fi
}

function logcatcache(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
    /system/bin/logcat -G 16M
    /system/bin/logcat -f ${CACHE_PATH}/apps/android_boot.txt -r10240 -n 5 -v threadtime
    fi
}
function radiocache(){
    radioenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    argtrue='true'
    if [ "${radioenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
    /system/bin/logcat -b radio -f ${CACHE_PATH}/apps/radio_boot.txt -r4096 -n 3 -v threadtime
    fi
}
function eventcache(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
    /system/bin/logcat -b events -f ${CACHE_PATH}/apps/events_boot.txt -r4096 -n 10 -v threadtime
    fi
}

function kernelcache(){
  panicenable=`getprop persist.sys.assert.panic`
  camerapanic=`getprop persist.sys.assert.panic.camera`
  argtrue='true'
  if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
  dmesg > ${CACHE_PATH}/kernel/kinfo_boot.txt
  cat proc/boot_dmesg > ${CACHE_PATH}/kernel/uboot.txt
  cat proc/bootloader_log > ${CACHE_PATH}/kernel/bootloader.txt
  cat /sys/pmic_info/pon_reason > ${CACHE_PATH}/kernel/pon_poff_reason.txt
  cat /sys/pmic_info/poff_reason >> ${CACHE_PATH}/kernel/pon_poff_reason.txt
  cat /sys/pmic_info/ocp_status >> ${CACHE_PATH}/kernel/pon_poff_reason.txt
  /system/system_ext/xbin/klogd -f ${CACHE_PATH}/kernel/kinfo_boot0.txt -n -x -l 7
  fi
}
#endif OPLUS_FEATURE_LOGKIT
#================================== COMMON LOG =========================

#================================== POWER =========================
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OppoPowerMonitor get dmesg at O
function kernelcacheforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  chmod 777 -R ${DATA_DEBUGGING_PATH}/
  
  mkdir -p /data/oppo/psw/powermonitor
  chmod 777 -R /data/oppo/psw/powermonitor
  chmod 777 -R ${opmlogpath}

  temp_kernel_dir=${DATA_DEBUGGING_PATH}/powermonitor_temp/kernel

  mkdir -p ${temp_kernel_dir}
  chown system:system ${temp_kernel_dir}
  chmod 777 -R ${DATA_DEBUGGING_PATH}/powermonitor_temp
  chmod 777 -R ${temp_kernel_dir}

  touch ${temp_kernel_dir}/dmesg.txt
  chown system:system ${temp_kernel_dir}/dmesg.txt
  chmod 777 -R ${temp_kernel_dir}/dmesg.txt

  dmesg > ${temp_kernel_dir}/dmesg.txt

  cp ${temp_kernel_dir}/dmesg.txt ${opmlogpath}dmesg.txt
  chown system:system ${opmlogpath}dmesg.txt
  chmod 777 -R ${opmlogpath}dmesg.txt
  
  rm -rf ${DATA_DEBUGGING_PATH}/powermonitor_temp
}

#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OppoPowerMonitor get Sysinfo at O
function psforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  ps -A -T > ${opmlogpath}psO.txt
  chown system:system ${opmlogpath}psO.txt
}
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2019/08/21, Add for OppoPowerMonitor get qrtr at Qcom
function qrtrlookupforopm() {
    echo "qrtrlookup begin"
    opmlogpath=`getprop sys.opm.logpath`
    if [ -d "/d/ipc_logging" ]; then
        echo ${opmlogpath}
        /vendor/bin/qrtr-lookup > ${opmlogpath}/qrtr-lookup_info.txt
        chown system:system ${opmlogpath}/qrtr-lookup_info.txt
    fi
    echo "qrtrlookup end"
}

function cpufreqforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/devices/system/cpu/*/cpufreq/scaling_cur_freq > ${opmlogpath}cpufreq.txt
  chown system:system ${opmlogpath}cpufreq.txt
}

function logcatMainCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -v threadtime -d > ${opmlogpath}logcat.txt
  chown system:system ${opmlogpath}logcat.txt
}

function logcatEventCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -b events -d > ${opmlogpath}events.txt
  chown system:system ${opmlogpath}events.txt
}

function logcatRadioCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -b radio -d > ${opmlogpath}radio.txt
  chown system:system ${opmlogpath}radio.txt
}

function catchBinderInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/kernel/debug/binder/state > ${opmlogpath}binderinfo.txt
  chown system:system ${opmlogpath}binderinfo.txt
}

function catchBattertFccForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/class/power_supply/battery/batt_fcc > ${opmlogpath}fcc.txt
  chown system:system ${opmlogpath}fcc.txt
}

function catchTopInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  opmfilename=`getprop sys.opm.logpath.filename`
  top -H -n 3 > ${opmlogpath}${opmfilename}top.txt
  chown system:system ${opmlogpath}${opmfilename}top.txt
}

function dumpsysHansHistoryForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys activity hans history > ${opmlogpath}hans.txt
  chown system:system ${opmlogpath}hans.txt
}

function dumpsysSurfaceFlingerForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys sensorservice > ${opmlogpath}sensorservice.txt
  chown system:system ${opmlogpath}sensorservice.txt
}

function dumpsysSensorserviceForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys sensorservice > ${opmlogpath}sensorservice.txt
  chown system:system ${opmlogpath}sensorservice.txt
}

function dumpsysBatterystatsForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats > ${opmlogpath}batterystats.txt
  chown system:system ${opmlogpath}batterystats.txt
}

function dumpsysBatterystatsOplusCheckinForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats --oppoCheckin > ${opmlogpath}batterystats_oplusCheckin.txt
  chown system:system ${opmlogpath}batterystats_oplusCheckin.txt
}

function dumpsysBatterystatsCheckinForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats -c > ${opmlogpath}batterystats_checkin.txt
  chown system:system ${opmlogpath}batterystats_checkin.txt
}

function dumpsysMediaForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys media.audio_flinger > ${opmlogpath}audio_flinger.txt
  dumpsys media.audio_policy > ${opmlogpath}audio_policy.txt
  dumpsys audio > ${opmlogpath}audio.txt

  chown system:system ${opmlogpath}audio_flinger.txt
  chown system:system ${opmlogpath}audio_policy.txt
  chown system:system ${opmlogpath}audio.txt
}

function getPropForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  getprop > ${opmlogpath}prop.txt
  chown system:system ${opmlogpath}prop.txt
}

function logcusMainForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    /system/bin/logcat -f ${opmlogpath}/android.txt -r 10240 -n 5 -v threadtime *:V
}

function logcusEventForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    /system/bin/logcat -b events -f ${opmlogpath}/event.txt -r 10240 -n 5 -v threadtime *:V
}

function logcusRadioForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    /system/bin/logcat -b radio -f ${opmlogpath}/radio.txt -r 10240 -n 5 -v threadtime *:V
}

function logcusKernelForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    /system/system_ext/xbin/klogd -f - -n -x -l 7 | tee - ${opmlogpath}/kernel.txt | awk 'NR%400==0'
}

function logcusTCPForOpm() {
    opmlogpath=`getprop sys.opm.logpath`
    tcpdump -i any -p -s 0 -W 1 -C 50 -w ${opmlogpath}/tcpdump.pcap
}

function customDiaglogForOpm() {
    echo "customdiaglog opm begin"
    opmlogpath=`getprop sys.opm.logpath`
    mv ${DATA_DEBUGGING_PATH}/diag_logs ${opmlogpath}
    chmod 777 -R ${opmlogpath}
    restorecon -RF ${opmlogpath}
    echo "customdiaglog opm end"
}

#================================== POWER =========================

#================================== PERFORMANCE =========================
function dmaprocsforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/kernel/debug/ion/heaps/system > ${opmlogpath}dmaprocs.txt
  cat /sys/kernel/debug/dma_buf/dmaprocs >> ${opmlogpath}dmaprocs.txt
  chown system:system ${opmlogpath}dmaprocs.txt
}
function slabinfoforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/slabinfo > ${opmlogpath}slabinfo.txt
  cat /sys/kernel/debug/page_owner > ${opmlogpath}pageowner.txt
  chown system:system ${opmlogpath}slabinfo.txt
  chown system:system ${opmlogpath}pageowner.txt
}
function svelteforhealth(){
  sveltetracer=`getprop sys.opm.svelte_tracer`
  svelteops=`getprop sys.opm.svelte_ops`
  svelteargs=`getprop sys.opm.svelte_args`
  opmlogpath=`getprop sys.opm.logpath`
  /system_ext/bin/svelte tracer -t ${sveltetracer} -o ${svelteops} -a ${svelteargs}
  sleep 12
  chown system:system ${opmlogpath}*svelte.txt
}
function meminfoforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/meminfo > ${opmlogpath}meminfo.txt
  chown system:system ${opmlogpath}meminfo.txt
}

#Yufeng.Liu@Plf.TECH.Performance, 2019/9/3, Add for malloc_debug
function memdebugregister() {
    process=`getprop sys.memdebug.process`
    setprop persist.oppo.mallocdebug.process ${process}
    type=`getprop sys.memdebug.type`
    if [ x"${type}" = x"0" ] || [ x"${type}" = x"1" ]; then
        key="wrap."
        setprop ${key}${process} "LIBC_DEBUG_MALLOC_OPTIONS=backtrace=8"
    fi
    if [ x"${type}" = x"1" ]; then
        setprop sys.memdebug.status 1
        setprop sys.memdebug.reboot false
    else
        setprop sys.memdebug.reboot true
        setprop sys.memdebug.status 0
    fi
}

function memdebugstart() {
    process=`getprop persist.oppo.mallocdebug.process`
    if [ x"${process}" = x"system" ]; then
        pid=`getprop persist.sys.systemserver.pid`
    else
        pid=`getprop sys.memdebug.pid`
    fi
    type=`getprop sys.memdebug.type`
    if [ x"${type}" = x"0" ] || [ x"${type}" = x"2" ]; then
        kill -45 ${pid}
    fi
    setprop sys.memdebug.status 1
    setprop sys.memdebug.reboot false
}

function memdebugdump() {
    process=`getprop persist.oppo.mallocdebug.process`
    if [ x"${process}" = x"system" ]; then
        pid=`getprop persist.sys.systemserver.pid`
    else
        pid=`getprop sys.memdebug.pid`
    fi
    kill -47 ${pid}
    dumpfile_path="${DATA_OPLUS_LOG_PATH}/DCS/de/quality_log/backtrace_heap.${pid}.txt"
    count=0
    while [ ! -f ${dumpfile_path} ] && [ $count -le 6 ];do
        count=$((count + 1))
        sleep 1
    done
    sleep 2
    mv ${DATA_OPLUS_LOG_PATH}/DCS/de/quality_log/backtrace_heap.${pid}.txt ${DATA_OPLUS_LOG_PATH}/DCS/de/quality_log/backtrace_heap.${process}.${pid}.txt
    chown -R system:system ${DATA_OPLUS_LOG_PATH}/DCS/de/quality_log/backtrace_heap.${process}.${pid}.txt
    setprop sys.memdebug.status 2
}

function memdebugremove() {
    process=`getprop persist.oppo.mallocdebug.process`
    type=`getprop sys.memdebug.type`
    if [ x"${type}" = x"0" ] || [ x"${type}" = x"1" ]; then
        key="wrap."
        setprop ${key}${process} ""
    fi
    setprop sys.memdebug.status 3
    setprop sys.memdebug.process ""
    setprop persist.oppo.mallocdebug.process ""
    setprop sys.memdebug.type ""
    setprop sys.memdebug.pid ""
    if [ x"${type}" = x"1" ]; then
        setprop sys.memdebug.reboot false
    else
        setprop sys.memdebug.reboot true
    fi
}
#================================== PERFORMANCE =========================

#================================== NETWORK =========================
function tcpdumpcache(){
    tcpdmpenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    argtrue='true'
    if [ "${tcpdmpenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
        tcpdump -i any -p -s 0 -W 2 -C 10 -w ${CACHE_PATH}/netlog/tcpdump_boot -Z root
    fi
}

function tcpDumpLog(){
    panicenable=`getprop persist.sys.assert.panic`
    DATA_LOG_TCPDUMPLOG_PATH=`getprop sys.oplus.logkit.netlog`
    #LiuHaipeng@NETWORK.DATA, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
    echo "tcpDumpLog tcpdumpSize=${tcpdumpSize} tcpdumpCount=${tcpdumpCount} tcpdumpPacketSize=${tcpdumpPacketSize}"
    if [ "${panicenable}" = "true" ] && [ "${tmpTcpdump}" != "" ]; then
        #ifndef OPLUS_FEATURE_TCPDUMP
        #DuYuanhua@NETWORK.DATA.2959182, keep root priviledge temporarily for rutils-remove action
        #tcpdump -i any -p -s 0 -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${DATA_LOG_TCPDUMPLOG_PATH}/tcpdump -Z root
        #else
        #LiuHaipeng@NETWORK.DATA, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
        tcpdump -i any -p -s ${tcpdumpPacketSize} -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${DATA_LOG_TCPDUMPLOG_PATH}/tcpdump
        #endif
    fi
}
#================================== NETWORK =========================

#================================== FINGERPRINT =========================
function fingerprintcache(){
    platform=`getprop ro.board.platform`
    echo "platform ${platform}"
    state=`cat /proc/oplus_secure_common/secureSNBound`

    if [ ${state} != "0" ]
    then
        cat /sys/kernel/debug/tzdbg/log > ${CACHE_PATH}/fingerprint/fingerprint_boot.txt
        if [ -f /proc/tzdbg/log ]
        then
            cat /proc/tzdbg/log > ${CACHE_PATH}/fingerprint/fingerprint_boot.txt
        fi
    fi
}

function fplogcache(){
    platform=`getprop ro.board.platform`

    state=`cat /proc/oplus_secure_common/secureSNBound`

    if [ ${state} != "0" ]
    then
        cat /sys/kernel/debug/tzdbg/qsee_log > ${CACHE_PATH}/fingerprint/qsee_boot.txt
        if [ -f /proc/tzdbg/qsee_log ]
        then
            cat /proc/tzdbg/qsee_log > ${CACHE_PATH}/fingerprint/qsee_boot.txt
        fi
    fi
}

function fingerprintLog(){
    countfp=1
    state=`cat /proc/oplus_secure_common/secureSNBound`
    echo "fingerprint state = ${state}"
    if [ ${state} != "0" ];then
        FP_LOG_PATH=`getprop sys.oplus.logkit.fingerprintlog`
        echo "fingerprint in loop"
        while true
        do
            cat /sys/kernel/debug/tzdbg/log > ${FP_LOG_PATH}/fingerprint_log${countfp}.txt
            if [ -f /proc/tzdbg/log ]
            then
                cat /proc/tzdbg/log > ${FP_LOG_PATH}/fingerprint_log${countfp}.txt
            fi
            if [ ! -s ${FP_LOG_PATH}/fingerprint_log${countfp}.txt ];then
                rm ${FP_LOG_PATH}/fingerprint_log${countfp}.txt;
            fi
            ((countfp++))
            sleep 1
        done
    fi
}

function fingerprintQseeLog(){
    countqsee=1
    state=`cat /proc/oplus_secure_common/secureSNBound`
    echo "fingerprint state = ${state}"
    if [ ${state} != "0" ];then
        FP_LOG_PATH=`getprop sys.oplus.logkit.fingerprintlog`
        echo "fingerprint qsee in loop"
        while true
        do
            cat /sys/kernel/debug/tzdbg/qsee_log > ${FP_LOG_PATH}/qsee_log${countqsee}.txt
            if [ -f /proc/tzdbg/qsee_log ]
            then
                cat /proc/tzdbg/qsee_log > ${FP_LOG_PATH}/qsee_log${countqsee}.txt
            fi
            if [ ! -s ${FP_LOG_PATH}/qsee_log${countqsee}.txt ];then
                rm ${FP_LOG_PATH}/qsee_log${countqsee}.txt;
            fi
            ((countqsee++))
            sleep 1
        done
    fi
}
#================================== FINGERPRINT =========================

#================================== COMMON LOG =========================
function initOplusLog(){
    if [ ! -d /dev/log ];then
        mkdir -p /dev/log
        chmod -R 755 /dev/log
    fi
    traceTransferState "INITOPLUSLOG: start..."

    # TODO less 2G stop logcat, return
    PANICE_NABLE=`getprop persist.sys.assert.panic`
    CAMERA_PANIC_ENABLE=`getprop persist.sys.assert.panic.camera`
    if [ "${PANICE_NABLE}" = "true" ] || [ x"${CAMERA_PANIC_ENABLE}" = x"true" ]; then
        boot_completed=`getprop sys.boot_completed`
        decrypt_delay=0
        while [ x${boot_completed} != x"1" ];do
            sleep 1
            decrypt_delay=`expr $decrypt_delay + 1`
            boot_completed=`getprop sys.boot_completed`
        done

        echo "start mkdir"
        DATA_LOG_DEBUG_PATH=${DATA_DEBUGGING_PATH}/${CURTIME}
        mkdir -p  ${DATA_LOG_DEBUG_PATH}

        mkdir -p  ${ANR_BINDER_PATH}
        chmod -R 777 ${ANR_BINDER_PATH}
        chown system:system ${ANR_BINDER_PATH}

        decrypt='false'
        if [ x"${decrypt}" != x"true" ]; then
            setprop ctl.stop logcatcache
            setprop ctl.stop radiocache
            setprop ctl.stop eventcache
            setprop ctl.stop kernelcache
            setprop ctl.stop fingerprintcache
            setprop ctl.stop fplogcache
            setprop ctl.stop tcpdumpcache
            traceTransferState "INITOPLUSLOG: mv cache log..."
            mv ${CACHE_PATH}/* ${DATA_LOG_DEBUG_PATH}/
            mv ${DATA_DEBUGGING_PATH}/unboot_* ${DATA_LOG_DEBUG_PATH}/
        fi

        setprop persist.sys.com.oplus.debug.time ${CURTIME}
        echo ${CURTIME} >> ${DATA_DEBUGGING_PATH}/log_history.txt
        echo ${CURTIME} >> ${DATA_DEBUGGING_PATH}/transfer_list.txt
        traceTransferState "INITOPLUSLOG:start debug time: ${CURTIME}"

        #setprop sys.oppo.collectlog.start true
        startCollectLog

        initLogSizeAndNums
    fi
}

function disableCameraOfflineProp(){
    PROP_DISABLE_OFFLINE=`getprop persist.sys.engineering.pre.disableoffline`
    PROP_OFFLINE=`getprop persist.sys.log.offline`
    if [ x"${PROP_OFFLINE}" == x"true" ] && [ x"${PROP_DISABLE_OFFLINE}" != x"false" ]; then
        setprop persist.sys.log.offline false
        setprop persist.sys.engineering.pre.disableoffline false
    fi
}

function startCollectLog(){
    startCollectCommonLog

    # TODO only for camera tmp plan on android R
    disableCameraOfflineProp

    LOG_TYPE=`getprop persist.sys.oppo.log.config`
    if [ "${LOG_TYPE}" == "call" ]; then
        startCollectCallLog
    elif [ "${LOG_TYPE}" == "media" ];then
        startCollectMediaLog
    elif [ "${LOG_TYPE}" == "bluetooth" ];then
        startCollectBluetoothLog
    elif [ "${LOG_TYPE}" == "gps" ];then
        startCollectGPSLog
    elif [ "${LOG_TYPE}" == "network" ];then
        startCollectDataNetworkLog
    elif [ "${LOG_TYPE}" == "wifi" ];then
        startCollectWifiLog
    elif [ "${LOG_TYPE}" == "junk" ];then
        startCollectPerformanceLog
    elif [ "${LOG_TYPE}" == "stability" ];then
        startCollectStabilityLog
    elif [ "${LOG_TYPE}" == "heat" ];then
        startCollectThermalLog
    elif [ "${LOG_TYPE}" == "power" ];then
        startCollectPowerLog
    elif [ "${LOG_TYPE}" == "charge" ];then
        startCollectChargingLog
    elif [ "${LOG_TYPE}" == "thirdpart" ];then
        startCollectAppsLog
    elif [ "${LOG_TYPE}" == "camera" ];then
        startCollectCameraLog
    elif [ "${LOG_TYPE}" == "sensor" ];then
        startCollectSensorLog
    elif [ "${LOG_TYPE}" == "touch" ];then
        startCollectTouchLog
    elif [ "${LOG_TYPE}" == "fingerprint" ];then
        startCollectFingerprintLog
    else
        #other
        startCollectOtherLog
    fi
}

function startCollectCommonLog(){

    DATA_LOG_APPS_PATH=${DATA_LOG_DEBUG_PATH}/apps
    DATA_LOG_KERNEL_PATH=${DATA_LOG_DEBUG_PATH}/kernel
    ASSERT_PATH=${DATA_LOG_DEBUG_PATH}/oppo_assert
    TOMBSTONE_PATH=${DATA_LOG_DEBUG_PATH}/tombstone
    ANR_PATH=${DATA_LOG_DEBUG_PATH}/anr
    mkdir -p  ${DATA_LOG_APPS_PATH}
    mkdir -p  ${DATA_LOG_KERNEL_PATH}
    mkdir -p  ${ASSERT_PATH}
    mkdir -p  ${TOMBSTONE_PATH}
    mkdir -p  ${ANR_PATH}
    chmod -R 777 ${DATA_LOG_DEBUG_PATH}
    setprop sys.oplus.logkit.appslog ${DATA_LOG_APPS_PATH}
    setprop sys.oplus.logkit.kernellog ${DATA_LOG_KERNEL_PATH}
    setprop sys.oplus.logkit.assertlog ${ASSERT_PATH}
    setprop sys.oplus.logkit.anrlog ${ANR_PATH}
    setprop sys.oplus.logkit.tombstonelog ${TOMBSTONE_PATH}
    getLogStatistics

    start logcatsdcard
    start logcatradio
    start logcatevent
    start logcatkernel
}
function startCollectCallLog(){
    DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_DEBUG_PATH}/netlog
    mkdir -p  ${DATA_LOG_TCPDUMPLOG_PATH}
    setprop sys.oplus.logkit.netlog ${DATA_LOG_TCPDUMPLOG_PATH}

    start tcpdumplog
    start logcatSsLog
}
function startCollectMediaLog(){
    # TODO
}
function startCollectBluetoothLog(){

}
function startCollectGPSLog(){
    #ifndef OPLUS_GPS_LOG
    #ShiMinghao@CONNECTIVITY.GPS, 2021/02/09, Enable tcpdump when capturing GPS Log for network locationing
    DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_DEBUG_PATH}/netlog
    mkdir -p  ${DATA_LOG_TCPDUMPLOG_PATH}
    setprop sys.oplus.logkit.netlog ${DATA_LOG_TCPDUMPLOG_PATH}

    start tcpdumplog
    #endif /* OPLUS_GPS_LOG */
}
function startCollectDataNetworkLog(){
    DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_DEBUG_PATH}/netlog
    QMI_PATH=${DATA_LOG_DEBUG_PATH}/qmi
    mkdir -p  ${DATA_LOG_TCPDUMPLOG_PATH}
    mkdir -p  ${QMI_PATH}
    setprop sys.oplus.logkit.netlog ${DATA_LOG_TCPDUMPLOG_PATH}
    setprop sys.oplus.logkit.qmilog ${QMI_PATH}

    start tcpdumplog
    start qmilogon
    start logcatSsLog
}
function startCollectWifiLog(){

    DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_DEBUG_PATH}/netlog
    QMI_PATH=${DATA_LOG_DEBUG_PATH}/qmi
    mkdir -p  ${DATA_LOG_TCPDUMPLOG_PATH}
    mkdir -p  ${QMI_PATH}
    setprop sys.oplus.logkit.netlog ${DATA_LOG_TCPDUMPLOG_PATH}
    setprop sys.oplus.logkit.qmilog ${QMI_PATH}

    start tcpdumplog
    start qmilogon
    start logcatSsLog
}
function startCollectPerformanceLog(){

}
function startCollectStabilityLog(){

}
function startCollectThermalLog(){
    DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_DEBUG_PATH}/netlog
    QMI_PATH=${DATA_LOG_DEBUG_PATH}/qmi
    mkdir -p  ${DATA_LOG_TCPDUMPLOG_PATH}
    mkdir -p  ${QMI_PATH}
    setprop sys.oplus.logkit.netlog ${DATA_LOG_TCPDUMPLOG_PATH}
    setprop sys.oplus.logkit.qmilog ${QMI_PATH}

    start tcpdumplog
    start qmilogon
    start logcatSsLog
}
function startCollectPowerLog(){
    DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_DEBUG_PATH}/netlog
    QMI_PATH=${DATA_LOG_DEBUG_PATH}/qmi
    mkdir -p  ${DATA_LOG_TCPDUMPLOG_PATH}
    mkdir -p  ${QMI_PATH}
    setprop sys.oplus.logkit.netlog ${DATA_LOG_TCPDUMPLOG_PATH}
    setprop sys.oplus.logkit.qmilog ${QMI_PATH}

    start tcpdumplog
    start qmilogon
    start logcatSsLog
}
function startCollectChargingLog(){

}
function startCollectAppsLog(){
    DATA_LOG_FINGERPRINTERLOG_PATH=${DATA_LOG_DEBUG_PATH}/fingerprint
    mkdir -p  ${DATA_LOG_FINGERPRINTERLOG_PATH}
    chmod 777 -R ${DATA_LOG_FINGERPRINTERLOG_PATH}
    setprop sys.oppo.logkit.fingerprintlog ${DATA_LOG_FINGERPRINTERLOG_PATH}

    start fingerprintlog
    start fplogqess
    # Add for catching fingerprint and face log
    dumpsys fingerprint log all 1
    dumpsys face log all 1
}
function startCollectCameraLog(){

}
function startCollectSensorLog(){

    DATA_LOG_FINGERPRINTERLOG_PATH=${DATA_LOG_DEBUG_PATH}/fingerprint
    mkdir -p  ${DATA_LOG_FINGERPRINTERLOG_PATH}
    chmod 777 -R ${DATA_LOG_FINGERPRINTERLOG_PATH}
    setprop sys.oplus.logkit.fingerprintlog ${DATA_LOG_FINGERPRINTERLOG_PATH}

    start fingerprintlog
    start fplogqess
    # Add for catching fingerprint and face log
    dumpsys fingerprint log all 1
    dumpsys face log all 1
}
function startCollectTouchLog(){

}
function startCollectFingerprintLog(){

    DATA_LOG_FINGERPRINTERLOG_PATH=${DATA_LOG_DEBUG_PATH}/fingerprint
    mkdir -p  ${DATA_LOG_FINGERPRINTERLOG_PATH}
    chmod 777 -R ${DATA_LOG_FINGERPRINTERLOG_PATH}
    setprop sys.oppo.logkit.fingerprintlog ${DATA_LOG_FINGERPRINTERLOG_PATH}

    start fingerprintlog
    start fplogqess
    # Add for catching fingerprint and face log
    dumpsys fingerprint log all 1
    dumpsys face log all 1
}
function startCollectOtherLog(){
    DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_DEBUG_PATH}/netlog
    QMI_PATH=${DATA_LOG_DEBUG_PATH}/qmi
    mkdir -p  ${DATA_LOG_TCPDUMPLOG_PATH}
    mkdir -p  ${QMI_PATH}
    setprop sys.oplus.logkit.netlog ${DATA_LOG_TCPDUMPLOG_PATH}
    setprop sys.oplus.logkit.qmilog ${QMI_PATH}

    start tcpdumplog
    start qmilogon

    DATA_LOG_FINGERPRINTERLOG_PATH=${DATA_LOG_DEBUG_PATH}/fingerprint
    mkdir -p  ${DATA_LOG_FINGERPRINTERLOG_PATH}
    chmod 777 -R ${DATA_LOG_FINGERPRINTERLOG_PATH}
    setprop sys.oppo.logkit.fingerprintlog ${DATA_LOG_FINGERPRINTERLOG_PATH}

    start fingerprintlog
    start fplogqess
    start logcatSsLog
    # Add for catching fingerprint and face log
    dumpsys fingerprint log all 1
    dumpsys face log all 1
}

function dumpsysInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    dumpsys > ${SDCARD_LOG_TRIGGER_PATH}/dumpsys_all_${CURTIME}.txt;
}
function dumpStateInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    dumpstate > ${SDCARD_LOG_TRIGGER_PATH}/dumpstate_${CURTIME}.txt
}
function topInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    top -n 1 > ${SDCARD_LOG_TRIGGER_PATH}/top_${CURTIME}.txt;
}
function psInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    ps > ${SDCARD_LOG_TRIGGER_PATH}/ps_${CURTIME}.txt;
}

function serviceListInfo(){
    if [ ! -d ${SDCARD_LOG_TRIGGER_PATH} ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    service list > ${SDCARD_LOG_TRIGGER_PATH}/service_list_${CURTIME}.txt;
}

function dumpStorageInfo() {
    STORAGE_PATH=${SDCARD_LOG_TRIGGER_PATH}/storage
    if [ ! -d ${STORAGE_PATH} ];then
        mkdir -p ${STORAGE_PATH}
    fi

    mount > ${STORAGE_PATH}/mount.txt
    dumpsys devicestoragemonitor > ${STORAGE_PATH}/dumpsys_devicestoragemonitor.txt
    dumpsys mount > ${STORAGE_PATH}/dumpsys_mount.txt
    dumpsys diskstats > ${STORAGE_PATH}/dumpsys_diskstats.txt
    du -H /data > ${STORAGE_PATH}/diskUsage.txt
}

function CleanAll(){
    rm -rf /cache/admin
    rm -rf /data/core/*
    if [ -d  ${DATA_DEBUGGING_PATH} ];
    then
        all_logs=`ls ${DATA_DEBUGGING_PATH} |grep -v junk_logs`
        for i in ${all_logs};do
        echo ${i}
        if [ -d ${DATA_DEBUGGING_PATH}/${i} ] || [ -f ${DATA_DEBUGGING_PATH}/${i} ]
        then
        echo "rm -rf ===>"${i}
        rm -rf ${DATA_DEBUGGING_PATH}/${i}
        fi
        done
    fi

    #add for TF card begin
    is_tf_card=`ls /mnt/media_rw/ | wc -l`
    tfcard_id=`ls /mnt/media_rw/`
    tf_config=`getprop persist.sys.log.tf`
    if [ "${tf_config}" = "true" ] && [ "$is_tf_card" != "0" ];then
        DATA_DEBUGGING_PATH="/mnt/media_rw/${tfcard_id}/oppo_log"
    fi

    if [ -d  ${DATA_DEBUGGING_PATH} ];
    then
        all_logs=`ls ${DATA_DEBUGGING_PATH} |grep -v junk_logs`
        for i in ${all_logs};do
        echo ${i}
        #delete all folder or files in ${SDCARD_LOG_BASE_PATH},except these files and folders
        if [ -d ${DATA_DEBUGGING_PATH}/${i} ] || [ -f ${DATA_DEBUGGING_PATH}/${i} ] && [ ${i} != "diag_logs" ] && [ ${i} != "diag_pid" ] && [ ${i} != "btsnoop_hci" ]
        then
        echo "rm -rf ===>"${i}
        rm -rf ${DATA_DEBUGGING_PATH}/${i}
        fi
        done
    fi
    #add for TF card end

    if [ -d  ${DATA_DEBUGGING_PATH} ];
    then
        all_logs=`ls ${DATA_DEBUGGING_PATH} |grep -v junk_logs`
        for i in ${all_logs};do
        echo ${i}
        #delete all folder or files in ${SDCARD_LOG_BASE_PATH},except these files and folders
        if [ -d ${DATA_DEBUGGING_PATH}/${i} ] || [ -f ${DATA_DEBUGGING_PATH}/${i} ] && [ ${i} != "diag_logs" ] && [ ${i} != "diag_pid" ] && [ ${i} != "btsnoop_hci" ]
        then
        echo "rm -rf ===>"${i}
        rm -rf ${DATA_DEBUGGING_PATH}/${i}
        fi
        done
    fi

    rm -rf /data/anr/*
    rm -rf /data/tombstones/*
    rm -rf /data/system/dropbox/*
    rm -rf /data/misc/bluetooth/logs/*
    setprop sys.clear.finished 1
}

#ifdef OPLUS_BUG_COMPATIBILITY
#Rui.Liu@ANDROID.COMPATIBILITY, 2020/11/11, Add for copy third part dir file
function copyThridPartDirToCfl() {
    #rm ${SDCARD_LOG_BASE_PATH}/test.log
    copyfinish=`getprop sys.copythirdpartdir.finished`
    if [ "$copyfinish" == "0" ] ;then
        return
    fi
    setprop sys.copythirdpartdir.finished 0
    cfltaskid=`getprop sys.crashbox.thirdpart.taskid`
    cflpath="/sdcard/Android/data/com.oplus.crashbox/files/cfl/${cfltaskid}"
    sourcefullpath=`getprop sys.crashbox.thirdpart.sourcepath`
    #echo "copyThridPartDirToOneTrace $sourcefullpath" >> ${SDCARD_LOG_BASE_PATH}/test.log
    #echo "copyThridPartDirToOneTrace $cflpath" >> ${SDCARD_LOG_BASE_PATH}/test.log
    if [ ! -d ${sourcefullpath} ];then
        #echo "sourcefullpath not exist!return!" >> ${SDCARD_LOG_BASE_PATH}/test.log
        return
    fi

    #clear file exist over 3 days
    find ${cflpath} -name '*.tar.gz' -mtime +3 | xargs rm -rf

    #cflpath LIMIT_SIZE is 450M, if still exceed, we have to clear it
    LIMIT_SIZE="460800"
    TMP_SIZE=`du -s -k ${cflpath} | awk '{print $1}'`
    #echo "TMP_SIZE:${TMP_SIZE};;;;LIMIT_SIZE:${LIMIT_SIZE}" >> ${SDCARD_LOG_BASE_PATH}/test.log
    if [ ${TMP_SIZE} -ge ${LIMIT_SIZE} ]; then
        #echo "clear all cfl!" >> ${SDCARD_LOG_BASE_PATH}/test.log
        rm -rf ${cflpath}
    fi
    if [ ! -d ${cflpath} ];then
        mkdir -p ${cflpath}
    fi

    # for weixin
    #wechat="com.tencent.mm"
    #if [[ $sourcefullpath == *$wechat* ]]; then
        #echo "into wechat" >> ${SDCARD_LOG_BASE_PATH}/test.log
        #targetstamp=$(date +%s)
        #targetdate=$(date +%Y%m%d)
        # collect lastest 15 days wechat xlog
        #for i in `seq 1 15`; do
            #tarWechatFileWithDateToTargerPath ${targetdate} ${sourcefullpath} ${cflpath}
            # for each day(24*60*60=86400), collect its xlog
            #let targetstamp=${targetstamp}-86400;
            #let targetdate=$(date -d @${targetstamp} +%Y%m%d)
        #done
    #else
        # for qq or other third-part, just tar all log
        # for other third part or path, pls contact saft&privacy to ensure it is legitimate
        #echo "into others" >> ${SDCARD_LOG_BASE_PATH}/test.log
        tarAllFileToTargerPath ${sourcefullpath} ${cflpath}
    #fi
    chmod -R 777 ${cflpath}
    setprop sys.copythirdpartdir.finished 1
}

function tarWechatFileWithDateToTargerPath() {
    STRING_DATE="$1"
    SOURCE_PATH="$2"
    TARGET_PATH="$3"
    TEMP_PATH="${TARGET_PATH}/${STRING_DATE}"
    targetzip="${TARGET_PATH}/${STRING_DATE}.tar.gz"
    if [ ! -d ${TEMP_PATH} ];then
        mkdir -p ${TEMP_PATH}
    fi
    cp -rf ${SOURCE_PATH}/*$1* ${TEMP_PATH}
    tar -czvf ${targetzip} -C ${TEMP_PATH} .
    rm -rf ${TEMP_PATH}
}

function tarAllFileToTargerPath() {
    SOURCE_PATH="$1"
    TARGET_PATH="$2"
    targetzip="${TARGET_PATH}/result.tar.gz"
    tar -czvf ${targetzip} -C ${SOURCE_PATH} .
}
#endif /* OPLUS_BUG_COMPATIBILITY */

#Chunbo.Gao@ANDROID.DEBUG, 2020/01/17, Add for copy weixin xlog
function copyWeixinXlog() {
    LOG_TYPE=`getprop persist.sys.oppo.log.config`
    if [ "${LOG_TYPE}" != "thirdpart" ]; then
        return
    fi
    stoptime=`getprop sys.oppo.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    saveallxlog=`getprop sys.oppo.log.save_all_xlog`
    argtrue='true'
    XLOG_MAX_NUM=35
    XLOG_IDX=0
    XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
    CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"
    mkdir -p ${newpath}/wechatlog
    if [ "${saveallxlog}" = "${argtrue}" ]; then
        mkdir -p ${newpath}/wechatlog/xlog
        if [ -d "${XLOG_DIR}" ]; then
            cp -rf ${XLOG_DIR}/*.xlog ${newpath}/wechatlog/xlog/
        fi
    else
        if [ -d "${XLOG_DIR}" ]; then
            mkdir -p ${newpath}/wechatlog/xlog
            ALL_FILE=`find ${XLOG_DIR} -iname '*.xlog' | xargs ls -t`
            for i in $ALL_FILE;
            do
                echo "now we have Xlog file $i"
                let XLOG_IDX=$XLOG_IDX+1;
                echo ========file num is $XLOG_IDX===========
                if [ "$XLOG_IDX" -lt $XLOG_MAX_NUM ] ; then
                    #echo  $i >> ${newpath}/xlog/.xlog.txt
                    cp $i ${newpath}/wechatlog/xlog/
                fi
            done
        fi
    fi
    setprop sys.tranfer.finished cp:xlog
    mkdir -p ${newpath}/wechatlog/crash
    if [ -d "${CRASH_DIR}" ]; then
            cp -rf ${CRASH_DIR}/* ${newpath}/wechatlog/crash/
    fi

    XLOG_IDX=0
    if [ "${saveallxlog}" = "${argtrue}" ]; then
        mkdir -p ${newpath}/sub_wechatlog/xlog
        cp -rf /storage/ace-999/Android/data/com.tencent.mm/MicroMsg/xlog/* ${newpath}/sub_wechatlog/xlog
    else
        if [ -d "/storage/ace-999/Android/data/com.tencent.mm/MicroMsg/xlog" ]; then
            mkdir -p ${newpath}/sub_wechatlog/xlog
            ALL_FILE=`ls -t /storage/ace-999/Android/data/com.tencent.mm/MicroMsg/xlog`
            for i in $ALL_FILE;
            do
                echo "now we have subXlog file $i"
                let XLOG_IDX=$XLOG_IDX+1;
                echo ========file num is $XLOG_IDX===========
                if [ "$XLOG_IDX" -lt $XLOG_MAX_NUM ] ; then
                   echo  $i\!;
                    cp  /storage/ace-999/Android/data/com.tencent.mm/MicroMsg/xlog/$i ${newpath}/sub_wechatlog/xlog
                fi
            done
        fi
    fi
    setprop sys.tranfer.finished cp:sub_wechatlog
}

#Rui.Liu@ANDROID.DEBUG, 2020/09/17, Add for copy qq log
function copyQQlog() {
    LOG_TYPE=`getprop persist.sys.oppo.log.config`
    if [ "${LOG_TYPE}" != "thirdpart" ]; then
        return
    fi
    stoptime=`getprop sys.oppo.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    saveallqqlog=`getprop sys.oppo.log.save_all_qqlog`
    argtrue='true'
    QQLOG_MAX_NUM=100
    QQLOG_IDX=0
    QQLOG_DIR="/sdcard/Tencent/msflogs/com/tencent/mobileqq"
    mkdir -p ${newpath}/qqlog
    if [ -d "${QQLOG_DIR}" ]; then
        mkdir -p ${newpath}/qqlog
            QQ_FILE=`find ${QQLOG_DIR} -iname '*log' | xargs ls -t`
        for i in $QQ_FILE;
        do
            echo "now we have QQlog file $i"
            let QQLOG_IDX=$QQLOG_IDX+1;
            echo ========file num is $QQLOG_IDX===========
            if [ "$QQLOG_IDX" -lt $QQLOG_MAX_NUM ] ; then
                cp $i ${newpath}/qqlog
            fi
        done
    fi
    setprop sys.tranfer.finished cp:qqlog

    QQLOG_IDX=0
    if [ -d "/storage/ace-999/Tencent/msflogs/com/tencent/mobileqq" ]; then
        mkdir -p ${newpath}/sub_qqlog
        ALL_FILE=`ls -t /storage/ace-999/Tencent/msflogs/com/tencent/mobileqq`
        for i in $ALL_FILE;
        do
            echo "now we have subQQlog file $i"
            let QQLOG_IDX=$QQLOG_IDX+1;
            echo ========file num is $QQLOG_IDX===========
            if [ "$QQLOG_IDX" -lt $QQLOG_MAX_NUM ] ; then
               echo  $i\!;
                cp  /storage/ace-999/Tencent/msflogs/com/tencent/mobileqq/$i ${newpath}/sub_qqlog
            fi
        done
    fi
    setprop sys.tranfer.finished cp:sub_qqlog
}

function testTransferSystem(){
    setprop sys.oppo.log.stoptime ${CURTIME}
    stoptime=`getprop sys.oppo.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    echo "${newpath}"

    mkdir -p ${newpath}/system
    cp -rf ${DATA_OPLUS_LOG_PATH}/ ${newpath}/system
}

function testTransferRoot(){
    setprop sys.oppo.log.stoptime ${CURTIME}
    stoptime=`getprop sys.oppo.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    mkdir -p ${newpath}
    echo "${newpath}" >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log

    transferRealTimeLog
}

function transferSystrace(){
    SYSTRACE_PATH=/data/local/traces
    checkNumberAndMove "${SYSTRACE_PATH}" "${newpath}/systrace"
}

# service user set to system,group sdcard_rw
function transferUser(){
    stoptime=`getprop sys.oppo.log.stoptime`
    userpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"

    DATA_USER_LOG=/data/system/users/0
    TARGET_DATA_USER_LOG=${userpath}/user_0

    checkNumberSizeAndCopy "${DATA_USER_LOG}" "${TARGET_DATA_USER_LOG}"
}

function tranferDump(){

    # cp bluetooth ramdump
    bluetooth_ramdump=/data/vendor/ramdump/bluetooth
    if [ -d "$bluetooth_ramdump" ]; then
        mkdir -p ${newpath}/dumplog/bluetooth_ramdump
        chmod 666 -R data/vendor/ramdump/bluetooth/*
        cp -rf ${bluetooth_ramdump}/* ${newpath}/dumplog/bluetooth_ramdump/
    fi
    #cp /data/vendor/ssrdump
    ssrdump=/data/vendor/ssrdump
    if [ -d "$ssrdump" ]; then
        mkdir -p ${newpath}/dumplog/ssrdump
        chmod 666 -R data/vendor/ssrdump/*
        cp -rf ${ssrdump}/* ${newpath}/dumplog/ssrdump/
    fi
    #cp adsp dump
    adsp_dump=/data/vendor/mmdump/adsp
    adsp_dump_enable=`getprop persist.sys.adsp_dump.switch`
    if [ "$adsp_dump_enable" == "true" ] && [ -d "$adsp_dump" ]; then
        mkdir -p ${newpath}/dumplog/adsp_dump
        chmod 666 -R data/vendor/mmdump/adsp/*
        cp -rf ${adsp_dump}/* ${newpath}/dumplog/adsp_dump/
    fi

    #wifi log
    tranferWifi
    traceTransferState "transfer log:copy dump done"
}

function tranferWifi(){
    #P wifi log
    mkdir -p ${newpath}/vendor_logs/wifi
    chmod 770 ${DATA_OPLUS_LOG_PATH}/data_vendor/wifi/*
    cp -r ${DATA_OPLUS_LOG_PATH}/data_vendor/wifi/* ${newpath}/vendor_logs/wifi
    rm -rf ${DATA_OPLUS_LOG_PATH}/data_vendor/wifi/*
}

function tranferScreenshots(){
    MAX_NUM=5
    is_release=`getprop ro.build.release_type`
    if [ x"${is_release}" != x"true" ]; then
        #Zhiming.chen@ANDROID.DEBUG.BugID 2724830, 2019/12/17,The log tool captures child user screenshots
        ALL_USER=`ls -t data/media/`
        for m in $ALL_USER;
        do
            IDX=0
            screen_shot="/data/media/$m/DCIM/Screenshots/"
            if [ -d "$screen_shot" ]; then
                mkdir -p ${newpath}/Screenshots/$m
                touch ${newpath}/Screenshots/$m/.nomedia
                ALL_FILE=`ls -t $screen_shot`
                for i in $ALL_FILE;
                do
                    echo "now we have file $i"
                    let IDX=$IDX+1;
                    echo ========file num is $IDX===========
                    if [ "$IDX" -lt $MAX_NUM ] ; then
                       echo  $i\!;
                       cp $screen_shot/$i ${newpath}/Screenshots/$m/
                    fi
                done
            fi
        done
    fi
    traceTransferState "transfer log:copy screenshots done"
}

function transferColorOS(){
    #TraceLog
    TRACELOG=/sdcard/Documents/TraceLog
    checkSizeAndCopy "${TRACELOG}" "os/TraceLog"

    #assistantscreen
    ASSISTANTSCREEN_LOG=/sdcard/Download/AppmonitorSDKLogs/com.coloros.assistantscreen
    checkSizeAndCopy "${ASSISTANTSCREEN_LOG}" "os/Assistantscreen"

    #ovoicemanager
    OVOICEMANAGER_LOG=/data/data/com.oppo.ovoicemanager/files/ovmsAudio
    checkSizeAndCopy "${OVOICEMANAGER_LOG}" "os/Ovoicemanager"

    #OVMS
    OVMS_LOG=/sdcard/Documents/OVMS
    checkSizeAndCopy "${OVMS_LOG}" "os/OVMS"

    #Pictorial
    PICTORIAL_LOG=/sdcard/Android/data/com.heytap.pictorial/files/xlog
    checkSizeAndCopy "${PICTORIAL_LOG}" "os/Pictorial"

    #Camera
    CAMERA_LOG=/sdcard/DCIM/Camera/spdebug
    checkSizeAndCopy "${CAMERA_LOG}" "os/Camera"

    #Browser
    BROWSER_LOG=/sdcard/Android/data/com.heytap.browser/files/xlog
    checkSizeAndCopy "${BROWSER_LOG}" "os/com.heytap.browser"

    #OBRAIN
    OBRAIN_LOG=/sdcard/Android/data/com.oplus.obrain/files/xlog
    checkSizeAndCopy "${OBRAIN_LOG}" "os/com.oplus.obrain"

    #common path
    cp /sdcard/Documents/*/.dog/* ${newpath}/os/
    traceTransferState "transfer log:copy colorOS done"
}

function checkSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    traceTransferState "checksize and transfer:from ${LOG_SOURCE_PATH} to ${LOG_TARGET_PATH}"
    LIMIT_SIZE="10240"

    if [ -d "${LOG_SOURCE_PATH}" ]; then
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        if [ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]; then  #log size less then 10M
            mkdir -p ${newpath}/${LOG_TARGET_PATH}
            cp -rf ${LOG_SOURCE_PATH}/* ${newpath}/${LOG_TARGET_PATH}
            traceTransferState "checkSize and transfer:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "checkSize and transfer:${LOG_SOURCE_PATH} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        fi
    fi
}

function checkNumberAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    traceTransferState "CHECKNUMBERANDCOPY:from ${LOG_SOURCE_PATH} to ${LOG_TARGET_PATH}"
    LIMIT_NUM=1000

    if [ -d "${LOG_SOURCE_PATH}" ] && [ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        traceTransferState "CHECKNUMBERANDCOPY:${LOG_SOURCE_PATH} ${TMP_LOG_NUM}/${LIMIT_NUM}"
        if [ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]; then  #log number less then 1000
            if [ ! -d ${LOG_TARGET_PATH} ];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKNUMBERANDCOPY:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "CHECKNUMBERANDCOPY:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM}"
        fi
    fi
}

function checkNumberSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LOG_LIMIT_NUM="$3"
    LOG_LIMIT_SIZE="$4"
    traceTransferState "CHECKNUMBERSIZEANDCOPY:FROM ${LOG_SOURCE_PATH} TO ${LOG_TARGET_PATH}"
    LIMIT_NUM=1000
    #500*1024KB
    LIMIT_SIZE="512000"

    if [ -d "${LOG_SOURCE_PATH}" ] && [ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        traceTransferState "CHECKNUMBERSIZEANDCOPY:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ] && [ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]; then
            if [ ! -d ${LOG_TARGET_PATH} ];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            cp -rf ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKNUMBERSIZEANDCOPY:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "CHECKNUMBERSIZEANDCOPY:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

function checkNumberSizeAndMove(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LOG_LIMIT_NUM="$3"
    LOG_LIMIT_SIZE="$4"
    traceTransferState "CHECKNUMBERSIZEANDMOVE:FROM ${LOG_SOURCE_PATH} TO ${LOG_TARGET_PATH}"
    LIMIT_NUM=1000
    #500*1024KB
    LIMIT_SIZE="512000"

    if [ -d "${LOG_SOURCE_PATH}" ] && [ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        traceTransferState "CHECKNUMBERSIZEANDMOVE:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ] && [ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]; then
            if [ ! -d ${LOG_TARGET_PATH} ];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            mv ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKNUMBERSIZEANDMOVE:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "CHECKNUMBERSIZEANDMOVE:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

function checkNumberAndMove(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    traceTransferState "checkNumber and move:from ${LOG_SOURCE_PATH} to ${LOG_TARGET_PATH}"
    echo "${CURTIME_FORMAT} checkNumber and move:from ${LOG_SOURCE_PATH} to ${LOG_TARGET_PATH}"
    LIMIT_NUM=2000

    if [ -d "${LOG_SOURCE_PATH}" ] && [ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        echo "${CURTIME_FORMAT} checkNumber and move:${LOG_SOURCE_PATH} ${TMP_LOG_NUM}/${LIMIT_NUM}"
        if [ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]; then  #log number less then 1000
            if [ ! -d ${LOG_TARGET_PATH} ];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            mv ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "checkNumber and move:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "checkNumber and move:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM}"
        fi
    fi
}

function tranferFingerprint(){
    #checkNumberAndMove "/data/vendor_de/0/faceunlock" "${newpath}/faceunlock"

    FINGERPRINT_LOG=${newpath}/fingerprint
    #checkNumberAndCopy "/persist/silead" "${FINGERPRINT_LOG}"
    #checkNumberAndMove "/data/system/silead" "${FINGERPRINT_LOG}"
    #checkNumberAndMove "/data/vendor/optical_fingerprint" "${FINGERPRINT_LOG}"
    #checkNumberAndMove "/data/vendor/fingerprint" "${FINGERPRINT_LOG}"
}

function tranferThirdApp(){
    #Chunbo.Gao@ANDROID.DEBUG.NA, 2019/6/21, Add for baidu ime log
    baidu_ime_dir="/sdcard/baidu/ime"
    if [ -d ${baidu_ime_dir} ]; then
        echo "copy BaiduIme..."
        cp -rf /sdcard/baidu/ime ${newpath}/
    fi

    #Chunbo.Gao@ANDROID.DEBUG.NA, 2019/6/21, Add for tencent.ig
    tencent_pubgmhd_dir="/sdcard/Android/data/com.tencent.tmgp.pubgmhd/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Logs"
    if [ -d ${tencent_pubgmhd_dir} ]; then
        mkdir -p ${newpath}/os/Tencentlogs/pubgmhd
        echo "copy tencent.pubgmhd..."
        cp -rf ${tencent_pubgmhd_dir} ${newpath}/os/Tencentlogs/pubgmhd
    fi
    traceTransferState "transfer log:copy third app done"
}

function tranferPower(){
    #Chunbo.Gao@ANDROID.DEBUG.NA, 2019/6/21, Add for thermalrec log
    dumpsys batterystats --thermalrec
    thermalrec_dir="/data/system/thermal/dcs"
    thermalstats_file="/data/system/thermalstats.bin"
    if [ -f ${thermalstats_file} ] || [ -d ${thermalrec_dir} ]; then
        mkdir -p ${newpath}/power/thermalrec/
        chmod 770 ${thermalstats_file}
	cp -rf ${thermalstats_file} ${newpath}/power/thermalrec/

        echo "copy Thermalrec..."
	chmod 770 /data/system/thermal/ -R
        cp -rf ${thermalrec_dir}/* ${newpath}/power/thermalrec/
    fi

    #Chunbo.Gao@ANDROID.DEBUG.NA, 2019/7/24, Add for powermonitor log
    powermonitor_dir="/data/oppo/psw/powermonitor"
    if [ -d ${powermonitor_dir} ]; then
        echo "copy Powermonitor..." >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
        mkdir -p ${newpath}/power/powermonitor/
		chmod 770 ${powermonitor_dir} -R
        cp -rf ${powermonitor_dir}/* ${newpath}/power/powermonitor/
    fi

    POWERMONITOR_BACKUP_LOG=/data/oppo/psw/powermonitor_backup/
    chmod 770 ${POWERMONITOR_BACKUP_LOG} -R
    if [ -d "${POWERMONITOR_BACKUP_LOG}" ]; then
        echo "copy powermonitor_backup..." >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
        mkdir -p ${newpath}/powermonitor_backup
        chmod 770 ${POWERMONITOR_BACKUP_LOG} -R
        cp -rf ${POWERMONITOR_BACKUP_LOG}/* ${newpath}/powermonitor_backup/
    fi
    traceTransferState "transfer log:copy power done"
}

#Wenshuai.Chen@RM.AD.OppoDebug.LogKit.NA, 2020/11/05, Add for bugreport log
function dump_bugreport() {
    traceTransferState "bugreport start..."
    if [ ! -d "${SDCARD_LOG_TRIGGER_PATH}" ];then
        mkdir -p ${SDCARD_LOG_TRIGGER_PATH}
    fi
    bugreport > ${SDCARD_LOG_TRIGGER_PATH}/bugreport_${CURTIME}.txt
}

function transferRealTimeLog_DumpSystem(){
    DUMP_SYSTEM_LOG=${DATA_DEBUGGING_PATH}/SI_stop

    # before mv ${DATA_DEBUGGING_PATH}, wait for dumpmeminfo done
    count=0
    while [ $count -le 30 ] && [ ! -f ${DUMP_SYSTEM_LOG}/finish_system ];do
        traceTransferState "TRANSFERREALTIMELOG_DUMPSYSTEM:count=$count"
        count=$((count + 1))
        sleep 1
    done

    mv ${DUMP_SYSTEM_LOG} ${newpath}
}

function transferTcpdumpLog(){

    if [ -d  ${DATA_DEBUGGING_PATH} ]; then
        ALL_TCPDUMP_DIR=`ls ${DATA_DEBUGGING_PATH} | grep netlog`
        for TCPDUMP_DIR in ${ALL_TCPDUMP_DIR};do
            # TODO
            echo ${TCPDUMP_DIR}
        done
    fi
}

function transferRealTimeLog(){
    chmod -R 777 ${DATA_DEBUGGING_PATH}/*
    #mv ${DATA_DEBUGGING_PATH}/* ${newpath}

    # filter SI_stop/
    traceTransferState "transferRealTimeLog start "
    if [ -d  ${DATA_DEBUGGING_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_DEBUGGING_PATH} | grep -v SI_stop`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_DEBUGGING_PATH}/${SUB_DIR} ] || [ -f ${DATA_DEBUGGING_PATH}/${SUB_DIR} ]; then
                traceTransferState "TRANSFERREALTIMELOG:mv ${DATA_DEBUGGING_PATH}/${SUB_DIR} to ${newpath}"
                mv ${DATA_DEBUGGING_PATH}/${SUB_DIR} ${newpath}
            fi
        done
    fi
    traceTransferState "transferRealTimeLog done "
}

function transferDataOppoLog(){
    TARGET_DATA_OPLUS_LOG=${newpath}/log

    chmod 777 ${DATA_OPLUS_LOG_PATH}/ -R
    #tar -czvf ${newpath}/LOG.dat.gz -C ${DATA_OPLUS_LOG_PATH} .
    #tar -czvf ${TARGET_DATA_OPLUS_LOG}/LOG.tar.gz ${DATA_OPLUS_LOG_PATH}

    # filter DCS
    if [ -d  ${DATA_OPLUS_LOG_PATH} ]; then
        ALL_SUB_DIR=`ls ${DATA_OPLUS_LOG_PATH} | grep -v DCS | grep -v data_vendor`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ] || [ -f ${DATA_OPLUS_LOG_PATH}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_OPLUS_LOG_PATH}/${SUB_DIR}" "${TARGET_DATA_OPLUS_LOG}/${SUB_DIR}"
            fi
        done
    fi

    transferDataDCS
}

function transferDataDCS(){
    TARGET_DATA_DCS_LOG=${newpath}/log/DCS

    DATA_DCS_LOG=${DATA_OPLUS_LOG_PATH}/DCS/de
    if [ -d  ${DATA_DCS_LOG} ]; then
        ALL_SUB_DIR=`ls ${DATA_DCS_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_DCS_LOG}/${SUB_DIR} ] || [ -f ${DATA_DCS_LOG}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_DCS_LOG}/${SUB_DIR}" "${TARGET_DATA_DCS_LOG}/${SUB_DIR}"
            fi
        done
    fi

    DATA_DCS_OTRTA_LOG=/data/persist_log/backup
    if [ -d  ${DATA_DCS_LOG} ]; then
        ALL_SUB_DIR=`ls ${DATA_DCS_OTRTA_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_DCS_OTRTA_LOG}/${SUB_DIR} ] || [ -f ${DATA_DCS_OTRTA_LOG}/${SUB_DIR} ]; then
                checkNumberSizeAndCopy "${DATA_DCS_OTRTA_LOG}/${SUB_DIR}" "${TARGET_DATA_DCS_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

function transferDataVendor(){
    stoptime=`getprop sys.oppo.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    DATA_VENDOR_LOG=${DATA_OPLUS_LOG_PATH}/data_vendor
    TARGET_DATA_VENDOR_LOG=${newpath}/data_vendor

    if [ -d  ${DATA_VENDOR_LOG} ]; then
        chmod 770 ${DATA_VENDOR_LOG}/ -R
        ALL_SUB_DIR=`ls ${DATA_VENDOR_LOG}`
        for SUB_DIR in ${ALL_SUB_DIR};do
            if [ -d ${DATA_VENDOR_LOG}/${SUB_DIR} ] || [ -f ${DATA_VENDOR_LOG}/${SUB_DIR} ]; then
                checkNumberSizeAndMove "${DATA_VENDOR_LOG}/${SUB_DIR}" "${TARGET_DATA_VENDOR_LOG}/${SUB_DIR}"
            fi
        done
    fi
}

function transfer2SDCard(){
    traceTransferState "TRANSFER2SDCARD:start...."
    stoptime=`getprop sys.oppo.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    mkdir -p ${newpath}
    traceTransferState "TRANSFER2SDCARD:from ${DATA_DEBUGGING_PATH} to ${newpath}"

    #Yujie.Long@ANDROID.DEBUG.NA, 2020/02/21, Add for save recovery log
    setprop ctl.start mvrecoverylog

    transferRealTimeLog
    transferRealTimeLog_DumpSystem

    mv ${SDCARD_LOG_BASE_PATH}/pcm_dump ${newpath}/
    mv ${SDCARD_LOG_BASE_PATH}/camera_monkey_log ${newpath}/

    # TODO
    checkNumberAndCopy "/data/misc/bluetooth/logs" "${newpath}/btsnoop_hci"
    #Laixin@CONNECTIVITY.BT.Basic.Log.70745, modify for auto capture hci log
    cp -rf /data/misc/bluetooth/cached_hci/ ${newpath}/btsnoop_hci/

    #user
    setprop ctl.start transferUser

    #copy thermalrec and powermonitor log
    tranferPower

    #copy third-app log
    tranferThirdApp
    #setprop sys.tranfer.finished cp:xxx_dir

    #copy fingerprint log
    #tranferFingerprint

    mv ${SDCARD_LOG_TRIGGER_PATH} ${newpath}/

    mkdir -p ${newpath}/tombstones/
    cp /data/tombstones/tombstone* ${newpath}/tombstones/
    setprop sys.tranfer.finished cp:tombstone

    #screenshots
    tranferScreenshots

    #systrace
    transferSystrace

    #Chunbo.Gao@ANDROID.DEBUG, 2020/01/17, Add for copy weixin xlog
    copyWeixinXlog
    #Rui.Liu@ANDROID.DEBUG, 2020/09/17, Add for copy qq log
    copyQQlog


    #get proc/dellog
    #cat proc/dellog > ${newpath}/proc_dellog.txt

    #os app
    transferColorOS

    #mv wm
    tranferWm

    #dump log
    #tranferDump
    #tranferWifi

    transferDataOppoLog

    setprop sys.tranfer.finished 1
}

function transfer_log() {
    traceTransferState "TRANSFER_LOG:start...."

    setprop ctl.start dump_system

    traceTransferState "TRANSFER_LOG:transfer2SDCard start...."
    transfer2SDCard
    traceTransferState "TRANSFER_LOG:transfer2SDCard done...."

    dmesg > ${newpath}/transferlog_done_dmesg.txt
    logcat -d > ${newpath}/transferlog_done_logcat.txt &
    traceTransferState "TRANSFER_LOG:catch transfer dmesg & logcat done...."

    chmod 2770 ${SDCARD_LOG_BASE_PATH} -R
    SDCARDFS_ENABLED=`getprop external_storage.sdcardfs.enabled 1`
    traceTransferState "TRANSFER_LOG:SDCARDFS_ENABLED is ${SDCARDFS_ENABLED}"
    if [ "${SDCARDFS_ENABLED}" == "0" ]; then
        chown system:ext_data_rw ${SDCARD_LOG_BASE_PATH} -R
    fi

    mv ${SDCARD_LOG_BASE_PATH}/recovery_log/ ${newpath}/
    traceTransferState "TRANSFER_LOG:done...."
    mv ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log ${newpath}/
}

function transferLog() {
    LOG_CONFIG_FILE="${DATA_OPLUS_LOG_PATH}/config/log_config.log"

    if [ -f "${LOG_CONFIG_FILE}" ]; then
        setprop sys.oplus.log.stoptime ${CURTIME}
        stoptime=`getprop sys.oplus.log.stoptime`
        LOG_PATH="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
        mkdir -p ${LOG_PATH}
        echo "${CURTIME_FORMAT} transfer log: ${LOG_PATH}, start..."

        cat ${LOG_CONFIG_FILE} | while read item_config
        do
            if [ "" != "${item_config}" ];then
                echo "${CURTIME_FORMAT} transfer log config: ${item_config}"
                OPERATION=`echo ${item_config} | awk '{print $1}'`
                SOURCE_PATH=`echo ${item_config} | awk '{print $2}'`
                if [ -d ${SOURCE_PATH} ];then
                    #if [ ! -d ${LOG_PATH}/${TARGET_PATH} ];then
                    #    mkdir ${LOG_PATH}/${TARGET_PATH}
                    #fi

                    TEMP_SIZE=`du -s ${SOURCE_PATH} | awk '{print $1}'`
                    if [ "" != "${OPERATION}" ] && [ x"${OPERATION}" = x"mv" ];then
                        ${OPERATION} ${SOURCE_PATH} ${LOG_PATH}/
                    else
                        checkNumberAndCopy ${SOURCE_PATH} ${LOG_PATH}/
                    fi
                    #${OPERATION} -rf ${SOURCE_PATH} ${LOG_PATH}/${TARGET_PATH}
                    #echo "${CURTIME_FORMAT} transfer log path: cp ${SOURCE_PATH} to ${TARGET_PATH} done, size ${TEMP_SIZE}"
                    traceTransferState "transfer log path: ${OPERATION} ${SOURCE_PATH} done, size ${TEMP_SIZE}"
                else
                    traceTransferState "transfer log path: ${SOURCE_PATH}, No such file or directory"
                fi
            fi
        done
    else
        echo "${CURTIME_FORMAT} transfer log: ${LOG_CONFIG_FILE}, not exits"
    fi
}

function transfer_qcomlog() {
    #qcom log
}

function transfer_mtklog() {
    #mtk log
}

function deleteFolder() {
    title=`getprop sys.oppo.log.deletepath.title`;
    logstoptime=`getprop sys.oppo.log.deletepath.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/${title}@stop@${logstoptime}";
    echo ${newpath}
    rm -rf ${newpath}
    setprop sys.clear.finished 1
}

function deleteOrigin() {
    stoptime=`getprop sys.oplus.log.stoptime`;
    newpath="${SDCARD_LOG_BASE_PATH}/log@stop@${stoptime}"
    rm -rf ${newpath}
    setprop sys.oppo.log.deleted 1
}

function initLogSizeAndNums() {
    FreeSize=`df /data | grep -v Mounted | awk '{print $4}'`
    GSIZE=`echo | awk '{printf("%d",2*1024*1024)}'`
    traceTransferState "INITLOGSIZEANDNUMS:data FreeSize:${FreeSize} and GSIZE:${GSIZE}"

    # TODO modified prop to config file
    tmpMain=`getprop persist.sys.log.main`
    tmpRadio=`getprop persist.sys.log.radio`
    tmpEvent=`getprop persist.sys.log.event`
    tmpKernel=`getprop persist.sys.log.kernel`
    tmpTcpdump=`getprop persist.sys.log.tcpdump`
    traceTransferState "INITLOGSIZEANDNUMS:main=${tmpMain}, radio=${tmpRadio}, event=${tmpEvent}, kernel=${tmpKernel}, tcpdump=${tmpTcpdump}"

    if [ ${FreeSize} -ge ${GSIZE} ]; then
        if [ "${tmpMain}" != "" ]; then
            #get the config size main
            tmpAndroidSize=`set -f;array=(${tmpMain//|/ });echo "${array[0]}"`
            tmpAdnroidCount=`set -f;array=(${tmpMain//|/ });echo "${array[1]}"`
            androidSize=`echo ${tmpAndroidSize} | awk '{printf("%d",$1*1024)}'`
            androidCount=`echo ${FreeSize} 30 50 ${androidSize} | awk '{printf("%d",$1*$2/$3/$4)}'`
            traceTransferState "INITLOGSIZEANDNUMS:tmpAndroidSize=${tmpAndroidSize}, tmpAdnroidCount=${tmpAdnroidCount}, androidSize=${androidSize}, androidCount=${androidCount}"
            if [ ${androidCount} -ge ${tmpAdnroidCount} ]; then
                androidCount=${tmpAdnroidCount}
            fi
            traceTransferState "INITLOGSIZEANDNUMS:last androidCount=${androidCount}"
        fi

        if [ "${tmpRadio}" != "" ]; then
            #get the config size radio
            tmpRadioSize=`set -f;array=(${tmpRadio//|/ });echo "${array[0]}"`
            tmpRadioCount=`set -f;array=(${tmpRadio//|/ });echo "${array[1]}"`
            radioSize=`echo ${tmpRadioSize} | awk '{printf("%d",$1*1024)}'`
            radioCount=`echo ${FreeSize} 1 50 ${radioSize} | awk '{printf("%d",$1*$2/$3/$4)}'`
            echo "tmpRadioSize=${tmpRadioSize}; tmpRadioCount=${tmpRadioCount} radioSize=${radioSize} radioCount=${radioCount}"
            if [ ${radioCount} -ge ${tmpRadioCount} ]; then
                radioCount=${tmpRadioCount}
            fi
            echo "last radioCount=${radioCount}"
        fi

        if [ "${tmpEvent}" != "" ]; then
            #get the config size event
            tmpEventSize=`set -f;array=(${tmpEvent//|/ });echo "${array[0]}"`
            tmpEventCount=`set -f;array=(${tmpEvent//|/ });echo "${array[1]}"`
            eventSize=`echo ${tmpEventSize} | awk '{printf("%d",$1*1024)}'`
            eventCount=`echo ${FreeSize} 1 50 ${eventSize} | awk '{printf("%d",$1*$2/$3/$4)}'`
            echo "tmpEventSize=${tmpEventSize}; tmpEventCount=${tmpEventCount} eventSize=${eventSize} eventCount=${eventCount}"
            if [ ${eventCount} -ge ${tmpEventCount} ]; then
                eventCount=${tmpEventCount}
            fi
            echo "last eventCount=${eventCount}"
        fi

        if [ "${tmpTcpdump}" != "" ]; then
            tmpTcpdumpSize=`set -f;array=(${tmpTcpdump//|/ });echo "${array[0]}"`
            tmpTcpdumpCount=`set -f;array=(${tmpTcpdump//|/ });echo "${array[1]}"`
            tcpdumpSize=`echo ${tmpTcpdumpSize} | awk '{printf("%d",$1*1024)}'`
            tcpdumpCount=`echo ${FreeSize} 10 50 ${tcpdumpSize} | awk '{printf("%d",$1*$2/$3/$4)}'`
            echo "tmpTcpdumpSize=${tmpTcpdumpCount}; tmpEventCount=${tmpEventCount} tcpdumpSize=${tcpdumpSize} tcpdumpCount=${tcpdumpCount}"
            ##tcpdump use MB in the order
            tcpdumpSize=${tmpTcpdumpSize}
            if [ ${tcpdumpCount} -ge ${tmpTcpdumpCount} ]; then
                tcpdumpCount=${tmpTcpdumpCount}
            fi
            echo "last tcpdumpCount=${tcpdumpCount}"
        else
            echo "tmpTcpdump is empty"
        fi
    else
        echo "free size is less than 2G"
        androidSize=20480
        androidCount=`echo ${FreeSize} 30 50 ${androidSize} | awk '{printf("%d",$1*$2*1024/$3/$4)}'`
        if [ ${androidCount} -ge 10 ]; then
            androidCount=10
        fi
        radioSize=10240
        radioCount=`echo ${FreeSize} 1 50 ${radioSize} | awk '{printf("%d",$1*$2*1024/$3/$4)}'`
        if [ ${radioCount} -ge 4 ]; then
            radioCount=4
        fi
        eventSize=10240
        eventCount=`echo ${FreeSize} 1 50 ${eventSize} | awk '{printf("%d",$1*$2*1024/$3/$4)}'`
        if [ ${eventCount} -ge 4 ]; then
            eventCount=4
        fi
        tcpdumpSize=50
        tcpdumpCount=`echo ${FreeSize} 10 50 ${tcpdumpSize} | awk '{printf("%d",$1*$2/$3/$4)}'`
        if [ ${tcpdumpCount} -ge 2 ]; then
            tcpdumpCount=2
        fi
    fi

    #LiuHaipeng@NETWORK.DATA.2959182, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
    LOG_TYPE=`getprop persist.sys.oppo.log.config`
    if [ "${LOG_TYPE}" == "call" ]; then
        tcpdumpPacketSize=0
    elif [ "${LOG_TYPE}" == "network" ];then
        tcpdumpPacketSize=0
    elif [ "${LOG_TYPE}" == "wifi" ];then
        tcpdumpPacketSize=0
    else
        tcpdumpPacketSize=100
        tcpdumpSizeTotal=300
        tcpdumpCount=`echo ${tcpdumpSizeTotal} ${tcpdumpSize} 1 | awk '{printf("%d",$1/$2)}'`
    fi
}

function logcatMain(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    DATA_LOG_APPS_PATH=`getprop sys.oplus.logkit.appslog`
    traceTransferState "logcat main:path=${DATA_LOG_APPS_PATH}, size=${androidSize}, Nums=${androidCount}"
    if [ "${panicenable}" = "true" ] || [ x"${camerapanic}" = x"true" ] && [ "${tmpMain}" != "" ]; then
        logdsize=`getprop persist.logd.size`
        if [ "${logdsize}" = "" ]; then
            /system/bin/logcat -G 5M
        fi

        /system/bin/logcat -f ${DATA_LOG_APPS_PATH}/android.txt -r${androidSize} -n ${androidCount}  -v threadtime -A
    else
        setprop ctl.stop logcatsdcard
    fi
}

function logcatRadio(){
    panicenable=`getprop persist.sys.assert.panic`
    DATA_LOG_APPS_PATH=`getprop sys.oplus.logkit.appslog`
    echo "logcat radio: radioSize=${radioSize}, radioCount=${radioCount}"
    if [ "${panicenable}" = "true" ] && [ "${tmpRadio}" != "" ]; then
        /system/bin/logcat -b radio -f ${DATA_LOG_APPS_PATH}/radio.txt -r${radioSize} -n ${radioCount}  -v threadtime -A
    else
        setprop ctl.stop logcatradio
    fi
}

function logcatEvent(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    DATA_LOG_APPS_PATH=`getprop sys.oplus.logkit.appslog`
    echo "logcat event: eventSize=${eventSize}, eventCount=${eventCount}"
    if [ "${panicenable}" = "true" ] || [ x"${camerapanic}" = x"true" ] && [ "${tmpEvent}" != "" ]; then
        /system/bin/logcat -b events -f ${DATA_LOG_APPS_PATH}/events.txt -r${eventSize} -n ${eventCount}  -v threadtime -A
    else
        setprop ctl.stop logcatevent
    fi
}

function logcatKernel(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    DATA_LOG_KERNEL_PATH=`getprop sys.oplus.logkit.kernellog`
    echo "logcat kernel: panicenable=${panicenable} tmpKernel=${tmpKernel}"
    if [ "${panicenable}" = "true" ] || [ x"${camerapanic}" = x"true" ] && [ "${tmpKernel}" != "" ]; then
        /system/system_ext/xbin/klogd -f - -n -x -l 7 | tee - ${DATA_LOG_KERNEL_PATH}/kernel.txt | awk 'NR%400==0'
    fi
}
#ifdef OPLUS_DEBUG_SSLOG_CATCH
#ZhangWankang@NETWORK.POWER 2020/04/02,add for catch ss log
function logcatSsLog(){
    echo "logcatSsLog start"
    outputPath="${DATA_DEBUGGING_PATH}/sslog"
    if [ ! -d "${outputPath}" ]; then
        mkdir -p ${outputPath}
    fi
    while [ -d "$outputPath" ]
    do
        ss -ntp -o state established >> ${outputPath}/sslog.txt
        sleep 15s #Sleep 15 seconds
    done
}
#endif

function clearDataOppoLog(){
    chmod 777 -R ${DATA_DEBUGGING_PATH}
    rm -rf ${DATA_DEBUGGING_PATH}/*
    setprop sys.clear.finished 1
}

function tranferTombstone() {
    srcpath=`getprop sys.tombstone.file`
    subPath=`getprop persist.sys.com.oplus.debug.time`
    cp ${srcpath} ${DATA_DEBUGGING_PATH}/${subPath}/tombstone/tomb_${CURTIME}
}

function tranferAnr() {
    srcpath=`getprop sys.anr.srcfile`
    subPath=`getprop persist.sys.com.oplus.debug.time`
    destfile=`getprop sys.anr.destfile`

    cp ${srcpath} ${DATA_DEBUGGING_PATH}/${subPath}/anr/${destfile}
}

#ifdef OPLUS_BUG_STABILITY
#Qing.Wu@ANDROID.STABILITY.2278668, 2019/09/03, Add for capture binder info
function binderinfocapture() {
    alreadycaped=`getprop sys.debug.binderinfocapture`
    if [ "$alreadycaped" == "1" ] ;then
        return
    fi
    if [ ! -d ${SDCARD_LOG_BASE_PATH}/binder_info/ ];then
    mkdir -p ${SDCARD_LOG_BASE_PATH}/binder_info/
    fi

    LOGTIME=`date +%F-%H-%M-%S`
    BINDER_DIR=${SDCARD_LOG_BASE_PATH}/binder_info/binder_${LOGTIME}
    echo ${BINDER_DIR}
    mkdir -p ${BINDER_DIR}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${BINDER_DIR}/state
        cat /dev/binderfs/binder_logs/stats > ${BINDER_DIR}/stats
        cat /dev/binderfs/binder_logs/transaction_log > ${BINDER_DIR}/transaction_log
        cat /dev/binderfs/binder_logs/transactions > ${BINDER_DIR}/transactions
    else
        cat /d/binder/state > ${BINDER_DIR}/state
        cat /d/binder/stats > ${BINDER_DIR}/stats
        cat /d/binder/transaction_log > ${BINDER_DIR}/transaction_log
        cat /d/binder/transactions > ${BINDER_DIR}/transactions
    fi
    ps -A -T > ${BINDER_DIR}/ps.txt

    kill -3 `pidof system_server`
    kill -3 `pidof com.android.phone`
    debuggerd -b `pidof netd` > "/data/anr/debuggerd_netd.txt"
    sleep 10
    cp -r /data/anr/*  ${BINDER_DIR}/
#package log folder to upload if logkit not enable
    logon=`getprop persist.sys.assert.panic`
    if [ ${logon} == "false" ];then
        current=`date "+%Y-%m-%d %H:%M:%S"`
        timeStamp=`date -d "$current" +%s`
        uuid=`cat /proc/sys/kernel/random/uuid`
        #uuid 0df1ed41-e0d6-40e2-8473-cdf7ccbd0d98
        otaversion=`getprop ro.build.version.ota`
        logzipname="${DATA_OPLUS_LOG_PATH}/DCS/de/quality_log/qp_deadsystem@"${uuid:0-12:12}@${otaversion}@${timeStamp}".tar.gz"
        tar -czf ${logzipname} ${BINDER_DIR}
        chown system:system ${logzipname}
    fi
    setprop sys.debug.binderinfocapture 1
}
#endif /* OPLUS_BUG_STABILITY */

#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/08/31.add for fix debug system_server register too many receivers issue
function receiverinfocapture() {
    alreadycaped=`getprop sys.debug.receiverinfocapture`
    if [ "$alreadycaped" == "1" ] ;then
        return
    fi

    LOGTIME=`date +%F-%H-%M-%S`
    dumpsys -t 60 activity broadcasts > ${DATA_DEBUGGING_PATH}/dumpsys_broadcasts_${LOGTIME}.txt
    setprop sys.debug.receiverinfocapture 1
}
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/09/21.add for fix debug system_server register too many receivers issue
function binderthreadfullcapture() {
    capturetimestamp=`getprop sys.debug.receiverinfocapture.timestamp`
    current=`date "+%Y-%m-%d %H:%M:%S"`
    timestamp=`date -d "$current" +%s`
    let interval=$timestamp-$capturetimestamp
    if [ $interval -lt 10 ] ; then
        return
    fi

    capturefinish=`getprop sys.capturebinderthreadinfo.finished`
    if [ "$capturefinish" == "0" ] ;then
        return
    fi
    setprop sys.capturebinderthreadinfo.finished 0

    if [ ! -d ${SDCARD_LOG_BASE_PATH}/binderthread_info/ ];then
    mkdir -p ${SDCARD_LOG_BASE_PATH}/binderthread_info/
    fi
    LOGTIME=`date +%F-%H-%M-%S`
    BINDER_DIR=${SDCARD_LOG_BASE_PATH}/binderthread_info/binderthread_${LOGTIME}
    echo ${BINDER_DIR}
    mkdir -p ${BINDER_DIR}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${BINDER_DIR}/state
        cat /dev/binderfs/binder_logs/stats > ${BINDER_DIR}/stats
        cat /dev/binderfs/binder_logs/transaction_log > ${BINDER_DIR}/transaction_log
        cat /dev/binderfs/binder_logs/transactions > ${BINDER_DIR}/transactions
    else
        cat /d/binder/state > ${BINDER_DIR}/state
        cat /d/binder/stats > ${BINDER_DIR}/stats
        cat /d/binder/transaction_log > ${BINDER_DIR}/transaction_log
        cat /d/binder/transactions > ${BINDER_DIR}/transactions
    fi
    ps -A -T > ${BINDER_DIR}/ps.txt

    kill -3 `pidof system_server`
    kill -3 `pidof com.android.phone`
    debuggerd -b `pidof netd` > "/data/anr/debuggerd_netd.txt"
    sleep 10
    cp -r /data/anr/*  ${BINDER_DIR}/
#package log folder to upload if logkit not enable
    logon=`getprop persist.sys.assert.panic`
    if [ ${logon} == "false" ];then
        current=`date "+%Y-%m-%d %H:%M:%S"`
        timeStamp=`date -d "$current" +%s`
        uuid=`cat /proc/sys/kernel/random/uuid`
        #uuid 0df1ed41-e0d6-40e2-8473-cdf7ccbd0d98
        otaversion=`getprop ro.build.version.ota`
        logzipname="${DATA_OPLUS_LOG_PATH}/DCS/de/quality_log/qp_binderinfo@"${uuid:0-12:12}@${otaversion}@${timeStamp}".tar.gz"
        tar -czf ${logzipname} ${BINDER_DIR}
        chown system:system ${logzipname}
    fi

    capturecount=`getprop debug.binderthreadfull.count`
    let capturecount=$capturecount+1
    setprop debug.binderthreadfull.count $capturecount

    current=`date "+%Y-%m-%d %H:%M:%S"`
    timeStamp=`date -d "$current" +%s`
    setprop sys.debug.receiverinfocapture.timestamp $timeStamp

    setprop sys.capturebinderthreadinfo.finished 1
}
#endif /*OPLUS_BUG_STABILITY*/

#Chunbo.Gao@ANDROID.DEBUG.2514795, 2019/11/12, Add for copy binder_info
function copybinderinfo() {
    CURTIME=`date +%F-%H-%M-%S`
    echo ${CURTIME}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${ANR_BINDER_PATH}/binder_info_${CURTIME}.txt
    else
        cat /sys/kernel/debug/binder/state > ${ANR_BINDER_PATH}/binder_info_${CURTIME}.txt
    fi
}

#Wuchao.Huang@ROM.Framework.EAP, 2019/11/19, Add for copy binder_info
function copyEapBinderInfo() {
    destBinderInfoPath=`getprop sys.eap.binderinfo.path`
    echo ${destBinderInfoPath}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${destBinderInfoPath}
    else
        cat /sys/kernel/debug/binder/state > ${destBinderInfoPath}
    fi
}

# add for ftm
function logcatftm(){
    FTM_CACHE_PATH=/cache/ftm_admin
    FTM_RESERVE_PATH=/mnt/vendor/opporeserve/ftm_admin
    if [ -d ${FTM_CACHE_PATH} ]; then
        /system/bin/logcat -f ${FTM_CACHE_PATH}/apps/android_log_ftm.txt -r1024 -n 6 -v threadtime *:V
    else
        mkdir -p ${FTM_RESERVE_PATH}/apps/
        /system/bin/logcat -f ${FTM_RESERVE_PATH}/apps/android_log_ftm.txt -r1024 -n 6 -v threadtime *:V
    fi
}

function klogdftm(){
    FTM_CACHE_PATH=/cache/ftm_admin
    FTM_RESERVE_PATH=/mnt/vendor/opporeserve/ftm_admin
    if [ -d ${FTM_CACHE_PATH} ]; then
        /system/system_ext/xbin/klogd -f ${FTM_CACHE_PATH}/kernel/kernel_log_ftm.txt -n -x -l 8
    else
        mkdir -p ${FTM_RESERVE_PATH}/kernel/
        /system/system_ext/xbin/klogd -f  ${FTM_RESERVE_PATH}/kernel/kernel_log_ftm.txt -n -x -l 8
    fi
}

# add for Sensor.logger
function resetlogpath(){
    setprop sys.oplus.logkit.appslog ""
    setprop sys.oplus.logkit.kernellog ""
    setprop sys.oplus.logkit.netlog ""
    setprop sys.oplus.logkit.assertlog ""
    setprop sys.oplus.logkit.anrlog ""
    setprop sys.oplus.logkit.tombstonelog ""
    setprop sys.oplus.logkit.fingerprintlog ""
    # Add for stopping catching fingerprint and face log
    dumpsys fingerprint log all 0
    dumpsys face log all 0
}

function gettpinfo() {
    tplogflag=`getprop persist.sys.oppodebug.tpcatcher`
    # tplogflag=511
    # echo "$tplogflag"
    if [ "$tplogflag" == "" ]
    then
        echo "tplogflag == error"
    else

        echo "tplogflag == $tplogflag"
        # tplogflag=`echo $tplogflag | $XKIT awk '{print lshift($0, 1)}'`
        tpstate=0
        tpstate=`echo $tplogflag | $XKIT awk '{print and($1, 1)}'`
        echo "switch tpstate = $tpstate"
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off"
        else
            echo "switch tpstate on"
            DATA_LOG_KERNEL_PATH=`getprop sys.oplus.logkit.kernellog`
            kernellogpath=${DATA_LOG_KERNEL_PATH}/tp_debug_info
            subpath=$kernellogpath/${CURTIME}.txt
            mkdir -p $kernellogpath
            # mFlagMainRegister = 1 << 1
            subflag=`echo | $XKIT awk '{print lshift(1, 1)}'`
            echo "1 << 1 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 1 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 1 $tpstate"
                echo /proc/touchpanel/debug_info/main_register  >> $subpath
                cat /proc/touchpanel/debug_info/main_register  >> $subpath
            fi
            # mFlagSelfDelta = 1 << 2;
            subflag=`echo | $XKIT awk '{print lshift(1, 2)}'`
            echo " 1<<2 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 2 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 2 $tpstate"
                echo /proc/touchpanel/debug_info/self_delta  >> $subpath
                cat /proc/touchpanel/debug_info/self_delta  >> $subpath
            fi
            # mFlagDetal = 1 << 3;
            subflag=`echo | $XKIT awk '{print lshift(1, 3)}'`
            echo "1 << 3 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 3 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 3 $tpstate"
                echo /proc/touchpanel/debug_info/delta  >> $subpath
                cat /proc/touchpanel/debug_info/delta  >> $subpath
            fi
            # mFlatSelfRaw = 1 << 4;
            subflag=`echo | $XKIT awk '{print lshift(1, 4)}'`
            echo "1 << 4 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 4 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 4 $tpstate"
                echo /proc/touchpanel/debug_info/self_raw  >> $subpath
                cat /proc/touchpanel/debug_info/self_raw  >> $subpath
            fi
            # mFlagBaseLine = 1 << 5;
            subflag=`echo | $XKIT awk '{print lshift(1, 5)}'`
            echo "1 << 5 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 5 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 5 $tpstate"
                echo /proc/touchpanel/debug_info/baseline  >> $subpath
                cat /proc/touchpanel/debug_info/baseline  >> $subpath
            fi
            # mFlagDataLimit = 1 << 6;
            subflag=`echo | $XKIT awk '{print lshift(1, 6)}'`
            echo "1 << 6 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 6 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 6 $tpstate"
                echo /proc/touchpanel/debug_info/data_limit  >> $subpath
                cat /proc/touchpanel/debug_info/data_limit  >> $subpath
            fi
            # mFlagReserve = 1 << 7;
            subflag=`echo | $XKIT awk '{print lshift(1, 7)}'`
            echo "1 << 7 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 7 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 7 $tpstate"
                echo /proc/touchpanel/debug_info/reserve  >> $subpath
                cat /proc/touchpanel/debug_info/reserve  >> $subpath
            fi
            # mFlagTpinfo = 1 << 8;
            subflag=`echo | $XKIT awk '{print lshift(1, 8)}'`
            echo "1 << 8 subflag = $subflag"
            tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 8 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 8 $tpstate"
            fi

            echo $tplogflag " end else"
        fi
    fi
}

function getSystemStatus() {
    traceTransferState "dumpSystem:start...."
    boot_completed=`getprop sys.boot_completed`
    if [ x${boot_completed} == x"1" ]; then
        outputPath="${DATA_DEBUGGING_PATH}/SI_stop"

        traceTransferState "dumpSystem:${outputPath}"
        if [[ ! -d ${outputPath} ]];then
            mkdir -p ${outputPath}
        fi

        rm -f ${outputPath}/finish_system
        dumpsys -t 15 meminfo > ${outputPath}/dumpsys_mem.txt &
        setprop sys.tranfer.finished mv:meminfo

        traceTransferState "dumpSystem:ps,top"
        ps -T -A > ${outputPath}/ps.txt
        top -n 1 -s 10 > ${outputPath}/top.txt
        cat /proc/meminfo > ${outputPath}/proc_meminfo.txt
        cat /proc/interrupts > ${outputPath}/interrupts.txt
        cat /sys/kernel/debug/wakeup_sources > ${outputPath}/wakeup_sources.log
        traceTransferState "dumpSystem:getprop"
        getprop > ${outputPath}/prop.txt
        traceTransferState "dumpSystem:df"
        df > ${outputPath}/df.txt
        traceTransferState "dumpSystem:mount"
        mount > ${outputPath}/mount.txt
        setprop sys.tranfer.finished mv:mount
        traceTransferState "dumpSystem:cat"
        cat data/system/packages.xml  > ${outputPath}/packages.txt
        cat data/system/appops.xml  > ${outputPath}/appops.xml
        traceTransferState "dumpSystem:dumpsys appops"
        dumpsys appops > ${outputPath}/dumpsys_appops.xml
        #/vendor/bin/qrtr-lookup > ${outputPath}/qrtr-lookup.txt
        cat /proc/zoneinfo > ${outputPath}/zoneinfo.txt
        cat /proc/slabinfo > ${outputPath}/slabinfo.txt
        cp -rf /sys/kernel/debug/ion ${outputPath}/
        cp -rf /sys/kernel/debug/dma_buf ${outputPath}/
        logcat -S > ${outputPath}/logStatistics_${CURTIME}.txt

        traceTransferState "dumpSystem:user"
        dumpsys user > ${outputPath}/dumpsys_user.txt
        dumpsys power > ${outputPath}/dumpsys_power.txt
        dumpsys cpuinfo > ${outputPath}/dumpsys_cpuinfo.txt
        dumpsys alarm > ${outputPath}/dumpsys_alarm.txt
        dumpsys batterystats > ${outputPath}/dumpsys_batterystats.txt
        dumpsys batterystats -c > ${outputPath}/dumpsys_battersystats_for_bh.txt
        dumpsys activity exit-info > ${outputPath}/dumpsys_exit_info.txt
        setprop sys.tranfer.finished mv:batterystats
        dumpsys location > ${outputPath}/dumpsys_location.txt
        traceTransferState "dumpSystem:dropbox"
        dumpsys dropbox --print > ${outputPath}/dumpsys_dropbox_all.txt

        #yong8.huang@ANDROID.AMS, 2020/12/30, Add for dumpsys activity info
        dumpsys activity processes > ${outputPath}/dumpsys_processes.txt
        dumpsys activity broadcasts > ${outputPath}/dumpsys_broadcasts.txt
        dumpsys activity providers > ${outputPath}/dumpsys_providers.txt
        dumpsys activity services > ${outputPath}/dumpsys_services.txt

        ##kevin.li@ROM.Framework, 2019/11/5, add for hans freeze manager(for protection)
        hans_enable=`getprop persist.sys.enable.hans`
        if [ "$hans_enable" == "true" ]; then
            dumpsys activity hans history > ${outputPath}/dumpsys_hans_history.txt
        fi
        #kevin.li@ROM.Framework, 2019/12/2, add for hans cts property
        hans_enable=`getprop persist.vendor.enable.hans`
        if [ "$hans_enable" == "true" ]; then
            dumpsys activity hans history > ${outputPath}/dumpsys_hans_history.txt
        fi

        #chao.zhu@ROM.Framework, 2020/04/17, add for preload
        preload_enable=`getprop persist.vendor.enable.preload`
        if [ "$preload_enable" == "true" ]; then
            dumpsys activity preload > ${outputPath}/dumpsys_preload.txt
        fi

        traceTransferState "dumpSystem:package start"
        dumpsys package --da > ${outputPath}/dumpsys_package_da.txt
        traceTransferState "dumpSystem:package end"

        wait
        getMemoryMap;

        #CaiLiuzhuang@MULTIMEDIA.AUDIODRIVER.FEATURE, 2021/01/18, Add for dump media log
        dumpMedia

        touch ${outputPath}/finish_system
        traceTransferState "dumpSystem:done...."
    fi
}

#Zhiming.chen@ANDROID.DEBUG 2724830, 2020/01/04,
function getMemoryMap() {
    traceTransferState " dumpSystem:memory map start...."
    LI=0
    LMI=4
    LMM=0
    MEMORY=921600
    PROCESS_MEMORY=819200
    RESIDUE_MEMORY=`cat proc/meminfo | grep MemAvailable | tr -cd "[0-9]"`
    if [ $RESIDUE_MEMORY -lt $MEMORY ] ; then
        while read -r line
        do
            if [ $LI -gt $LMM -a $LI -lt $LMI ] ; then
                let LI=$LI+1;
                echo $line
                PROMEM=`echo $line | grep -o '.*K' | tr -cd "[0-9]"`
                echo $PROMEM
                PID=`echo $line | grep -o '(.*)' | tr -cd "[0-9]"`
                echo $PID
                if [ $PROMEM -gt $PROCESS_MEMORY ] ; then
                    cat proc/$PID/smaps > ${outputPath}/pid$PID-smaps.txt
                    dumpsys meminfo $PID > ${outputPath}/pid$PID-dumpsysmen.txt
                fi
                if [ $LI -eq $LMI ] ; then
                    break
                fi
            fi
            if [ "$line"x = "Total PSS by process:"x ] ; then
                echo $line
                let LI=$LI+1;
            fi
        done < ${outputPath}/dumpsys_mem.txt
    fi
    traceTransferState "dumpSystem:memory map done...."
}

#ifdef OPLUS_BUG_STABILITY
#CaiLiuzhuang@MULTIMEDIA.AUDIODRIVER.FEATURE, 2021/01/18, Add for dump media log
function dumpMedia() {
    mediaPath="${DATA_DEBUGGING_PATH}/SI_stop/media"
    mkdir -p ${mediaPath}
    traceTransferState "dumpMedia:start...."
    dumpsys media.audio_flinger > ${mediaPath}/audio_flinger.txt
    dumpsys media.audio_policy > ${mediaPath}/audio_policy.txt
    dumpsys media.metrics > ${mediaPath}/media_metrics.txt
    dumpsys media_session > ${mediaPath}/media_session.txt
    dumpsys media_router > ${mediaPath}/media_router.txt
    dumpsys audio > ${mediaPath}/audioservice.txt
    dumpsys media.player > ${mediaPath}/media_player.txt
    pid_audioserver=`pgrep -f audioserver`
    debuggerd -b ${pid_audioserver} > ${mediaPath}/audioserver.txt
    pid_audiohal=`pgrep -f audio.service`
    debuggerd -b ${pid_audiohal} > ${mediaPath}/audiohal.txt
    atlasservice=`pgrep -f atlasservice`
    debuggerd -b ${atlasservice} > ${mediaPath}/atlasservice.txt
    system_server=`pgrep -f system_server`
    debuggerd -j ${system_server} > ${mediaPath}/system_server.txt
    multimedia=`pgrep -f persist.multimedia`
    debuggerd -j ${multimedia} > ${mediaPath}/multimedia.txt
    traceTransferState "dumpMedia:done...."
}
#endif /* OPLUS_BUG_STABILITY */

#Chunbo.Gao@ANDROID.DEBUG 2020/6/18, Add for ...
function delcustomlog() {
    echo "delcustomlog begin"
    rm -rf ${DATA_DEBUGGING_PATH}/customer
    echo "delcustomlog end"
}

function customdmesg() {
    echo "customdmesg begin"
    chmod 777 -R ${DATA_DEBUGGING_PATH}/
    echo "customdmesg end"
}

function customdiaglog() {
    echo "customdiaglog begin"
    mv data/vendor/oppo/log/device_log/diag_logs ${DATA_DEBUGGING_PATH}/customer
    chmod 777 -R ${DATA_DEBUGGING_PATH}/customer
    restorecon -RF ${DATA_DEBUGGING_PATH}/customer
    echo "customdiaglog end"
}

function cleanramdump() {
    echo "cleanramdump begin"
    rm -rf /data/ramdump/*
    echo "cleanramdump end"
}

function logcusmain() {
    echo "logcusmain begin"
    path=${DATA_DEBUGGING_PATH}/customer/apps
    mkdir -p ${path}
    /system/bin/logcat  -f ${path}/android.txt -r10240 -v threadtime *:V
    echo "logcusmain end"
}

function logcusevent() {
    echo "logcusevent begin"
    path=${DATA_DEBUGGING_PATH}/customer/apps
    mkdir -p ${path}
    /system/bin/logcat -b events -f ${path}/event.txt -r10240 -v threadtime *:V
    echo "logcusevent end"
}

function logcusradio() {
    echo "logcusradio begin"
    path=${DATA_DEBUGGING_PATH}/customer/apps
    mkdir -p ${path}
    /system/bin/logcat -b radio -f ${path}/radio.txt -r10240 -v threadtime *:V
    echo "logcusradio end"
}

function logcuskernel() {
    echo "logcuskernel begin"
    path=${DATA_DEBUGGING_PATH}/customer/kernel
    mkdir -p ${path}
    dmesg > ${DATA_DEBUGGING_PATH}/customer/kernel/dmesg.txt
    /system/system_ext/xbin/klogd -f - -n -x -l 7 | tee - ${path}/kinfo0.txt | awk 'NR%400==0'
    echo "logcuskernel end"
}

function logcustcp() {
    echo "logcustcp begin"
    path=${DATA_DEBUGGING_PATH}/customer/tcpdump
    mkdir -p ${path}
    tcpdump -i any -p -s 0 -W 1 -C 50 -w ${path}/tcpdump.pcap
    echo "logcustcp end"
}

function cameraloginit() {
    logdsize=`getprop persist.logd.size`
    echo "get logdsize ${logdsize}"
    if [ "${logdsize}" = "" ]
    then
        echo "camere init set log size 16M"
         setprop persist.logd.size 16777216
    fi
}
#================================== COMMON LOG =========================

#ifdef OPLUS_BUG_DEBUG
#Miao.Yu@ANDROID.WMS, 2019/11/25, Add for dump wm info
function dumpWm() {
    panicstate=`getprop persist.sys.assert.panic`
    dumpenable=`getprop debug.screencapdump.enable`
    if [ "$panicstate" == "true" ] && [ "$dumpenable" == "true" ]
    then
        if [ ! -d ${DATA_DEBUGGING_PATH}/wm/ ];then
        mkdir -p ${DATA_DEBUGGING_PATH}/wm/
        fi

        LOGTIME=`date +%F-%H-%M-%S`
        DIR=${DATA_DEBUGGING_PATH}/wm/${LOGTIME}
        mkdir -p ${DIR}
        dumpsys window -a > ${DIR}/windows.txt
        dumpsys activity a > ${DIR}/activities.txt
        dumpsys activity -v top > ${DIR}/top_activity.txt
        dumpsys input > ${DIR}/input.txt
        ps -A > ${DIR}/ps.txt
        mv -f ${DATA_DEBUGGING_PATH}/wm_log.pb ${DIR}/wm_log.pb
        getLogStatistics
    fi
}
function tranferWm() {
    mkdir -p ${newpath}/wm
    mv -f ${DATA_DEBUGGING_PATH}/wm/* ${newpath}/wm
}
#endif /* OPLUS_BUG_DEBUG */

function getLogStatistics() {
    LOG_STATISTICS_PATH=${DATA_DEBUGGING_PATH}/logStatistics
    if [ ! -d ${LOG_STATISTICS_PATH} ]; then
        mkdir -p ${LOG_STATISTICS_PATH}
    fi
    logcat -S > ${DATA_DEBUGGING_PATH}/logStatistics/logStatistics_${CURTIME}.txt
}

function inittpdebug(){
    panicstate=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    tplogflag=`getprop persist.sys.oppodebug.tpcatcher`
    if [ "$tplogflag" != "" ]
    then
        echo "inittpdebug not empty panicstate = $panicstate tplogflag = $tplogflag"
        if [ "$panicstate" == "true" ] || [ x"${camerapanic}" = x"true" ]
        then
            tplogflag=`echo $tplogflag , | $XKIT awk '{print or($1, 1)}'`
        else
            tplogflag=`echo $tplogflag , | $XKIT awk '{print and($1, 510)}'`
        fi
        setprop persist.sys.oppodebug.tpcatcher $tplogflag
    fi
}
function settplevel(){
    tplevel=`getprop persist.sys.oppodebug.tplevel`
    if [ "$tplevel" == "0" ]
    then
        echo 0 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "1" ]
    then
        echo 1 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "2" ]
    then
        echo 2 > /proc/touchpanel/debug_level
    fi
}

#Chunbo.Gao@ANDROID.DEBUG.1968962, 2019/4/23, Add for qmi log
function qmilogon() {
    echo "qmilogon begin"
    qmilog_switch=`getprop persist.sys.qmilog.switch`
    echo ${qmilog_switch}
    if [ "$qmilog_switch" == "true" ]; then
        setprop ctl.start adspglink
        setprop ctl.start modemglink
        setprop ctl.start cdspglink
        setprop ctl.start modemqrtr
        setprop ctl.start sensorqrtr
        setprop ctl.start npuqrtr
        setprop ctl.start slpiqrtr
        setprop ctl.start slpiglink
    fi
    echo "qmilogon end"
}

function qmilogoff() {
    echo "qmilogoff begin"
    qmilog_switch=`getprop persist.sys.qmilog.switch`
    echo ${qmilog_switch}
    if [ "$qmilog_switch" == "true" ]; then
        setprop ctl.stop adspglink
        setprop ctl.stop modemglink
        setprop ctl.stop cdspglink
        setprop ctl.stop modemqrtr
        setprop ctl.stop sensorqrtr
        setprop ctl.stop npuqrtr
        setprop ctl.stop slpiqrtr
        setprop ctl.stop slpiglink
    fi
    echo "qmilogoff end"
}

function adspglink() {
    echo "adspglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/adsp/log_cont > ${path}/adsp_glink.log
        cat /d/ipc_logging/diag/log_cont > ${path}/diag_ipc_glink.log &
    fi
}

function modemglink() {
    echo "modemglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/modem/log_cont > ${path}/modem_glink.log
    fi
}

function cdspglink() {
    echo "cdspglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/cdsp/log_cont > ${path}/cdsp_glink.log
    fi
}
function modemqrtr() {
    echo "modemqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_0/log_cont > ${path}/modem_qrtr.log
    fi
}

function sensorqrtr() {
    echo "sensorqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_5/log_cont > ${path}/sensor_qrtr.log
    fi
}

function npuqrtr() {
    echo "NPUqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_10/log_cont > ${path}/NPU_qrtr.log
    fi
}

function slpiqrtr() {
    echo "slpiqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_9/log_cont > ${path}/slpi_qrtr.log
    fi
}

function slpiglink() {
    echo "slpiglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/slpi/log_cont > ${path}/slpi_glink.log
    fi
}

#================================== STABILITY =========================
function pwkdumpon(){
    platform=`getprop ro.board.platform`
    echo "platform ${platform}"

    echo "sdm660 845 670 710"
    echo 0x843 > /d/regmap/spmi0-00/address
    echo 0x80 > /d/regmap/spmi0-00/data
    echo 0x842 > /d/regmap/spmi0-00/address
    echo 0x01 > /d/regmap/spmi0-00/data
    echo 0x840 > /d/regmap/spmi0-00/address
    echo 0x0F > /d/regmap/spmi0-00/data
    echo 0x841 > /d/regmap/spmi0-00/address
    echo 0x07 > /d/regmap/spmi0-00/data

}

function pwkdumpoff(){
    platform=`getprop ro.board.platform`
    echo "platform ${platform}"
    echo "sdm660 845 670 710"
    echo 0x843 > /d/regmap/spmi0-00/address
    echo 0x00 > /d/regmap/spmi0-00/data
    echo 0x842 > /d/regmap/spmi0-00/address
    echo 0x07 > /d/regmap/spmi0-00/data

}

#Qi.Zhang@TECH.BSP.Stability 2019/09/20, Add for uefi log
function LogcatUefi(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ];then
        mkdir -p  ${CACHE_PATH}/uefi
        /system/system_ext/bin/extractCurrentUefiLog
    fi
}

function DumpEnvironment(){
    rm  -rf /cache/environment
    umask 000
    mkdir -p /cache/environment
    chmod 777 /data/misc/gpu/gpusnapshot/*
    ls -l /data/misc/gpu/gpusnapshot/ > /cache/environment/snapshotlist.txt
    cp -rf /data/misc/gpu/gpusnapshot/* /cache/environment/
    chmod 777 /cache/environment/dump*
    rm -rf /data/misc/gpu/gpusnapshot/*
    #ps -A > /cache/environment/ps.txt &
    ps -AT > /cache/environment/ps_thread.txt &
    mount > /cache/environment/mount.txt &
    futexwait_log="${DATA_OPLUS_LOG_PATH}/futexwait_log"
    if [ -d  ${futexwait_log} ];
    then
        all_logs=`ls ${futexwait_log}`
        for i in ${all_logs};do
            echo ${i}
            cp /data/system/dropbox/futexwait_log/${i}  /cache/environment/futexwait_log_${i}
        done
        chmod 777 /cache/environment/futexwait_log*
    fi
    getprop > /cache/environment/prop.txt &
    dumpsys SurfaceFlinger --dispsync > /cache/environment/sf_dispsync.txt &
    dumpsys SurfaceFlinger > /cache/environment/sf.txt &
    /system/bin/dmesg > /cache/environment/dmesg.txt &
    /system/bin/logcat -d -v threadtime > /cache/environment/android.txt &
    /system/bin/logcat -b radio -d -v threadtime > /cache/environment/radio.txt &
    /system/bin/logcat -b events -d -v threadtime > /cache/environment/events.txt &
    i=`ps -A | grep system_server | $XKIT awk '{printf $2}'`
    ls /proc/$i/fd -al > /cache/environment/system_server_fd.txt &
    ps -A -T | grep $i > /cache/environment/system_server_thread.txt &
    cp -rf /data/system/packages.xml /cache/environment/packages.xml
    chmod +r /cache/environment/packages.xml
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > /cache/environment/binder_info.txt &
    else
        cat /sys/kernel/debug/binder/state > /cache/environment/binder_info.txt &
    fi
    cat /proc/meminfo > /cache/environment/proc_meminfo.txt &
    cat /d/ion/heaps/system > /cache/environment/iom_system_heaps.txt &
    #Yufeng.liu@Plf.AD.Performance, 2020/06/10, Add for ion memory leak
    cat /d/dma_buf/bufinfo > /cache/environment/dma_bufinfo.txt &
    cat /d/dma_buf/dmaprocs > /cache/environment/dma_dmaprocs.txt &
    df -k > /cache/environment/df.txt &
    ls -l /data/anr > /cache/environment/anr_ls.txt &
    du -h -a /data/system/dropbox > /cache/environment/dropbox_du.txt &
    watchdogfile=`getprop persist.sys.oplus.watchdogtrace`
    #Chunbo.Gao@ANDROID.DEBUG.BugID, 2019/4/23, Add for ...
    cp -rf ${DATA_DEBUGGING_PATH}/sf/backtrace/* /cache/environment/
    chmod 777 cache/environment/*
    if [ x"$watchdogfile" != x"0" ] && [ x"$watchdogfile" != x"" ]
    then
        chmod 666 $watchdogfile
        cp -rf $watchdogfile /cache/environment/
        setprop persist.sys.oplus.watchdogtrace 0
    fi
    wait
    setprop sys.dumpenvironment.finished 1
    umask 077
}

function packupminidump() {

    timestamp=`getprop sys.oppo.minidump.ts`
    echo time ${timestamp}
    uuid=`getprop sys.oppo.minidumpuuid`
    otaversion=`getprop ro.build.version.ota`
    minidumppath="${DATA_OPLUS_LOG_PATH}/DCS/de/minidump"
    #tag@hash@ota@datatime
    packupname=${minidumppath}/SYSTEM_LAST_KMSG@${uuid}@${otaversion}@${timestamp}
    echo name ${packupname}
    #read device info begin
    #"/proc/oplusVersion/serialID",
    #"/proc/devinfo/ddr",
    #"/proc/devinfo/emmc",
    #"proc/devinfo/emmc_version"};
    model=`getprop ro.product.model`
    version=`getprop ro.build.version.ota`
    echo "model:${model}" > ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "version:${version}" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/serialID" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/serialID >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "\n/proc/devinfo/ddr" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ddr >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/ocp" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/ocp >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cp /data/system/packages.xml ${DATA_OPLUS_LOG_PATH}/DCS/minidump/packages.xml
    echo "tar -czvf ${packupname} -C ${DATA_OPLUS_LOG_PATH}/DCS/minidump ." >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    tar -czvf ${packupname}.dat.gz.tmp -C ${DATA_OPLUS_LOG_PATH}/DCS/minidump .
    echo "chown system:system ${packupname}*" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    chown system:system ${packupname}*
    echo "mv ${packupname}.dat.gz.tmp ${packupname}.dat.gz" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    mv ${packupname}.dat.gz.tmp ${packupname}.dat.gz
    chown system:system ${packupname}*
    echo "-rf ${DATA_OPLUS_LOG_PATH}/DCS/minidump"
    rm -rf ${DATA_OPLUS_LOG_PATH}/DCS/minidump
    #setprop sys.oppo.phoenix.handle_error ERROR_REBOOT_FROM_KE_SUCCESS
    #echo "try_copy_minidump_to_opporeserve "${packupname}.dat.gz"" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    #try_copy_minidump_to_opporeserve "${packupname}.dat.gz"
    setprop sys.backup.minidump.tag "SYSTEM_LAST_KMSG"
    setprop ctl.start backup_minidumplog
}

#Fangfang.Hui@TECH.AD.Stability, 2019/08/13, Add for the quality feedback dcs config
function backupMinidump() {
    tag=`getprop sys.backup.minidump.tag`
    if [ x"$tag" = x"" ]; then
        echo "backup.minidump.tag is null, do nothing"
        return
    fi
    minidumppath="${DATA_OPLUS_LOG_PATH}/DCS/de/minidump"
    miniDumpFile=$minidumppath/$(ls -t ${minidumppath} | head -1)
    if [ x"$miniDumpFile" = x"" ]; then
        echo "minidump.file is null, do nothing"
        return
    fi
    result=$(echo $miniDumpFile | grep "${tag}")
    if [ x"$result" = x"" ]; then
        echo "tag mismatch, do not backup"
        return
    else
        try_copy_minidump_to_opporeserve $miniDumpFile
        setprop sys.backup.minidump.tag ""
    fi
}

function try_copy_minidump_to_opporeserve() {
    OPPORESERVE_MINIDUMP_BACKUP_PATH="${DATA_OPLUS_LOG_PATH}/opporeserve/media/log/minidumpbackup"
    OPPORESERVE2_MOUNT_POINT="/mnt/vendor/opporeserve"

    if [ ! -d ${OPPORESERVE_MINIDUMP_BACKUP_PATH} ]; then
        mkdir ${OPPORESERVE_MINIDUMP_BACKUP_PATH}
    fi
    #chmod -R 0774 ${OPPORESERVE_MINIDUMP_BACKUP_PATH}
    #chown -R system ${OPPORESERVE_MINIDUMP_BACKUP_PATH}
    #chgrp -R system ${OPPORESERVE_MINIDUMP_BACKUP_PATH}
    NewLogPath=$1
    if [ ! -f $NewLogPath ] ;then
        echo "Can not access ${NewLogPath}, the file may not exists "
        return
    fi
    TmpLogSize=$(du -sk ${NewLogPath} | sed 's/[[:space:]]/,/g' | cut -d "," -f1) #`du -s -k ${NewLogPath} | $XKIT awk '{print $1}'`
    curBakCount=`ls ${OPPORESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
    echo "curBakCount = ${curBakCount}, TmpLogSize = ${TmpLogSize}, NewLogPath = ${NewLogPath}"
    while [ ${curBakCount} -gt 5 ]   #can only save 5 backup minidump logs at most
    do
        rm -rf ${OPPORESERVE_MINIDUMP_BACKUP_PATH}/$(ls -t ${OPPORESERVE_MINIDUMP_BACKUP_PATH} | tail -1)
        curBakCount=`ls ${OPPORESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
        echo "delete one file curBakCount = $curBakCount"
    done
    FreeSize=$(df -ak | grep "${OPPORESERVE_MINIDUMP_BACKUP_PATH}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f4)
    TotalSize=$(df -ak | grep "${OPPORESERVE_MINIDUMP_BACKUP_PATH}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f2)
    ReserveSize=`expr $TotalSize / 5`
    NeedSize=`expr $TmpLogSize + $ReserveSize`
    echo "NeedSize = ${NeedSize}, ReserveSize = ${ReserveSize}, FreeSize = ${FreeSize}"
    while [ ${FreeSize} -le ${NeedSize} ]
    do
        curBakCount=`ls ${OPPORESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
        if [ $curBakCount -gt 1 ]; then #leave at most on log file
            rm -rf ${OPPORESERVE_MINIDUMP_BACKUP_PATH}/$(ls -t ${OPPORESERVE_MINIDUMP_BACKUP_PATH} | tail -1)
            echo "${OPPORESERVE2_MOUNT_POINT} left space ${FreeSize} not enough for minidump, delete one de minidump"
            FreeSize=$(df -k | grep "${OPPORESERVE2_MOUNT_POINT}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f4)
            continue
        fi
        echo "${OPPORESERVE2_MOUNT_POINT} left space ${FreeSize} not enough for minidump, nothing to delete"
        return 0
    done
    #space is enough, now copy
    cp $NewLogPath $OPPORESERVE_MINIDUMP_BACKUP_PATH
    chmod -R 0771 ${OPPORESERVE_MINIDUMP_BACKUP_PATH}
    chown -R system ${OPPORESERVE_MINIDUMP_BACKUP_PATH}
    chgrp -R system ${OPPORESERVE_MINIDUMP_BACKUP_PATH}
}

#Jianping.Zheng@Swdp.Android.Stability.Crash,2017/04/04,add for record performance
function perf_record() {
    check_interval=`getprop persist.sys.oppo.perfinteval`
    if [ x"${check_interval}" = x"" ]; then
        check_interval=60
    fi
    perf_record_path=${DATA_DEBUGGING_PATH}/perf_record_logs
    while [ true ];do
        if [ ! -d ${perf_record_path} ];then
            mkdir -p ${perf_record_path}
        fi

        echo "\ndate->" `date` >> ${perf_record_path}/cpu.txt
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq >> ${perf_record_path}/cpu.txt

        echo "\ndate->" `date` >> ${perf_record_path}/mem.txt
        cat /proc/meminfo >> ${perf_record_path}/mem.txt

        echo "\ndate->" `date` >> ${perf_record_path}/buddyinfo.txt
        cat /proc/buddyinfo >> ${perf_record_path}/buddyinfo.txt

        echo "\ndate->" `date` >> ${perf_record_path}/top.txt
        top -n 1 >> ${perf_record_path}/top.txt

        topneocount=0
        if [ $topneocount -le 10 ]; then
            topneo=`top -n 1 | grep neo | awk '{print $9}' | head -n 1 | awk -F . '{print $1}'`;
            if [ $topneo -gt 90 ]; then
                neopid=`ps -A | grep neo | awk '{print $2}'`;
                echo "\ndate->" `date` >> ${perf_record_path}/neo_debuggerd.txt
                debuggerd $neopid >> ${perf_record_path}/neo_debuggerd.txt;
                let topneocount+=1
            fi
        fi

        sleep "$check_interval"
    done
}

#Jianping.Zheng@PSW.Android..Stability.Crash, 2017/06/20, Add for collect futexwait block log
function collect_futexwait_log() {
    collect_path=${DATA_OPLUS_LOG_PATH}/futexwait_log
    if [ ! -d ${collect_path} ]
    then
        mkdir -p ${collect_path}
        chmod 700 ${collect_path}
        chown system:system ${collect_path}
    fi

    #time
    echo `date` > ${collect_path}/futexwait.time.txt

    #ps -t info
    ps -A -T > $collect_path/ps.txt

    #D status to dmesg
    echo w > /proc/sysrq-trigger

    #systemserver trace
    system_server_pid=`ps -A |grep system_server | $XKIT awk '{print $2}'`
    kill -3 ${system_server_pid}
    sleep 10
    cp /data/anr/traces.txt $collect_path/

    #systemserver native backtrace
    debuggerd -b ${system_server_pid} > $collect_path/systemserver.backtrace.txt
}

#Jianping.Zheng@PSW.Android.Stability.Crash,2017/05/08,add for systemserver futex_wait block check
function checkfutexwait_wrap() {
    if [ -f /system_ext/bin/checkfutexwait ]; then
        setprop ctl.start checkfutexwait_bin
    else
        while [ true ];do
            is_futexwait_started=`getprop init.svc.checkfutexwait`
            if [ x"${is_futexwait_started}" != x"running" ]; then
                setprop ctl.start checkfutexwait
            fi
            sleep 180
        done
    fi
}

function do_check_systemserver_futexwait_block() {
    exception_max=`getprop persist.sys.futexblock.max`
    if [ x"${exception_max}" = x"" ]; then
        exception_max=60
    fi

    system_server_pid=`ps -A |grep system_server | $XKIT awk '{print $2}'`
    if [ x"${system_server_pid}" != x"" ]; then
        exception_count=0
        while [ $exception_count -lt $exception_max ] ;do
            systemserver_stack_status=`ps -A | grep system_server | $XKIT awk '{print $6}'`
            if [ x"${systemserver_stack_status}" != x"futex_wait_queue_me" ]; then
                break
            fi

            inputreader_stack_status=`ps -A -T | grep InputReader  | $XKIT awk '{print $7}'`
            if [ x"${inputreader_stack_status}" == x"futex_wait_queue_me" ]; then
                exception_count=`expr $exception_count + 1`
                if [ x"${exception_count}" = x"${exception_max}" ]; then
                    echo "Systemserver,FutexwaitBlocked-"`date` > "/proc/sys/kernel/hung_task_kill"
                    setprop sys.oppo.futexwaitblocked "`date`"
                    collect_futexwait_log
                    kill -9 $system_server_pid
                    sleep 60
                    break
                fi
                sleep 1
            else
                break
            fi
        done
    fi
}
#end, add for systemserver futex_wait block check

#Fuchun.Liao@BSP.CHG.Basic 2019/06/09 modify for black/bright check
function create_black_bright_check_file(){
	if [ ! -d "/data/oplus/log/bsp" ]; then
		mkdir -p /data/oplus/log/bsp
		chmod -R 777 /data/oplus/log/bsp
		chown -R system:system /data/oplus/log/bsp
	fi

	if [ ! -f "/data/oplus/log/bsp/blackscreen_count.txt" ]; then
		touch /data/oplus/log/bsp/blackscreen_count.txt
		echo 0 > /data/oplus/log/bsp/blackscreen_count.txt
	fi
	chmod 0664 /data/oplus/log/bsp/blackscreen_count.txt

	if [ ! -f "/data/oplus/log/bsp/blackscreen_happened.txt" ]; then
		touch /data/oplus/log/bsp/blackscreen_happened.txt
		echo 0 > /data/oplus/log/bsp/blackscreen_happened.txt
	fi
	chmod 0664 /data/oplus/log/bsp/blackscreen_happened.txt

	if [ ! -f "/data/oplus/log/bsp/brightscreen_count.txt" ]; then
		touch /data/oplus/log/bsp/brightscreen_count.txt
		echo 0 > /data/oplus/log/bsp/brightscreen_count.txt
	fi
	chmod 0664 /data/oplus/log/bsp/brightscreen_count.txt

	if [ ! -f "/data/oplus/log/bsp/brightscreen_happened.txt" ]; then
		touch /data/oplus/log/bsp/brightscreen_happened.txt
		echo 0 > /data/oplus/log/bsp/brightscreen_happened.txt
	fi
	chmod 0664 /data/oplus/log/bsp/brightscreen_happened.txt
}
#================================== STABILITY =========================

#Fei.Mo@PSW.BSP.Sensor, 2017/09/05 ,Add for power monitor top info
function thermalTop(){
   top -m 3 -n 1 > /data/system/dropbox/thermalmonitor/top
   chown system:system /data/system/dropbox/thermalmonitor/top
}
#end, Add for power monitor top info

#Canjie.Zheng@ANDROID.DEBUG.1078692, 2017/11/20, Add for iotop
function getiotop() {
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    if [ x"${panicenable}" = x"true" ] || [ x"${camerapanic}" = x"true" ]; then
        APPS_LOG_PATH=`getprop sys.oplus.logkit.appslog`
        iotop=${APPS_LOG_PATH}/iotop.txt
        timestamp=`date +"%m-%d %H:%M:%S"\(timestamp\)`
        echo ${timestamp} >> ${iotop}
        iotop -m 5 -n 5 -P >> ${iotop}
    fi
}

function mvrecoverylog() {
    echo "mvrecoverylog begin"
    rm -rf ${SDCARD_LOG_BASE_PATH}/recovery_log/
    mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log
    state=`getprop ro.build.ab_update`
    if [ "${state}" = "true" ] ;then
        mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log/recovery
        mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log/factory
        mkdir -p ${SDCARD_LOG_BASE_PATH}/recovery_log/update_engine_log
        setprop sys.oplus.copyrecoverylog 1
    else
        mv /cache/recovery/* ${SDCARD_LOG_BASE_PATH}/recovery_log
    fi
    echo "mvrecoverylog end"
}

function logcusqmistart() {
    echo "logcusqmistart begin"
    echo 0x2 > /sys/module/ipc_router_core/parameters/debug_mask
    #add for SM8150 platform
    if [ -d "/d/ipc_logging" ]; then
        path=${DATA_DEBUGGING_PATH}/customer/ipc_log
        mkdir -p ${path}
        cat /d/ipc_logging/adsp/log > ${path}/adsp_glink.txt
        cat /d/ipc_logging/modem/log > ${path}/modem_glink.txt
        cat /d/ipc_logging/cdsp/log > ${path}/cdsp_glink.txt
        cat /d/ipc_logging/qrtr_0/log > ${path}/modem_qrtr.txt
        cat /d/ipc_logging/qrtr_5/log > ${path}/sensor_qrtr.txt
        cat /d/ipc_logging/qrtr_10/log > ${path}/NPU_qrtr.txt
        /vendor/bin/qrtr-lookup > ${path}/qrtr-lookup_start.txt
    fi
    echo "logcusqmistart end"
}
function logcusqmistop() {
    echo "logcusqmistop begin"
    echo 0x0 > /sys/module/ipc_router_core/parameters/debug_mask
    path=${DATA_DEBUGGING_PATH}/customer/ipc_log
    mkdir -p ${path}
    /vendor/bin/qrtr-lookup > ${path}/qrtr-lookup_stop.txt
    echo "logcusqmistop end"
}

#ifdef OPLUS_BUG_STABILITY
#WangGuoqiang@OPLUS_FEATURE_WIFI_SWITCHFAILED ,2020/04/19 , add for collect wifi log
function captureAndroidLog(){
    COLLECT_LOG_PATH="${DATA_DEBUGGING_PATH}/wifi_log_temp"
    if [ ! -d  ${COLLECT_LOG_PATH} ];then
        mkdir -p ${COLLECT_LOG_PATH}
        chown system:system ${COLLECT_LOG_PATH}
        chmod -R 777 ${COLLECT_LOG_PATH}
    fi
    /system/bin/logcat -b main -b system -f ${COLLECT_LOG_PATH}/android_log.txt -r10240 -v threadtime *:V
}

function captureKernelLog(){
    COLLECT_LOG_PATH="${DATA_DEBUGGING_PATH}/wifi_log_temp"
    if [ ! -d  ${COLLECT_LOG_PATH} ];then
        mkdir -p ${COLLECT_LOG_PATH}
        chown system:system ${COLLECT_LOG_PATH}
        chmod -R 777 ${COLLECT_LOG_PATH}
    fi
    dmesg > ${COLLECT_LOG_PATH}/dmesg_log.txt
}

function captureNetworkLog(){
    COLLECT_LOG_PATH="${DATA_DEBUGGING_PATH}/wifi_log_temp"
    if [ ! -d  ${COLLECT_LOG_PATH} ];then
        mkdir -p ${COLLECT_LOG_PATH}
        chown system:system ${COLLECT_LOG_PATH}
        chmod -R 777 ${COLLECT_LOG_PATH}
    fi
    tcpdump -i any -p -s 0 -W 5 -C 10 -w ${COLLECT_LOG_PATH}/tcpdump.pcap -Z root
}

function packReturnLog() {
    sleep 20
    COLLECT_LOG_PATH="${DATA_DEBUGGING_PATH}/wifi_log_temp"
    DCS_WIFI_LOG_PATH="${DATA_OPLUS_LOG_PATH}/DCS/de/network_logs/wifi_log"
    zip_name=`getprop sys.oppo.wifi.log.zipPath`
    filename="${zip_name}.tar.gz"
    if [ ! -d ${DCS_WIFI_LOG_PATH} ];then
        mkdir -p ${DCS_WIFI_LOG_PATH}
        chown system:system ${DCS_WIFI_LOG_PATH}
        chmod -R 777 ${DCS_WIFI_LOG_PATH}
    fi
    tar -czvf ${DCS_WIFI_LOG_PATH}/${filename} ${COLLECT_LOG_PATH}
    chown system:system ${DCS_WIFI_LOG_PATH}/${filename}
    rm -rf ${COLLECT_LOG_PATH}
    sleep 5
    setprop sys.oppo.wifi.log.collectorOn "false"
}
#endif /* OPLUS_BUG_STABILITY */

#ifdef OPLUS_FEATURE_WIFI_CONNECTFAILED
#Add for collect wifi connect fail log
function collectWifiConnectLog() {
    boot_completed=`getprop sys.boot_completed`
    while [ x${boot_completed} != x"1" ];do
        sleep 2
        boot_completed=`getprop sys.boot_completed`
    done
    wifiConnectLogPath="${DATA_DEBUGGING_PATH}/wifi_connect_log"
    if [ -d  ${wifiConnectLogPath} ];then
        rm -rf ${wifiConnectLogPath}
    fi

    if [ ! -d  ${wifiConnectLogPath} ];then
        mkdir -p ${wifiConnectLogPath}
    fi

    # collect driver and firmware log
    cnss_pid=`getprop vendor.oppo.wifi.cnss_diag_pid`
    if [[ "w${cnss_pid}" != "w" ]];then
        kill -s SIGUSR1 $cnss_pid
        sleep 2
        mv /data/vendor/wifi/buffered_wlan_logs/* $wifiConnectLogPath
        chmod 666 ${wifiConnectLogPath}/buffered*
    fi

    dmesg > ${wifiConnectLogPath}/dmesg.txt
    /system/bin/logcat -b main -b system -f ${wifiConnectLogPath}/android.txt -r10240 -v threadtime *:V
}

function packWifiConnectLog() {
    wifiConnectLogPath="${DATA_DEBUGGING_PATH}/wifi_connect_log"
    DCS_WIFI_LOG_PATH="/data/oppo/coloros/dcs/netlog"
    logType=`getprop sys.oplus.wifi.connect.log.type`
    logReason=`getprop sys.oplus.wifi.connect.log.reason`
    logFid=`getprop sys.oplus.wifi.connect.log.fid`
    version=`getprop ro.build.version.ota`

    if [ ! -d  ${wifiConnectLogPath} ] || [ ! -d ${DCS_WIFI_LOG_PATH} ];then
        return
    fi

    if [ "w${logReason}" == "w" ] || [ "w${logFid}" == "w" ] || [ "w${logType}" == "w" ];then
        rm -rf ${wifiConnectLogPath}
        return
    fi

    dumpsys wifi > ${wifiConnectLogPath}/dumpsys_wifi.txt

    $XKIT tar -czvf  ${wifiConnectLogPath}/${logReason}.tar.gz -C ${wifiConnectLogPath} ${wifiConnectLogPath}
    abs_file=${wifiConnectLogPath}/${logReason}.tar.gz
    targetFile="${logType}@${logFid}@${version}@${logReason}.tar.gz"
    mv ${abs_file} ${DCS_WIFI_LOG_PATH}/${targetFile}

    chmod 777 ${DCS_WIFI_LOG_PATH}/${targetFile}

    setprop sys.oplus.wifi.connect.log.stop 0
    setprop sys.oplus.wifi.connect.log.fid 0
    setprop sys.oplus.wifi.connect.log.reason 0
    setprop sys.oplus.wifi.connect.log.type 0
    rm -rf ${wifiConnectLogPath}
}
#endif /* OPLUS_FEATURE_WIFI_CONNECTFAILED */

#Guotian.Wu add for wifi p2p connect fail log
function collectWifiP2pLog() {
    boot_completed=`getprop sys.boot_completed`
    while [ x${boot_completed} != x"1" ];do
        sleep 2
        boot_completed=`getprop sys.boot_completed`
    done
    wifiP2pLogPath="${DATA_DEBUGGING_PATH}/wifi_p2p_log"
    if [ ! -d  ${wifiP2pLogPath} ];then
        mkdir -p ${wifiP2pLogPath}
    fi

    # collect driver and firmware log
    cnss_pid=`getprop vendor.oppo.wifi.cnss_diag_pid`
    if [[ "w${cnss_pid}" != "w" ]];then
        kill -s SIGUSR1 $cnss_pid
        sleep 2
        mv /data/vendor/wifi/buffered_wlan_logs/* $wifiP2pLogPath
        chmod 666 ${wifiP2pLogPath}/buffered*
    fi

    dmesg > ${wifiP2pLogPath}/dmesg.txt
    /system/bin/logcat -b main -b system -f ${wifiP2pLogPath}/android.txt -r10240 -v threadtime *:V
}

function packWifiP2pFailLog() {
    wifiP2pLogPath="${DATA_DEBUGGING_PATH}/wifi_p2p_log"
    DCS_WIFI_LOG_PATH=`getprop oppo.wifip2p.connectfail`
    logReason=`getprop oppo.wifi.p2p.log.reason`
    logFid=`getprop oppo.wifi.p2p.log.fid`
    version=`getprop ro.build.version.ota`

    if [ "w${logReason}" == "w" ];then
        return
    fi

    if [ ! -d ${DCS_WIFI_LOG_PATH} ];then
        mkdir -p ${DCS_WIFI_LOG_PATH}
        chown system:system ${DCS_WIFI_LOG_PATH}
        chmod -R 777 ${DCS_WIFI_LOG_PATH}
    fi

    if [ ! -d  ${wifiP2pLogPath} ];then
        return
    fi

    $XKIT tar -czvf  ${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz -C ${wifiP2pLogPath} ${wifiP2pLogPath}
    abs_file=${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz

    fileName="wifip2p_connect_fail@${logFid}@${version}@${logReason}.tar.gz"
    mv ${abs_file} ${DCS_WIFI_LOG_PATH}/${fileName}
    chown system:system ${DCS_WIFI_LOG_PATH}/${fileName}
    setprop sys.oppo.wifi.p2p.log.stop 0
    rm -rf ${wifiP2pLogPath}
}

#Xiao.Liang@PSW.CN.WiFi.Basic.Log.1072015, 2018/10/22, Add for collecting wifi driver log
function setiwprivpkt0() {
    iwpriv wlan0 pktlog 0
}

function setiwprivpkt1() {
    iwpriv wlan0 pktlog 1
}

function setiwprivpkt4() {
    iwpriv wlan0 pktlog 4
}

#Zaogen.Hong@PSW.CN.WiFi.Connect,2020/03/03, Add for trigger wifi dump by engineerMode
function wifi_minidump() {
    iwpriv wlan0 setUnitTestCmd 19 1 4
}

#Xiao.Liang@PSW.CN.WiFi.Basic.SoftAP.1610391, 2018/10/30, Modify for reading client devices name from /data/misc/dhcp/dnsmasq.leases
function changedhcpfolderpermissions(){
    state=`getprop oppo.wifi.softap.readleases`
    if [ "${state}" = "true" ] ;then
        chmod -R 0775 /data/misc/dhcp/
    else
        chmod -R 0770 /data/misc/dhcp/
    fi
}


#ifdef OPLUS_FEATURE_RECOVERY_BOOT
#Shuangquan.du@ANDROID.UPDATABILITY, 2019/07/03, add for generate runtime prop
function generate_runtime_prop() {
    getprop | sed -r 's|\[||g;s|\]||g;s|: |=|' | sed 's|ro.cold_boot_done=true||g' > /cache/runtime.prop
    chown root:root /cache/runtime.prop
    chmod 600 /cache/runtime.prop
    sync
}
#endif /* OPLUS_FEATURE_RECOVERY_BOOT */

#Qilong.Ao@ANDROID.BIOMETRICS, 2020/10/16, Add for adb sync
function oplussync() {
    sync
}
#endif

#add for oidt begin
#PanZhuan@BSP.Tools, 2020/10/21, modify for way of OIDT log collection changed, please contact me for new reqirement in the future, or your new requiement may not be applied in OIDT correctly
function oidtlogs() {
    # this prop is set means the value path will be removed
    removed_path=`getprop sys.oidt.remove_path`
    if [ "$removed_path" ];then
        traceTransferState "remove path ${removed_path}"
        rm -rf ${removed_path}
        setprop sys.oidt.remove_path ''
        return
    fi

    traceTransferState "oidtlogs start... "
    setprop sys.oppo.oidtlogs 0

    logTypes=`getprop sys.oppo.logTypes`
    if [ "$logTypes" = "" ];then
        logTypes=`getprop sys.oidt.log_types`
    fi

    log_path=`getprop sys.oidt.log_path`

    if [ "$log_path" ];then
        oidt_root=${log_path}
    else
        oidt_root="sdcard/OppoStamp"
    fi

    mkdir -p ${oidt_root}
    traceTransferState "oidt root: ${oidt_root}"

    log_config_file=`getprop sys.oidt.log_config`
    traceTransferState "log config file: ${log_config_file} "

    if [ "$log_config_file" ];then
        setprop sys.oidt.log_ready 0
        paths=`cat ${log_config_file}`

        for file_path in ${paths};do
            # create parent directory of each path
            dest_path=${oidt_root}${file_path%/*}
            # replace dunplicate character '//' with '/' in directory
            dest_path=${dest_path//\/\//\/}
            mkdir -p ${dest_path}
            traceTransferState "copy ${file_path} "
            cp -rf ${file_path} ${dest_path}
        done

        chmod -R 777 ${oidt_root}

        setprop sys.oidt.log_ready 1
        setprop sys.oidt.log_config ''
    elif [ "$logTypes" = "" ] || [ "$logTypes" = "100" ];then
        collect_stamp_config
        logStable
        logPerformance
        logPower
    else
        collect_stamp_config
        arr=${logTypes//,/ }
        for each in ${arr[*]}
        do
            if [ "$each" = "101" ];then
                logStable
            elif [ "$each" = "102" ];then
                logPerformance
            elif [ "$each" = "103" ];then
                logPower
            fi
        done
    fi

    setprop sys.oppo.logTypes ''
    setprop sys.oidt.log_types ''
    setprop sys.oidt.log_path ''
    setprop sys.oppo.oidtlogs 1
    traceTransferState "oidtlogs end "
}

function collect_stamp_config() {
    mkdir -p ${oidt_root}/config
    cp system/etc/sys_stamp_config.xml ${oidt_root}/config/
    cp data/system/sys_stamp_config.xml ${oidt_root}/config/
}

function logStable(){
    mkdir -p ${oidt_root}/log/stable
    cp -r ${DATA_OPLUS_LOG_PATH}/DCS/de/minidump/ ${oidt_root}/log/stable
    cp -r ${DATA_OPLUS_LOG_PATH}/DCS/en/minidump/ ${oidt_root}/log/stable
    cp -r ${DATA_OPLUS_LOG_PATH}/DCS/en/AEE_DB/ ${oidt_root}/log/stable
    cp -r data/vendor/mtklog/aee_exp/ ${oidt_root}/log/stable
    cp -r ${DATA_OPLUS_LOG_PATH}/DCS/en/hang_oppo ${oidt_root}/log/stable
    cp -r ${DATA_OPLUS_LOG_PATH}/opporeserve/media/log/hang_oppo ${oidt_root}/log/stable
}

function logPerformance(){
    mkdir -p ${oidt_root}/log/performance
    cat /proc/meminfo > ${oidt_root}/log/performance/meminfo_fs.txt
    dumpsys meminfo > ${oidt_root}/log/performance/meminfo_dump.txt
    cat proc/slabinfo > ${oidt_root}/log/performance/slabinfo_fs.txt
}

function logPower(){
    mkdir -p ${oidt_root}/log/power
    mkdir -p ${oidt_root}/log/power/trace_viewer/de
    mkdir -p ${oidt_root}/log/power/trace_viewer/en
    mkdir -p ${oidt_root}/log/power/trace_viewer_bp/de
    mkdir -p ${oidt_root}/log/power/Otrace
    cp -r ${DATA_OPLUS_LOG_PATH}/DCS/de/trace_viewer ${oidt_root}/log/power/trace_viewer/de
    cp -r ${DATA_OPLUS_LOG_PATH}/DCS/en/trace_viewer ${oidt_root}/log/power/trace_viewer/en
    cp -r ${DATA_OPLUS_LOG_PATH}/DCS/de/trace_viewer_bp ${oidt_root}/log/power/trace_viewer_bp/de
    cp -r /storage/emulated/0/Android/data/com.coloros.athena/files/Documents ${oidt_root}/log/power/Otrace
    cp -r /data/oppo/psw/powermonitor_backup ${oidt_root}/log/power
    dumpsys batterystats --thermalrec > ${oidt_root}/log/power/thermalrec.txt
    dumpsys batterystats --thermallog > ${oidt_root}/log/power/thermallog.txt
}
#add for oidt end

#ifdef OPLUS_FEATURE_MEMLEAK_DETECT
#Hailong.Liu@ANDROID.MM, 2020/03/18, add for capture native malloc leak on aging_monkey test
function storeSvelteLog() {
    local dest_dir="/data/oppo/heapdump/svelte/"
    local log_file="${dest_dir}/svelte_log.txt"
    local log_dev="/dev/svelte_log"

    if [ ! -c ${log_dev} ]; then
        /system/bin/logwrapper echo "svelte ${log_dev} does not exist."
        return 1
    fi

    if [ ! -d ${dest_dir} ]; then
        mkdir -p ${dest_dir}
        if [ "$?" -ne "0" ]; then
            /system/bin/logwrapper echo "svelte mkdir failed."
            return 1
        fi
        chmod 0777 ${dest_dir}
    fi

    if [ ! -f ${log_file} ]; then
        echo --------Start `date` >> ${log_file}
        if [ "$?" -ne "0" ]; then
            /system/bin/logwrapper echo "svelte create file failed."
            return 1
        fi
        chmod 0777 ${log_file}
    fi

    /system/bin/logwrapper echo "start store svelte log."
    while true
    do
        echo --------`date` >> ${log_file}
        /system/system_ext/bin/svelte logger >> ${log_file}
    done
}
#endif /* OPLUS_FEATURE_MEMLEAK_DETECT */

function traceTransferState() {
    if [ ! -d ${SDCARD_LOG_BASE_PATH} ]; then
        mkdir -p ${SDCARD_LOG_BASE_PATH}
        chmod 2770 ${SDCARD_LOG_BASE_PATH} -R
        echo "${CURTIME_FORMAT} TRACETRANSFERSTATE:${SDCARD_LOG_BASE_PATH} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
    fi

    content=$1
    currentTime=`date "+%Y-%m-%d %H:%M:%S"`
    echo "${currentTime} ${content} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
    log -p d -t Debuglog ${content}
}

function chmodDcsEnPath() {
    DCS_EN_PATH=${DATA_OPLUS_LOG_PATH}/DCS/en
    chmod 777 -R ${DCS_EN_PATH}
}

case "$config" in
    "transfer_log")
        transfer_log
        ;;
    "deleteFolder")
        deleteFolder
        ;;
    "deleteOrigin")
        deleteOrigin
        ;;
    "psinfo")
        psInfo
        ;;
    "topinfo")
        topInfo
        ;;
    "servicelistinfo")
        serviceListInfo
        ;;
    "dumpsysinfo")
        dumpsysInfo
        ;;
    "dumpstorageinfo")
        dumpStorageInfo
        ;;
    "tranfer_tombstone")
        tranferTombstone
        ;;
    "logcache")
        CacheLog
        ;;
    "initopluslog")
        initOplusLog
        ;;
    "tranfer_anr")
        tranferAnr
        ;;
#Chunbo.Gao@ANDROID.DEBUG.2514795, 2019/11/12, Add for copy binder_info
    "copybinderinfo")
        copybinderinfo
    ;;
#Wuchao.Huang@ROM.Framework.EAP, 2019/11/19, Add for copy binder_info
    "copyEapBinderInfo")
        copyEapBinderInfo
    ;;
#Miao.Yu@ANDROID.WMS, 2019/11/25, Add for dump wm info
    "dumpWm")
        dumpWm
    ;;
#Wenshuai.Chen@RM.AD.OppoDebug.LogKit.NA, 2020/11/05, Add for bugreport log
        "dump_bugreport")
        dump_bugreport
    ;;
    "logcatmain")
        initLogSizeAndNums
        logcatMain
        ;;
    "logcatradio")
        initLogSizeAndNums
        logcatRadio
        ;;
    "fingerprintlog")
        fingerprintLog
        ;;
    "fpqess")
        fingerprintQseeLog
        ;;
    "logcatevent")
        initLogSizeAndNums
        logcatEvent
        ;;
    "logcatkernel")
        initLogSizeAndNums
        logcatKernel
        ;;
    #Qi.Zhang@TECH.BSP.Stability 2019/09/20, Add for uefi log
    "logcatuefi")
        LogcatUefi
        ;;
    "tcpdumplog")
        initLogSizeAndNums
        #ifndef OPLUS_FEATURE_TCPDUMP
        #DuYuanhua@NETWORK.DATA.2959182, remove redundant code for rutils-remove action
        #enabletcpdump
        #endif
        tcpDumpLog
        ;;
    "clean")
        CleanAll
        ;;
    "cleardataoppolog")
        clearDataOppoLog
        ;;

#ifdef OPLUS_FEATURE_RECOVERY_BOOT
#Shuangquan.du@ANDROID.UPDATABILITY, 2019/07/03, add for generate runtime prop
    "generate_runtime_prop")
        generate_runtime_prop
        ;;
#endif /* OPLUS_FEATURE_RECOVERY_BOOT */
#Qilong.Ao@ANDROID.BIOMETRICS, 2020/10/16, Add for adb sync
    "oplussync")
        oplussync
        ;;
#endif
    "dumpstateinfo")
        dumpStateInfo
        ;;
    "dumpenvironment")
        DumpEnvironment
        ;;
    "initcache")
        initcache
        ;;
    "logcatcache")
        logcatcache
        ;;
    "radiocache")
        radiocache
        ;;
    "eventcache")
        eventcache
        ;;
    "kernelcache")
        kernelcache
        ;;
    "tcpdumpcache")
        tcpdumpcache
        ;;
    "fingerprintcache")
        fingerprintcache
        ;;
    "fplogcache")
        fplogcache
        ;;
    "logobserver")
        logObserver
        ;;
    "gettpinfo")
        gettpinfo
    ;;
    "inittpdebug")
        inittpdebug
    ;;
    "settplevel")
        settplevel
    ;;
#Canjie.Zheng@ANDROID.DEBUG,2017/01/21,add for ftm
        "logcatftm")
        logcatftm
    ;;
        "klogdftm")
        klogdftm
    ;;
#Canjie.Zheng@ANDROID.DEBUG,2017/03/09, add for Sensor.logger
    "resetlogpath")
        resetlogpath
    ;;
#Canjie.Zheng@ANDROID.DEBUG,2017/03/23, add for power key dump
    "pwkdumpon")
        pwkdumpon
    ;;
    "pwkdumpoff")
        pwkdumpoff
    ;;
    "dumpoff")
        dumpoff
    ;;
    "packupminidump")
        packupminidump
    ;;
#Jianping.Zheng@Swdp.Android.Stability.Crash,2017/04/04,add for record performance
        "perf_record")
        perf_record
    ;;
#Jianping.Zheng@PSW.Android.Stability.Crash,2017/05/08,add for systemserver futex_wait block check
        "checkfutexwait")
        do_check_systemserver_futexwait_block
    ;;
    "checkfutexwait_wrap")
        checkfutexwait_wrap
#end, add for systemserver futex_wait block check
    ;;
#Fei.Mo@PSW.BSP.Sensor, 2017/09/01 ,Add for power monitor top info
        "thermal_top")
        thermalTop
#end, Add for power monitor top info
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OppoPowerMonitor get dmesg at O
        "kernelcacheforopm")
        kernelcacheforopm
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OppoPowerMonitor get Sysinfo at O
        "psforopm")
        psforopm
    ;;
        "logcatMainCacheForOpm")
        logcatMainCacheForOpm
    ;;
        "logcatEventCacheForOpm")
        logcatEventCacheForOpm
    ;;
        "logcatRadioCacheForOpm")
        logcatRadioCacheForOpm
    ;;
        "catchBinderInfoForOpm")
        catchBinderInfoForOpm
    ;;
        "catchBattertFccForOpm")
        catchBattertFccForOpm
    ;;
        "catchTopInfoForOpm")
        catchTopInfoForOpm
    ;;
          "dumpsysHansHistoryForOpm")
        dumpsysHansHistoryForOpm
    ;;
        "getPropForOpm")
        getPropForOpm
    ;;
        "dumpsysSurfaceFlingerForOpm")
        dumpsysSurfaceFlingerForOpm
    ;;
        "dumpsysSensorserviceForOpm")
        dumpsysSensorserviceForOpm
    ;;
        "dumpsysBatterystatsForOpm")
        dumpsysBatterystatsForOpm
    ;;
        "dumpsysBatterystatsOplusCheckinForOpm")
        dumpsysBatterystatsOplusCheckinForOpm
    ;;
        "dumpsysBatterystatsCheckinForOpm")
        dumpsysBatterystatsCheckinForOpm
    ;;
        "dumpsysMediaForOpm")
        dumpsysMediaForOpm
    ;;
        "logcusMainForOpm")
        logcusMainForOpm
    ;;
        "logcusEventForOpm")
        logcusEventForOpm
    ;;
        "logcusRadioForOpm")
        logcusRadioForOpm
    ;;
        "logcusKernelForOpm")
        logcusKernelForOpm
    ;;
        "logcusTCPForOpm")
        logcusTCPForOpm
    ;;
        "customDiaglogForOpm")
        customDiaglogForOpm
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2019/08/21, Add for OppoPowerMonitor get qrtr at Qcom
        "qrtrlookupforopm")
        qrtrlookupforopm
    ;;
        "cpufreqforopm")
        cpufreqforopm
    ;;
        "slabinfoforhealth")
        slabinfoforhealth
    ;;
        "svelteforhealth")
        svelteforhealth
    ;;
        "meminfoforhealth")
        meminfoforhealth
    ;;
        "dmaprocsforhealth")
        dmaprocsforhealth
    ;;
#add for customer log
        "delcustomlog")
        delcustomlog
    ;;
        "customdmesg")
        customdmesg
    ;;
        "customdiaglog")
        customdiaglog
    ;;
        "cleanramdump")
        cleanramdump
    ;;
        "mvrecoverylog")
        mvrecoverylog
    ;;
        "logcusmain")
        logcusmain
    ;;
        "logcusevent")
        logcusevent
    ;;
        "logcusradio")
        logcusradio
    ;;
        "logcustcp")
        logcustcp
    ;;
        "logcuskernel")
        logcuskernel
    ;;
        "logcusqmistart")
        logcusqmistart
    ;;
        "logcusqmistop")
        logcusqmistop
    ;;
#laixin@PSW.CN.WiFi.Basic.Switch.1069763, 2018/09/03, Add for collect wifi switch log
        "collectWifiP2pLog")
        collectWifiP2pLog
    ;;
        "packWifiP2pFailLog")
        packWifiP2pFailLog
    ;;
#ifdef OPLUS_FEATURE_WIFI_CONNECTFAILED
#Add for collect wifi connect fail log
        "collectWifiConnectLog")
        collectWifiConnectLog
    ;;
        "packWifiConnectLog")
        packWifiConnectLog
    ;;
#endif  /* OPLUS_FEATURE_WIFI_CONNECTFAILED */
#Xiao.Liang@PSW.CN.WiFi.Basic.Log.1072015, 2018/10/22, Add for collecting wifi driver log
        "setiwprivpkt0")
        setiwprivpkt0
    ;;
        "setiwprivpkt1")
        setiwprivpkt1
    ;;
        "setiwprivpkt4")
        setiwprivpkt4
    ;;
#Zaogen.Hong@PSW.CN.WiFi.Connect,2020/03/03, Add for trigger wifi dump by engineerMode
        "wifi_minidump")
        wifi_minidump
    ;;

#Xiao.Liang@PSW.CN.WiFi.Basic.SoftAP.1610391, 2018/10/30, Modify for reading client devices name from /data/misc/dhcp/dnsmasq.leases
        "changedhcpfolderpermissions")
        changedhcpfolderpermissions
    ;;
#add for change printk
        "chprintk")
        chprintk
    ;;
#ifdef OPLUS_BUG_STABILITY
#Qing.Wu@ANDROID.STABILITY.2278668, 2019/09/03, Add for capture binder info
    "binderinfocapture")
        binderinfocapture
        ;;
#endif /* OPLUS_BUG_STABILITY */
#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/08/31.add for fix debug system_server register too many receivers issue.
    "receiverinfocapture")
        receiverinfocapture
        ;;
#endif /*OPLUS_BUG_STABILITY*/
#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/09/21.add for fix debug system_server register too many receivers issue.
    "binderthreadfullcapture")
        binderthreadfullcapture
        ;;
#endif /*OPLUS_BUG_STABILITY*/
#//Chunbo.Gao@ANDROID.DEBUG.1968962, 2019/4/23, Add for qmi log
        "qmilogon")
        qmilogon
    ;;
        "qmilogoff")
        qmilogoff
    ;;
        "adspglink")
        adspglink
    ;;
        "modemglink")
        modemglink
    ;;
        "cdspglink")
        cdspglink
    ;;
        "modemqrtr")
        modemqrtr
    ;;
        "sensorqrtr")
        sensorqrtr
    ;;
        "npuqrtr")
        npuqrtr
    ;;
        "slpiqrtr")
        slpiqrtr
    ;;
        "slpiglink")
        slpiglink
    ;;
#ifdef OPLUS_DEBUG_SSLOG_CATCH
#ZhangWankang@NETWORK.POWER 2020/04/02,add for catch ss log
        "logcatSsLog")
        logcatSsLog
    ;;
#endif

#ifdef OPLUS_BUG_STABILITY
#WangGuoqiang@OPLUS_FEATURE_WIFI_SWITCHFAILED ,2020/04/19 , add for collect wifi log
        "logReturnControlStart")
        logReturnControlStart
    ;;
        "captureAndroidLog")
        captureAndroidLog
    ;;
        "captureKernelLog")
        captureKernelLog
    ;;
        "captureNetworkLog")
        captureNetworkLog
    ;;
        "packReturnLog")
        packReturnLog
    ;;
#endif /* OPLUS_BUG_STABILITY */
    "cameraloginit")
        cameraloginit
    ;;
        "oidtlogs")
        oidtlogs
    ;;
#Yufeng.Liu@Plf.TECH.Performance, 2019/9/3, Add for malloc_debug
        "memdebugregister")
        memdebugregister
    ;;
        "memdebugstart")
        memdebugstart
    ;;
        "memdebugdump")
        memdebugdump
    ;;
        "memdebugremove")
        memdebugremove
    ;;
	"transferUser")
        transferUser
    ;;
	"dump_system")
        getSystemStatus
    ;;
    "transfer_data_vendor")
        transferDataVendor
    ;;
    "testtransfersystem")
        testTransferSystem
    ;;
	"testtransferroot")
        testTransferRoot
    ;;
#Fuchun.Liao@BSP.CHG.Basic 2019/06/09 modify for black/bright check
	"create_black_bright_check_file")
        create_black_bright_check_file
    ;;
#ifdef OPLUS_BUG_COMPATIBILITY
#Rui.Liu@ANDROID.COMPATIBILITY, 2020/11/11, Add for copy third part dir file
    "copyThridPartDirToCfl")
        copyThridPartDirToCfl
    ;;
#endif /* OPLUS_BUG_COMPATIBILITY */
#ifdef OPLUS_FEATURE_MEMLEAK_DETECT
#Hailong.Liu@ANDROID.MM, 2020/03/18, add for capture native malloc leak on aging_monkey test
    "storeSvelteLog")
        storeSvelteLog
    ;;
#endif /* PLUS_FEATURE_MEMLEAK_DETECT */
    "backup_minidumplog")
        backupMinidump
    ;;
    "chmoddcsenpath")
        chmodDcsEnPath
    ;;
       *)

      ;;
esac
