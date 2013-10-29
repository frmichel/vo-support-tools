#!/bin/bash
# This script allows to run the show-se-space.sh script from a cron job, like:
# */10 * * * * . /etc/profile; export VO_SUPPORT_TOOLS=/home/fmichel/biomed-support-tools; $VO_SUPPORT_TOOLS/SE/show-se-space/run-biomed-reports.sh >> /tmp/show-se-space.log
#
# Variable $VO_SUPPORT_TOOLS must be set before running the script.

VO=biomed

. /etc/profile
export PATH=/opt/lcg/bin/lcg-infosites/:$PATH
SHOW_SE_SPACE=$VO_SUPPORT_TOOLS/SE/show-se-space
TMP_FILE=/tmp/$VO/show-se-space/tmp_file_$$

date "+%Y-%m-%d %H:%M:%S %Z"
$SHOW_SE_SPACE/show-se-space.sh --sort avail --max 30 --no-sum > $TMP_FILE
mv $TMP_FILE $HOME/public_html/biomed-top-most-loaded-se.txt

$SHOW_SE_SPACE/show-se-space.sh --sort avail --reverse --max 30 --no-sum > $TMP_FILE
mv $TMP_FILE $HOME/public_html/biomed-top-least-loaded-se.txt

$SHOW_SE_SPACE/show-se-space.sh --sort %used --reverse > $TMP_FILE
mv $TMP_FILE $HOME/public_html/biomed-se-status.txt

$SHOW_SE_SPACE/show-se-space.sh --multiples --no-sum > $TMP_FILE
mv $TMP_FILE $HOME/public_html/biomed-se-multiples.txt
