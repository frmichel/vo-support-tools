#!/bin/bash
# Generate a proxy certificate with a VO given in parameter using default 
# cert and key files from $HOME/.globus.
# The proxy file name is /tmp/x509_up_${VO}_u$[USERID}, e.g. /tmp/x509up_biomed_u499
#
# This script helps is intended to be run by a cron job, like:
# 0 0,8,16 * * * /path/vo-support-tools/renew-proxy.sh --vo biomed

. /etc/profile
# Set the default VO
VO=biomed

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
  esac
  shift
done

# Make sure file .globus/proxy_pass.txt is private (rights 600)
USERID=`id --user`
PROXY_FILE=/tmp/x509up_${VO}_u${USERID}
voms-proxy-init -quiet -out $PROXY_FILE -voms $VO -pwstdin < $HOME/.globus/proxy_pass_${VO}.txt

