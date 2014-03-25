#!/bin/bash
# This script deletes files from Storage Elements using their SURL formated as
# srm://<SE_hostname>/.../<file_name>
# It is used in particular to remove zombie files (dark data) from DPM SEs,
# identified by script diff-dpm-lfc.sh.

help()
{
  echo
  echo "This script deletes files from Storage Elements using their SURL formated as"
  echo "    srm://<SE_hostname>/.../<file_name>."
  echo "SURLs are given in the input file that contains one SURL per line."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [-s|--silent] [--vo <VO>] --se <SE hostname> --surls <filename>"
  echo
  echo "  --vo <VO>: the Virtual Organisation file owners belong to. Defaults to biomed."
  echo
  echo "  --se <SE hostname>: the storage element host name"
  echo
  echo "  --surls <filename>: file containing the SURLs of files to delete, one SURL per line"
  echo
  echo "  -s, --silence: be as silent as possible"
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Call example:"
  echo "   ./cleanup-zombies.sh --vo biomed --surls gridse.ilc.cnr.it_zombie_files "
  echo
  exit 1
}


# ----------------------------------------------------------------------------------------------------
# Check parameters and set environment variables
# ----------------------------------------------------------------------------------------------------

VO=biomed	# Set the default VO
VERBOSE=-v	# Set commands lcg-del verbose by default

SILENT=
SURLS=
SE_HOSTNAME=

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --se ) SE_HOSTNAME=$2; shift;;
    --surls ) SURLS=$2; shift;;
    -s | --silent ) 
        SILENT=true
        VERBOSE=;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

if test -z "$SURLS" ; then help; fi
if test -z "$SE_HOSTNAME" ; then help; fi

if test -z "$SILENT"; then
  NOW=`date "+%Y-%m-%d %H:%M:%S"`
  echo "--------------------------------------------"
  echo "Start $0: $NOW"
  echo "--------------------------------------------"
  echo "VO: $VO"
  echo "LCG_GFAL_INFOSYS: $LCG_GFAL_INFOSYS"
  echo "--------------------------------------------"
  lcg-infosites --vo $VO space | egrep "Reserved|Online|$SE_HOSTNAME"
fi

# ----------------------------------------------------------------------------------------------------
# Delete the files
# ----------------------------------------------------------------------------------------------------

cat $SURLS | head -n 10 | while read SURL; do
  lcg-del --nolfc $VERBOSE --vo $VO --connect-timeout 30 --sendreceive-timeout 900 --bdii-timeout 30 --srm-timeout 300 $SURL 2>&1
  echo "safe mode : scheduling $SURL for deletion"
  if test $? -ne 0; then
    echo "Could not delete $SURL."
  fi
done

if test -z "$SILENT"; then
  NOW=`date "+%Y-%m-%d %H:%M:%S"`
  echo "--------------------------------------------"
  echo "Exiting $0 - $NOW"
  echo "--------------------------------------------"
  lcg-infosites --vo $VO space | egrep "Reserved|Online|$SE_HOSTNAME"
fi

