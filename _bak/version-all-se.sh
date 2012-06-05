#!/bin/bash
# version-all-se.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This script list the SRM implementation and version of all SEs supporting the biomed VO.

VO=biomed
TMPDIR=/tmp/version-all-se
mkdir -p $TMPDIR

NOW=`date "+%Y%m%d-%H%M%S"`
TMP_LCGINFOSITES=$TMPDIR/$NOW-list-se.txt

# Build the list of SEs from lcg-infosites: remove header lines and lines with value "n.a"
lcg-infosites --vo $VO space | egrep -v 'Nearline|Reserved|-----' | awk '{print $8}' | sort | uniq > $TMP_LCGINFOSITES

# Run the ldap request on each SE
for SE in `cat $TMP_LCGINFOSITES`
do
  ldapsearch -x -L -s sub -H ldap://cclcgtopbdii01.in2p3.fr:2170 -b mds-vo-name=local,o=grid "(&(ObjectClass=GlueSE)(GlueSEUniqueID=$SE))" GlueSEUniqueID GlueSEImplementationName GlueSEImplementationVersion | egrep "GlueSEUniqueID:|GlueSEImplementationName:|GlueSEImplementationVersion:" > $TMPDIR/ver_se.tmp
  implNam=`grep "GlueSEImplementationName:" $TMPDIR/ver_se.tmp | awk '{print $2}'` 
  implVer=`grep "GlueSEImplementationVersion:" $TMPDIR/ver_se.tmp| awk '{print $2}'`
  echo "$implNam $implVer"
done

rm -f $TMP_LCGINFOSITES

