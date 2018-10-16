#!/bin/bash

# Script for CpuShutDown Failure Injection
# This script allows setting to shutdown a specified number of CPUs.
# Note: it is not possible to disable CPU0 on Linux systems since at least one CPU
# must be available. So this script does not work for nodes that have a single CPU.

# Here start the bash script
# Number of available CPU cores
TOTAL_CPU=$(grep -c ^processor /proc/cpuinfo)
# Number of CPU to shutdown
DEFAULT_SHUTDOWN_CPU=`expr ${TOTAL_CPU} - 1`
# Timeout after which the CPUs are restarted
TIMEOUT=0

# getopt parameters
PROGNAME=${0##*/}
SHORTOPTS="c:t:h"
LONGOPTS="help,start,stop,cpu-number:,timeout:"

OPTS=$(getopt -s bash --options ${SHORTOPTS}  \
  --longoptions ${LONGOPTS} --name ${PROGNAME} -- "$@" )

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "${OPTS}"


# help function
function usage
{
        G="\e[92m"
        Y="\e[93m"
        W="\e[39m"

        echo -e "   $G - Cpu hang stress load $W"
        echo -e ""
        echo -e "       Usage: $G $0 $Y < --start [OPTION [ARG]] ... |stop|help > $W"
        echo -e ""
        echo -e "       If no parameter are provided along with the \"start\" option"
        echo -e "       then the (Max num of CPU - 1) are shut down."
        echo -e ""
        echo -e "       options:"
        echo -e "       $G -h, --help               $Y show this help statement"
        echo -e "       $G --start                  $Y start the cpu shutdown"
        echo -e "       $G --stop                   $Y stop the cpu shutdown"
        echo -e "       $G -c | --cpu-number <N>    $Y specify the number of cpu to shutdown"
        echo -e "       $G -t | --timeout <N>       $Y timeout after N seconds"
        echo -e ""
        exit 1
};

# Function to print error line
function error() {
	printf "%s\n" "$1" >&2
}

# Function that checks if the provided input is an integer value
function isInt ()
{
    if ! echo "$1" | grep -E '^[0-9]+$' > /dev/null; then
        error "-t option must be an integer value, got '$1'"
		usage
	fi
}

# Function that shutdown the CPUs
function startShutdown () {

    # If only one CPU is available then do nothing
    if [[ ${TOTAL_CPU} == 1 ]]; then
        error "No available CPU to shutdown.";
        exit 0;
    fi

    # If default option is 1 then shutdown all the available CPUs (with the exception of CPU0)
    # Loop to shutdown the required CPUs or all the available CPUs
    SUB=$((TOTAL_CPU - SHUTDOWN_CPU))
    if [[ ${SUB}  -le 0 ]]; then
        for ((i=1; i<=${TOTAL_CPU}-1; i++));
        do
            0</dev/null sudo bash -c "echo 0 > /sys/devices/system/cpu/cpu"${i}"/online" > /dev/null;
        done
    else
        for ((i=1;i<=${SHUTDOWN_CPU}; i++));
        do
            0</dev/null sudo bash -c "echo 0 > /sys/devices/system/cpu/cpu"${i}"/online" > /dev/null;
        done
    fi

    # If a timeout has been provided then sleep and stop
    if [[ ${TIMEOUT} -gt 0 ]]
    then
        sleep ${TIMEOUT}
        stopShutdown
    fi
}

# Function that restart all the available CPUs
function stopShutdown () {
#    OFFLINE_CPU=$(cat /sys/devices/system/cpu/offline | sed "s/-.*//g")
#    for ((i=1; k<${#OFFLINE_CPU[@]} && i<=${OFFLINE_CPU}; i++));
#    do
#        0</dev/null sudo bash -c "echo 1 > /sys/devices/system/cpu/cpu"${i}"/online" > /dev/null;
#    done
    find /sys/devices/system/cpu/ -type d -regex '.*cpu[1-9][0-9]*' | \
    while read CPU; do
        sudo bash -c "echo 1 > $CPU/online";
    done
}


# Iterate over the provided parameters
while true; do
    case "$1" in
        -h | --help)
            usage
            ;;
        --start | --stop)
            OPERATION=${1#"--"};
            shift;
            ;;
        -c | --cpu-number)
            isInt "$2"
            SHUTDOWN_CPU=$2;
            shift 2;
            ;;
        -t | --timeout)
            isInt "$2"
            TIMEOUT=$2;
            shift 2;
            ;;
        -- )
            shift;
            break
            ;;
        *)
            shift;
            break
            ;;
    esac
done


# Set default value if not provided
SHUTDOWN_CPU=${SHUTDOWN_CPU:-${DEFAULT_SHUTDOWN_CPU}}

# main
case "$OPERATION" in
    start)
        startShutdown;
        ;;
    stop)
        stopShutdown;
        ;;
    *)
      usage;
esac

exit 0;