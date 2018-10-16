#!/bin/bash

# Script for BurnCPU Failure Injection
# This script allows setting the number of tasks to run to burn the I/O and
# the timeout after which the script kill all the previous tasks

# Default number of tasks
DEFAULT_CPU_TASKS=32
# Timeout after which the corruption injection stops
TIMEOUT=0

# getopt parameters
PROGNAME=${0##*/}
SHORTOPTS="c:t:h"
LONGOPTS="help,start,stop,task-number:,timeout:"

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
        echo -e "       then a stress CPU burn is started with 32 tasks."
        echo -e ""
        echo -e "       options:"
        echo -e "       $G -h, --help               $Y show this help statement"
        echo -e "       $G --start                  $Y start the cpu burn tasks"
        echo -e "       $G --stop                   $Y stop the cpu burn tasks"
        echo -e "       $G -c | --task-number <N>   $Y specify the number of CPU tasks to run"
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


function createTask() {
# Burn the CPU by stressing the testing of the cryptographic algorithms
sudo bash -c 'cat << EOF > /tmp/loopburncpu.sh
#!/bin/bash
while true;
do
    openssl speed > /dev/null 2>&1;
done
EOF'
}

# Function that starts a specific number of CPU tasks
function startCpuBurn()
{
    [[ ! -f "/tmp/loopburncpu.sh" ]] && createTask;

    for ((i=0; i<$CPU_TASKS; i++));
    do
       0</dev/null sudo nohup nice -n -1 /bin/bash /tmp/loopburncpu.sh </dev/null >/dev/null 2>&1 &
    done

    # If a timeout has been provided then sleep and stop
    if [[ ${TIMEOUT} -gt 0 ]]
    then
        sleep ${TIMEOUT}
        stopCpuBurn;
    fi
};

# Function that stop all the burn tasks
function stopCpuBurn()
{
    #ps -ef | grep -E '[l]oopburncpu|[o]penssl' | awk '{print $2}' | xargs sudo kill -9
    for pid in `ps -ef | grep -E '[l]oopburncpu|[o]penssl' | awk '{print $2}'`;
    do
        0</dev/null sudo renice 0 ${pid};
        0</dev/null sudo kill -9 ${pid};
    done
};


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
        -c | --task-number)
            isInt "$2"
            CPU_TASKS=$2;
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
CPU_TASKS=${CPU_TASKS:-${DEFAULT_CPU_TASKS}}

# main
case "$OPERATION" in
    start)
        startCpuBurn;
        ;;
    stop)
        stopCpuBurn;
        ;;
    *)
      usage;
esac

exit 0;