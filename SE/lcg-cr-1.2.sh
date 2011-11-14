#!/bin/bash
# lcg-cr.sh, v1.2
# Author: Initial version by Univertisy of Valencia. 
#         Modified by F. Michel, CNRS I3S, biomed VO support
#
# This tool registers a file on an SE (lcg-cr), and deletes that file (lcg-del) afterwards if it worked. 
# It is intended to help daily work for support team of the biomed VO.
#
# ChangeLog:
# 1.0: initial version from Univertisy of Valencia
# 1.1:
#   - Fix shebang
#   - Fix line-breaks
#   - Fix error messages
#   - Don't over-engineer `set -e`
# 1.2:
#   - Add options -h, --vo, and --silent to reuse it easier in loops to monitor all SEs

help()
{
  echo
  echo "$0 registers (lcg-cr) a small file on the given SE and removes it."
  echo "The LFC_HOME variable must be set prior to calling $0."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] [--silent] <SE-hostname>"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  -s, --silent: be as much as possible NOT verbose"
  echo
  echo "  -h, --help: display this help"
  echo
  exit 1
}
# Set the default VO to register files
VO=biomed

# Set commands lcg-cr and lcg-del verbose by default
VERBOSE=-v

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    -s | --silent ) 
        SILENT=true
        VERBOSE=
        ;;
    -h | --help ) help;;
	*) SEHOSTNAME=$1;;
  esac
  shift
done

if test -z "$SEHOSTNAME" ; then
    help
fi

if test -z "$LFC_HOME"; then
	echo "Please set variable LFC_HOME before calling $0, e.g. export LFC_HOME=/grid/biomed/yourhomedir"
	exit 1
fi

if test -z "$SILENT"; then
	echo "LCG_GFAL_INFOSYS: $LCG_GFAL_INFOSYS"
	echo "LFC_HOST: $LFC_HOST"
	echo "LFC_HOME: $LFC_HOME"
	echo "--------------------------------------------"
fi

filename=shift_`date "+%s_%N"`.txt
date > /tmp/$filename
if test -z "$SILENT"; then
	echo "--- Registering file $filename on SE $1..."
fi

#--- Register a file on the SE
if test -z "$SILENT"; then
	set -xe
fi
lcg-cr $VERBOSE --connect-timeout 30 --sendreceive-timeout 900 --bdii-timeout 30 --srm-timeout 300 --vo biomed file:///tmp/$filename -l lfn:$LFC_HOME/$filename -d $SEHOSTNAME 2>&1
if test -z "$SILENT"; then
	set +xe
fi

#--- Delete the file previsouly registered on the SE
if test -z "$SILENT"; then
	echo "--------------------------------------------"
	echo "--- Deleting file $filename from SE $1..."
fi
if test -z "$SILENT"; then
	set -xe
fi
lcg-del $VERBOSE -a --vo biomed lfn:$LFC_HOME/$filename  2>&1
if test -z "$SILENT"; then
	set +xe
fi

#--- Cleaning up
rm /tmp/$filename
rm RECV.log SENT.log TEST.log

exit 0

