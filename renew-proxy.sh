#!/bin/bash
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

# Make sure file .globus/proxy_pass.txt is private! (rights 600)
voms-proxy-init -q --voms $VO -pwstdin < $HOME/.globus/proxy_pass_${VO}.txt

