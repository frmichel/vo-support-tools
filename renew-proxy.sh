#!/bin/bash
# This script helps is intended to be run by a cron job, like:
# 0 0,8,16 * * * /path/biomed-support-tools/renew-proxy.sh

. /etc/profile
export PATH=/opt/lcg/bin/lcg-infosites/:$PATH
export VO_SUPPORT_TOOLS=/home/fmichel/biomed-support-tools/
export HOME=/home/fmichel

# Make sure file .globus/proxy_pass.txt is private! (rights 600)
voms-proxy-init -q --voms biomed -pwstdin < $HOME/.globus/proxy_pass.txt

