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
$VO_SUPPORT_TOOLS/SE/monitor-se/collect-se-space.py --vo $VO --csv $HOME/public_html/$VO/monitor-se/${NOW}.csv

