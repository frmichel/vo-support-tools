#!/bin/bash
# This script allows to run the show-se-space.sh script from a cron job, like:
# */10 * * * * /path/biomed-support-tools/SE/show-se-space/make-reports.sh >> /tmp/show-se-space.log

. /etc/profile
export PATH=/opt/lcg/bin/lcg-infosites/:$PATH
export VO_SUPPORT_TOOLS=/home/fmichel/biomed-support-tools
SHOW_SE_SPACE=$VO_SUPPORT_TOOLS/SE/show-se-space
TMP_FILE=/tmp/show-se-space/tmp_file

export HOME=/home/fmichel

# Generate the list of SE with downtime of specific status in the GOCDB
$SHOW_SE_SPACE/gocdb-se-status.sh > $TMP_FILE
mv $TMP_FILE $HOME/public_html/gocdb-se-status.txt

date "+%Y-%m-%d %H:%M:%S %Z"
$SHOW_SE_SPACE/show-se-space.sh --sort avail --max 30 --no-sum > $TMP_FILE
mv $TMP_FILE $HOME/public_html/biomed-top-most-loaded-se.txt

$SHOW_SE_SPACE/show-se-space.sh --sort avail --reverse --max 30 --no-sum > $TMP_FILE
mv $TMP_FILE $HOME/public_html/biomed-top-least-loaded-se.txt

$SHOW_SE_SPACE/show-se-space.sh --sort %used --reverse > $TMP_FILE
mv $TMP_FILE $HOME/public_html/biomed-se-status.txt

$SHOW_SE_SPACE/show-se-space.sh --multiples --no-sum > $TMP_FILE
mv $TMP_FILE $HOME/public_html/biomed-se-multiples.txt

