#!/bin/bash
# This script is made to be run by a cron in order to regularly update the status of SEs
# supporting biomed.

. /etc/profile

export HOME=/home/fmichel
export CHECKER=$HOME/biomed-support-tools/SE/show-se-space
export PATH=/opt/lcg/bin/lcg-infosites/:$PATH

date "+%Y-%m-%d %H:%M:%S %Z"

cd $CHECKER
./show-se-space.sh --sort avail --max 15 --no-sum > $HOME/public_html/biomed-top-most-loaded-se.txt
./show-se-space.sh --sort avail --reverse --max 20 --no-sum > $HOME/public_html/biomed-top-least-loaded-se.txt
./show-se-space.sh --sort %used --reverse > $HOME/public_html/biomed-se-status.txt

