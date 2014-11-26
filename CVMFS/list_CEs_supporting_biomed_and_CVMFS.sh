#!/bin/bash

export ldapsearch='ldapsearch -x -LLL -s sub -H ldap://cclcgtopbdii01.in2p3.fr:2170 -b mds-vo-name=local,o=grid'
export OUTPUT=/tmp/list_CEs_supporting_biomed_and_CVMFS.txt
rm -r $OUTPUT

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
            echo $CEID >> $OUTPUT
        done
    done
done

# Sort and remove duplicates
cat $OUTPUT | sort | uniq > list_CE_from_sites_supporting_biomed_and_CVMFS.txt

echo
echo "### List of CEs supporting biomed and providing biomed with CVMFS :"
echo
cat list_CE_from_sites_supporting_biomed_and_CVMFS.txt
echo
echo "### Check result in: list_CE_from_sites_supporting_biomed_and_CVMFS.txt"

