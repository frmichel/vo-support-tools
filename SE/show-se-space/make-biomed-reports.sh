#!/bin/bash
# This script allows to run the show-se-space.sh script from a cron job, like:
# */10 * * * * /path/biomed-support-tools/SE/show-se-space/make-reports.sh >> /tmp/show-se-space.log

. /etc/profile
export PATH=/opt/lcg/bin/lcg-infosites/:$PATH
export VO_SUPPORT_TOOLS=/home/fmichel/biomed-support-tools
SHOW_SE_SPACE=$VO_SUPPORT_TOOLS/SE/show-se-space

export HOME=/home/fmichel

date "+%Y-%m-%d %H:%M:%S %Z"
$SHOW_SE_SPACE/show-se-space.sh --sort avail --max 15 --no-sum > $HOME/public_html/biomed-top-most-loaded-se.txt
$SHOW_SE_SPACE/show-se-space.sh --sort avail --reverse --max 20 --no-sum > $HOME/public_html/biomed-top-least-loaded-se.txt
$SHOW_SE_SPACE/show-se-space.sh --sort %used --reverse > $HOME/public_html/biomed-se-status.txt

