#! /system/bin/sh

origtime=$(date "+%s.%N")

#Log Definition
FREQ_TEST_PATH=/cache/freqtest
#trace test log info
FREQ_TEST_LOG_FILE=${FREQ_TEST_PATH}/freqtest.log
#trace test cpu info
FREQ_TEST_RECORD_FILE=${FREQ_TEST_PATH}/freqrecord.log
FREQ_TEST_RECORD_TEMP_FILE=${FREQ_TEST_PATH}/detailedfreqrecord.log
#record cpu clusters info
FREQ_TEST_CLUSTER_FILE=${FREQ_TEST_PATH}/clusterlist.txt
#conf file for test
FREQ_TEST_CONFIG_FILE=${FREQ_TEST_PATH}/freqtest.conf

#Propertity Definition
FREQ_TEST_PROCESS_PROPERTITY=vendor.oppo.freqtest.process
FREQ_TEST_RESULT_INFO_PROPERTITY=persist.vendor.oppo.freqtest.info

function usage()
{
    echo "usage: autofixfreqtest.sh [--help] [testtime(s)]"
    echo
    echo "Example: autofixfreqtest.sh 300"
}

function check_oppo_hypuns_state()
{
    hypnusdStateStr=`getprop | grep init.svc.hypnusd`
    hypnusdState=${hypnusdStateStr#*:}
    if [[ "$hypnusdStateStr" != "" && "$hypnusdState" = *"running"* ]]; then
        echo 0  #echo return in sub function
    else
        echo 1
    fi
}


function is_value_in_string_list()
{
    ret="no"
    var=$1
    array=($2)
    for item in ${array[@]}
    do
        if [ "$item" == "$var" ]; then
            ret="yes"
            break
        fi
    done
    echo $ret
}

function is_value_in_array()
{
    ret=0
    var=$1
    array=$2
    for item in ${array[*]}
    do
        if [ "$item" == "$var" ]; then
            ret=1
            break
        fi
    done
    echo $ret
}

function is_big_core()
{
    testcpu=$1
    echo $(is_value_in_array $testcpu "${bigcorelist[*]}")
}

function get_random_small_cpu()
{
    smalllen=${#smallcorelist[@]}
    randindex=$(($RANDOM % $smalllen))
    echo ${smallcorelist[$randindex]}
}

function get_random_big_cpu()
{
  biglen=${#bigcorelist[@]}
  randindex=$(($RANDOM % $biglen))
  echo ${bigcorelist[$randindex]}
}
function get_cpu_clusters_and_list()
{
    n=0
    echo 0 > ${FREQ_TEST_CLUSTER_FILE}
    cpuarray[$n]=0

    relatedcpusStr=`cat /sys/devices/system/cpu/cpu0/cpufreq/related_cpus`

    for i in $(seq 0 $(($cpus-1)))
    do
        ret=$(is_value_in_string_list $i "$relatedcpusStr")
        if [[ $ret == "no" ]]; then
            n=$(($n+1))
            echo $i >> ${FREQ_TEST_CLUSTER_FILE}
            cpuarray[$n]=$i
            relatedcpusStr=`cat /sys/devices/system/cpu/cpu$i/cpufreq/related_cpus`
        fi
    done
    echo ${cpuarray[*]}
}

function get_big_or_small_cpus_list()
{
    big=$1
    n=0
    m=0

    for i in $(seq 0 $(($cpus-1)))
    do
        relatedcpusStr=`cat /sys/devices/system/cpu/cpu$i/cpufreq/related_cpus`
        relatedcpus=($relatedcpusStr)
        relatedlen=${#relatedcpus[@]}
        if [ $relatedlen -gt 1 ]; then
            smallcpuarray[$n]=$i
            n=$(($n+1))
		else
            bigcpuarray[$m]=$i
            m=$(($m+1))
        fi
    done
    if [[ $big == 1 ]]; then
       echo ${bigcpuarray[*]}
    else
       echo ${smallcpuarray[*]}
    fi
}

function get_cpu_test_freq_count()
{
    clusternum=$1
    referminmaxfreq=$2
    lowfreqnum=$3
    freqcount[0]=0
    freqcount[1]=0
    for i in $(seq 0 $(($clusternum-1)))
    do
        curnum=${cpuslist[$i]}
        availfreq=`cat /sys/devices/system/cpu/cpu$curnum/cpufreq/scaling_available_frequencies`
        freqarray=($availfreq)
        if [[ $referminmaxfreq == "true" ]]; then
            minfreq=`cat /sys/devices/system/cpu/cpu$curnum/cpufreq/scaling_min_freq`
            maxfreq=`cat /sys/devices/system/cpu/cpu$curnum/cpufreq/scaling_max_freq`
            arraylen=0
            for item in ${freqarray[@]}
            do
                if [ $item -ge $minfreq -a $item -le $maxfreq ]; then
                    arraylen=$(($arraylen+1))
                fi
            done
            if [ $arraylen -ge $lowfreqnum ]; then
                freqcount[0]=$((${freqcount[0]}+$lowfreqnum))
                freqcount[1]=$((${freqcount[1]}+$arraylen-$lowfreqnum))
            else
                freqcount[0]=$((${freqcount[0]}+$arraylen))
            fi
        else
            arraylen=${#freqarray[@]}
            if [ $arraylen -ge $lowfreqnum ]; then
                freqcount[0]=$((${freqcount[0]}+$lowfreqnum))
                freqcount[1]=$((${freqcount[1]}+$arraylen-$lowfreqnum))
            else
                freqcount[0]=$((${freqcount[0]}+$arraylen))
            fi
        fi
    done
    echo ${freqcount[*]}
}

function get_current_timing_count()
{
    time=$(date "+%s.%N")
    echo $time
}

function get_diff_time()  #para1(timeunit:s,ms,us),para2(start time), para3(end time)
{
    starttime=$2
    endtime=$3
    start_s=${starttime%.*}
    start_n=${starttime#*.}
    end_s=${endtime%.*}
    end_n=${endtime#*.}

    if [ "$end_n" -lt "$start_n" ]; then
        end_s=$(($end_s - 1))
        end_n=$(($end_n + 1000*1000*1000))
    fi

    case "$1" in
     "s" )
        diff=$(($end_s-$start_s))
    ;;
     "ms" )
        diff=$((($end_s-$start_s)*1000 + ($end_n-$start_n)/1000000))
    ;;
     "us" )
        diff=$((($end_s-$start_s)*1000*1000 + ($end_n-$start_n)/1000))
    ;;
    esac
    echo $diff
}

#fix task test
function backup_cpuset_config()
{
    n=0
    cpusetlen=${#cpusetarray[@]}
    for item in $(seq 0 $(($cpusetlen-1)))
    do
        cpusettype=${cpusetarray[$item]}
        if [ -d /dev/cpuset/$cpusettype ]; then
            origconfig[$n]=`cat /dev/cpuset/$cpusettype/cpus`
            n=$(($n+1))
        fi
    done
    echo ${origconfig[*]}
}

function restore_cpuset_config()
{
    n=0
    cpusetlen=${#cpusetarray[@]}
    for item in $(seq 0 $(($cpusetlen-1)))
    do
        cpusettype=${cpusetarray[$item]}
        if [ -d /dev/cpuset/$cpusettype ]; then
            echo ${oricpusetconfig[$item]} > /dev/cpuset/$cpusettype/cpus
            n=$(($n+1))
        fi
    done
}

function case_fix_cpuset_config()
{
    n=0
    cpusetlen=${#cpusetarray[@]}
    if [[ $cpusetpolicy == 2 ]]; then
        bigcore=$(is_big_core $1)
        if [[ $bigcore == 1 ]]; then
            assistcpu=$(get_random_small_cpu $1)
        else
            assistcpu=$(get_random_big_cpu $1)
        fi
		testcpu=$1,$assistcpu
    elif [[ $cpusetpolicy == 3 ]]; then
        bigcore=$(is_big_core $1)
        if [[ $bigcore == 0 ]]; then
            assistcpu=$(get_random_big_cpu $1)
            testcpu=$1,$assistcpu
        else
            testcpu=$1
        fi
    else
        testcpu=$1
    fi

    for item in $(seq 0 $(($cpusetlen-1)))
    do
        cpusettype=${cpusetarray[$item]}
        if [ -d /dev/cpuset/$cpusettype ]; then
            echo $testcpu > /dev/cpuset/$cpusettype/cpus
            #configread=`cat /dev/cpuset/$cpusettype/cpus`
            #if [ "$configread" != "$testcpu" ]; then
                #echo "ERROR:case_fix_cpuset_config():set cpuset cpus[$testcpu] fail for $cpusettype" >> ${FREQ_TEST_LOG_FILE}
            #fi
            n=$(($n+1))
        fi
    done
    #record cpuset
    echo "cpuset:$testcpu" >> ${FREQ_TEST_RECORD_FILE}
}

function restore_freq_config()
{
    testcpu=$1
    testminfreq=$2
    testmaxfreq=$3
    for i in $(seq 1 $restoreretrymax)
    do
        echo $testminfreq > /sys/devices/system/cpu/cpu$testcpu/cpufreq/scaling_min_freq
        echo $testmaxfreq > /sys/devices/system/cpu/cpu$testcpu/cpufreq/scaling_max_freq
        rebackminfreq=`cat /sys/devices/system/cpu/cpu$testcpu/cpufreq/scaling_min_freq`
	    rebackmaxfreq=`cat /sys/devices/system/cpu/cpu$testcpu/cpufreq/scaling_max_freq`
        if [[ $testminfreq == $rebackminfreq ]] && [[ $testmaxfreq == $rebackmaxfreq ]]; then
           break
        else
           echo "ERROR:restore fail, min[$testminfreq vs $rebackminfreq], max[$testmaxfreq vs $rebackmaxfreq] for cpu[$testcpu]" >> ${FREQ_TEST_LOG_FILE}
        fi
    done
}

function fix_current_freq()
{
    testcpu=$1
    testfreq=$2
    for i in $(seq 1 $restoreretrymax)
    do
        echo $testfreq > /sys/devices/system/cpu/cpu$testcpu/cpufreq/scaling_min_freq
        echo $testfreq > /sys/devices/system/cpu/cpu$testcpu/cpufreq/scaling_max_freq
        readbackfreq=`cat /sys/devices/system/cpu/cpu$curcpu/cpufreq/scaling_cur_freq`
        if [[ $testfreq == $readbackfreq ]]; then
           break
        fi
    done
    if [ $i -gt $restoreretrymax ]; then
        echo "ERROR:Fix freq[$testfreq] for cpu[testcpu] fail" >> ${FREQ_TEST_LOG_FILE}
    fi
}

function backup_min_max_freq()
{
    n=0
    for i in $(seq 0 $(($cpuscount-1)))
    do
        testcpu=${cpuslist[$i]}
        origmin=`cat /sys/devices/system/cpu/cpu$testcpu/cpufreq/scaling_min_freq`
        origmax=`cat /sys/devices/system/cpu/cpu$testcpu/cpufreq/scaling_max_freq`
        minmaxarray[$n]=$origmin
        n=$((n+1))
        minmaxarray[$n]=$origmax
        n=$((n+1))
    done
    echo ${minmaxarray[*]}
}

function get_min_max_freq_per_cpu()
{
    testcpu=$1
    arrayindex=$(($testcpu*2))
    echo ${origmixmaxfreq[$arrayindex]}
    echo ${origmixmaxfreq[$(($arrayindex+1))]}
}

function check_cputest_conf_data()
{
    confkey=$1
    confvalue=$2
    valid=0
    case $confkey in
     "testtime" )
        if [ $(($confvalue)) -ge 300 -a $(($confvalue)) -le 604800 ]; then
            valid=1
        fi
     ;;
     "cpusetpolicy" )
        if [ $(($confvalue)) -ge 1 -a $(($confvalue)) -le 4 ]; then
            valid=1
        fi
     ;;
     "ratio" )
        if [ $(($confvalue)) -ge 1 -a $(($confvalue)) -le 10 ]; then
            valid=1
        fi
     ;;
     "lowfreqnum" )
        if [ $(($confvalue)) -ge 0 -a $(($confvalue)) -le 7 ]; then
            valid=1
        fi
     ;;
     "testonminmaxsetting" )
        if [ $(($confvalue)) -ge 0 -a $(($confvalue)) -le 1 ]; then
            valid=1
        fi
     ;;
     "maxretry" )
        if [ $(($confvalue)) -ge 1 -a $(($confvalue)) -le 10 ]; then
            valid=1
        fi
     ;;
     "timeunit" )
        if [ $(($confvalue)) -ge 0 -a $(($confvalue)) -le 2 ]; then
            valid=1
        fi
     ;;
     "cpusetarray" )
        confarray=($confvalue)
        if [[ ${#confarray[@]} == [0-9] ]]; then
            valid=1
        fi
     ;;
     esac
    if [[ $valid != 1 ]]; then
        echo "ERROR: $confkey is not valid, input is $confvalue,please check,and here use the default value" >> ${FREQ_TEST_LOG_FILE}
    fi
    echo $valid
}

#Here script entry

if [[ $1 == "--help" ]];then
    usage
    exit
fi

#Intialize property
setprop $FREQ_TEST_PROCESS_PROPERTITY "enter"
setprop $FREQ_TEST_RESULT_INFO_PROPERTITY "unset"

#Log path intialization
if [ ! -d "$FREQ_TEST_PATH" ]; then
    mkdir -p ${FREQ_TEST_PATH}
    chown system ${FREQ_TEST_PATH}
fi

#make sure group as system and can read&write
chmod 0770 ${FREQ_TEST_PATH}
chgrp system ${FREQ_TEST_PATH}

CURTIME=`date +%F-%H-%M-%S`
echo >> ${FREQ_TEST_LOG_FILE}
echo "/********************$CURTIME START********************/" >> ${FREQ_TEST_LOG_FILE}

#First to check hypnus status
hypusDisable=$(check_oppo_hypuns_state)

if [[ $hypusDisable != 1 ]]; then
    echo "ERROR: This freqtest need hypnus function disabled, Exit" >> ${FREQ_TEST_LOG_FILE}
    exit
fi

#testtime:                      #scope: 300s ~604800s One test's time
#cpusetpolicy=2                 #scpoe: 1~4,1:fix freq test only 2: big and small cpu 3:small&big and big only 4: only cpu itself
#ratio=6                        #scope: 1~10, test time ratio separatly for low freq or high freq.
#lowfreqnum=2                   #scope: 0~7, how the number think as the low freq.
#testonminmaxsetting="true"     #scope: 0~1，define test wheather begin from scaling_min_freq to scaling_max_freq
#maxretry=5                     #scope: 1~10, retry times when write node fail
#timeunit="ms"                  #scope: 0~2, test time unit,support 's','ms','us'
#cpusetarray=("top-app")        #cpuset array definition

#Variable initialization, later read from freqtest.conf file
if [ -f "$FREQ_TEST_CONFIG_FILE" ]; then
    while read text
	do
        text=`echo $text | sed -e 's/^[ \t]*//g'`
	    if [[ "${text:0:1}" == "#" ]]; then
	        continue
	    fi
        if [[ "${text:0:1}" == [a-zA-Z0-9] ]]; then
            textkey=`echo ${text%%=*} | sed -e 's/^[ \t]*//g' -e 's/[ \t]*$//g'`
            textvalue=`echo ${text##*=} | sed -e 's/^[ \t]*//g' -e 's/[ \t\r\n]*$//g'`
            valid=$(check_cputest_conf_data $textkey $textvalue)
            case $textkey in
             "testtime" )
                if [[ $valid == 1 ]]; then
                    timesetting=$(($textvalue))
                fi
             ;;
             "cpusetpolicy" )
                if [[ $valid == 1 ]]; then
                    cpusetpolicy=$(($textvalue))
                fi
                ;;
             "ratio" )
                if [[ $valid == 1 ]]; then
                    lowfreqratio=$(($textvalue))
                fi
                ;;
             "lowfreqnum" )
                if [[ $valid == 1 ]]; then
                    lowfreqnum=$(($textvalue))
                fi
             ;;
             "testonminmaxsetting" )
                if [[ $valid == 1 ]]; then
                    if [[ $(($textvalue)) == 1 ]]; then
                        countbaseminmaxfreq="true"
                    else
                        countbaseminmaxfreq="false"
                    fi
                fi
             ;;
             "maxretry" )
                if [[ $valid == 1 ]]; then
                    restoreretrymax=$(($textvalue))
                fi
             ;;
             "timeunit" )
                if [[ $valid == 1 ]]; then
                    if [[ $(($textvalue)) == 2 ]]; then
                        timeunit="us"
                    elif [[ $(($textvalue)) == 1 ]]; then
                        timeunit="ms"
                    else
                        timeunit="s"
                    fi
                fi
             ;;
             "cpusetarray" )
                if [[ $valid == 1 ]]; then
                    cpusetarray=($textvalue)
                fi
             ;;
            esac
        fi
    done < $FREQ_TEST_CONFIG_FILE
fi

if [ -z $timeunit ]; then
    timeunit="ms"
fi
if [ -z $lowfreqratio ]; then
    lowfreqratio=6 #need /10 at last, check data valid or not
fi
if [ -z $lowfreqnum ]; then
    lowfreqnum=2
fi
if [ -z $countbaseminmaxfreq ]; then
    countbaseminmaxfreq="true"
fi
if [ -z $cpusetpolicy ]; then
    cpusetpolicy=2    #1:fix freq test only 2: big and small cpu 3:small&big and big only 4: only cpu itself
fi
if [ -z $cpusetarray ]; then
    cpusetarray=("top-app" "foreground")
fi
if [ -z $restoreretrymax ]; then
    restoreretrymax=5
fi
if [ -z $timesetting ]; then
    timesetting=$1
fi

#check time
if [[ $timesetting == "" ]];then
    timesetting=300
fi

if [ $timesetting -gt 604800 ];then #support 7*24h test
    echo "ERROR: Don't support the test time over 604800s(7*24h)"
    exit
fi

if [ $timesetting -gt 86400 -a $timeunit != "s" ]; then
   echo "INFO: time setting is more than 1 day, default timeunit to 's'"
   timeunit="s"
fi

case "$timeunit" in
 "s" )
    testtime=$timesetting
 ;;
 "ms" )
    testtime=$(($timesetting*1000)) #90%
 ;;
 "us" )
    testtime=$(($timesetting*1000*1000))
 ;;
esac

echo "INFO:Test config, time:$testtime($timeunit), lowfreqratio:$lowfreqratio, countbaseminmaxfreq:$countbaseminmaxfreq, cpusetpolicy:$cpusetpolicy, timeunit:$timeunit" >> ${FREQ_TEST_LOG_FILE}

#Get CPU number
platform=`getprop ro.board.platform`
echo "platform:$platform"
cpus=`find /sys/devices/system/cpu -type d -name "cpu[0-9]" | wc -l`
echo "INFO:Support cpus:$cpus" >> ${FREQ_TEST_LOG_FILE}

#Get test cpus list&count
if [[ $cpusetpolicy == 1 ]]; then
    cpuslist=($(get_cpu_clusters_and_list)) #fix freq only
else
    cpuslist=($(seq 0 $(($cpus-1))))
fi
cpuscount=${#cpuslist[@]}

#Get big/small core list&count
bigcorelist=($(get_big_or_small_cpus_list 1))
smallcorelist=($(get_big_or_small_cpus_list 0))

#Get total frequency count array, includ lowfreq count, and other count
cpufreqcount=($(get_cpu_test_freq_count $cpuscount $countbaseminmaxfreq $lowfreqnum))
lowfreqcount=${cpufreqcount[0]}
otherfreqcount=${cpufreqcount[1]}
echo "INFO:Test freq count, lowfreqcount[$lowfreqcount], otherfreqcount[$otherfreqcount]" >> ${FREQ_TEST_LOG_FILE}

#backup cpuset setting
if [[ $cpusetpolicy != 1 ]];then
    echo "INFO:Backup cpuset original settings" >> ${FREQ_TEST_LOG_FILE}
    oricpusetconfig=($(backup_cpuset_config))
fi

#backup cpus min&max freqs
if [[ $countbaseminmaxfreq == "true" ]]; then
    origmixmaxfreq=($(backup_min_max_freq))
    echo "INFO:Backup cpu min&max freq original settings,len[${#origmixmaxfreq[@]}]" >>  ${FREQ_TEST_LOG_FILE}
fi

setprop $FREQ_TEST_PROCESS_PROPERTITY "ongoing"

#computer every cpu freq test time
testbegintime=$(get_current_timing_count)
diff_s=$(get_diff_time $timeunit $origtime $testbegintime)

temptime=$(((($testtime -$diff_s)/(($lowfreqcount*$lowfreqratio)+($otherfreqcount*(10-$lowfreqratio))))*10))
lowcputime=$(($temptime * $lowfreqratio/10))
highcputime=$(($temptime*(10-$lowfreqratio)/10))

echo "INFO:Low freq time(${lowcputime}$timeunit), Higher freq time(${highcputime}$timeunit)" >>  ${FREQ_TEST_LOG_FILE}

if [[ $lowcputime == "0" ]] || [[ $highcputime == "0" ]]; then
    echo "ERROR: Test time for every CPU can't be zero, please check total test time, Exit"
    exit
fi

#Begin cpu test
CURTIME=`date +%F-%H-%M-%S`
echo "INFO:Start freq test at $CURTIME!!!!!!!!!!"  >> ${FREQ_TEST_LOG_FILE}
echo "######$CURTIME######" > ${FREQ_TEST_RECORD_TEMP_FILE} #note here is > not >>;

for i in $(seq 0 $(($cpuscount-1)))
do
    curcpu=${cpuslist[$i]}
    echo "cpu:$curcpu" >> ${FREQ_TEST_RECORD_TEMP_FILE}
    if [ -f ${FREQ_TEST_RECORD_FILE} ]; then
        sed -i '/cpu/d'  ${FREQ_TEST_RECORD_FILE} > /dev/null
    fi
    echo "cpu:$curcpu" >> ${FREQ_TEST_RECORD_FILE}
    availfreqStr=`cat /sys/devices/system/cpu/cpu$curcpu/cpufreq/scaling_available_frequencies` #here can save in a file and test read from the file
    testfreqarray=($availfreqStr)
    maxfreqindex=$((${#testfreqarray[@]}-1))
    minfreq=${testfreqarray[0]}
    maxfreq=${testfreqarray[$maxfreqindex]}
    if [[ $countbaseminmaxfreq == "true" ]]; then
        minmaxfreqpercpu=($(get_min_max_freq_per_cpu $curcpu))
        minfreq=${minmaxfreqpercpu[0]}
        maxfreq=${minmaxfreqpercpu[1]}
    fi

    if [[ $cpusetpolicy != 1 ]];then
        #fix task test case
        echo "INFO:Fix tasks on special cpu[$curcpu]" >> ${FREQ_TEST_LOG_FILE}
        case_fix_cpuset_config $curcpu
    fi
    #Intialize freq count
    testfreqcount=0
    testtime_s=$(get_current_timing_count)
    for item in ${testfreqarray[@]}
    do
        if [ $item -ge $minfreq ] && [ $item -le $maxfreq ]; then
        #update freq in record file
            echo "freq:$item" >> ${FREQ_TEST_RECORD_TEMP_FILE}
            if [ -f ${FREQ_TEST_RECORD_FILE} ]; then
                sed -i '/freq/d' ${FREQ_TEST_RECORD_FILE} > /dev/null
            fi
            echo "freq:$item" >>  ${FREQ_TEST_RECORD_FILE}
            #fix freq
            fix_current_freq $curcpu $item
            curfreq=`cat /sys/devices/system/cpu/cpu$curcpu/cpufreq/scaling_cur_freq`
            if [[ $item != $curfreq ]]; then
                echo "set freq:$item fail, curfreq:$curfreq for cpu[$curcpu]" >> ${FREQ_TEST_LOG_FILE}
            fi
            #update cpu:freq:cpuset value
            tempcpuset=`cat /dev/cpuset/${cpusetarray[0]}/cpus`
            setprop ${FREQ_TEST_RESULT_INFO_PROPERTITY} "cpu:${curcpu}cpufreq:${curfreq}cpuset:${tempcpuset}"
            testtime_e=$(get_current_timing_count)
            testtimediff=$(get_diff_time $timeunit $testtime_s $testtime_e)
            #echo "testtimediff:$testtimediff$timeunit for cpu[$curcpu] for freq[$item]" >> ${FREQ_TEST_LOG_FILE}
            #wait more if test time is not end
            if [ $testfreqcount -lt $lowfreqnum ]; then
                #use lowcputime
                if [ $testtimediff -lt $lowcputime ]; then
                    waittime=$(($lowcputime - $testtimediff))
                    case "$timeunit" in
                     "s" )
                        sleep $waittime
                     ;;
                     "ms" )
                        usleep $(($waittime*1000))
                     ;;
                     "us" )
                        usleep $waittime
                     ;;
                    esac
                fi
            else
                #use highcputime
                if [ $testtimediff -lt $highcputime ]; then
                    waittime=$(($highcputime - $testtimediff))
                    case "$timeunit" in
                     "s" )
                        sleep $waittime
                     ;;
                     "ms" )
                        usleep $(($waittime*1000))
                     ;;
                     "us" )
                        usleep $waittime
                     ;;
                    esac
                fi
            fi
            testtime_s=$(get_current_timing_count)
            testfreqcount=$(($testfreqcount+1))
            #Read again for freq to see whether changed  or not after test
            curfreq=`cat /sys/devices/system/cpu/cpu$curcpu/cpufreq/scaling_cur_freq`
            if [[ $item != $curfreq ]]; then
                echo "Not match after test: dst freq[$item] but curfreq[$curfreq] for cpu[$curcpu]" >> ${FREQ_TEST_LOG_FILE}
            fi
            #restore freq setting
            restore_freq_config $curcpu $minfreq $maxfreq
        fi
    done
done

#restore cpuset settings
if [[ $cpusetpolicy != 1 ]];then
    echo "INFO:Restore cpuset original settings" >> ${FREQ_TEST_LOG_FILE}
    restore_cpuset_config
fi

setprop $FREQ_TEST_PROCESS_PROPERTITY "finish"
#End

echo `getprop | grep freqtest`

CURTIME=`date +%F-%H-%M-%S`
echo "/*********************$CURTIME END*********************/" >> ${FREQ_TEST_LOG_FILE}