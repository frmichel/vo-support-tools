#!/bin/bash
# Author: F. Michel, CNRS I3S, biomed VO support
#
# Customize file test_register.sh with appropriate SE, and this script
# with the appropriate WMS if needed.

WMS=https://graspol.nikhef.nl:7443/glite_wms_wmproxy_server 

help()
{
  echo
  echo "$0 runs a job on one of the queues of the CE given by its hostname. The job"
  echo "registers a file on an SE."
  echo "The jobid is appended into file ./jobids."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 <CE-hostname>"
  echo
  exit 1
}

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    -h | --help ) help;;
    *) CEHOSTNAME=$1;;
  esac
  shift
done

if test -z "$CEHOSTNAME" ; then
    help
fi

#--- Get one job queue of that CE
QUEUE=`lcg-infosites ce | grep $CEHOSTNAME | head -n1 | cut -f6`
if test -z "$QUEUE"; then
  echo "No such CE found in the BDII."
  exit 0
fi

#--- Submit the job
echo "Using queue $QUEUE."
OUTPUT=/tmp/jobsubmit_$$.output
set -xe
glite-wms-job-submit -a -e $WMS -r $QUEUE $VO_SUPPORT_TOOLS/CE/test_register.jdl > $OUTPUT
set +xe

#--- Save the job id
echo -n "$CEHOSTNAME " >> jobids
cat $OUTPUT  | egrep "^https"  >> jobids

#--- Cleaning up
rm $OUTPUT
rm -f RECV.log SENT.log TEST.log

exit 0

