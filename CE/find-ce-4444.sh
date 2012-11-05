#!/bin/bash
#
# Shortcut to the lcg-infosites command for VO biomed, to find out those CEs with
# erroneous number of running or waiting jobs 4444...

NOW=`date "+%Y-%m-%d %H:%M:%S %Z"`

echo "# $NOW. VO: biomed"
echo "#--------------------------------------------------------------------------------"
echo "#   CPU    Free Total Jobs      Running Waiting ComputingElement"
echo "#--------------------------------------------------------------------------------"

lcg-infosites --vo biomed ce | egrep "4444"

