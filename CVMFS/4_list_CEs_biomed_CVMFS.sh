#!/bin/bash

export ldapsearch='ldapsearch -x -LLL -s sub -H ldap://cclcgtopbdii01.in2p3.fr:2170 -b mds-vo-name=local,o=grid'
export OUTPUT=_CEs_biomed_CVMFS.txt
export TMP=/tmp/$OUTPUT
rm -r $OUTPUT $TMP

# Get the list of sites
SITES=`cat vo_biomed.txt | cut -d' ' -f4 | sort | uniq`
echo "Sites to check: $SITES"

for SITENAME in $SITES
do
    echo "  Site: $SITENAME"
    # Obtenir la liste des GlueClusterUniqueID d'un site
    CLUSTERS=`$ldapsearch "(&(ObjectClass=GlueCluster)(GlueForeignKey=GlueSiteUniqueID=$SITENAME))" GlueClusterUniqueID | grep "^GlueClusterUniqueID" | cut -d" " -f2`
    echo "    Clusters: $CLUSTERS"
    for CLUSTERID in $CLUSTERS
    do
        echo "      Cluster: $CLUSTERID"
        # Obtenir la liste des CEs d'un cluster
        CES=`$ldapsearch "(&(objectclass=GlueCE)(GlueForeignKey=GlueClusterUniqueID=$CLUSTERID)(GlueCEAccessControlBaseRule=VO:${VO}*))" GlueCEInfoHostName | grep "^GlueCEInfoHostName" | cut -d" " -f2`
        for CEID in $CES
        do
            echo "        CE: $CEID"
            echo $CEID >> $TMP
        done
    done
done

# Sort and remove duplicates
cat $TMP | sort | uniq > $OUTPUT

echo
echo "### List of CEs supporting biomed and providing biomed with CVMFS :"
echo
cat $OUTPUT

