#!/bin/bash
# se-heavy-users.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This script looks for users of a the given VO who have more that 1GB of data on the given SE.
# It provides the list of such users as well as their email address.
#
# All parameters default to biomed specific values, but can be specified using the options.
#

VO=biomed
VOMS_HOST=voms-biomed.in2p3.fr
VOMS_PORT=8443
WDIR=`pwd`

help()
{
  echo
  echo "This script looks for users of a the given VO who have more that 1GB of data on the given SE."
  echo "It provides the list of such users as well as their email address."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] [--voms-host <hostname>] [--voms-port <port>] [--dir <work directory>] <SE hostname>"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --voms-host <hostname>: VOMS server hostname. Defaults to voms-biomed.in2p3.fr."
  echo
  echo "  --voms-port <post>: VOMS server hostname. Defaults to 8443."
  echo
  echo "  --dir <work directory>: where to store results. Defaults to '.'."
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
    --dir ) WDIR=$2; shift;;
    --voms-host ) VOMS_HOST=$2; shift;;
    --voms-port ) VOMS_PORT=$2; shift;;
    -h | --help ) help;;
    *) SEHOSTNAME=$1;;
  esac
  shift
done

if test -z "$SEHOSTNAME" ; then
    help
fi

# Check environment
if test -z "$LFC_HOME"; then
    echo "Please set variable LFC_HOME before calling $0, e.g. export LFC_HOME=/grid/biomed/"
    exit 1
fi
if test -z "$LFC_HOST"; then
    echo "Please set variable LFC_HOST before calling $0, e.g. export LFC_HOST=lfc-biomed.in2p3.fr"
    exit 1
fi
if test -z "$LFCBROWSESE"; then
    echo "Please set variable LFCBROWSESE to the full path of binary LFCBrosweSE before calling $0."
    exit 1
fi
if ! [ -d $WDIR ]; then
    mkdir -p $WDIR
fi

mkdir -p $WDIR/work
LFCBROWSESE_OUTPUT=$WDIR/work/$SEHOSTNAME.lst

# Process the SE: get all VO users having files there
touch $LFCBROWSESE_OUTPUT
echo -n "# Starting LFCBrowseSE at " >> $LFCBROWSESE_OUTPUT
date "+%Y-%m-%d-%H:%M:%S" >> $LFCBROWSESE_OUTPUT
$LFCBROWSESE $SEHOSTNAME --vo $VO --summary 2>&1 >> $LFCBROWSESE_OUTPUT
echo -n "# LFCBrowseSE completed at " >> $LFCBROWSESE_OUTPUT
date "+%Y-%m-%d-%H:%M:%S" >> $LFCBROWSESE_OUTPUT

# Get the current list of users from the VOMS server
VOMS_USERS=$WDIR/voms-list-users.txt
if test ! -f $VOMS_USERS; then
  voms-admin --vo=$VO --host $VOMS_HOST --port $VOMS_PORT list-users > $VOMS_USERS
fi

# For each user with more than 1GB, get his email address from the VOMS
RESULT=$WDIR/$SEHOSTNAME.users
NOTFOUND=$WDIR/$SEHOSTNAME.notfound
awk -f parse-lfcbrowsese.awk $LFCBROWSESE_OUTPUT | while read LINE ; do
  dn=`echo $LINE | cut -d"|" -f1`
  used=`echo $LINE | cut -d"|" -f2`

  voms_user=`grep "$dn" $VOMS_USERS`
  if test $? -eq 0; then
    # Get the user's email address
    echo -n "$dn|$used|$email"  >> $RESULT
    echo $voms_user | awk '{ print gensub("^.+ - ([^ ]+@[^ ]+)$", "\\1", 1); }' >> $RESULT
  else
    echo "$dn" >> $NOTFOUND
  fi

done
