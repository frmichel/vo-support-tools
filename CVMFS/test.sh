#!/bin/bash

function listDir
{
    path=$1
    echo "*** List content of $path"
    if [ -e $path ]; then
        for file in `ls -A $path`; do
           echo $path/$file
        done
    fi
}

echo "*** Starting CVMFS test on `hostname`"
printf "Site: %-21s  WN: %-36s\n" $SITE_NAME `hostname`

echo -n "*** Number of CVMFS packages installed: "
rpm -qa | grep -i cvmfs | wc -l

listDir /cvmfs
listDir /cvmfs/atlas
listDir /cvmfs/atlas.cern.ch
listDir /cvmfs/mice.gridpp.ac.uk
listDir /cvmfs/biomed.gridpp.ac.uk
listDir /cvmfs/biomed.egi.eu

echo "*** ls /cvmfs/biomed.gridpp.ac.uk"
ls -AlF /cvmfs/biomed.gridpp.ac.uk
echo "*** ls /cvmfs/biomed.egi.eu"
ls -AlF /cvmfs/biomed.egi.eu

echo "VO_BIOMED_SW_DIR: $VO_BIOMED_SW_DIR"
echo "*** Done."

