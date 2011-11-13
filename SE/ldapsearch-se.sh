#!/bin/bash
# ldapsearch-se.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This tool runs 3 LDAP requests against a top BDII in order to get data describing 
# a SE. Retrieved objects are GlueSE, GlueSA, VOInfo.

TOPBDII=cclcgtopbdii01.in2p3.fr:2170

help()
{
  echo
  echo "$0 runs LDAP requests to retrieve the data related to a given SE: GlueSE, GlueSA, VOInfo"
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [[-b|--bdii] hostname:port] <SE-hostname>"
  echo "       -h|--help : display this help"
  echo "       -b, --bdii : top BDII hostname and port. Defaults to $TOPBDII"
  echo
  exit 1
}

while [ ! -z "$1" ]
do
  case "$1" in
    -b | --bdii ) 
		TOPBDII=$2
		shift
		;;
    -h | --help ) help;;
	*) SEHOSTNAME=$1;;
  esac
  shift
done

if test -z "$SEHOSTNAME"; then
	help
fi

echo "------------------- GlueSE ---------------------"
ldapsearch -x -L -s sub -H ldap://$TOPBDII -b mds-vo-name=local,o=grid "(&(ObjectClass=GlueSE)(GlueSEUniqueID=$SEHOSTNAME))"

echo 
echo "------------------- GlueSA ---------------------"
ldapsearch -x -L -s sub -H ldap://$TOPBDII -b mds-vo-name=local,o=grid "(&(ObjectClass=GlueSA)(GlueChunkKey=GlueSEUniqueID=$SEHOSTNAME)(|(GlueSAAccessControlBaseRule=VO:biomed*)(GlueSAAccessControlBaseRule=biomed*)))"

echo
echo "------------------- VOInfo ---------------------"
ldapsearch -x -L -s sub -H ldap://$TOPBDII -b mds-vo-name=local,o=grid "(&(GlueVOInfoLocalID=biomed*)(GlueChunkKey=GlueSEUniqueID=$SEHOSTNAME))"

