#!/bin/bash
# list-voms-users.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support

VO=biomed
VOMS_HOST=voms-biomed.in2p3.fr
VOMS_PORT=8443
VOMS_SUSPENDED_EXPIRED_USERS=`pwd`/suspended-expired-voms-users.txt

help()
{
  echo
  echo "This script gets the list of suspended or expired users from the VOMS server using the voms-admin command."
  echo "The result file is replaced/created only if the voms-admin commands succeeds, otherwise "
  echo "the existing file remains unchanged."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] [--voms-host <hostname>] [--voms-port <port>] [--out  <file name>]"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --voms-host <hostname>: VOMS server hostname. Defaults to voms-biomed.in2p3.fr."
  echo
  echo "  --voms-port <post>: VOMS server hostname. Defaults to 8443."
  echo
  echo "  --out <file name>: where to store results. Defaults to './voms-users.txt'."
  echo
  echo "  -h, --help: display this help"
  echo
  exit 1
}



# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --out ) VOMS_SUSPENDED_EXPIRED_USERS=$2; shift;;
    --voms-host ) VOMS_HOST=$2; shift;;
    --voms-port ) VOMS_PORT=$2; shift;;
    -h | --help ) help;;
    *) help;;
  esac
  shift
done

# Get the current list of users from the VOMS server
voms-admin --vo=$VO --host $VOMS_HOST --port $VOMS_PORT list-suspended-users | grep -v -i ',Active,' | cut -d ',' -f 1 > $VO-suspended-voms-users.temp
voms-admin --vo=$VO --host $VOMS_HOST --port $VOMS_PORT list-expired-users | grep -v -i ',Active,' | cut -d ',' -f 1 > $VO-expired-voms-users.temp
voms-admin --vo=$VO --host $VOMS_HOST --port $VOMS_PORT list-users > $VO-voms-users.aux.temp

cat $VO-suspended-voms-users.temp $VO-expired-voms-users.temp | sort | uniq > $VOMS_SUSPENDED_EXPIRED_USERS.temp
if test -f $VOMS_SUSPENDED_EXPIRED_USERS.aux.temp; then
    rm $VOMS_SUSPENDED_EXPIRED_USERS.aux.temp
fi
cat $VOMS_SUSPENDED_EXPIRED_USERS.temp | while read line
do
    grep -s -h "$line" $VO-voms-users.aux.temp >> $VOMS_SUSPENDED_EXPIRED_USERS.aux.temp
done 
 
if test -f $VOMS_SUSPENDED_EXPIRED_USERS.aux.temp; then
    mv $VOMS_SUSPENDED_EXPIRED_USERS.aux.temp $VOMS_SUSPENDED_EXPIRED_USERS
    rm $VOMS_SUSPENDED_EXPIRED_USERS.temp
    rm $VO-suspended-voms-users.temp
    rm $VO-expired-voms-users.temp
    rm $VO-voms-users.aux.temp 
    echo "Users list built successfully: $VOMS_SUSPENDED_EXPIRED_USERS."
    exit 0
else
    echo "Failed to build list of users from VOMS."
    exit 1
fi
