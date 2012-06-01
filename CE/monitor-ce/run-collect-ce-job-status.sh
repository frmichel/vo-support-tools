#!/bin/bash

NOW=`date "+%Y%m%d-%H%M%S"`
/home/fmichel/biomed-support-tools/CE/monitor-ce/collect-ce-job-status.py > /home/fmichel/public_html/monitor-ce/${NOW}.csv

