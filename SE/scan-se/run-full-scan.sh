#!/bin/bash
# Run a full scan of SEs that is all SE with at least 0% of used space (i.e. all), and users with at least 0GB (i.e. all) of used space
$VO_SUPPORT_TOOLS/SE/scan-se/scan-se.sh --voms-users /tmp/monitor-se/voms-users.txt --work-dir /tmp/monitor-se --result-dir $HOME/public_html/scan-full-se --threshold 0 --user-min-used 0  >> /tmp/monitor-se/scan-full-se.log

