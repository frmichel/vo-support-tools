#!/bin/bash

. $HOME/.bashrc

# Set the default VO
VO=biomed

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
  esac
  shift
done

NOW=`date "+%Y%m%d-%H%M%S"`
$VO_SUPPORT_TOOLS/CE/monitor-ce/collect-ce-job-status.py --vo $VO > $HOME/public_html/$VO/monitor-ce/${NOW}.csv

