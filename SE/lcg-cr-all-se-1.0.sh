#!/bin/bash
# lcg-cr-all-se.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This script is intended to be used in case Nagios is unavailable, to monitor all SEs supporting 
# the biomed VO. The list of SEs is taken from the lcg-infosites command.
# Results are written to files named /tmp/monitor-se/YYYYMMDD-HHMMSS.result.
# It uses the lcg-cr.sh script version > 1.2.

VO=biomed
TMPDIR=/tmp/monitor-se
mkdir -p $TMPDIR

NOW=`date "+%Y%m%d-%H%M%S"`
TMP_LCGINFOSITES=$TMPDIR/$NOW-list-se.txt
RESULT=$TMPDIR/$NOW.result

echo > $RESULT

# Build the list of SEs from lcg-infosites: remove header lines and lines with value "n.a"
lcg-infosites --vo $VO se | egrep -v 'Avail Space|-----' | awk '{print $4}' | sort | uniq > $TMP_LCGINFOSITES

echo "Output written to: $RESULT"

# Run the lcg-cr script on each SE
for SEHOSTNAME in `cat $TMP_LCGINFOSITES`
do
  echo "----------------------------------------------------------- $SEHOSTNAME -----------" | tee -a $RESULT
  ./lcg-cr-1.2.sh --silent $SEHOSTNAME | tee -a $RESULT
done

echo "Removing file $TMP_LCGINFOSITES."
rm -f $TMP_LCGINFOSITES

