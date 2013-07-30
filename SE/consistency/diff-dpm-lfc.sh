#!/bin/bash
# This script looks for differences between and SE dump and an LFC dump. It lists
# - zombie files (aka. dark data) on the SE, i.e. files present on a DPM storage element but not listed in the catalog,
# - ghost entries (aka. lost data) on the LFC, i.e. entries in the catalog with nomore  physical replica on the SE
# It takes as input a dump of the DPM SE obtained with command:
#	dpns-ls -lR <se_hostname>:/dpm/<domain_name>/home/<vo_name>
# and a dump of the LFC obtained with the LFCBrowseSE tool:
#       LFCBrowseSE <se_hostname> --vo <vo_name> --sfn
# It produces 3 output files:
# - <se_hostname>_lfc_ghosts: SURLs of files only registered in the LFC (ghosts, aka. lost files)
# - <se_hostname>_se_zombies: SURLs of files only registered in the SE (zombies, aka. dark data)
# - <se_hostname>_common: SURLs of files found on both the SE and the LFC
#
# Zombie files are applied are safety minimum age: only files older than 6 months
# (by default, can be changed with option --age) are listed in <se_hostname>_se_zombies.
# Call example:
#    ./diff-dpm-lfc-time.sh --se gridse.ilc.cnr.it \
#                           --age 6 \
#                           --se-dump gridse.ilc.cnr.it.dpns-ls-lR \
#                           --lfc-dump gridse.ilc.cnr.it.lfcbrowsese-sfn

# Set to true to skip the convertion into SURLs (time consuming). 
# To use when the file is already present in the local directory.
CONVERT_SE_DUMP=true

# Default minimum age of zombies to take into account
AGE=6		

INPUT_LFC_DUMP=
INPUT_SE_DUMP=
SE_HOSTNAME=
SILENT=

help()
{
  echo 'Help. To be done...'
  exit 1
}

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --se ) SE_HOSTNAME=$2; shift;;
    --age ) AGE=$2; shift;;
    --lfc-dump ) INPUT_LFC_DUMP=$2; shift;;
    --se-dump ) INPUT_SE_DUMP=$2; shift;;
    -s | --silent ) SILENT=true;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

OUTPUT_LFC_GHOSTS=${SE_HOSTNAME}_lfc_ghosts
OUTPUT_SE_ZOMBIES=${SE_HOSTNAME}_se_zombies
OUTPUT_COMMON=${SE_HOSTNAME}_common
INPUT_SE_DUMP_SURLS=${INPUT_SE_DUMP}_surls

# Files older than $AGE months can be safely deleted. Others must be kept.
LIMIT_DATE=`date --date="$AGE months ago" "+%Y-%m-%d"`
LIMIT_DATE_TS=`date --date="$AGE months ago" "+%s"`

if test -z "$SILENT"; then
  NOW=`date "+%Y-%m-%d %H:%M:%S"`
  echo $0 - $NOW
  #echo "--------------------------------------------"
  #echo "LCG_GFAL_INFOSYS: $LCG_GFAL_INFOSYS"
  #echo "LFC_HOST: $LFC_HOST"
  #echo "LFC_HOME: $LFC_HOME"
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

  rm -r $INPUT_SE_DUMP_SURLS
  SE_PATH=
  if test -z "$SILENT"; then
    echo "Building the list of SURLs from file ${INPUT_SE_DUMP}..."
  fi

  # Loop on lines: skip empty lines, and skip lines with directories marked
  # by authorizations starting with d, such as "drwxrwxr-x"
  cat $INPUT_SE_DUMP | awk -- '/^$/{next} $1~/^d/{next} {print $0}' | while read LINE; do

    if echo "$LINE" | egrep --silent "$SE_HOSTNAME"; then
      # Changing to a new directory
      SE_PATH=
      SE_PATH=`echo $LINE | cut -d':' -f2`
    else
      if test -z "$SE_PATH"; then
        echo "Error, path was not yet initialized. Directory name was presumably not found,"
        echo "or SE hostname and input file $INPUT_SE_DUMP do not match."
      else
        # Build the date formated as YYYY-MM-DD
        FILEDATE=`echo $LINE | awk '{print $6" "$7" "$8}'`
        FORMATED_DATE=`date --date="$FILEDATE" "+%Y-%m-%d"`

        # Build the full SURL of the file
        FILENAME=`echo $LINE | awk '{print $9}'`
        SURL="srm://"${SE_HOSTNAME}${SE_PATH}/${FILENAME}

        # Write date and SURL into the output file
        echo "$FORMATED_DATE $SURL" >> $INPUT_SE_DUMP_SURLS
      fi
    fi
  done # loop on lines of file $INPUT_SE_DUMP
fi

if test -z "$SILENT"; then
  echo "Found `wc -l $INPUT_SE_DUMP_SURLS | awk -- '{print $1}'` SURLs in input file $INPUT_SE_DUMP."
fi


# ----------------------------------------------------------------------------------------------------
#--- Check zombie files: loop on all SURLs in the SE dump, and search each one in the LFC dump
# ----------------------------------------------------------------------------------------------------

if test -z "$SILENT"; then
  echo -n "Looking for SE zombie files..."
fi

rm -f $OUTPUT_SE_ZOMBIES
cat $INPUT_SE_DUMP_SURLS | while read LINE; do
  FILEDATE=`echo $LINE | awk '{print $1}'`
  FILEDATE_TS=`date --date $FILEDATE "+%s"`
  SURL=`echo $LINE | awk '{print $2}'`

  # Check if that file is older than $AGE months. If not it is ignored.
  if ((FILEDATE_TS < LIMIT_DATE_TS)); then
    # Check if that SURL is also in the LFC dump
    if ! grep --silent $SURL $INPUT_LFC_DUMP; then
      echo $SURL >> $OUTPUT_SE_ZOMBIES
    fi
  fi
done

if test -z "$SILENT"; then
  echo "Found `wc -l $OUTPUT_SE_ZOMBIES | awk -- '{print $1}'` zombie files on SE."
fi

# ----------------------------------------------------------------------------------------------------
#--- Check LFC ghost entries: loop on all files listed in the LFC dump, and search each one in the SE dump
# ----------------------------------------------------------------------------------------------------

if test -z "$SILENT"; then
  echo -n "Looking for LFC ghost entries..."
fi

# Loop on lines, skip empty lines and lines starting with "Progress" or "Processing". 
# Keep only second word on the line ($2) => the SURL
rm -f $OUTPUT_LFC_GHOSTS
rm -f ${OUTPUT_COMMON}
cat $INPUT_LFC_DUMP | awk -- '/^$/{next} /^Pro/{next} {print $2}' | while read SURL; do

  # Check if that SURL is also in the SE dump
  if grep --silent $SURL $INPUT_SE_DUMP_SURLS; then
    echo $SURL >> ${OUTPUT_COMMON}
  else
    echo $SURL >> $OUTPUT_LFC_GHOSTS
  fi
done

if test -z "$SILENT"; then
  echo "Found `wc -l $OUTPUT_LFC_GHOSTS | awk -- '{print $1}'` ghosts entries in LFC."
  echo "Found `wc -l $OUTPUT_COMMON | awk -- '{print $1}'` files common to SE and LFC."
fi

exit 0


