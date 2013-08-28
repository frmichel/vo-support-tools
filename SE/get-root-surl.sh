#!/bin/bash
# This script lists, for all SEs supporting a VO, the SURL to the storage space dedicated to that VO.
# It queries the top BDII for VOInfo objects to get the SE hostname and VO-specific path, and the
# GlueService objects to get the port on which SRMv2 service is supported.
# Then it builds the URL as srm://<hostname>:<port>/<path>
#
# Author: F. Michel, CNRS I3S

help()
{
  echo
  echo "$0 script lists, for all SEs supporting a VO, the SURL to the storage space dedicated to that VO.
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>]"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  -h, --help: display this help"
  echo
  exit 1
}

# Set the default VO to register files
VO=biomed

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    -h | --help ) help;;
  esac
  shift
done

LDAPOPT="-x -LLL -s sub -H ldap://cclcgtopbdii01.in2p3.fr:2170 -b mds-vo-name=local,o=grid"

# List the hostnames of the SEs that support the VO
SEs=`ldapsearch $LDAPOPT "(&(objectclass=GlueVOInfo)(GlueVOInfoAccessControlBaseRule=*${VO}*))" GlueChunkKey | sort | uniq | awk --field-separator='=' '/^GlueChunkKey: GlueSEUniqueID/ {print $2} {next}'`

for hostname in $SEs; do
    # Get the path of the space(s) reserved for the VO, from VOInfo Glue objects.
    # If the VO is not supported by this SE, the result will be empty
    # There may be more than one VOInfo declared for the VO, using the same or different paths
    paths=`ldapsearch $LDAPOPT "(&(objectclass=GlueVOInfo)(GlueChunkKey=GlueSEUniqueID=${hostname})(GlueVOInfoAccessControlBaseRule=*${VO}*))" GlueVOInfoPath | sort | uniq | awk '/^GlueVOInfoPath/ {print $2} {next}'`
    if test -z "$paths"; then
        echo "*** $hostname: error, no path declared for VO $VO."
        continue
    fi 

    # Find the port on which SRMv2 is available (generally 8444 for Storm SEs, 8446 for DPM SEs.
    # It can happen (se.scope.unina.it) that 2 service endpoints be declared on the same SE with 2 different hostname.
    # To avoid this: we grep the hostname of the SE.
    # Still, in case we would have the same hostname but several ports, we only keep the first port (head -n1)
    ports=`ldapsearch $LDAPOPT  "(&(ObjectClass=GlueService)(GlueServiceUniqueID=*${hostname}*)(|(GlueServiceAccessControlBaseRule=*${VO}*)(GlueServiceAccessControlRule=${VO}))(GlueServiceType=SRM)(GlueServiceVersion=2*))" GlueServiceUniqueID | grep "/$hostname" | awk 'match($0, /^GlueServiceUniqueID.+:([0-9]+)/, m) {print m[1]}' | head -n1`
    if test -z "$ports"; then
        echo "*** $hostname: SRMv2 not supported for VO $VO."
        continue
    fi 

    for path in $paths; do
        for port in $ports; do
            surl=srm://${hostname}:${port}${path}
            echo "-----------------------------------------------------------------------------------"
            echo "$surl"
            # srmls $surl
        done
    done
done  

