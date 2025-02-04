#!/bin/bash
# This script looks for differences between an SE dump and an LFC dump in order to detect zombie files (dark data) on SE,
# and ghost files (lost entries on the LFC).
#
# It takes as input:
# 1. a dump of the SE obtained from a site admin. Two different formats have been noticed so far, 
#    named after the site that first sent that type of dump:
#  - The Pisa-style dump that consits of one line per directory, then one line for each file
#    within the dirtectory, like this:
#       ./026a272d-5310-4d15-9d72-4f6b6231ea5d/persistent:
#       -rw-rwx---+ 1 storm storm    232381 Mar  5 15:18 1425565082015_b8fad9d2-d36d
#    Caution: the dump can be made like above with related paths, or with absolute paths.
#    Check that the paths are exactly like the example, that is relative.
#  - The Roma-style dump with one line per file, like this:
#       1889    Nov 15 2011      293a2edb-8c/tmp/132135307686717f186b3bc48.tar
# 2. and a dump of the LFC obtained with the LFCBrowseSE tool:
#       LFCBrowseSE <se_hostname> --vo <vo_name> --sfn
#
# It produces 3 output files:
# - <se_hostname>_lfc_ghosts: SURLs of files only registered in the LFC (ghosts, aka. lost files)
# - <se_hostname>_se_zombies: SURLs of files only registered in the SE (zombies, aka. dark data)
# - <se_hostname>_common: SURLs of files found on both the SE and the LFC
#
# By default only dark data files older than 12 months are listed.

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
  echo "  --pisa-style: the dump consits of one line per directory then one line for each file "
  echo "                within the dirtectory (exclusive with --roma-style)"
  echo
  echo "  --roma-style: the dump consits of one line per file (exclusive with --pisa-style)"
  echo
  echo "  --se <SE hostname>: the storage element host name"
  echo
  echo "  --srm-url <srmUrl>: The SRM url to of the SE. Mandatory."
  echo
  echo "  --older-than <age>: only files older than <age> months are listed in <se_hostname>_se_zombies."
  echo "        Defaults to 12 months."
  echo
  echo "  --se-dump <filename>: dump of the SE obtained from a site admin. That consists of one line"
  echo "                        per directory, then one line for each file within the dirtectory"
  echo
  echo "  --lfc-dump <filename>: dump of the LFC obtained with the LFCBrowseSE tool:"
  echo "        LFCBrowseSE <se_hostname> --vo <vo_name> --sfn"
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
  echo "   ./diff-se-dump-lfc.sh --se stormfe1.pi.infn.it \ "
  echo "                     --srm-url srm://stormfe1.pi.infn.it:8444/biomed \ "
  echo "                     --older-than 6 \ "
  echo "                     --se-dump stormfe1.pi.infn.it_dump_se.txt \ "
  echo "                     --lfc-dump stormfe1.pi.infn.it_dump_lfc.txt \ "
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
DUMP_STYLE="PISA"

while [ ! -z "$1" ]
do
  case "$1" in
    --pisa-style ) DUMP_STYLE="PISA";;
    --roma-style ) DUMP_STYLE="ROMA";;
    --se ) SE_HOSTNAME=$2; shift;;
    --older-than ) AGE=$2; shift;;
    --lfc-dump ) INPUT_LFC_DUMP=$2; shift;;
    --se-dump ) INPUT_SE_DUMP=$2; shift;;
    --srm-url ) SRM_URL=$2; shift;;
    --result-dir ) RESDIR=$2; shift;;
    --work-dir ) WDIR=$2; shift;;
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


OUTPUT_LFC_GHOSTS=$RESDIR/${SE_HOSTNAME}.output_lfc_lost_files
OUTPUT_SE_ZOMBIES=$RESDIR/${SE_HOSTNAME}.output_se_dark_data
OUTPUT_COMMON=$RESDIR/${SE_HOSTNAME}.output_common
SE_DUMP_FILES_ONLY=$WDIR/${INPUT_SE_DUMP}_reformatted
LFCDUMPTMP=${INPUT_LFC_DUMP}_reformatted

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
# LFC dump clean-up:
# - remove empty lines and lines with comments, like: Processing... Progress...
# - remove the port number like ":8446" in case it exists.
# ----------------------------------------------------------------------------------------------------
cat $INPUT_LFC_DUMP | awk -- '/^$/{next} /^Pro/{next} {print $2}' | sed 's/:[0-9]\{4\}//g' > $LFCDUMPTMP


# ----------------------------------------------------------------------------------------------------
# Transform the raw SE dump received from the admin into a dump that gives 
# the date and SRM URL of each file.
# ----------------------------------------------------------------------------------------------------

if test -z "$SILENT"; then
    echo "# Building the list of SURLs from file ${INPUT_SE_DUMP}..."
fi

# Remove optional port number from the SRM URL and escape back slashes
SRM_URL_NO_PORT=`echo $SRM_URL | sed 's/:[0-9]\{4\}//g' | sed 's/\//\\\\\//g'`

# Instantiate the awk file to generate the reformated dump
if [[ $DUMP_STYLE == "PISA" ]]; then AWK_TPL=parse-se-dump-pisastyle.awk.tpl; fi
if [[ $DUMP_STYLE == "ROMA" ]]; then AWK_TPL=parse-se-dump-romastyle.awk.tpl; fi

TMP_PARSE_AWK=${INPUT_SE_DUMP}_parse.awk
sed "s/@SRM_URL@/$SRM_URL_NO_PORT/g" $AWK_TPL > $TMP_PARSE_AWK

# Generate the reformated dump
awk -f $TMP_PARSE_AWK $INPUT_SE_DUMP > $SE_DUMP_FILES_ONLY


# Cleanup temp files
rm -f $TMP_PARSE_AWK

# ----------------------------------------------------------------------------------------------------
# --- Display the number of files in LFC dump and the SE dump
# ----------------------------------------------------------------------------------------------------
if test -z "$SILENT"; then
    echo "# Found `wc -l $SE_DUMP_FILES_ONLY | awk -- '{print $1}'` SURLs in input file $INPUT_SE_DUMP."
    echo "# Found `cat $LFCDUMPTMP | wc -l | awk -- '{print $1}'` SURLs in input file $INPUT_LFC_DUMP."
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
    if ! grep --silent $SURL $LFCDUMPTMP; then
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
cat $LFCDUMPTMP | while read SURL; do

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

rm -f $LFCDUMPTMP $SE_DUMP_FILES_ONLY $TMP_PARSE_AWK

exit 0



