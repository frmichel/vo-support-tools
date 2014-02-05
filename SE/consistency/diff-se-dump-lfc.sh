#!/bin/bash
# This script looks for differences between and SE dump and an LFC dump in order to detect zombie files (dark data) on SE,
# and ghost files (lost entries on the LFC).
# It takes as input a dump of the DPM SE obtained with command:
#       dpns-ls -lR <se_hostname>:/dpm/<domain_name>/home/<vo_name>
# and a dump of the LFC obtained with the LFCBrowseSE tool:
#       LFCBrowseSE <se_hostname> --vo <vo_name> --sfn
# It produces 3 output files:
# - <se_hostname>_lfc_ghosts: SURLs of files only registered in the LFC (ghosts, aka. lost files)
# - <se_hostname>_se_zombies: SURLs of files only registered in the SE (zombies, aka. dark data)
# - <se_hostname>_common: SURLs of files found on both the SE and the LFC
#
# Only zombie files older than 6 months (by default, can be changed with option --older-than) are listed.
#
# Author: F. Michel, CNRS I3S

help()
{
  echo
  echo "This script looks for differences between an SE dump and an LFC dump. It lists:"
  echo "- zombie files (aka. dark data) on the SE, i.e. files present on a DPM storage element but not listed in the catalog,"
  echo "- ghost entries (aka. lost data) on the LFC, i.e. entries in the catalog with no more physical replica on the SE."
  echo "It produces 3 output files:"
  echo "- <se_hostname>_lfc_ghosts: SURLs of files only registered in the LFC (ghosts, aka. lost files)"
  echo "- <se_hostname>_se_zombies: SURLs of files only registered in the SE (zombies, aka. dark data)"
  echo "- <se_hostname>_common: SURLs of files found on both the SE and the LFC"
  echo "Only zombie files older than 6 months (by default, can be changed with option --older-than) are listed."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [-s|--silent] [--older-than <age>] --se <SE hostname> --se-dump <file name> --lfc-dump <file name>"
  echo
  echo "  --se <SE hostname>: the storage element host name"
  echo
  echo "  --older-than <age>: only files older than <age> months are listed in <se_hostname>_se_zombies."
  echo "        Defaults to 6 months."
  echo
  echo "  --se-dump <filename>: dump of the DPM SE obtained with command:"
  echo "        dpns-ls -lR <se_hostname>:/dpm/<domain_name>/home/<vo_name>"
  echo
  echo "  --lfc-dump <filename>: dump of the LFC obtained with the LFCBrowseSE tool:"
  echo "        LFCBrowseSE <se_hostname> --vo <vo_name> --sfn"
  echo
  echo "  --output-dir <directory>: directory where to write output files."
  echo 
  echo "  -h, --help: display this help"
  echo
  echo "  -s, --silence: be as silent as possible"
  echo
  echo "Call example:"
  echo "   ./diff-dpm-lfc.sh --se gridse.ilc.cnr.it \ "
  echo "                     --older-than 6 \ "
  echo "                     --se-dump gridse.ilc.cnr.it.dpns-ls-lR \ "
  echo "                     --lfc-dump gridse.ilc.cnr.it.lfcbrowsese-sfn"
  echo
  exit 1
}

# Set to true to skip the convertion into SURLs (time consuming). 
# To use when the file is already present in the local directory.
CONVERT_SE_DUMP=true

# ----------------------------------------------------------------------------------------------------
# Check parameters and set environment variables
# ----------------------------------------------------------------------------------------------------

AGE=6		# Default minimum age of zombies to take into account
INPUT_LFC_DUMP=
INPUT_SE_DUMP=
OUTPUT_DIR=
SE_HOSTNAME=
SILENT=

while [ ! -z "$1" ]
do
  case "$1" in
    --se ) SE_HOSTNAME=$2; shift;;
    --older-than ) AGE=$2; shift;;
    --lfc-dump ) INPUT_LFC_DUMP=$2; shift;;
    --se-dump ) INPUT_SE_DUMP=$2; shift;;
    --output-dir ) OUTPUT_DIR=$2; shift;;
    -s | --silent ) SILENT=true;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

if test -z "$SE_HOSTNAME" ; then help; fi
if test -z "$INPUT_LFC_DUMP" ; then help; fi
if test -z "$INPUT_SE_DUMP" ; then help; fi
if test -z "$OUTPUT_DIR"; then help; fi

OUTPUT_LFC_GHOSTS=${SE_HOSTNAME}.output_lfc_lost_files
OUTPUT_SE_ZOMBIES=${SE_HOSTNAME}.output_se_dark_data
OUTPUT_COMMON=${SE_HOSTNAME}.output_common
INPUT_SE_DUMP_SURLS=${SE_HOSTNAME}_se_dump_surls

# Files older than $AGE months are considered as zombies. Others are ignored.
LIMIT_DATE=`date --date="$AGE months ago" "+%Y-%m-%d"`
LIMIT_DATE_TS=`date --date="$AGE months ago" "+%s"`

if test -z "$SILENT"; then
  NOW=`date "+%Y-%m-%d %H:%M:%S"`
  echo "--------------------------------------------"
  echo "Start $0: $NOW"
  echo "--------------------------------------------"
  echo "Output file for SE zombies: $OUTPUT_SE_ZOMBIES"
  echo "Output file for LFC ghosts: $OUTPUT_LFC_GHOSTS"
  echo "Output file for entries found in LFC and SE: $OUTPUT_COMMON"
  echo "Zombies modified after $LIMIT_DATE will be ignored."
  echo "--------------------------------------------"
fi

# ----------------------------------------------------------------------------------------------------
#--- Convert the SE dump file into a file with only SURLs and dates formated as YYYY-MM-DD
# ----------------------------------------------------------------------------------------------------

if test "$CONVERT_SE_DUMP" = "true"; then

    echo -n "" > $OUTPUT_DIR/$INPUT_SE_DUMP_SURLS
    
    if test -z "$SILENT"; then
	echo "Building the list of SURLs from file ${INPUT_SE_DUMP}..."
    fi

    # Convert the gfal2 dump output to format YYYY-MM-DD SURL lines
    # The selected date is the last modification date as creation 
    # date may be wrong for gsiftp protocol
    grep ^- $INPUT_SE_DUMP | cut -d ' ' -f 3,5 | sed 's/:84[0-9][0-9]//g' > $OUTPUT_DIR/$INPUT_SE_DUMP_SURLS

    if test -z "$SILENT"; then
	echo "Found `wc -l $OUTPUT_DIR/$INPUT_SE_DUMP_SURLS | awk -- '{print $1}'` SURLs in input file $INPUT_SE_DUMP."
    fi

fi
# ----------------------------------------------------------------------------------------------------
#--- Check zombie files: loop on all SURLs in the SE dump, and search each one in the LFC dump
# ----------------------------------------------------------------------------------------------------

if test -z "$SILENT"; then
  echo -n "Looking for SE zombie files... "
fi

echo -n "" > $OUTPUT_DIR/$OUTPUT_SE_ZOMBIES
cat $OUTPUT_DIR/$INPUT_SE_DUMP_SURLS | while read LINE; do
  FILEDATE=`echo $LINE | awk '{print $1}'`
  FILEDATE_TS=`date --date $FILEDATE "+%s"`
  SURL=`echo $LINE | awk '{print $2}'`

  # Check if that file is older than $AGE months. If not it is ignored.
  if ((FILEDATE_TS < LIMIT_DATE_TS)); then
    # Check if that SURL is also in the LFC dump
    if ! grep --silent $SURL $INPUT_LFC_DUMP; then
      echo $SURL >> $OUTPUT_DIR/$OUTPUT_SE_ZOMBIES
    fi
  fi
done

if test -z "$SILENT"; then
  echo "Found `wc -l $OUTPUT_DIR/$OUTPUT_SE_ZOMBIES | awk -- '{print $1}'` zombie files on SE."
fi

# ----------------------------------------------------------------------------------------------------
#--- Check LFC ghost entries: loop on all files listed in the LFC dump, and search each one in the SE dump
# ----------------------------------------------------------------------------------------------------

if test -z "$SILENT"; then
  echo -n "Looking for LFC ghost entries... "
fi

# Loop on lines, skip empty lines and lines starting with "Progress" or "Processing". 
# Keep only second word on the line ($2) => the SURL
echo -n "" > $OUTPUT_DIR/$OUTPUT_LFC_GHOSTS
echo -n "" >  $OUTPUT_DIR/${OUTPUT_COMMON}
cat $INPUT_LFC_DUMP | awk -- '/^$/{next} /^Pro/{next} {print $2}' | while read SURL; do

  # Check if that SURL is also in the SE dump
  if grep --silent $SURL $OUTPUT_DIR/$INPUT_SE_DUMP_SURLS; then
    echo $SURL >> $OUTPUT_DIR/${OUTPUT_COMMON}
  else
    echo $SURL >> $OUTPUT_DIR/$OUTPUT_LFC_GHOSTS
  fi
done

if test -z "$SILENT"; then
  echo "Found `wc -l $OUTPUT_DIR/$OUTPUT_LFC_GHOSTS | awk -- '{print $1}'` ghost entries in LFC."
  echo "Found `wc -l $OUTPUT_DIR/$OUTPUT_COMMON | awk -- '{print $1}'` files common to SE and LFC."
fi

NB_DARK_DATA=`wc -l $OUTPUT_DIR/$OUTPUT_SE_ZOMBIES | cut -d ' ' -f1`
NB_LOST_FILES=`wc -l $OUTPUT_DIR/$OUTPUT_LFC_GHOSTS | cut -d ' ' -f1`
NB_COMMON=`wc -l $OUTPUT_DIR/$OUTPUT_COMMON | cut -d ' ' -f1`
NB_FILES_TOTAL_LFC=$(($NB_LOST_FILES+$NB_COMMON))
NB_FILES_TOTAL_SE=$(($NB_DARK_DATA+$NB_COMMON))
PERCENT_LOST_FILES=
PERCENT_DARK_DATA=

if [ $NB_FILES_TOTAL_LFC -gt 0 ]; then
    PERCENT_LOST_FILES=$(($NB_LOST_FILES*100/$NB_FILES_TOTAL_LFC))
else
    PERCENT_LOST_FILES='N/A'
fi

if [ $NB_FILES_TOTAL_SE -gt 0 ]; then
    PERCENT_DARK_DATA=$(($NB_DARK_DATA*100/$NB_FILES_TOTAL_SE))
else
    PERCENT_DARK_DATA='N/A'
fi

echo "<checkResult><hostname>$SE_HOSTNAME</hostname><darkData>$NB_DARK_DATA</darkData><percentDarkData>$PERCENT_DARK_DATA</percentDarkData><lostFiles>$NB_LOST_FILES</lostFiles><percentLostFiles>$PERCENT_LOST_FILES</percentLostFiles></checkResult>" > $OUTPUT_DIR/${SE_HOSTNAME}_check_result.xml


if test -z "$SILENT"; then
  NOW=`date "+%Y-%m-%d %H:%M:%S"`
  echo "--------------------------------------------"
  echo "Exit $0: $NOW"
  echo "--------------------------------------------"
fi

exit 0

