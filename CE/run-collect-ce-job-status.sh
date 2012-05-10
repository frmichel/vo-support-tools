#!/bin/bash

NOW=`date "+%Y%m%d-%H%M%S"`
/home/fmichel/biomed-support-tools/CE/ce-global-job-status.py > /home/fmichel/public_html/monitor-ce/${NOW}.csv

