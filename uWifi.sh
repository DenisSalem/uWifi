#! /bin/bash

uWifiVersion="0.0.2"
basePath="/home/http/dev/uWifi/"
langPath="Messages/"
langFileName=$(echo $LANG | cut -f 1 -d '.' | cut -f 1 -d '_')

function abort {
  echo $1
  exit $2
}

###########################################################
# LANGUAGE SETTING ########################################
###########################################################

if [ -f $basePath$langPath$langFileName ]
then
  source $basePath$langPath$langFileName
else
  source $basePath$langPath"en"
fi


###########################################################
# CHECK IF COMMANDS EXIST #################################
###########################################################

wpa_supplicant -v >/dev/null 2>&1 || abort "$uWifi_wpaSupplicantIsntInstalled"
dhcpcd --version >/dev/null 2>&1 || abort "$uWifi_dhcpcdIsntInstalled"
iw --version >/dev/null 2>&1 || abort "$uWifi_iwIsntInstalled"
ip -V >/dev/null 2>&1 || abort "$uWifi_ipIsntInstalled"

###########################################################
# AVOID ARP POISONING #####################################
###########################################################

function avoidArpPoisoning {
  parser='$2 != "0.0.0.0" && $2 != "127.0.0.1" {gateway=$2} END {printf "%s",gateway}'
  gatewayIp=$(route -n | tail -n +3 | awk "$parser")

  if [[ "$gatewayIp" != "" ]]
  then
    echo "GATEWAY IP:	$gatewayIp"
    gatewayMac=$(nmap -sP "$gatewayIp" | grep "MAC Add" | cut -d ' ' -f 3)
    if [[ "$gatewayMac" == "" ]]
    then
      echo $uWifi_cannotFetchRouteMAC
    else
      echo "GATEWAY MAC:	$gatewayMac"
    fi
  else
    echo $uWifi_cannotFetchRouteIP
  fi

  if [[ "$gatewayMac" != "" && "$gatewayIp" != "" ]]
  then
    echo $uWifi_permanentlyAssociateHardwareAddresseToHostname
    arp -s "$gatewayIp" "$gatewayMac"
  fi
}

###########################################################
# GET AVAILABLE WIRELESS NETWORK ##########################
###########################################################

function getAvailableWirelessNetWork {
  parser='\
    $1 == "BSS" {
      MAC = substr($2,0,17)
      wifi[MAC]["enc"] = "NONE"
    }
  
    $1 == "SSID:" {
      wifi[MAC]["SSID"] = $2
    }
  
    $1 == "signal:" {
      wifi[MAC]["signal"] = $2
    }
  
    $1 == "WEP:" {
      wifi[MAC]["enc"] = "WEP"
    }
  
    $1 == "WPA:" {
      wifi[MAC]["enc"] = "WPA"
    }
  
    $1 == "RSN:" {
      wifi[MAC]["enc"] = "WPA2"
    }
  
    END {
      for (w in wifi) {
        printf "%s\t%s dBm\t%s\t%s\n",w,wifi[w]["signal"],wifi[w]["enc"],wifi[w]["SSID"]
      }
    }
  '

  ip link set dev "$1" up
  scanOutput=`iw dev "$1" scan | awk "$parser"`
  echo "$scanOutput" > /tmp/uWifiScanOutput
  sort --key 2 --reverse --numeric-sort /tmp/uWifiScanOutput
  rm /tmp/uWifiScanOutput
}

###########################################################
# DECICE WHAT TO DO #######################################
###########################################################


if [ $# -eq "0" ]
then
  abort "$uWifi_nothingToDo" 0
elif [ $1 = "auto" ]
then
  getAvailableWirelessNetWork "wlp0s20u3"
else
  echo "$uWifi_unknownCommand"
fi

