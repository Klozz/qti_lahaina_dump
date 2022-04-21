#!/system/bin/sh
#***********************************************************
#** Copyright (C), 2019-2029, OPPO Mobile Comm Corp., Ltd
#** All rights reserved.
#**
#** File: - init.oppo.wifi.RusUpgrade.sh
#** Description: support auto update function, include mtk fw, mtk wifi.cfg, qcom fw, qcom bdf, qcom ini
#**
#** Version: 1.1
#** Date : 2020/02/20
#** Author: JiaoBo
#** TAG: CONNECTIVITY.WIFI.BASIC.HARDWARE.2795386
#** ---------------------Revision History: ---------------------
#**  <author>    <data>       <version >       <desc>
#**  Jiao.Bo       2020/02/20     1.0     build this module
#**  Jiao.Bo       2020/05/20     1.1     OPLUS_FEATURE_WIFI_RUSUPGRADE
#****************************************************************/

config="$1"

#common info
defaultVersion="20190101000000"
nullVersion="null"
rusDir="/data/oppo/common/sau_res/res/SAU-AUTO_LOAD_FW-10/wifi"
rusTempFinishPath="/data/misc/wifi/rus/finish"
rusTempDir="/data/misc/wifi/rus/"
rusEntityConfigXmlfile=/system_ext/etc/sys_wifi_rus_config.xml
rusFirmwareDir="/data/misc/firmware/"
rusPushDir="/data/misc/firmware/push/"
isConfigXmlParseDone="false"
isVendorVerUpdate="false"
isTempVerUpdate="false"
isPushVerUpdate="false"

#mtk platform info
mtkWifiTempDirVersionList=("20190101000000" "20190101000000" "20190101000000")
mtkWifiPushDirVersionList=("20190101000000" "20190101000000" "20190101000000")
mtkWifiVendorDirVersionList=("20190101000000" "20190101000000" "20190101000000")
mtkWifirusEntityTypeList=("wifi.cfg" "wifi.fw" "wifi.nv")
mtkWifirusEntityVersionFileNameList=(
"wifi.cfg"
"WIFI_RAM_CODE_soc2_0_3a_1.bin"
"WIFI")
mtkWifirusEntityFileNameList=(
"wifi.cfg"
"WIFI_RAM_CODE_soc2_0_3a_1.bin;soc2_0_ram_wifi_3a_1_hdr.bin;soc2_0_ram_bt_3a_1_hdr.bin;soc2_0_ram_mcu_3a_1_hdr.bin;soc2_0_patch_mcu_3a_1_hdr.bin"
"WIFI")
mtkWifirusEntityActivePathList=(
"/data/misc/firmware/active/"
"/data/misc/firmware/active/"
"/data/misc/firmware/active/")

#qcom paltform info
qcomWifiTempDirVersionList=("20190101000000" "20190101000000" "20190101000000")
qcomWifiPushDirVersionList=("20190101000000" "20190101000000" "20190101000000")
qcomWifiVendorDirVersionList=("20190101000000" "20190101000000" "20190101000000")
qcomWifirusEntityTypeList=("wifi.ini" "wifi.fw" "wifi.bdf")
qcomWifirusEntityVersionFileNameList=(
"WCNSS_qcom_cfg.ini"
"wlandsp.mbn"
"bin_version")
qcomWifirusEntityFileNameList=(
"WCNSS_qcom_cfg.ini"
"wlandsp.mbn"
"bin_version;bdwlan.bin")
qcomWifirusEntityActivePathList=(
"/data/misc/firmware/active/"
"/data/misc/firmware/active/"
"/data/misc/firmware/active/")


#function: get the entity type index
function getrusEntityTypeIdx() {
    local platform=$1
    local type=$2
    if [ "$platform" = "mtk" ]; then
        if [ "$type" = "wifi.cfg" ]; then
            return 0
        elif [ "$type" = "wifi.fw" ]; then
            return 1
        elif [ "$type" = "wifi.nv" ]; then
            return 2
        fi
    elif [ "$platform" = "qcom" ]; then
        if [ "$type" = "wifi.ini" ]; then
            return 0
        elif [ "$type" = "wifi.fw" ]; then
            return 1
        elif [ "$type" = "wifi.bdf" ]; then
            return 2
        fi
    fi
    return 0
}

#function: get the vendor suppprt Entity file name which include version information
function parseSupportrusEntityConfigXml() {
    local board=`getprop ro.board.platform`
    if [ "$isConfigXmlParseDone" = "false" ]; then
        local cmd=`sed -n -e 's/<Entity //' -e 's/\/>//p' $rusEntityConfigXmlfile | sed -e 's/platform="//' -e 's/type="//' -e 's/versionFileName="//' -e 's/fileNameList="//' -e 's/"//g'`
        execute=($(echo $cmd))
        local length=${#execute[*]}
        local i=0
        while [ i -lt length ]
        do
            local platform=${execute[i]}
            local type=${execute[++i]}
            local versionFileName=${execute[++i]}
            local fileNameList=${execute[++i]}
            local typeIdx
            if [[ $board == *"mt"* ]] || [[ $board == *"Mt"*  ]] || [[ $board == *"MT"*  ]];then
                getrusEntityTypeIdx "mtk" $type
                typeIdx=$?
                if [ "$platform" = "$board" ]; then
                    mtkWifirusEntityVersionFileNameList[typeIdx]=$versionFileName
                    mtkWifirusEntityFileNameList[typeIdx]=$fileNameList
                    echo "index=$i Entity$typeIdx: platform:$platform type:$type"
                    echo "         versionFileName:${mtkWifirusEntityVersionFileNameList[typeIdx]}"
                    echo "         fileNameList:${mtkWifirusEntityFileNameList[typeIdx]}"
                fi
            else
                getrusEntityTypeIdx "qcom" $type
                typeIdx=$?
                if [ "$platform" = "$board" ]; then
                    qcomWifirusEntityVersionFileNameList[typeIdx]=$versionFileName
                    qcomWifirusEntityFileNameList[typeIdx]=$fileNameList
                    echo "index=$i Entity$typeIdx: platform:$platform type:$type"
                    echo "         versionFileName:${qcomWifirusEntityVersionFileNameList[typeIdx]}"
                    echo "         fileNameList:${qcomWifirusEntityFileNameList[typeIdx]}"
                fi
            fi
            i=$((i+1))
        done
        isConfigXmlParseDone="true"
    else
        echo "already parse done."
    fi
}

#function: get all vendor suppprt Entity version for mtk
function rusMtkWifiEntityVerUpdate() {
    parseSupportrusEntityConfigXml
    local folderType=$1
    local i=0
    local folder=""
    local version=""
    local length=${#mtkWifirusEntityTypeList[@]}
    if [ "$folderType" = "temp" ]; then
        if [ "$isTempVerUpdate" = "true" ]; then
            echo "temp version already update done."
            return 0
        fi
        folder=$rusTempDir
        isTempVerUpdate="true"
    elif [ "$folderType" = "push" ]; then
        if [ "$isPushVerUpdate" = "true" ]; then
            echo "push version already update done."
            return 0
        fi
        folder=$rusPushDir
        isPushVerUpdate="true"
    elif [ "$folderType" = "vendor" ]; then
        if [ "$isVendorVerUpdate" = "false" ]; then
            i=0
            local vendorVerlist=`getprop vendor.oplus.wifi.rus.version`
            for version  in `echo $vendorVerlist | sed 's/;/ /g'`
            do
                if [ "$version" = "$nullVersion" ]; then
                    mtkWifiVendorDirVersionList[i]=$defaultVersion
                else
                    mtkWifiVendorDirVersionList[i]=$version
                fi
                echo "mtkWifiVendorDirVersionList[$i]=${mtkWifiVendorDirVersionList[i]}"
                i=$((i+1))
            done
            isVendorVerUpdate="true"
        else
            echo "vendor version already update done."
        fi
        return 0
    fi
    i=0
    while [ i -lt length ]
    do
        local str=""
        local type=${mtkWifirusEntityTypeList[i]}
        local file=$folder${mtkWifirusEntityVersionFileNameList[i]}
        if [ -f $file ]; then
            if [ "$type" = "wifi.cfg" ]; then
                str=`head -c 25 $file`
                version=${str:9:14}
            elif [ "$type" = "wifi.fw" ]; then
                str=`tail -c 19 $file`
                version=${str:0:14}
            elif [ "$type" = "wifi.nv" ]; then
                version=$defaultVersion
            else
                version=$defaultVersion
            fi
        else
            version=$defaultVersion
        fi
        if [ "$folderType" = "temp" ]; then
            mtkWifiTempDirVersionList[i]=$version
            echo "mtkWifiTempDirVersionList[$i]=${mtkWifiTempDirVersionList[i]}"
        elif [ "$folderType" = "push" ]; then
            mtkWifiPushDirVersionList[i]=$version
            echo "mtkWifiPushDirVersionList[$i]=${mtkWifiPushDirVersionList[i]}"
        elif [ "$folderType" = "vendor" ]; then
            mtkWifiVendorDirVersionList[i]=$version
            echo "mtkWifiVendorDirVersionList[$i]=${mtkWifiVendorDirVersionList[i]}"
        fi
        i=$((i+1))
    done
}

#function: get all vendor suppprt Entity version for qcom
function rusQcomWifiEntityVerUpdate() {
    parseSupportrusEntityConfigXml
    local folderType=$1
    local i=0
    local folder=""
    local length=${#qcomWifirusEntityTypeList[@]}
    local version=""
    if [ "$folderType" = "temp" ]; then
        if [ "$isTempVerUpdate" = "true" ]; then
            echo "temp version already update done."
            return 0
        fi
        folder=$rusTempDir
        isTempVerUpdate="true"
    elif [ "$folderType" = "push" ]; then
        if [ "$isPushVerUpdate" = "true" ]; then
            echo "push version already update done."
            return 0
        fi
        folder=$rusPushDir
        isPushVerUpdate="true"
    elif [ "$folderType" = "vendor" ]; then
        if [ "$isVendorVerUpdate" = "false" ]; then
            i=0
            local vendorVerlist=`getprop vendor.oplus.wifi.rus.version`
            for version  in `echo $vendorVerlist | sed 's/;/ /g'`
            do
                if [ "$version" = "$nullVersion" ]; then
                    qcomWifiVendorDirVersionList[i]=$defaultVersion
                else
                    qcomWifiVendorDirVersionList[i]=$version
                fi
                echo "qcomWifiVendorDirVersionList[$i]=${qcomWifiVendorDirVersionList[i]}"
                i=$((i+1))
            done
            isVendorVerUpdate="true"
        else
            echo "vendor version already update done."
        fi
        return 0
    fi
    i=0
    while [ i -lt length ]
    do
        local type=${qcomWifirusEntityTypeList[i]}
        local file=$folder${qcomWifirusEntityVersionFileNameList[i]}
        if [ -f $file ]; then
            if [ "$type" = "wifi.ini" ]; then
                #default not support update this entity
                version=$nullVersion
            elif [ "$type" = "wifi.fw" ]; then
                #default not support update this entity
                version=$nullVersion
            elif [ "$type" = "wifi.bdf" ]; then
                #default not support update this entity
                version=$nullVersion
            else
                version=$nullVersion
            fi
        else
            version=$nullVersion
        fi
        if [ "$folderType" = "temp" ]; then
            qcomWifiTempDirVersionList[i]=$version
            echo "qcomWifiTempDirVersionList[$i]=${qcomWifiTempDirVersionList[i]}"
        elif [ "$folderType" = "push" ]; then
            qcomWifiPushDirVersionList[i]=$version
            echo "qcomWifiPushDirVersionList[$i]=${qcomWifiPushDirVersionList[i]}"
        elif [ "$folderType" = "vendor" ]; then
            qcomWifiVendorDirVersionList[i]=$version
            echo "qcomWifiVendorDirVersionList[$i]=${qcomWifiVendorDirVersionList[i]}"
        fi
        i=$((i+1))
    done
}

# function: get all suppprt Entity version
function rusWifiEntityVerUpdate() {
    local platform=$1
    local folderType=$2
    if [ "$platform" = "mtk" ]; then
        rusMtkWifiEntityVerUpdate $folderType
    elif [ "$platform" = "qcom" ]; then
        rusQcomWifiEntityVerUpdate $folderType
    fi
}

function rusWifiObjsVerGet() {
    local platform=$1
    local type=$2
    local folderType=$3

    getrusEntityTypeIdx $platform $type
    local typeIdx=$?
    local version=$defaultVersion

    if [ "$platform" = "mtk" ]; then
        if [ "$folderType" = "vendor" ]; then
            version=${mtkWifiVendorDirVersionList[typeIdx]}
        elif [ "$folderType" = "temp" ]; then
            version=${mtkWifiTempDirVersionList[typeIdx]}
        elif [ "$folderType" = "push" ]; then
            version=${mtkWifiPushDirVersionList[typeIdx]}
        fi
    elif [ "$platform" = "qcom" ]; then
        if [ "$folderType" = "vendor" ]; then
            version=${qcomWifiVendorDirVersionList[typeIdx]}
        elif [ "$folderType" = "temp" ]; then
            version=${qcomWifiTempDirVersionList[typeIdx]}
        elif [ "$folderType" = "push" ]; then
            version=${qcomWifiPushDirVersionList[typeIdx]}
        fi
    fi
    echo "$version"
}

# function: remove files
# $1: folder
# $2: file list
function removeFiles() {
    local folder=$1
    local filelist=$2
    local name=""
    for name  in `echo $filelist | sed 's/;/ /g'`
    do
        local file="$folder$name"
        if [ -f $file ]; then
            rm -rf $file
        fi
    done
}

# function: copy files from srcfolder to dstfolder
# $1: srcfolder
# $2: dstfolder
# $3: file list
function copyFiles() {
    local srcfolder=$1
    local dstfolder=$2
    local filelist=$3
    local name=""
    for name  in `echo $filelist | sed 's/;/ /g'`
    do
        local srcfile="$srcfolder$name"
        local dstfile="$dstfolder$name"
        if [ -f $srcfile ]; then
            cp -f $srcfile $dstfile
        fi
    done
}

# function: calculate filelist MD5 value and write to md5file, formate:"md5_1;md5_2;md5_3"
# $1: folder
# $2: file list
# $3: md5file
function createMd5Files() {
    local folder=$1
    local filelist=$2
    local md5file=$3
    local md5list=""
    local name=""
    for name  in `echo $filelist | sed 's/;/ /g'`
    do
        local file="$folder$name"
        if [ -f $file ]; then
            local str=`md5sum $file`
            md5list+="${str%% *};"
        else
            md5list+="ffffffff;"
        fi
    done
    local finalmd5list=${md5list%;*}
    if [ ! -f $md5file ]; then
        touch $md5file
    fi
    echo "$finalmd5list" > $md5file
}

# function: check md5 value make sure file abnormal change
# $1: folder
# $2: file list
# $3: md5file
function checkMd5() {
    local folder=$1
    local filelist=$2
    local md5file=$3
    local md5list=""
    local name=""
    if [ -f $md5file ]; then
        local oriMd5list=`cat $md5file`
    fi

    for name  in `echo $filelist | sed 's/;/ /g'`
    do
        local file="$folder$name"
        if [ -f $file ]; then
            local str=`md5sum $file`
            md5list+="${str%% *};"
        else
            md5list+="eeeeeeee;"
        fi
    done
    local newMd5list=${md5list%;*}

    if [ "$oriMd5list" == "$newMd5list" ];then
        return 0
    else
        return 1
    fi
}

# function: 1. check rus push dir's specific types of objs validity and copy to rus active dir
# $1: type
# $2: versionfile
# $3: file list
function rusWifiBootCheckInternel() {
    local platform=$1
    local type=$2
    local versionfile=""
    local filelist=""
    local activedir=""

    getrusEntityTypeIdx $platform $type
    local typeIdx=$?
    echo "typeIdx=$typeIdx"

    if [ "$platform" = "mtk" ]; then
        versionfile=${mtkWifirusEntityVersionFileNameList[typeIdx]}
        filelist=${mtkWifirusEntityFileNameList[typeIdx]}
        activedir=${mtkWifirusEntityActivePathList[typeIdx]}
    elif [ "$platform" = "qcom" ]; then
        versionfile=${qcomWifirusEntityVersionFileNameList[typeIdx]}
        filelist=${qcomWifirusEntityFileNameList[typeIdx]}
        activedir=${qcomWifirusEntityActivePathList[typeIdx]}
    fi

    echo "rusWifiBootCheckInternel: type = $type"
    echo "rusWifiBootCheckInternel: versionfile = $versionfile"
    echo "rusWifiBootCheckInternel: filelist = $filelist"
    echo "rusWifiBootCheckInternel: activedir = $activedir"

    local md5file=$rusPushDir$type".md5.txt"
    if [ ! -f $md5file ]; then
        removeFiles $rusPushDir $filelist
        removeFiles $activedir $filelist
        echo "rusWifiBootCheckInternel: no exist objs, return"
        return 1
    fi

    #step1 get the vendor dir obj's version
    rusWifiEntityVerUpdate $platform "push"
    local newversion=$(rusWifiObjsVerGet $platform $type "push" "true")

    #step2 get the rus dir obj's version
    rusWifiEntityVerUpdate $platform "vendor"
    local curversion=$(rusWifiObjsVerGet $platform $type "vendor" "true")
    echo "rusWifiBootCheckInternel: objs curversion = $curversion, newversion = $newversion"

    #step3 cp objs to rusPushDir when the rus dir obj's version if largger than the vendor dir obj's version
    if [ $newversion -gt $curversion ];then
        #step3.1 remove rus push dir obj file list
        removeFiles $activedir $filelist
        #step3.2 copy rus temp dir obj files to push dir obj files
        copyFiles $rusPushDir $activedir $filelist
        #step3.3 check the active dir files md5 and make sure step3.2 integrity operation
        checkMd5 $activedir $filelist $md5file
        local md5Result=$?
        if [ "$md5Result" == "0" ];then
            chmod -R 0705 $rusFirmwareDir
            chmod -R 0740 ${activedir}/*
            echo "rusWifiBootCheckInternel: $type boot check success, use active dir"
            return 0
        else
            echo "rusWifiBootCheckInternel: $type boot check failed, md5 check err when copy, use vendor dir"
            removeFiles $activedir $filelist
            return 1
        fi
    else
        echo "rusWifiBootCheckInternel: $type boot check failed, version is small than vendor dir"
        removeFiles $rusPushDir $filelist
        removeFiles $activedir $filelist
        removeFiles $rusPushDir $type".md5.txt"
        return 1
    fi
}

# function: update one type objs to rus push dir and trigger copy to rus active dir from rus push dir
# $1: type
# $2: versionfile
# $3: file list
function rusWifiCheckAndUpdate() {
    local platform=$1
    local type=$2
    local versionfile=""
    local filelist=""

    getrusEntityTypeIdx $platform $type
    local typeIdx=$?
    echo "typeIdx=$typeIdx"

    if [ "$platform" = "mtk" ]; then
        versionfile=${mtkWifirusEntityVersionFileNameList[typeIdx]}
        filelist=${mtkWifirusEntityFileNameList[typeIdx]}
    elif [ "$platform" = "qcom" ]; then
        versionfile=${qcomWifirusEntityVersionFileNameList[typeIdx]}
        filelist=${qcomWifirusEntityFileNameList[typeIdx]}
    fi

    echo "rusWifiCheckAndUpdate: type = $type"
    echo "rusWifiCheckAndUpdate: versionfile = $versionfile"
    echo "rusWifiCheckAndUpdate: filelist = $filelist"

    #step1 get the vendor dir obj's version
    rusWifiEntityVerUpdate $platform "temp"
    local newversion=$(rusWifiObjsVerGet $platform $type "temp" "true")

    #step2 get the rus dir obj's version
    rusWifiEntityVerUpdate $platform "vendor"
    local curversion=$(rusWifiObjsVerGet $platform $type "vendor" "true")
    echo "rusWifiCheckAndUpdate: objs curversion = $curversion, newversion = $newversion"

    #step3 cp objs to rusPushDir when the rus dir obj's version if largger than the vendor dir obj's version
    if [ $newversion -gt $curversion ];then
        #step3.1 remove rus push dir obj file list
        removeFiles $rusPushDir $filelist
        #step3.2 copy rus temp dir obj files to push dir obj files
        copyFiles $rusTempDir $rusPushDir $filelist
        #step3.3 create rus temp dir obj files md5file and copy to push dir
        local md5file=$rusPushDir$type".md5.txt"
        createMd5Files $rusTempDir $filelist $md5file
        #step3.3 check the push dir files md5 and make sure step3.2 integrity operation
        checkMd5 $rusPushDir $filelist $md5file
        local md5Result=$?

        if [ "$md5Result" == "0" ];then
            #step3.4 trigger copy form rusPushDir to rus Active Dir
            rusWifiBootCheckInternel $platform $type
            local bootCheckResult=$?
            if [ "$bootCheckResult" == "0" ];then
                setprop sys.oplus.wifi.rus.objs.upgrade.status "success"
                echo "rusWifiCheckAndUpdate: $type update success"
            else
                setprop sys.oplus.wifi.rus.objs.upgrade.status "faild"
                echo "rusWifiCheckAndUpdate: $type update failed, boot check err"
            fi
        else
            setprop sys.oplus.wifi.rus.objs.upgrade.status "faild"
            echo "rusWifiCheckAndUpdate: $type update failed, md5 check err"
        fi
    else
        setprop sys.oplus.wifi.rus.objs.upgrade.status "faild"
        echo "rusWifiCheckAndUpdate: $type update failed, version check err"
    fi

    removeFiles $rusTempDir $filelist
    if [ -f $rusTempFinishPath ]; then
        rm -rf $rusTempFinishPath
    fi
    touch ${rusTempFinishPath}
    chown system:system ${rusTempDir}*
}

# function: cp rus file to rus temp dir
function rusWifiFileTransfer() {
    platform=`getprop ro.board.platform`

    # step1. copy SAU-AUTO_LOAD_FW-10/wifi to /data/misc/wifi/rus and clean SAU-AUTO_LOAD_FW-10/wifi
    rm -rf ${rusTempDir}*
    echo "copy from rusDir to rus temp dir beging."
    cp -f ${rusDir}/* ${rusTempDir}
    #rm -rf ${rusDir}/*

    # step3. create finish to notify framework
    if [ -f $rusTempFinishPath ]; then
        rm -rf $rusTempFinishPath
    fi
    touch ${rusTempFinishPath}
    chown system:system ${rusTempDir}*
    setprop sys.oplus.wifi.rus.upgrade.ctl "0"
}

# function: 1. check rus temp dir's specific types of objs validity and copy to rus push dir
#           2. trigger copy to rus active dir from rus push dir
function rusWifiObjsUpgrade() {
    local platform
    board=`getprop ro.board.platform`
    if [[ $board == *"mt"* ]] || [[ $board == *"Mt"*  ]] || [[ $board == *"MT"*  ]];then
        platform="mtk"
    else
        platform="qcom"
    fi

    local wifiObjsType=`getprop sys.oplus.wifi.rus.objs.type`
    echo "start rusWifiObjsUpgrade platform=$platform wifiObjsType=$wifiObjsType"
    parseSupportrusEntityConfigXml

    rusWifiCheckAndUpdate $platform $wifiObjsType
    setprop sys.oplus.wifi.rus.upgrade.ctl "0"
}

# function: check rus push dir's all objs validity and copy to rus active dir when boot-up phase
function rusWifiBootCheck() {
    local platform
    board=`getprop ro.board.platform`
    if [[ $board == *"mt"* ]] || [[ $board == *"Mt"*  ]] || [[ $board == *"MT"*  ]];then
        platform="mtk"
    else
        platform="qcom"
    fi
    echo "start rusWifiBootCheck platform=$platform"

    parseSupportrusEntityConfigXml
    local length=0
    local i=0
    local type=""
    if [ "$platform" = "mtk" ]; then
        length=${#mtkWifirusEntityTypeList[@]}
        i=0
        while [ i -lt length ]
        do
            type=${mtkWifirusEntityTypeList[i]}
            rusWifiBootCheckInternel $platform $type
            i=$((i+1))
        done
    elif [ "$platform" = "qcom" ]; then
        length=${#qcomWifirusEntityTypeList[@]}
        i=0
        while [ i -lt length ]
        do
            type=${qcomWifirusEntityTypeList[i]}
            rusWifiBootCheckInternel $platform $type
            i=$((i+1))
        done
    fi
}

case "$config" in
    "rusWifiFileTransfer")
    rusWifiFileTransfer
    ;;
    "rusWifiObjsUpgrade")
    rusWifiObjsUpgrade
    ;;
    "rusWifiBootCheck")
    rusWifiBootCheck
    ;;
esac
