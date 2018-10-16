#!/bin/bash

# Script for Process Killing failure injection


# help function
function usage
{
        G="\e[92m"
        Y="\e[93m"
        W="\e[39m"

        echo -e "  $G - Kill process $W"
        echo -e ""
        echo -e "       Usage: $G $0 $Y <process_name> $W"
        exit 1
};

# Checks the input parameter
if ([[ $# < 1 || $# > 1 ]]) ; then
        usage;
fi

PROCESS=$1

ps -ef | grep -E "$PROCESS" | grep -v grep | awk '{print $2}' | xargs kill >/dev/null 2>&1 &

#nohup pkill -KILL -f ${PROCESS} >/dev/null 2>&1 &