#!/bin/bash

VO=biomed
LISTCE=_celist.txt
JOBIDS=_jobids.txt
rm -f $JOBIDS

# Rereieve all CE supporting the VO
lcg-infosites --vo $VO ce | awk -F' ' '/ComputingElement/ {next;} /--------/{next;} {print $NF}' > $LISTCE

cat $LISTCE | while read ce
do
    echo "*** Submitting job to CE $ce"
    CMD="glite-wms-job-submit -a -o $JOBIDS -r $ce test_ce.jdl"
    echo "$CMD"
    $CMD
done

