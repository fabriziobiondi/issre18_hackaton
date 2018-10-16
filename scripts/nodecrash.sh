#!/bin/bash

# Script for NodeShutDown Failure Injection
# This script allows:
#   1. Simulating a shutdown by disabling all the network interfaces
#   2. Powering off the node
#   3. Restarting the node
#   4. Setting a timeout after which the shutdown simulation stops (the interfaces are up again)



# Here start the bash script
# Network interface names (loopback interface is avoided)
NET_INTERFACES=$(sudo ip -o link show | awk '{print $2}' | sed 's/://g;/^\(lo\|\)$/d')

# Timeout after which the latency injection stops
TIMEOUT=0

# getopt parameters
PROGNAME=${0##*/}
SHORTOPTS="t:h"
LONGOPTS="help,bomb,simulate,restart,shutdown,timeout:"

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

        echo -e "   $G - Node Shut Down failure injection $W"
        echo -e ""
        echo -e "       Usage: $G $0 $Y <bomb|simulate|restart|shutdown|stop> $W"
        echo -e ""
        echo -e "       If no parameter are provided along with the \"start\" option"
        echo -e "       then a simulation of the shutdown is started."
        echo -e ""
        echo -e "       options:"
        echo -e "       $G -h | --help                  $Y show this help statement"
        echo -e "       $G --bomb                 $Y fork bom to deplete available system resources"
        echo -e "       $G --simulate             $Y simulate shutdown by disabling all the network interfaces"
        echo -e "       $G --restart              $Y restart the node"
        echo -e "       $G --shutdown             $Y power off the node"
        echo -e "       $G -t <N>               $Y timeout after N seconds (this works only along with the \"simulate\" option)"
        echo -e ""
        exit 1
};

# Function that checks if the provided input is an integer value
function isInt ()
{
    if ! echo "$1" | grep -E '^[0-9]+$' > /dev/null; then
        error "-t option must be an integer value, got '$1'"
		usage
	fi
}


# Start fork-bomb task
cat << EOF > /tmp/forkbomb.sh
#!/bin/bash
:(){ :|:& };:
EOF

function bomb() {
    local BOMB_NUMBER=10;

    chmod +x /tmp/forkbomb.sh
    for ((i=0; i<${BOMB_NUMBER}; i++));
    do
       sudo nohup nice -n -20 /bin/bash /tmp/forkbomb.sh </dev/null >/dev/null 2>&1 &
    done

    # If a timeout has been provided then sleep and stop
    if [[ ${TIMEOUT} -gt 0 ]]
    then
        sleep ${TIMEOUT}
        stop
    fi
}

function simulation() {
    # Repeat the corresponding operation for each network interface
    echo "$NET_INTERFACES" | while read interface
    do
        0</dev/null sudo ip link set ${interface} down &
    done

    # If a timeout has been provided then sleep and stop
    if [[ ${TIMEOUT} -gt 0 ]]
    then
        sleep ${TIMEOUT}
        stop
    fi
}

function restart() {
    # Reboot the node
    0</dev/null sudo reboot &
}

function shutdown() {
    # Shutdown the node
    0</dev/null sudo shutdown -h now &
}


# This function stop the simulation of the shutdown by restarting all the
# network interfaces
function stop() {

    case "$OPERATION" in
        bomb)
            pid=$(ps -ef | grep -E '[f]orkbomb' | awk '{print $2}');
            sudo kill -9 ${pid};
            ;;
        simulate)
            echo "$NET_INTERFACES" | while read interface
            do
                0</dev/null sudo ip link set ${interface} up &
            done
            ;;
        *)
            ;;
     esac
}

# Iterate over the provided parameters
while true; do
    case "$1" in
        -h | --help)
            usage
            ;;
        --bomb | --simulate | --restart | --shutdown| --stop)
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
    bomb)
        bomb;
        ;;
    simulate)
        simulation;
        ;;
    restart)
        restart;
        ;;
    shutdown)
        shutdown;
        ;;
    stop)
        stop
        ;;
    *)
      usage;
esac

exit 0;
