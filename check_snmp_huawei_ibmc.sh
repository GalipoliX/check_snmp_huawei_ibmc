#!/bin/bash
#################################################################################
# Script:       check_snmp_huawei_ibmc
# Author:       Michael Geschwinder (Maerkischer-Kreis)
# Description:  Plugin for Nagios to Monitor Huawei iBMC with snmp
#
# Version:      1.0
#
# History:
# 20180318      Created plugin
#
#################################################################################################################
# Usage:        ./check_snmp_huawei_ibmc.sh -H host -C community -t type [-w warning] [-c critical] [-D debug]
##################################################################################################################

help="check_snmp_huawei_ibmc (c) 2018 Michael Geschwinder published under GPL license
\nUsage: ./check_snmp_huawei_ibmc.sh -H host -C community -t type [-w warning] [-c critical] [-D debug]
\nRequirements: snmpget, awk, sed, grep\n
\nOptions: \t-H hostname\n\t\t-C Community (to be defined in snmp settings)\n\t\t-D enable Debug messages\n\t\t-t Type to check, see list below
\t\t-w Warning Threshold (optional)\n\t\t-c Critical Threshold (optional)\n
\nTypes:\t\t
\t\tsystemhealth -> Checks the overall System health
\t\tpowerhealth -> Checks the health of the powersupplys
\t\tfanhealth -> Checks the health of the fans
\t\tcpuhealth -> Checks the health of the CPUs
\t\tmemoryhealth -> Checks the health of the Memory
\t\tdiskhealth -> Checks the health of the disks
\t\tcomponenthealth -> Checks the health of the components"
##########################################################
# Nagios exit codes and PATH
##########################################################
STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown
PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/lib/nagios/plugins/custom: # Set path


##########################################################
# Debug Ausgabe aktivieren
##########################################################
DEBUG=0

##########################################################
# Debug output function
##########################################################
function debug_out {
        if [ $DEBUG -eq "1" ]
        then
                datestring=$(date +%d%m%Y-%H:%M:%S)
                echo -e $datestring DEBUG: $1
        fi
}

###########################################################
# Check if programm exist $1
###########################################################
function check_prog {
        if ! `which $1 1>/dev/null`
        then
                echo "UNKNOWN: $1 does not exist, please check if command exists and PATH is correct"
                exit ${STATE_UNKNOWN}
        else
                debug_out "OK: $1 does exist"
        fi
}

############################################################
# Check Script parameters and set dummy values if required
############################################################
function check_param {
        if [ ! $host ]
        then
                echo "No Host specified... exiting..."
                exit $STATE_UNKNOWN
        fi

        if [ ! $community ]
        then
                debug_out "Setting default community (public)"
                community="public"
        fi
        if [ ! $type ]
        then
                echo "No check type specified... exiting..."
                exit $STATE_UNKNOWN
        fi
        if [ ! $warning ]
        then
                debug_out "Setting dummy warn value "
                warning=999
        fi
        if [ ! $critical ]
        then
                debug_out "Setting dummy critical value "
                critical=999
        fi
}



############################################################
# Get SNMP Value
############################################################
function get_snmp {
        oid=$1
        snmpret=$(snmpget -v2c -c $community $host $oid -Oqv) # | awk '{print $4}'
        #echo "snmpget -v2c -c $community $host $oid"
        if [ $?  == 0 ]
        then
                echo $snmpret
        else
                exit $STATE_UNKNOWN
        fi
}
############################################################
# Get SNMP Walk
############################################################
function get_snmp_walk {
        oid=$1
        snmpret=$(snmpwalk -v2c -c $community $host $oid -Oqv) # | awk '{print $4}'
        i=0
        IFS=$'\n'
        if [ $?  == 0 ]
        then
                for line in $snmpret
                do
                        line=$(echo $line | sed 's/\"/ /g')
                        retval[$i]=$line
                        let "i+=1"
                done;
        else
                exit $STATE_UNKNOWN
        fi
        IFS=$IFSold

}
############################################################
# Get SNMP Table
############################################################
function get_snmp_table {
        oid=$1
        snmpret=$(snmptable2csv $host --community=$community $oid)
        IFSold=$IFS
        IFS=$'\n'
        if [ $?  == 0 ]
        then
                for line in $snmpret
                do
                        echo $line
                done;
        else
                exit $STATE_UNKNOWN
        fi
        IFS=$IFSold
}


############################################################
# Huawei specific mappings
############################################################

function get_healthstat {
        stat=$1

        case ${stat} in
        1)
                echo "Normal;$STATE_OK"
        ;;
        2)
                echo "Minor;$STATE_WARNING"
        ;;
        3)
                echo "Major;$STATE_CRITICAL"
        ;;
        4)
                echo "Critical;$STATE_CRITICAL"
        ;;
        5)
                echo "Absence;$STATE_WARNING"
        ;;
        6)
                echo "Unknown;$STATE_UNKNOWN"
        ;;
        *)
        esac

}


function get_presence
{
pres=$1
case ${pres} in

        1)
                echo "Absent"
        ;;
        2)
                echo "Present"
        ;;
        3)
                echo "Unknown"
        ;;
        *)
        esac
}

function get_workmode
{
wm=$1
case ${wm} in

        1)
                echo "Active"
        ;;
        2)
                echo "Backup"
        ;;
        3)
                echo "Unknown"
        ;;
        *)
        esac
}

function get_component
{
comp=$1
case ${comp} in

        1)
                echo "baseBoard"
        ;;
        2)
                echo "mezzCard"
        ;;
        3)
                echo "amcController"
        ;;
        4)
                echo "mmcController"
        ;;
        5)
                echo "hddBackPlane"
        ;;
        6)
                echo "raidCard"
        ;;
        *)
                echo "$comp       "
        esac
}



function get_noyes
{
        val=$1
        case ${val} in
        0)
                echo No
        ;;
        1)
                echo Yes
        ;;
        *)
                echo UNKNOWN
        esac


}
function check_ret
{
        if [ "$1" == "" ]
        then
                echo "No data received!"
                exit $STATE_UNKNOWN
        fi
}

#################################################################################
# Display Help screen
#################################################################################
if [ "${1}" = "--help" -o "${#}" = "0" ];
       then
       echo -e "${help}";
       exit $STATE_UNKNOWN;
fi

################################################################################
# check if requiered programs are installed
################################################################################
for cmd in snmpget snmpwalk snmptable2csv awk sed grep;do check_prog ${cmd};done;

################################################################################
# Get user-given variables
################################################################################
while getopts "H:C:t:w:c:o:D" Input;
do
       case ${Input} in
       H)      host=${OPTARG};;
       C)      community=${OPTARG};;
       t)      type=${OPTARG};;
       w)      warning=${OPTARG};;
       c)      critical=${OPTARG};;
       o)      moid=${OPTARG};;
       D)      DEBUG=1;;
       *)      echo "Wrong option given. Please use options -H for host, -c for SNMP-Community, -t for type, -w for warning and -c for critical"
               exit 1
               ;;
       esac
done

debug_out "Host=$host, Community=$community, Type=$type, Warning=$warning, Critical=$critical"

check_param



#################################################################################
# Switch Case for different check types
#################################################################################
case ${type} in
#manual oid
manual)
        declare -A retval
        set -e
        get_snmp_walk $moid
        a=("${retval[@]}")
        echo "length:"
        echo ${#a[@]}
        echo ${a[@]}
        set +e
        exit
;;

systemhealth)
        set -e
        #echo -e "id\thealthstat\trunningstat\tlocation\ttype\tcapacity\tdiskrole\tdiskspeed\ttemp\tmodel\t\t\tfwversion=\tmanufacturer\t\tserial\t\tdomain\truntime"
        ret=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.1.1.0 )
        systime=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.1.3.0)
        devname=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.1.6.0)
        devserial=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.1.7.0)
        sysguid=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.1.10.0)
        syspower=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.1.13.0)
        devownerid=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.1.14.0)
        devslotid=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.1.15.0)
        info="DeviceName: $devname\nDeviceSerial: $devserial\nSystemGUID: $sysguid\nSystemTime: $systime\nSystemPower: $syspower\ndeviceOwnerID: $devownerid\nDeviceSlotID: $devslotid"
        check_ret $ret
        healthstatret=$(get_healthstat $ret)
        nagret=$(echo $healthstatret | cut -d ";" -f2)
        healthstat=$(echo $healthstatret | cut -d ";" -f1)



        if [ "$nagret" == "$STATE_CRITICAL" ]
        then
                echo "Overall System Health is Critical!"
                exit $STATE_CRITICAL

        elif [ "$nagret" == "$STATE_WARNING" ]
        then
                echo "Overall System Health is Warning!"
                exit $STATE_WARNING
        elif [ "$nagret" == "$SATE_UNKNOWN" ]
        then
                echo "Overall System Health is Unknown!"
                exit $SATE_UNKNOWN
        else
                echo "Overall System Health is OK!"
                echo -e $info
                exit $SATE_OK
        fi

        set +e
;;

powerstatistic)
        set -e
        #echo -e "id\thealthstat\trunningstat\tlocation\ttype\tcapacity\tdiskrole\tdiskspeed\ttemp\tmodel\t\t\tfwversion=\tmanufacturer\t\tserial\t\tdomain\truntime"
        peakpower=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.20.1.0 | sed 's/\"//g')
        peakpowertime=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.20.2.0| sed 's/\"//g')
        averagepower=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.20.3.0| sed 's/\"//g')
        powerconsumption=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.20.4.0| sed 's/\"//g')
        powerconsumptiontime=$(get_snmp .1.3.6.1.4.1.2011.2.235.1.1.20.5.0| sed 's/\"//g')

        echo -e "System is using $averagepower W of Power average\nPeak Power: $peakpower W at $peakpowertime\nPowerconsumption $powerconsumption kWh | avgpower=$averagepower;;;"
        exit $SATE_OK

        set +e
;;


powerhealth)
        messagetext="Power Supplys"
        set -e
        ret=$(get_snmp_table .1.3.6.1.4.1.2011.2.235.1.1.6.50.1)
        check_ret $ret
        IFSold=$IFS
        IFS=$'\n'

        for line in $ret
        do
                line=$(echo $line | sed 's/\"//g')

                id=$(echo $line | cut -d "," -f1)
                model=$(echo $line | cut -d "," -f4)
                rating=$(echo $line | cut -d "," -f6)
                psstatus=$(echo $line | cut -d "," -f7)
                inputpower=$(echo $line | cut -d "," -f8)
                presence=$(echo $line | cut -d "," -f9)
                presence=$(get_presence $presence)
                location=$(echo $line | cut -d "," -f11)
                name=$(echo $line | cut -d "," -f13)
                workmode=$(echo $line | cut -d "," -f14)
                workmode=$(get_workmode $workmode)

                debug_out "id=$id model=$model rating=$rating status=$psstatus inputpower=$inputpower presence=$presence location=$location name=$name workmode=$workmode"

                healthstatret=$(get_healthstat $psstatus)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)

                outtext="id=$id\tmodel=$model\trating=$rating V\tstatus=$healthstat\tinputpower=$inputpower V\tpresence=$presence\tlocation=$location\tname=$name\tworkmode=$workmode\n"
                perf="$perf inputpower-$id=$inputpower;;;"
                if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi



        done;
        IFS=$IFSold
        set +e
;;

fanhealth)
        messagetext="Fans"
        set -e
        ret=$(get_snmp_table .1.3.6.1.4.1.2011.2.235.1.1.8.50.1)
        check_ret $ret
        IFSold=$IFS
        IFS=$'\n'
        for line in $ret
        do
                line=$(echo $line | sed 's/\"//g')
                id=$(echo $line | cut -d "," -f1)
                speed=$(echo $line | cut -d "," -f2)
                presence=$(echo $line | cut -d "," -f3)
                presence=$(get_presence $presence)
                fstatus=$(echo $line | cut -d "," -f4)
                location=$(echo $line | cut -d "," -f5)
                name=$(echo $line | cut -d "," -f7)


                healthstatret=$(get_healthstat $fstatus)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)

                outtext="id=$id\tspeed=$speed rpm\tpresence=$presence\tszatus=$healthstat\tlocation=$location\tname=$name\n"
                perf="$perf fanspeed-$id=$speed;;;"

                if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi




        done;
        IFS=$IFSold
        set +e
;;

cpuhealth)
        messagetext="CPUs"
        set -e
        ret=$(get_snmp_table .1.3.6.1.4.1.2011.2.235.1.1.15.50.1)
        check_ret $ret
        IFSold=$IFS
        IFS=$'\n'
        for line in $ret
        do
                line=$(echo $line | sed 's/\"//g')
                id=$(echo $line | cut -d "," -f1)
                cputype=$(echo $line | cut -d "," -f4)
                clock=$(echo $line | cut -d "," -f5)
                cpustatus=$(echo $line | cut -d "," -f6)
                name=$(echo $line | cut -d "," -f10)

                healthstatret=$(get_healthstat $cpustatus)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)

                #echo $elabel

                outtext="id=$id\tcputype=$cputype\tclock=$clock\tstatus=$healthstat\tname=$name\n"

                if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi

        done;
        IFS=$IFSold
        set +e
;;

memoryhealth)
        messagetext="RAM sticks"
        set -e
        ret=$(get_snmp_table .1.3.6.1.4.1.2011.2.235.1.1.16.50.1)
        check_ret $ret
        IFSold=$IFS
        IFS=$'\n'
        for line in $ret
        do

                line=$(echo $line | sed 's/\"//g')
                id=$(echo $line | cut -d "," -f1)
                manuf=$(echo $line | cut -d "," -f3)
                size=$(echo $line | cut -d "," -f4)
                clock=$(echo $line | cut -d "," -f5)
                memstatus=$(echo $line | cut -d "," -f6)
                name=$(echo $line | cut -d "," -f10)

                if [ "$memstatus" == "5" ]
                then
                        debug_out "Stick not present"
                        continue
                fi

                healthstatret=$(get_healthstat $memstatus)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)

                #echo $elabel
                outtext="id=$id\tmanufacturer=$manuf\tsize=$size\tclock=$clock\t\tstatus=$healthstat\tname=$name\n"
                if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi

        done;
        IFS=$IFSold
        set +e
;;

diskhealth)
        messagetext="Disks"
        set -e
        retval=()
        debug_out "Getting col B"
        get_snmp_walk .1.3.6.1.4.1.2011.2.235.1.1.18.50.1.2
        colb=("${retval[@]}")
        retval=()
        debug_out "Getting col C"
        get_snmp_walk .1.3.6.1.4.1.2011.2.235.1.1.18.50.1.3
        colc=("${retval[@]}")
        retval=()
        debug_out "Getting col D"
        get_snmp_walk .1.3.6.1.4.1.2011.2.235.1.1.18.50.1.4
        cold=("${retval[@]}")
        retval=()
        debug_out "Getting col E"
        get_snmp_walk .1.3.6.1.4.1.2011.2.235.1.1.18.50.1.5
        cole=("${retval[@]}")
        retval=()
        get_snmp_walk .1.3.6.1.4.1.2011.2.235.1.1.18.50.1.6
        debug_out "Getting col F"
        colf=("${retval[@]}")
        retval=()
        debug_out "Getting col G"
        get_snmp_walk .1.3.6.1.4.1.2011.2.235.1.1.18.50.1.7
        colg=("${retval[@]}")
        retval=()
        debug_out "Getting col H"
        get_snmp_walk .1.3.6.1.4.1.2011.2.235.1.1.18.50.1.8
        colh=("${retval[@]}")
        retval=()
        debug_out "Getting col I"
        get_snmp_walk .1.3.6.1.4.1.2011.2.235.1.1.18.50.1.9
        coli=("${retval[@]}")
        retval=()
        set +e
        count=0
        for i in "${colb[@]}"
        do
                ret=$(echo -e "${ret}\n$count,${colb[$count]},${colc[$count]},${cold[$count]},${cole[$count]},${colf[$count]},${colg[$count]},${colh[$count]},${coli[$count]}")
                let "count+=1"
        done


        check_ret $ret
        IFSold=$IFS
        IFS=$'\n'
        for line in $ret

        do
              line=$(echo $line | sed 's/\"//g')
              id=$(echo $line | cut -d "," -f1)
              pres=$(echo $line | cut -d "," -f2)
              diskstatus=$(echo $line | cut -d "," -f3)
              devname=$(echo $line | cut -d "," -f6)
              serial=$(echo $line | cut -d "," -f7)
              model=$(echo $line | cut -d "," -f8)
              manuf=$(echo $line | cut -d "," -f9)



                if [ "$pres" == "1" ]
                then
                        debug_out "Disk not present"
                        continue
                fi

                healthstatret=$(get_healthstat $diskstatus)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)

                #echo $elabel
                outtext="id=$id\tdiskstatus=$healthstat\tdevname=$devname\tserial=$serial\tmodel=$model\tmanuf=$manuf\n"
                if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi

        done;
        IFS=$IFSold
        set +e
;;

componenthealth)
        messagetext="Components"
        set -e
        ret=$(get_snmp_table .1.3.6.1.4.1.2011.2.235.1.1.10.50.1)
        check_ret $ret
        IFSold=$IFS
        IFS=$'\n'
        for line in $ret
        do
                line=$(echo $line | sed 's/\"//g')
                name=$(echo $line | cut -d "," -f1)
                type=$(echo $line | cut -d "," -f2)
                type=$(get_component $type)
                pcbversion=$(echo $line | cut -d "," -f3)
                boardid=$(echo $line | cut -d "," -f4)
                status=$(echo $line | cut -d "," -f5)

                healthstatret=$(get_healthstat $status)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)

                outtext="name=$name\t\ttype=$type\t\tpcbversion=$pcbversion\tboardid=$boardid\tstatus=$healthstat\n"

                if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi




        done;
        IFS=$IFSold
        set +e
;;

*)
        echo -e "${help}";
        exit $STATE_UNKNOWN;

esac








###################################################################################################################################
# Output an exit status
###################################################################################################################################

if [ $CRIT ]
then
        echo "One or more $messagetext are in critical state!"
        echo -e "CRITICAL: \n$crittext"
        echo -e "\nWARNING: \n$warntext"
        echo -e "\nOK: \n$oktext"
        echo -e "\nUNKNOWN: \n$unknowntext"
        exit $STATE_CRITICAL
elif [ $WARN ]
then
        echo "One or more $messagetext are in warning state!"
        echo -e "\nWARNING: \n$warntext"
        echo -e "\nOK: \n$oktext"
        echo -e "\nUNKNOWN: \n$unknowntext"
        exit $STATE_WARNING
elif [ $UNKNOWN ]
then
        echo "One or more $messagetext are in unknown state!"
        echo -e "\nUNKNOWN: \n$unknowntext"
        echo -e "\nOK: \n$oktext"
        exit $STATE_UNKNOWN
else
        echo "All $messagetext are in OK state!"
        echo -e "\nOK: \n$oktext | $perf"
        exit $STATE_OK
fi
