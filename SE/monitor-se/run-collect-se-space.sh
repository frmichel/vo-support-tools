#!/bin/bash

NOW=`date "+%Y%m%d-%H%M%S"`
/home/fmichel/biomed-support-tools/SE/monitor-se/collect-se-space.py --debug --csv /home/fmichel/public_html/monitor-se/${NOW}.csv

