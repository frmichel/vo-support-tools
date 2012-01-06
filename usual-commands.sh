#!/bin/bash

# VOMS commands
voms-admin --vo=biomed --host voms-biomed.in2p3.fr --port 8443 list-users
voms-admin --vo=biomed --host  voms-biomed.in2p3.fr --port 8443 list-cas
voms-admin --vo=biomed --host voms-biomed.in2p3.fr --port 8443 --nousercert get-certificates '/O=GRID-FR/C=FR/O=CNRS/OU=I3S/CN=Franck Michel' '/C=FR/O=CNRS/CN=GRID2-FR'
voms-admin --vo=biomed --host voms-biomed.in2p3.fr --port 8443 --nousercert list-user-attributes '/O=GRID-FR/C=FR/O=CNRS/OU=I3S/CN=Franck Michel' '/C=FR/O=CNRS/CN=GRID2-FR'
				
./LFCBrowseSE egee2.irb.hr --vo biomed --dn --summary

# List CEs hostnames from lcg-infosites
lcg-infosites --vo biomed ce -v 1 | awk -F ":" '{ print $1 }' | sort | uniq 

# List WMSs hostnames from lcg-infosites
lcg-infosites --vo biomed wms | awk -F "/" '{ print $3 }' | awk -F ":" '{ print $1 }' | sort | uniq

# List SEs hostnames from lcg-infosites
lcg-infosites --vo biomed se | egrep -v 'Avail Space|-----' | awk '{print $4}' | sort | uniq
