# author  : Xing Qingjie  xqjcool@gmail.com
# version : 0.03
# history :
#           02/22/2022	v0.03 optimize ps memory display
#           02/21/2022	v0.02 support ash shell
#           01/18/2022  v0.01 init draft

# socket queue Recv-Q and Send-Q limit(Bytes)
MEM_THRESHOLD=80
# socket queue Recv-Q and Send-Q limit(Bytes)
SOCK_QUEUE_LIMIT=500000
# black hole memory limit(KBytes)
BLACK_HOLE_LIMIT=500000
# /tmp directory memory limit(KBytes)
TMP_MEM_LIMIT=100000

# color print functions
echoGreen()
{
    content=$@
    echo -e "\033[32m${content}\033[0m"
}

echoYellow()
{
    content=$@
    echo -e "\033[33m${content}\033[0m"
}

echoRed()
{
    content=$@
    echo -e "\033[31m${content}\033[0m"
}

echoBlue()
{
    content=$@
    echo -e "\033[34m${content}\033[0m"
}

# parse /proc/meminfo and set the relative parameters
get_meminfo()
{
    MemTotal=$(cat /proc/meminfo | grep -w MemTotal | awk '{print $2}')
    MemFree=$(cat /proc/meminfo | grep -w MemFree | awk '{print $2}')
    MemAvailable=$(cat /proc/meminfo | grep -w MemAvailable | awk '{print $2}')
    Buffers=$(cat /proc/meminfo | grep -w Buffers | awk '{print $2}')
    Cached=$(cat /proc/meminfo | grep -w Cached | awk '{print $2}')

    Active=$(cat /proc/meminfo | grep -w Active: | awk '{print $2}')
    Inactive=$(cat /proc/meminfo | grep -w Inactive: | awk '{print $2}')

    Unevictable=$(cat /proc/meminfo | grep -w Unevictable | awk '{print $2}')

    Slab=$(cat /proc/meminfo | grep -w Slab | awk '{print $2}')

    KernelStack=$(cat /proc/meminfo | grep -w KernelStack | awk '{print $2}')
    PageTables=$(cat /proc/meminfo | grep -w PageTables | awk '{print $2}')
    Bounce=$(cat /proc/meminfo | grep -w Bounce | awk '{print $2}')

    VmallocUsed=$(cat /proc/meminfo | grep -w VmallocUsed | awk '{print $2}')

    HardwareCorrupted=$(cat /proc/meminfo | grep -w HardwareCorrupted | awk '{print $2}')

    HugePages_Total=$(cat /proc/meminfo | grep -w HugePages_Total | awk '{print $2}')
    Hugepagesize=$(cat /proc/meminfo | grep -w Hugepagesize | awk '{print $2}')

    HardwareCorrupted=$(cat /proc/meminfo | grep -w HardwareCorrupted | awk '{print $2}')
}

diagnose_socket_queue()
{
    # check socket Recv-Q and Send-Q

    old=$IFS
    IFS=$'\n'
    for i in $(ss -ap); do
       rcv=$(echo $i | awk '{print $3}')
       snd=$(echo $i | awk '{print $4}')

       if [ $rcv -gt $SOCK_QUEUE_LIMIT ]; then
           # process Recv-Q 
           echoRed socket Recv-Q over limited
           echo $i 
       fi

       if [ $snd -gt $SOCK_QUEUE_LIMIT ]; then
           # process Send-Q 
           echoRed socket Send-Q over limited
           echo $i 
       fi
    done
    IFS=$old
}

diagnose_black_mem()
{
    # check virutal machine
    echoYellow ======== check black hole memory ========
    mod_name=$(lsmod | grep balloon | awk '{print $1}')
    if [ -n "$mod_name" ]; then
        # virtual machine with balloon tech
        echoRed virtual machine with $mod_name module
    fi

    # check socket queue
    diagnose_socket_queue

}

diagnose_user_mem()
{
    # check /tmp memory
    echoYellow ======== check user space memory ========

    tmp_mem=$(du -s /tmp/ | awk '{print $1}')

    if [ $tmp_mem -gt $TMP_MEM_LIMIT ]; then
        echoRed tmp directory occupies too much memory $tmp_mem. please clean it
    else
        echoRed please check these proesses:
        old=$IFS
        IFS=$'\n'
        if [ "${SHELL}" = "/bin/bash" ]; then
            ps_list=$(ps aux | sort -rn -k6 | head -5)
            echo "${ps_list}"
        else
            top1=0
            process1=""
            top2=0
            process2=""
            top3=0
            process3=""
            for i in $(ps | grep -v PID); do
                mem=$(echo $i | awk '{print $3}')
                tailchar=${mem: -1}

                if [ $tailchar = "m" ]; then
                    mem=${mem%?}
                    mem=$((mem * 1000))
                elif [ $tailchar = "g" ]; then
                    mem=${mem%?}
                    mem=$((mem * 1000 * 1000))
                fi

                if [ $mem -gt $top1 ]; then
                    top3=$top2
                    process3=$process2
                    top2=$top1
                    process2=$process1
                    top1=$mem
                    process1=$i
                elif [ $mem -gt $top2 ]; then
                    top3=$top2
                    process3=$process2
                    top2=$mem
                    process2=$i
                elif [ $mem -gt $top3 ]; then
                    top3=$mem
                    process3=$i
                fi
            done
            echo -e "${process1}\n${process2}\n$process3"
            fi
        IFS=$old
    fi 
}

diagnose_kernel_mem()
{
    echoYellow ======== check kernel space memory ========

    # check slab memory
    slab_usage_percent=$(($Slab * 100 / $MemTotal))

	# slab usage is greater than 3/8 MEM_THRESHOLD
    if [ $(($slab_usage_percent * 8)) -gt $(($MEM_THRESHOLD * 3)) ]; then
        echoRed slab memory is suspicious, please check
        slab_list=$(slabtop -o -sc | sed '1,7d')
        echo "${slab_list}"
    else
        echoRed vmalloc memory is suspicious, please check
        if [ "${SHELL}" = "/bin/bash" ]; then
            declare -A vmalloc
            old=$IFS
            IFS=$'\n'
            vmallc_list=$(cat /proc/vmallocinfo | grep -v "ioremap")
            for i in $vmallc_list; do
                type=$(echo $i | awk '{print $3}')
                vmem=$(echo $i | awk '{print $2}')

                let vmalloc[$type]+=$vmem
            done
            IFS=$old

            for i in ${!vmalloc[@]}; do
                echo $i: ${vmalloc[$i]}
            done
        fi
    fi 
}

diagnose_huge_mem()
{
    echoYellow ======== check huge page memory ========
    echoRed HugePage consumption $hugeMem HugePages_Total=$HugePages_Total Hugepagesize=$Hugepagesize
}

#### main process ####

get_meminfo

if [ $VmallocUsed -eq 0 ]; then
    VmallocUsed=$(cat /proc/vmallocinfo |grep -v "ioremap" |awk '{total=total+$2};END{print total/1024}')
fi

usedMem=$(($MemTotal - $MemFree))
kernelMem=$(($Slab + $VmallocUsed + $PageTables + $KernelStack + $HardwareCorrupted + $Bounce))
userMem=$(($Active + $Inactive + $Unevictable))
hugeMem=$(($HugePages_Total * $Hugepagesize))
#echo Active=$Active Inactive=$Inactive Unevictable=$Unevictable
#echo  Slab=$Slab  VmallocUsed=$VmallocUsed  PageTables=$PageTables  KernelStack=$KernelStack  HardwareCorrupted=$HardwareCorrupted  Bounce=$Bounce
#echo MemTotal=$MemTotal usedMem=$usedMem kernelMem=$kernelMem userMem=$userMem 
## check memory usage
mem_usage_percent=$((($MemTotal - $MemAvailable) * 100 / $MemTotal))

if [ $mem_usage_percent -le $MEM_THRESHOLD ];then
    echoGreen memory usages $mem_usage_percent%, no need to diagnose
    exit 0
fi

## check black hole memory
blackmem=$(($usedMem - $userMem - $kernelMem - $hugeMem))
user_usage_percent=$(($userMem * 100/ $MemTotal))
kernel_usage_percent=$(($kernelMem * 100 / $MemTotal))
huge_usage_percent=$(($hugeMem * 100 / $MemTotal))
#echo blackmem=$blackmem user_usage_percent=$user_usage_percent kernel_usage_percent=$kernel_usage_percent huge_usage_percent=$huge_usage_percent 
if [ $blackmem -gt $BLACK_HOLE_LIMIT ]; then
    diagnose_black_mem
elif [ $(($huge_usage_percent * 2)) -gt $MEM_THRESHOLD ]; then
    diagnose_huge_mem
elif [ $(($user_usage_percent * 2)) -gt $MEM_THRESHOLD  ]; then
    diagnose_user_mem
else
    diagnose_kernel_mem
fi
