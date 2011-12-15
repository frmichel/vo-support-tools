#!/bin/bash
# This script creates the list of biomed SEs from the BDII, used by global.php to verify the requested SEs.
# It should be set to run regularly in a cronjob, like this:
# 0 3 * * * . /etc/profile; /home/fmichel/biomed-support-tools/SE/se-web-report-gen/make-list-se.sh > /tmp/make-list-se.log

lcg-infosites --vo biomed space | awk '/Reserved|Nearline|--------/ { next; } { print $8; }' | sort | uniq | awk '{ printf "%s ", $0;}' > /home/fmichel/public_html/biomed-list-se.txt

