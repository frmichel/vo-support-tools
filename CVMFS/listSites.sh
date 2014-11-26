#!/bin/bash

rm -f vo_alice.txt vo_atlas.txt vo_mice.txt vo_biomed.txt vo_no_biomed.txt

echo "Listing sites supporting alice"
for fn in `egrep "^/cvmfs/alice.cern.ch" /tmp/jobOutput/*/*.out | cut -d':' -f1 | sort | uniq`
do
    echo -n "$fn - " >> vo_alice.txt
    cat $fn | grep "Site:" >> vo_alice.txt
done

echo "Listing sites supporting atlas"
for fn in `egrep "^/cvmfs/atlas.cern.ch" /tmp/jobOutput/*/*.out | cut -d':' -f1 | sort | uniq`
do
    echo -n "$fn - " >> vo_atlas.txt
    cat $fn | grep "Site:" >> vo_atlas.txt
done

echo "Listing sites supporting mice"
for fn in `egrep "^/cvmfs/mice" /tmp/jobOutput/*/*.out | cut -d':' -f1 | sort | uniq`
do
    echo -n "$fn - " >> vo_mice.txt
    cat $fn | grep "Site:" >> vo_mice.txt
done

echo "Listing sites supporting biomed"
for fn in `egrep "^/cvmfs/biomed.(gridpp.ac.uk|egi.eu)/vip" /tmp/jobOutput/*/*.out | cut -d':' -f1 | sort | uniq`
do
    echo -n "$fn - " >> vo_biomed.txt
    cat $fn | grep "Site:" >> vo_biomed.txt
done

echo "Listing CEs supporting CVMFS but not biomed"
# List all CEs supporting cvmfs
for fn in `egrep "^/cvmfs/" /tmp/jobOutput/*/*.out | cut -d':' -f1 | sort | uniq`
do
    # Among them, list those that do not support biomed
    if ! egrep --silent "^/cvmfs/biomed.(gridpp.ac.uk|egi.eu)" $fn; then
        echo -n "$fn - " >> vo_no_biomed.txt
        cat $fn | grep "Site:" >> vo_no_biomed.txt
    fi
done

nbsites=`ls -l /tmp/jobOutput/*/*.out | wc -l`
nbsites_cvmfs=`grep "^/cvmfs/" /tmp/jobOutput/*/*.out | cut -d':' -f1 | sort | uniq | wc -l`
echo
echo "*** $nbsites_cvmfs CEs support CVMFS out of $nbsites CEs where jobs were successfull."
echo
echo "*** List of sites supporting CVMFS but not biomed:"
cat vo_no_biomed.txt | cut -d' ' -f4 | sort | uniq

