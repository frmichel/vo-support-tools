#!/bin/bash
# gocdb-se-status.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This tool searches the GOCDB for downtime and status information concerning all SEs supporting biomed.
# It lists only SEs currently in downtime on the standard output.

VO=biomed

mkdir -p /tmp/check-se-downtime
LIST_SE=/tmp/check-se-downtime/list_se.txt

GOCDB_DOWNTIME_URL="https://goc.egi.eu/gocdbpi/private/?method=get_downtime&ongoing_only=yes&topentity="
GOCDB_SERVICE_URL="https://goc.egi.eu/gocdbpi/private/?method=get_service_endpoint&hostname="
GOCDB_RESP=/tmp/check-se-downtime/gocdb-get-downtime.resp

CURL_CMD="curl --silent --insecure --pass `cat $HOME/.globus/proxy_pass.txt` --cert $HOME/.globus/usercert.pem --key $HOME/.globus/userkey.pem --url"

# Get the current list of SEs supporting the VO from the BDII
lcg-infosites --vo $VO space | egrep -v "Reserved|Nearline|[\-]{10}" | egrep -o "[^[:space:]]*$" > $LIST_SE

for SE in `cat $LIST_SE`; do
   SE_STATUS=""

   # Check if the SE is in downtime
   $CURL_CMD "${GOCDB_DOWNTIME_URL}${SE}" > $GOCDB_RESP
   grep --silent --ignore-case "<results></results>" $GOCDB_RESP
   if test $? -eq 1; then
      SE_STATUS="downtime"
   fi

   # Check if the SE is in status "not in production"
   $CURL_CMD "${GOCDB_SERVICE_URL}${SE}" > $GOCDB_RESP
   grep --silent --ignore-case "<IN_PRODUCTION>Y</IN_PRODUCTION>" $GOCDB_RESP
   if test $? -eq 1; then
      if test "$SE_STATUS" != ""; then
         SE_STATUS="$SE_STATUS, not in production"
      else
        SE_STATUS="not in production"
      fi
   fi

   # Check if the SE is in status "not monitored"
   grep --silent --ignore-case "<NODE_MONITORED>Y</NODE_MONITORED>" $GOCDB_RESP
   if test $? -eq 1; then
      if test "$SE_STATUS" != ""; then
         SE_STATUS="$SE_STATUS, not monitored"
      else
        SE_STATUS="not monitored"
      fi
   fi

   if test "$SE_STATUS" != ""; then
      echo "$SE|$SE_STATUS"
   fi
#   echo "$SE"
done

rm -f $LIST_SE
rm -f $GOCDB_RESP

