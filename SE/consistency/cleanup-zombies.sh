#!/bin/bash
# This script deletes files from Storage Elements using their SURL formated as
# srm://<SE_hostname>/.../<file_name>
# It is used in particular to remove zombie files (dark data) from DPM,
# identified by script diff-dpm-lfc.sh.

help()
{
  echo
  echo "This script deletes files from Storage Elements using their SURL formated as"
  echo "    srm://<SE_hostname>/.../<file_name>."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [-s|--silent] [--vo <VO>] --surls <filename>"
  echo
  echo "  -s, --silence: be as silent as possible"
  echo
  echo "  -h, --help: display this help"
  echo
  echo "  --vo <VO>: the Virtual Organisation file owners belong to. Defaults to biomed."
  echo
  echo "  --surls <filename>: file containing the SURLs of file to delete"
  echo
  echo "Call example:"
  echo "   ./cleanup-zombies.sh --vo biomed --surls gridse.ilc.cnr.it_zombie_files "
  echo
  exit 1
}


# Set the default VO
VO=biomed

# Set commands lcg-del verbose by default
VERBOSE=-v

SILENT=
SURLS=

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
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

if test -z "$SILENT"; then
  NOW=`date "+%Y-%m-%d %H:%M:%S"`
  echo "--------------------------------------------"
  echo "Start $0: $NOW"
  echo "--------------------------------------------"
  echo "VO: $VO"
  echo "LCG_GFAL_INFOSYS: $LCG_GFAL_INFOSYS"
  echo "--------------------------------------------"
fi

# Delete the zombies files
cat $SURLS | while read SURL; do
  lcg-del --nolfc $VERBOSE --vo $VO --connect-timeout 30 --sendreceive-timeout 900 --bdii-timeout 30 --srm-timeout 300 $SURL
  if test $? -ne 0; then
    echo "Could not delete $SURL."
  fi
done

if test -z "$SILENT"; then
  NOW=`date "+%Y-%m-%d %H:%M:%S"`
  echo "--------------------------------------------"
  echo "Exit $0 - $NOW"
  echo "--------------------------------------------"
fi
