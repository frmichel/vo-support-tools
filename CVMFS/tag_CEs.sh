#!/bin/bash

# Require role lcgadmin:
# voms-proxy-init --voms biomed:/biomed/Role=lcgadmin

VO=biomed
LISTCE=list_CEs_supporting_biomed_and_CVMFS.txt
TAG=VO-biomed-CVMFS
FAILED=$0_failed.log

rm -f $FAILED

cat $LISTCE | while read ce
do
    echo "*** Tagging CE $ce"
    CMD="lcg-tags --verbose --debug --ce $ce --add --vo $VO --tags $TAG"
    $CMD
    if [ $? -ne 0 ]; then
        echo "*** Failed to tag CE $ce."
        echo $ce >> $FAILED
    fi
done

