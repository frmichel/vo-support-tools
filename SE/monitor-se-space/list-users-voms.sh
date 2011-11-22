#!/bin/bash
# list-voms-users.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This script gets the list of users from the VOMS server using the voms-admin command.
#
# All parameters default to biomed specific values, but can be specified using the options.
#

VO=biomed
VOMS_HOST=voms-biomed.in2p3.fr
VOMS_PORT=8443
VOMS_USERS=`pwd`/voms-users.txt

help()
{
  echo
  echo "This script gets the list of users from the VOMS server using the voms-admin command."
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
    --out ) VOMS_USERS=$2; shift;;
    --voms-host ) VOMS_HOST=$2; shift;;
    --voms-port ) VOMS_PORT=$2; shift;;
    -h | --help ) help;;
    *) help;;
  esac
  shift
done

# Get the current list of users from the VOMS server
voms-admin --vo=$VO --host $VOMS_HOST --port $VOMS_PORT list-users > $VOMS_USERS.temp
if test $? -eq 0; then
  mv $VOMS_USERS.temp $VOMS_USERS
  echo "Users list built successfully: $VOMS_USERS."
  exit 0
else
  echo "Failed to build list of users from VOMS."
  exit 1
fi

