#!/bin/sh
#By Zy143L

PROGRAM="RM520N_MODEM"
printMsg() {
    local msg="$1"
    logger -t "${PROGRAM}" "${msg}"
} #日志输出调用API

# 检查是否存在锁文件 @Icey
lock_file="/tmp/rm520n.lock"

if [ -e "$lock_file" ]; then
  # 锁文件存在，获取锁定的进程 ID，并终止它
  locked_pid=$(cat "$lock_file")
  if [ -n "$locked_pid" ]; then
    echo "Terminating existing rm520n.sh process (PID: $locked_pid)..." >>/tmp/moduleInit
    kill "$locked_pid"
    sleep 2  # 等待一段时间确保进程终止
  fi
fi

# 创建新的锁文件，记录当前进程 ID
echo "$$" > "$lock_file"
sleep 2 && /sbin/uci commit
Modem_Enable=`uci -q get modem.@ndis[0].enable` || Modem_Enable=1
#模块启动

Sim_Sel=`uci -q get modem.@ndis[0].simsel`|| Sim_Sel=0
echo "simsel: $Sim_Sel" >> /tmp/moduleInit
#SIM选择

Enable_IMEI=`uci -q get modem.@ndis[0].enable_imei` || Enable_IMEI=0
#IMEI修改开关

RF_Mode=`uci -q get modem.@ndis[0].smode` || RF_Mode=0
#网络制式 0: Auto, 1: 4G, 2: 5G
NR_Mode=`uci -q get modem.@ndis[0].nrmode` || NR_Mode=0
#0: Auto, 1: SA, 2: NSA
Band_LTE=`uci -q get modem.@ndis[0].bandlist_lte` || Band_LTE=0
Band_SA=`uci -q get modem.@ndis[0].bandlist_sa` || Band_SA=0
Band_NSA=`uci -q get modem.@ndis[0].bandlist_nsa` || Band_NSA=0
Enable_PING=`uci -q get modem.@ndis[0].pingen` || Enable_PING=0
PING_Addr=`uci -q get modem.@ndis[0].pingaddr` || PING_Addr="119.29.29.29"
PING_Count=`uci -q get modem.@ndis[0].count` || PING_Count=10

if [ "$Modem_Enable" == 0 ]; then
    echo 1 >/sys/class/gpio/cpe-pwr/value
    printMsg "禁用移动网络"
    echo "Modem_Enable: $Modem_Enable 模块禁用" >> /tmp/moduleInit
fi

if [ ${Enable_PING} == 1 ];then
    /usr/share/modem/pingCheck.sh &
else 
    process=`ps -ef | grep "pingCheck" | grep -v grep | awk '{print $1}'` 
    if [[ -n "$process" ]]; then
        kill -9 "$process" >/dev/null 2>&1
    fi
    rm -rf /tmp/pingCheck.lock
fi

if [ ${Enable_IMEI} == 1 ];then
    IMEI_file="/tmp/IMEI"
    if [ -e "$IMEI_file" ]; then
        last_IMEI=$(cat "$IMEI_file")
    else
        last_IMEI=-1
    fi
    IMEI=`uci -q get modem.@ndis[0].modify_imei`
    if [ "$IMEI" != "$last_IMEI" ]; then
        /usr/share/modem/moimei ${IMEI} 1>/dev/null 2>&1
        printMsg "IMEI: ${IMEI}"
        echo "修改IMEI $IMEI" >> /tmp/moduleInit
        echo "$IMEI" > "$IMEI_file"
    else
        echo "IMEI未变动, 不执行操作" >> /tmp/moduleInit
    fi
fi
# 网络模式选择
#---------------------------------
RF_Mode_file="/tmp/RF_Mode"
if [ -e "$RF_Mode_file" ]; then
    last_RF_Mode=$(cat "$RF_Mode_file")
else
    last_RF_Mode=-1
fi
#--
if [ "$RF_Mode" != "$last_RF_Mode" ]; then
    if [ "$RF_Mode" == 0 ]; then
        echo "RF_Mode: $RF_Mode 自动网络" >> /tmp/moduleInit
        sendat 2 'AT+QNWPREFCFG="mode_pref",AUTO' >> /tmp/moduleInit
    elif [ "$RF_Mode" == 1 ]; then
        echo "RF_Mode: $RF_Mode 4G网络" >> /tmp/moduleInit
        sendat 2 'AT+QNWPREFCFG="mode_pref",LTE' >> /tmp/moduleInit
    elif [ "$RF_Mode" = 2 ]; then
        echo "RF_Mode: $RF_Mode 5G网络" >> /tmp/moduleInit
        sendat 2 'AT+QNWPREFCFG="mode_pref",NR5G' >> /tmp/moduleInit
    fi
    echo "$RF_Mode" > "$RF_Mode_file"
else
    echo "RF_Mode未变动, 不执行操作" >> /tmp/moduleInit
fi
#-------------------------

# LTE锁频
#-------------------------
Band_LTE_file="/tmp/Band_LTE"
if [ -e "$Band_LTE_file" ]; then
    last_Band_LTE=$(cat "$Band_LTE_file")
else
    last_Band_LTE=-1
fi
#--
if [ "$Band_LTE" != "$last_Band_LTE" ]; then
    if [ "$Band_LTE" == 0 ]; then
        sendat_command='AT+QNWPREFCFG="lte_band",1:3:5:8:34:38:39:40:41'
        sendat_result=$(sendat 2 "$sendat_command")
        echo "LTE自动: $sendat_result" >> /tmp/moduleInit
    else
        sendat_command="AT+QNWPREFCFG=\"lte_band\",$Band_LTE"
        sendat_result=$(sendat 2 "$sendat_command")
        echo "LTE锁频: $sendat_result" >> /tmp/moduleInit
    fi
    echo "$Band_LTE" > "$Band_LTE_file"
else
    echo "Band_LTE未变动, 不执行操作" >> /tmp/moduleInit
fi
#----------------------

# SA/NSA模式切换
#----------------------
NR_Mode_file="/tmp/NR_Mode"
if [ -e "$NR_Mode_file" ]; then
    last_NR_Mode=$(cat "$NR_Mode_file")
else
    last_NR_Mode=-1
fi
#--
if [ "$NR_Mode" != "$last_NR_Mode" ]; then
    if [ "$NR_Mode" == 0 ]; then
        echo "NR_Mode: $NR_Mode 自动网络" >> /tmp/moduleInit
        sendat 2 'AT+QNWPREFCFG="nr5g_disable_mode",0' >> /tmp/moduleInit
    elif [ "$NR_Mode" = 1 ]; then
        echo "NR_Mode: $NR_Mode SA网络" >> /tmp/moduleInit
        sendat 2 'AT+QNWPREFCFG="nr5g_disable_mode",2' >> /tmp/moduleInit
    elif [ "$NR_Mode" = 2 ]; then
        echo "NR_Mode: $NR_Mode NSA网络" >> /tmp/moduleInit
        sendat 2 'AT+QNWPREFCFG="nr5g_disable_mode",1' >> /tmp/moduleInit
    fi
    echo "$NR_Mode" > "$NR_Mode_file"
else
    echo "NR_Mode未变动, 不执行操作" >> /tmp/moduleInit
fi
#----------------------

# SA锁频
#----------------------
band_sa_file="/tmp/Band_SA"
if [ -e "$band_sa_file" ]; then
    last_Band_SA=$(cat "$band_sa_file")
else
    last_Band_SA=-1
fi
#--
if [ "$Band_SA" != "$last_Band_SA" ]; then
    if [ "$Band_SA" == 0 ]; then
        sendat_command='AT+QNWPREFCFG="nr5g_band",1:3:8:28:41:78:79'
        sendat_result=$(sendat 2 "$sendat_command")
        echo "SA自动: $sendat_result" >> /tmp/moduleInit
    else
        sendat_command="AT+QNWPREFCFG=\"nr5g_band\",$Band_SA"
        sendat_result=$(sendat 2 "$sendat_command")
        echo "SA锁频: $sendat_result" >> /tmp/moduleInit
    fi
    echo "$Band_SA" > "$band_sa_file"
else
    echo "Band_SA未变动, 不执行操作" >> /tmp/moduleInit
fi
#-------------------

# NSA锁频
#-------------------
band_nsa_file="/tmp/Band_NSA"
if [ -e "$band_nsa_file" ]; then
    last_Band_NSA=$(cat "$band_nsa_file")
else
    last_Band_NSA=-1
fi

if [ "$Band_NSA" != "$last_Band_NSA" ]; then
    if [ "$Band_NSA" == 0 ]; then
        sendat_command='AT+QNWPREFCFG="nsa_nr5g_band",41:78:79'
        sendat_result=$(sendat 2 "$sendat_command")
        echo "NSA自动: $sendat_result" >> /tmp/moduleInit
        echo 0 > /tmp/Band_NSA
    else
        sendat_command="AT+QNWPREFCFG=\"nsa_nr5g_band\",$Band_SA"
        sendat_result=$(sendat 2 "$sendat_command")
        echo "NSA锁频: $sendat_result" >> /tmp/moduleInit
        echo 1 > /tmp/Band_NSA
    fi
    echo "$Band_NSA" > "$band_nsa_file"
else
    echo "Band_NSA未变动, 不执行操作" >> /tmp/moduleInit
fi

#-----------------
    case "$Sim_Sel" in
        0)
            printMsg "外置SIM卡"
            sendat 2 "AT+QUIMSLOT=1"
            echo 1 > /etc/simsel
            sleep 2
            echo "外置SIM卡" >> /tmp/moduleInit
            echo 0 > /tmp/sim_sel
        ;;
        1)
            printMsg "内置SIM1"
            echo 1 > /sys/class/gpio/cpe-sel0/value
            sendat 2 "AT+QUIMSLOT=2"
            echo 2 > /etc/simsel
            sleep 2
            echo "内置SIM卡1" >> /tmp/moduleInit
            echo 1 > /tmp/sim_sel
        ;;
        2)
            printMsg "内置SIM2"
            echo 0 > /sys/class/gpio/cpe-sel0/value
            sendat 2 "AT+QUIMSLOT=2"
            echo 2 > /etc/simsel
            sleep 2
            echo "内置SIM卡2" >> /tmp/moduleInit
            echo 2 > /tmp/sim_sel
        ;;
        *)
            printMsg "错误状态"
            sendat 2 "AT+QUIMSLOT=1"
            sleep 2
            echo 3 > /tmp/Sim_Sel
            echo "SIM状态错误" >> /tmp/moduleInit
        ;;
        esac




#Check if wan work
check_and_activate_wan() {
  echo "Internet IP Check START--------------------->" >>/tmp/moduleInit

  max_retries=10
  retry_interval=30
  retries=0

  while [ "$retries" -lt "$max_retries" ]; do
    ipv4_info=$(sendat 2 'at+qmap="wwan"' | grep IPV4)

    ipv4_address=$(echo "$ipv4_info" | awk -F',' '{print $5}' | tr -d '"')
    echo $(valid_ip "$ipv4_address")
    if [ -z "$ipv4_address" ] || ! valid_ip "$ipv4_address" ; then
      echo "Retry $((retries + 1)): IPv4 address not obtained or invalid. Retrying in $retry_interval seconds..." >>/tmp/moduleInit
      sleep "$retry_interval"
      retries=$((retries + 1))
    else
      echo "IPv4 address obtained: $ipv4_address" >>/tmp/moduleInit
      /sbin/ifup wan up
      /sbin/ifup wan6 up
      echo "WAN UP!Ready to go Internet!" >>/tmp/moduleInit
      rm /tmp/rm520n.lock
    echo '<------------------------------------------------All Job is done' >> /tmp/moduleInit
      exit 0
    fi
  done

  if [ "$retries" -eq "$max_retries" ]; then
    echo "Failed to obtain valid IPv4 address after $max_retries retries. Exiting program." >>/tmp/moduleInit
    exit 1
  fi
}

valid_ip() {
  local ip=$1
  local UNCONNIP="0.0.0.0"
  echo $ip|hexdump -c >>/tmp/moduleInit

  # 包含IP地址的正则表达式
  if echo "$ip" | grep -q -E '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)'; then
    if echo "$ip" | grep -q "0\.0\.0\.0"; then
         return 1  # 返回 1 表示错误
         else
     return 0
    fi
    
  fi

  return 1  # 返回 1 表示错误
}

check_module_startup() {
  echo "Module BOOT and SIM Check START--------------------->" >>/tmp/moduleInit
  max_retries=10
  retry_interval=15
  retries=0
  while [ "$retries" -lt "$max_retries" ]; do
    # 使用 sendat 命令检测模块启动状态
    qinistat_result=$(sendat 2 'at+qinistat')

    # 检查返回值是否包含 "+QINISTAT: 7"
    if echo "$qinistat_result" | grep -q "+QINISTAT: 7"; then
      echo "Module SIM Init Ready,start successfully.">>/tmp/moduleInit
    echo '<------------------------------------------------End Check' >> /tmp/moduleInit
      return 0
    else
      echo "Retry $((retries + 1)): Module not started or SIM card initialization failed. Retrying in $retry_interval seconds...">>/tmp/moduleInit
      sleep "$retry_interval"
      retries=$((retries + 1))
    fi
  done

  # 检查是否达到最大重试次数
  if [ "$retries" -eq "$max_retries" ]; then
    echo "Failed to start module after $max_retries retries. Exiting program.">>/tmp/moduleInit
    rm /tmp/rm520n.lock
    exit 1
  fi
}

#icey@20231202
rm520n_ippt_init(){
    echo "Module IPPT Mode Initialization START--------------------->" >>/tmp/moduleInit
    /sbin/ifup wan down
    /sbin/ifup wan6 down
    echo 'WAN DOWN!' >> /tmp/moduleInit
    mac_address=FF:FF:FF:FF:FF:FF
    echo "WAN MAC is $mac_address"
    send_at_command 'AT+QETH="ipptmac",'$mac_address''
    send_at_command 'at+qmap="mpdn_rule",0'
    send_at_command 'AT+QMAP="mpdn_rule",0,1,0,1,1,"'$mac_address'"'
    sleep 10 
    send_at_command 'AT+QMAP="dhcpv4dns","disable"'
    send_at_command 'AT+QMAP="dhcpv6dns","disable"'
    send_at_command 'AT+QMAP="ippt_nat",0'
    #配置自定义APN
    apnconfig=`uci -q get modem.@ndis[0].apnconfig` || apnconfig=""
    sendat_result=$(sendat 2  'AT+CGDCONT=1,"IPV4V6","'$apnconfig'"')
    echo "APN Result: $sendat_result" >> /tmp/moduleInit
    send_at_command 'AT+cfun=1,1'
    echo '<------------------------------------------------End Init' >> /tmp/moduleInit
}

send_at_command() {
  command="$1"
  max_retries=3
  retries=0

  while [ "$retries" -lt "$max_retries" ]; do
    # 使用 sendat 命令发送 AT 指令并获取返回值
    response=$(sendat 2 "$command")

    # 检查返回值是否包含 "No response from modem."
    if echo "$response" | grep -q "No response from modem."; then
      echo "Retry $((retries + 1)): No response from modem. Retrying in 3 seconds...">>/tmp/moduleInit
      sleep 5
      retries=$((retries + 1))
    else
      # 成功收到响应，打印响应并退出循环
      echo "$command Response received: $response" >>/tmp/moduleInit
      break
    fi
  done

  # 检查是否达到最大重试次数
  if [ "$retries" -eq "$max_retries" ]; then
    echo "Failed to receive response at command $command after $max_retries retries. Exiting." >>/tmp/moduleInit
    exit 1
  fi
}


echo "Module Initialization Pipeline START--------------------->" >>/tmp/moduleInit
rm520n_ippt_init
echo "Wait 20s for Module reboot!--------------------->" >>/tmp/moduleInit
sleep 20
check_module_startup
check_and_activate_wan

exit
