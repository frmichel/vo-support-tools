#!/bin/bash
# This script looks for differences between and SE dump and an LFC dump in order to detect zombie files (dark data) on SE,
# and ghost files (lost entries on the LFC).
# It takes as input a dump of the SE obtained either using the dpm-se-files.py:
#       dump-se-files.py --url srm://<se_hostname>/dpm/<domain_name>/home/<vo_name>
# or, for DPM SEs only, with command:
#       dpns-ls -lR <se_hostname>:/dpm/<domain_name>/home/<vo_name>
# and a dump of the LFC obtained with the LFCBrowseSE tool:
#       LFCBrowseSE <se_hostname> --vo <vo_name> --sfn
# It produces 3 output files:
# - <se_hostname>_lfc_ghosts: SURLs of files only registered in the LFC (ghosts, aka. lost files)
# - <se_hostname>_se_zombies: SURLs of files only registered in the SE (zombies, aka. dark data)
# - <se_hostname>_common: SURLs of files found on both the SE and the LFC
#
# By default only dark data files older than 12 months are listed.
#
# Author: F. Michel, CNRS I3S

help()
{
  echo
  echo "This script looks for differences between an SE dump and an LFC dump. It lists:"
  echo "- zombie files (aka. dark data) on the SE, i.e. files present on a storage element but not listed in the catalog,"
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
  echo "        Defaults to 12 months."
  echo
  echo "  --se-dump <filename>: dump of the SE. For DPM SEs, this is possibly obtained with command:"
  echo "        dpns-ls -lR <se_hostname>:/dpm/<domain_name>/home/<vo_name>"
  echo "        dump-se-files.py --url srm://<se_hostname>/dpm/<domain_name>/home/<vo_name>"
  echo
  echo "  --lfc-dump <filename>: dump of the LFC obtained with the LFCBrowseSE tool:"
  echo "        LFCBrowseSE <se_hostname> --vo <vo_name> --sfn"
  echo
  echo "  --srm-url <srm url>: the srm URL of the VO space on the SE. Mandatory."
  echo
  echo "  --access-url <access url>: the access URL to list files on the SE. Mandatory."
  echo "               This may be the same as the srm URL or a URL using another access protocol such as gsiftp."
  echo
  echo "  --work-dir <work directory>: where to store temporary files. Defaults to '.'."
  echo
  echo "  --result-dir <result directory>: where to store result files. Defaults to '.'."
  echo
  echo "  -h, --help: display this help"
  echo
  echo "  -s, --silence: be as silent as possible"
  echo
  echo "Call example:"
  echo "   ./diff-dpm-lfc.sh --se gridse.ilc.cnr.it \ "
  echo "                     --older-than 6 \ "
  echo "                     --se-dump gridse.ilc.cnr.it.dpns-ls-lR \ "
  echo "                     --lfc-dump gridse.ilc.cnr.it.lfcbrowsese-sfn \ "
  echo "                     --srm-url srm://gridse.ilc.cnr.it:8446/dpm/ilc.cnr.it/home/biomed\ "
  echo "                     --access-url gsiftp://gridse.ilc.cnr.it:2811/dpm/ilc.cnr.it/home/biomed"
  echo
  exit 1
}

# ----------------------------------------------------------------------------------------------------
# Check parameters and set environment variables
# ----------------------------------------------------------------------------------------------------

AGE=12		# Default minimum age of zombies to take into account
RESDIR=`pwd`
WDIR=`pwd`
SILENT=
SRM_URL=
GSIFTP_URL=

while [ ! -z "$1" ]
do
  case "$1" in
    --se ) SE_HOSTNAME=$2; shift;;
    --older-than ) AGE=$2; shift;;
    --lfc-dump ) INPUT_LFC_DUMP=$2; shift;;
    --se-dump ) INPUT_SE_DUMP=$2; shift;;
    --result-dir ) RESDIR=$2; shift;;
    --work-dir ) WDIR=$2; shift;;
    --srm-url ) SRM_URL=$2; shift;;
    --access-url ) GSIFTP_URL=$2; shift;;
    -s | --silent ) SILENT=true;;
    -h | --help ) help;;
    * ) echo "Error: unknown option $1."; help;;
  esac
  shift
done

if test -z "$SE_HOSTNAME" ; then echo "Option --se is mandatory."; help; fi
if test -z "$INPUT_LFC_DUMP" ; then echo "Option --lfc-dump is mandatory."; help; fi
if test -z "$INPUT_SE_DUMP" ; then echo "Option --se-dump is mandatory."; help; fi
if test -z "$SRM_URL" ; then echo "Option --srm-url is mandatory."; help; fi
if test -z "$GSIFTP_URL" ; then echo "Option --access-url is mandatory."; help; fi


OUTPUT_LFC_GHOSTS=$RESDIR/${SE_HOSTNAME}.output_lfc_lost_files
OUTPUT_SE_ZOMBIES=$RESDIR/${SE_HOSTNAME}.output_se_dark_data
OUTPUT_COMMON=$RESDIR/${SE_HOSTNAME}.output_common
SE_DUMP_FILES_ONLY=$WDIR/${SE_HOSTNAME}_dump_se_files.txt

# Files older than $AGE months are considered as zombies. Others are ignored.
LIMIT_DATE=`date --date="$AGE months ago" "+%Y-%m-%d"`
LIMIT_DATE_TS=`date --date="$AGE months ago" "+%s"`

if test -z "$SILENT"; then
  NOW=`date "+%Y-%m-%d %H:%M:%S"`
  echo "# --------------------------------------------"
  echo "# $NOW - Starting $(basename $0) for SE ${SE_HOSTNAME}"
  echo "# Output file for SE zombies: $OUTPUT_SE_ZOMBIES"
  echo "# Output file for LFC ghosts: $OUTPUT_LFC_GHOSTS"
  echo "# Output file for entries found in LFC and SE: $OUTPUT_COMMON"
  echo "# Zombies modified after $LIMIT_DATE will be ignored."
  echo "# --------------------------------------------"
fi

# ----------------------------------------------------------------------------------------------------
# Convertion of the SE dump so that URLs be in the same format as in the LFC dump:
# - Remove directories: convert the SE dump file into a file with last modification date and SURLs of files only.
# - The LFC lists URLs in srm://hostname/path (port removed in check-se.sh) while the SE dump lists URLs with
#   possibly another access protocol like gsiftp and the port number.
#   => we convert the URLs of the SE dump so that they can be compared with URLs from the LFC:
#      replace gsiftp://hostname:2811/path with srm://hostname/path
# ----------------------------------------------------------------------------------------------------
if test -z "$SILENT"; then
    echo "# Building the list of SURLs from file ${INPUT_SE_DUMP}..."
fi

# Get the base of gsiftp URL, and escape slash characters (because we will use sed). Expected format: gsiftp:\/\/hostname:port
GSIFTP_URL_BASE=`echo $GSIFTP_URL | grep -o -E "(gsiftp|srm)://.*:[0-9]{4}" | sed 's/\//\\\\\//g'`

# Get the base of srm URL, escape slash characters, remove optional port number. Expected format: srm:\/\/hostname
SRM_URL_BASE=`echo $SRM_URL | grep -o -E srm://.*:[0-9]{4} | sed 's/\//\\\\\//g'`
SRM_URL_BASE_NO_PORT=`echo $SRM_URL_BASE | sed 's/:[0-9]\{4\}//g'`

# In the gfal2 SE dump, keep only lines starting with "-" (files), 
# and replace the gsiftp URL base with the srm URL base (without the port)
echo -n "" > $SE_DUMP_FILES_ONLY
grep ^- $INPUT_SE_DUMP | egrep -v "/\.{1,2}$" | cut -d ' ' -f 3,5 | sed "s/${GSIFTP_URL_BASE}/${SRM_URL_BASE_NO_PORT}/g" > $SE_DUMP_FILES_ONLY


# ----------------------------------------------------------------------------------------------------
# --- Display the number of files in LFC dump and the SE dump
# ----------------------------------------------------------------------------------------------------

if test -z "$SILENT"; then
    echo "# Found `wc -l $SE_DUMP_FILES_ONLY | awk -- '{print $1}'` SURLs in input file $INPUT_SE_DUMP."
    echo "# Found `cat $INPUT_LFC_DUMP | wc -l | awk -- '{print $1}'` SURLs in input file $INPUT_LFC_DUMP."
fi


# ----------------------------------------------------------------------------------------------------
# --- Check zombie files: loop on all SURLs in the SE dump, and search each one in the LFC dump
# ----------------------------------------------------------------------------------------------------

if test -z "$SILENT"; then echo "# Looking for dark data files... "; fi
echo -n "" > $OUTPUT_SE_ZOMBIES

# Loop on all files from the converted SE dump
cat $SE_DUMP_FILES_ONLY | while read LINE; do
  FILEDATE=`echo $LINE | awk '{print $1}'`
  FILEDATE_TS=`date --date $FILEDATE "+%s"`
  SURL=`echo $LINE | awk '{print $2}'`

  # Check if that file is older than $AGE months. If not it is ignored.
  if ((FILEDATE_TS < LIMIT_DATE_TS)); then
    # Check if that SURL is also in the LFC dump
    if ! grep --silent $SURL $INPUT_LFC_DUMP; then
      # Reset the initial URL (that we replaced with the srm URL to be able to do the diff)
      # echo $SURL | sed "s/${SRM_URL_BASE_NO_PORT}/${GSIFTP_URL_BASE}/g" >> $OUTPUT_SE_ZOMBIES
      # or keep the srm URL
      echo $SURL >> $OUTPUT_SE_ZOMBIES
    fi
  fi
done

if test -z "$SILENT"; then
  echo "# Found `wc -l $OUTPUT_SE_ZOMBIES | awk -- '{print $1}'` dark data files on SE."
fi

# ----------------------------------------------------------------------------------------------------
#--- Check LFC ghost entries: loop on all files listed in the LFC dump, and search each one in the SE dump
# ----------------------------------------------------------------------------------------------------

if test -z "$SILENT"; then echo "# Looking for lost files... "; fi

# Loop on lines, keep only second word on the line ($2) => the SURL
echo -n "" > $OUTPUT_LFC_GHOSTS
echo -n "" >  ${OUTPUT_COMMON}
cat $INPUT_LFC_DUMP | while read SURL; do

  # Check if that SURL is also in the SE dump
  if grep --silent $SURL $SE_DUMP_FILES_ONLY; then
    echo $SURL >> ${OUTPUT_COMMON}
  else
    echo $SURL >> $OUTPUT_LFC_GHOSTS
  fi
done

if test -z "$SILENT"; then
  echo "# Found `wc -l $OUTPUT_LFC_GHOSTS | awk -- '{print $1}'` lost file entries in LFC."
  echo "# Found `wc -l $OUTPUT_COMMON | awk -- '{print $1}'` files common to SE and LFC."
fi

# Calculate the percent of zombie and ghost files found
NB_DARK_DATA=`wc -l $OUTPUT_SE_ZOMBIES | cut -d ' ' -f1`
NB_LOST_FILES=`wc -l $OUTPUT_LFC_GHOSTS | cut -d ' ' -f1`
NB_COMMON=`wc -l $OUTPUT_COMMON | cut -d ' ' -f1`
NB_FILES_TOTAL_LFC=$(($NB_LOST_FILES+$NB_COMMON))
NB_FILES_TOTAL_SE=$(($NB_DARK_DATA+$NB_COMMON))
NB_FILES_TOTAL_SE_DUMP=`wc -l $SE_DUMP_FILES_ONLY | cut -d ' ' -f1`

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

# ----------------------------------------------------------------------------------
# Output xml report
# ----------------------------------------------------------------------------------

OUTPUT_FILE=$RESDIR/${SE_HOSTNAME}_check_result.xml
touch $OUTPUT_FILE
echo "<checkResult>" > $OUTPUT_FILE
echo "  <hostname>$SE_HOSTNAME</hostname>" >> $OUTPUT_FILE
echo "  <darkData>$NB_DARK_DATA</darkData>" >> $OUTPUT_FILE
echo "  <percentDarkData>$PERCENT_DARK_DATA</percentDarkData>" >> $OUTPUT_FILE
echo "  <lostFiles>$NB_LOST_FILES</lostFiles>" >> $OUTPUT_FILE
echo "  <percentLostFiles>$PERCENT_LOST_FILES</percentLostFiles>" >> $OUTPUT_FILE
echo "  <nbTotalFilesSEDump>$NB_FILES_TOTAL_SE_DUMP</nbTotalFilesSEDump>" >> $OUTPUT_FILE
echo "</checkResult>" >> $OUTPUT_FILE

if test -z "$SILENT"; then
  NOW=`date "+%Y-%m-%d %H:%M:%S"`
  echo "# --------------------------------------------"
  echo "# $NOW - Exiting $(basename $0)"
fi

exit 0

