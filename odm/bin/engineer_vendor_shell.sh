#!/vendor/bin/sh

config="$1"

function doAddRadioFile(){
    if [[ -d /mnt/vendor/opporeserve/radio ]]; then
        if [[ ! -f /mnt/vendor/opporeserve/radio/exp_operator_switch.config ]]; then
            touch /mnt/vendor/opporeserve/radio/exp_operator_switch.config
        fi
        if [[ ! -f /mnt/vendor/opporeserve/radio/exp_region_netlock.config ]]; then
            touch /mnt/vendor/opporeserve/radio/exp_region_netlock.config
        fi
        if [[ ! -f /mnt/vendor/opporeserve/radio/exp_operator_simlock_switch.config ]]; then
            touch /mnt/vendor/opporeserve/radio/exp_operator_simlock_switch.config
        fi
        if [[ ! -f /mnt/vendor/opporeserve/radio/exp_operator_simlock_times.config ]]; then
            touch /mnt/vendor/opporeserve/radio/exp_operator_simlock_times.config
        fi
        if [[ ! -f /mnt/vendor/opporeserve/radio/exp_sim_operator_switch.config ]]; then
            touch /mnt/vendor/opporeserve/radio/exp_sim_operator_switch.config
        fi
        if [[ ! -f /mnt/vendor/opporeserve/radio/exp_open_market_singlecard.config ]]; then
            touch /mnt/vendor/opporeserve/radio/exp_open_market_singlecard.config
        fi

        chown radio system /mnt/vendor/opporeserve/radio/exp_operator_switch.config
        chown radio system /mnt/vendor/opporeserve/radio/exp_region_netlock.config
        chown radio system /mnt/vendor/opporeserve/radio/exp_operator_simlock_switch.config
        chown radio system /mnt/vendor/opporeserve/radio/exp_operator_simlock_times.config
        chown radio system /mnt/vendor/opporeserve/radio/exp_sim_operator_switch.config
        chown radio system /mnt/vendor/opporeserve/radio/exp_open_market_singlecard.config


        chmod 0660 /mnt/vendor/opporeserve/radio/exp_operator_switch.config
        chmod 0660 /mnt/vendor/opporeserve/radio/exp_region_netlock.config
        chmod 0660 /mnt/vendor/opporeserve/radio/exp_operator_simlock_switch.config
        chmod 0660 /mnt/vendor/opporeserve/radio/exp_operator_simlock_times.config
        chmod 0660 /mnt/vendor/opporeserve/radio/exp_sim_operator_switch.config
        chmod 0660 /mnt/vendor/opporeserve/radio/exp_open_market_singlecard.config

    fi
    if [[ -d /mnt/vendor/oplusreserve/radio ]]; then
        if [[ ! -f /mnt/vendor/oplusreserve/radio/exp_operator_switch.config ]]; then
            touch /mnt/vendor/oplusreserve/radio/exp_operator_switch.config
        fi
        if [[ ! -f /mnt/vendor/oplusreserve/radio/exp_region_netlock.config ]]; then
            touch /mnt/vendor/oplusreserve/radio/exp_region_netlock.config
        fi
        if [[ ! -f /mnt/vendor/oplusreserve/radio/exp_operator_simlock_switch.config ]]; then
            touch /mnt/vendor/oplusreserve/radio/exp_operator_simlock_switch.config
        fi
        if [[ ! -f /mnt/vendor/oplusreserve/radio/exp_operator_simlock_times.config ]]; then
            touch /mnt/vendor/oplusreserve/radio/exp_operator_simlock_times.config
        fi
        if [[ ! -f /mnt/vendor/oplusreserve/radio/exp_sim_operator_switch.config ]]; then
            touch /mnt/vendor/oplusreserve/radio/exp_sim_operator_switch.config
        fi
        if [[ ! -f /mnt/vendor/oplusreserve/radio/exp_open_market_singlecard.config ]]; then
            touch /mnt/vendor/oplusreserve/radio/exp_open_market_singlecard.config
        fi

        chown radio system /mnt/vendor/oplusreserve/radio/exp_operator_switch.config
        chown radio system /mnt/vendor/oplusreserve/radio/exp_region_netlock.config
        chown radio system /mnt/vendor/oplusreserve/radio/exp_operator_simlock_switch.config
        chown radio system /mnt/vendor/oplusreserve/radio/exp_operator_simlock_times.config
        chown radio system /mnt/vendor/oplusreserve/radio/exp_sim_operator_switch.config
        chown radio system /mnt/vendor/oplusreserve/radio/exp_open_market_singlecard.config


        chmod 0660 /mnt/vendor/oplusreserve/radio/exp_operator_switch.config
        chmod 0660 /mnt/vendor/oplusreserve/radio/exp_region_netlock.config
        chmod 0660 /mnt/vendor/oplusreserve/radio/exp_operator_simlock_switch.config
        chmod 0660 /mnt/vendor/oplusreserve/radio/exp_operator_simlock_times.config
        chmod 0660 /mnt/vendor/oplusreserve/radio/exp_sim_operator_switch.config
        chmod 0660 /mnt/vendor/oplusreserve/radio/exp_open_market_singlecard.config

    fi
}

function doStartDiagSocketLog {
    ip_address=`getprop vendor.oppo.diag.socket.ip`
    port=`getprop vendor.oppo.diag.socket.port`
    retry=`getprop vendor.oppo.diag.socket.retry`
    channel=`getprop vendor.oppo.diag.socket.channel`
    if [[ -z "${ip_address}" ]]; then
        ip_address=181.157.1.200
    fi
    if [[ -z "${port}" ]]; then
        port=2500
    fi
    if [[ -z "${retry}" ]]; then
        port=10000
    fi
    if [[ -z "${channel}" ]]; then
        diag_socket_log -a ${ip_address} -p ${port} -r ${retry}
    else
        diag_socket_log -a ${ip_address} -p ${port} -r ${retry} -c ${channel}
    fi
}

function doStopDiagSocketLog {
    diag_socket_log -k
}

function doWlanFtmBatchTestInit {
    rmmod wlan
    if [[ -f /vendor/lib/modules/qca_cld3_qca6390.ko ]]; then
        insmod /vendor/lib/modules/qca_cld3_qca6390.ko
    else
        insmod /vendor/lib/modules/qca_cld3_wlan.ko
    fi
    sleep 1
    ifconfig  wlan0 up
    sleep 3
    echo 5 > /sys/module/wlan/parameters/con_mode
    ftmdaemon -n -dd
}

function doWlanFtmBatchTestUninit {
    rmmod wlan
    if [[ -f /vendor/lib/modules/qca_cld3_qca6390.ko ]]; then
        insmod /vendor/lib/modules/qca_cld3_qca6390.ko
    else
        insmod /vendor/lib/modules/qca_cld3_wlan.ko
    fi
    ifconfig  wlan0 up
}

case "$config" in
    "addRadioFile")
    doAddRadioFile
    ;;
    "startDiagSocketLog")
    doStartDiagSocketLog
    ;;
    "stopDiagSocketLog")
    doStopDiagSocketLog
    ;;
    "wlanFtmBatchTestInit")
    doWlanFtmBatchTestInit
    ;;
    "wlanFtmBatchTestUninit")
    doWlanFtmBatchTestUninit
    ;;
esac
