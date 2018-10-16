#!/bin/bash

# Script for FillMemory Failure Injection
# Timeout after which the corruption injection stops
TIMEOUT=0

# getopt parameters
PROGNAME=${0##*/}
SHORTOPTS="t:h"
LONGOPTS="help,start,stop,timeout:"

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

        echo -e " $G - Memory saturation load $W"
        echo -e ""
        echo -e ""
        echo -e "       Usage: $G $0 $Y < --start [OPTION [ARG]] ... |stop|help > $W"
        echo -e ""
        echo -e "       The start option saturate the memory."
        echo -e "       The stop option release the memory."
        echo -e ""
        echo -e "       Options:"
        echo -e "       $G -h, --help     $Y show this help statement"
        echo -e "       $G --start        $Y start the writing on the memory"
        echo -e "       $G --stop         $Y start the writing on the memory"
        echo -e "       $G -t <N>         $Y timeout after N seconds"
        echo -e ""
        exit 1
};

cat << EOF > /tmp/fillmemory.c
#include <stdlib.h>

int main() {
int *p;
while(1) {
    int inc=1024*1024*sizeof(char);
    p=(int*) calloc(1,inc);
    if(!p) break;
    }
}
EOF


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

function start() {
    # Fill up the memory
    0</dev/null sudo nice -n -20 gcc /tmp/fillmemory.c -x c; ./a.out > /dev/null;

    # If a timeout has been provided then sleep and stop
    if [[ ${TIMEOUT} -gt 0 ]]
    then
        sleep ${TIMEOUT}
        stop
    fi
}

function stop() {
    #pid=$(ps -ef | grep -E '[f]illmemory' | awk '{print $2}')
    pid=$(ps -ef | grep -E '[a.]out' | awk '{print $2}')
    kill -9 $pid
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

# main
case "$OPERATION" in
    start)
        start;
        ;;
    stop)
        stop;
        ;;
    *)
      usage;
esac

exit 0;