#!/bin/bash
# This script is made to be run by a cron in order to regularly update the status of SEs
# supporting biomed.

. /etc/profile
export PATH=/opt/lcg/bin/lcg-infosites/:$PATH

export HOME=/home/fmichel

# Check environment
if test -z "$VO_SUPPORT_TOOLS"; then
    echo "Please set variable \$VO_SUPPORT_TOOLS before calling $0."
    exit 1
fi
SHOW_SE_SPACE=$VO_SUPPORT_TOOLS/show-se-space

date "+%Y-%m-%d %H:%M:%S %Z"
$SHOW_SE_SPACE/show-se-space.sh --sort avail --max 15 --no-sum > $HOME/public_html/biomed-top-most-loaded-se.txt
$SHOW_SE_SPACE/show-se-space.sh --sort avail --reverse --max 20 --no-sum > $HOME/public_html/biomed-top-least-loaded-se.txt
$SHOW_SE_SPACE/show-se-space.sh --sort %used --reverse > $HOME/public_html/biomed-se-status.txt

