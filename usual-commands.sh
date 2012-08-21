#!/bin/bash

# VOMS commands
VOMS_HOST=voms-biomed.in2p3.fr
VOMS_PORT=8443
VO=biomed

voms-admin --vo=$VO --host $VOMS_HOST --port $VOMS_PORT list-users
voms-admin --vo=$VO --host $VOMS_HOST --port $VOMS_PORT list-cas
voms-admin --vo=$VO --host $VOMS_HOST --port $VOMS_PORT --nousercert get-certificates '/O=GRID-FR/C=FR/O=CNRS/OU=I3S/CN=Franck Michel' '/C=FR/O=CNRS/CN=GRID2-FR'
voms-admin --vo=biomed --host voms-biomed.in2p3.fr --port 8443 --nousercert list-user-attributes '/O=GRID-FR/C=FR/O=CNRS/OU=I3S/CN=Franck Michel' '/C=FR/O=CNRS/CN=GRID2-FR'

# Add a member to the biomed support team
voms-admin --vo=$VO --host $VOMS_HOST --port $VOMS_PORT --nousercert add-member /biomed/team "/O=GRID-FR/C=FR/O=CNRS/OU=IPHC/CN=Jerome Pansanel" "/C=FR/O=CNRS/CN=GRID2-FR"


./LFCBrowseSE egee2.irb.hr --vo biomed --dn --summary


# List CEs hostnames from lcg-infosites
lcg-infosites --vo biomed ce -v 1 | awk -F ":" '{ print $1 }' | sort | uniq 

# List WMSs hostnames from lcg-infosites
lcg-infosites --vo biomed wms | awk -F "/" '{ print $3 }' | awk -F ":" '{ print $1 }' | sort | uniq

# List SEs hostnames from lcg-infosites
lcg-infosites --vo biomed se | egrep -v 'Avail Space|-----' | awk '{print $4}' | sort | uniq

# Requête GGUS pour avoir un fichier CSV avec les tickets: TEAM, VO biomed, créés entre 01/06/11 et 31/05/2012, tous états, notified site = INFN-BARI
https://ggus.eu/ws/ticket_search.php?show_columns_check[]=REQUEST_ID&show_columns_check[]=TICKET_TYPE&show_columns_check[]=AFFECTED_SITE&show_columns_check[]=STATUS&show_columns_check[]=DATE_OF_CREATION&show_columns_check[]=LAST_UPDATE&show_columns_check[]=SUBJECT&ticket=&supportunit=all&vo=biomed&user=&keyword=&involvedsupporter=&assignto=&affectedsite=INFN-BARI&specattrib=9&status=all&priority=all&typeofproblem=all&mouarea=&timeframe=any&radiotf=2&from_date=01+Jun+2011&to_date=31+May+2012&untouched_date=&orderticketsby=GHD_INT_REQUEST_ID&orderhow=descending

