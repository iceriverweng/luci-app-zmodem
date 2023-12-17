#!/bin/sh

PROGRAM="RM520N_IPCHK"
printMsg() {
    local msg="$1"
    logger -t "${PROGRAM}" "${msg}"
} #日志输出调用API


printMsg "Start IP Check"

LOCKFILE="/tmp/ipcheck.lock"
FAILCOUNT=0
# Check if lockfile exists
if [ -f $LOCKFILE ]; then
    OLD_PID=$(cat $LOCKFILE)
    printMsg "Kill $OLD_PID" 
    kill $OLD_PID
fi

echo $$ > $LOCKFILE
/usr/share/modem/netmodeled.sh &

check_ip_if_alive() {
    eth1ip=$(sendat 2 'at+qmap="wwan"' | grep IPV4 | awk -F \" '{print $6}')
    if_stillAlive0=$(sendat 2 'AT+CGPADDR' | grep $eth1ip)
    if_stillAlive1=$(ifconfig | grep  $eth1ip)
    if_ip_is00=$(echo $eth1ip | grep  "0.0.0.0")

    if [ -z "$if_stillAlive0" ] || [ -z "$if_stillAlive1" ]; then
        printMsg "IP FAILURE,try restore"
            sendat 2 'at+qmap="connect",0,1' 
            printMsg "Try to RECONNECT"
            sleep 2
            /sbin/ifup wan up
            /sbin/ifup wan6 up
            sleep 10
        FAILCOUNT=$((FAILCOUNT+1))
    else
       http_codeChk0=$(curl -o /dev/null -s -w %{http_code} http://connect.rom.miui.com/generate_204)
       http_codeChk1=$(curl -o /dev/null -s -w %{http_code} http://connectivitycheck.platform.hicloud.com/generate_204)
       nettype=$(sendat 2 'at+qnwinfo'|grep '+QNWINFO'|awk -F \" {'print $2'}|tr -d '\r\n')
       echo "$nettype" > /tmp/nettype
        if [ "$http_codeChk0" != "204" ] && [ "$http_codeChk1" != "204" ]; then
            printMsg "HTTP Check FAILURE: http_codeChk0=$http_codeChk0, http_codeChk1=$http_codeChk1"
            sendat 2 'at+qmap="connect",0,1' 
            printMsg "Try to RECONNECT"
            sleep 2
            /sbin/ifup wan up
            /sbin/ifup wan6 up
            sleep 10
             if [ $FAILCOUNT -eq 5 ]; then
                retrylimit_file="/tmp/retrylimit"
                # 检查retrylimit文件是否存在
                if [ -e "$retrylimit_file" ]; then
                    printMsg "Retry limit file ($retrylimit_file) already exists. Exiting."
                    printMsg "FAILURE to save the world,Retry Modem Init,exit"
                    exit 1
                else
                    touch "$retrylimit_file"
                    /usr/share/modem/rm520n.sh &
                fi
                rm -f $LOCKFILE
                exit 1
             fi
         FAILCOUNT=$((FAILCOUNT+1))
        fi
        FAILCOUNT=0
    fi
}

# loop 2
while true; do
    check_ip_if_alive
    sleep 20
done
