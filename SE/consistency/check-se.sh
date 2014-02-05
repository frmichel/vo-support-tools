#!/bin/bash
# This script check the consistency of a SE.
# It sequentially do the following actions by calling the 
# corresponding script:
# - call LFCBrowseSE to get an LFC dump of the se files
# - call dump-se-files.py to get a gfal2 dump of the se files
# - call diff-se-dump-lfc.sh to list the differeneces between lfc dump and gfal2 dump
# - call cleanup-dark-data.sh to clean zombies files
#
# This script takes as arguments:
# - the SE hostname
# - the vo
# - the srm url of the SE
# - the date of the check
# - the minimum age of files to check
help()
{
  echo " This script check the consistency of a SE."
  echo " It sequentially do the following actions by calling the "
  echo " corresponding script:"
  echo " - call LFCBrowseSE to get an LFC dump of the se files"
  echo " - call dump-se-files.py to get a gfal2 dump of the se files"
  echo " - call diff-se-dump-lfc.sh to list the differeneces between lfc dump and gfal2 dump"
  echo " - call cleanup-dark-data.sh to clean zombies files"
  echo 
  echo " This script takes as arguments:"
  echo " - the SE hostname"
  echo " - the srm url of the SE"
  echo " - the output directory of the check"
  echo " - the vo"
  echo " - the minimum age of files to check"
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [-s|--silent] [--older-than <age>] --se <SE hostname> --url <url> --datetime <datetime>"
  echo
  echo "  --se <SE hostname>: the storage element host name"
  echo
  echo "  --url <url>: The url to call of the SE"
  echo
  echo "  --vo <vo>: the vo"
  echo
  echo "  --older-than <age>: The minimum number of months since today for files to be checked "
  echo
  echo "  --output-dir <directory>: the output directory of the check \ " 
  echo "		            (in general the date time of the check: YYYYMMDD-hhmmss)"
  echo
  echo "  -h, --help: display this help"
  echo
  echo "  -s, --silence: be as silent as possible"
  echo
  echo "Call example:"
  echo "   ./check-se.sh --se sampase.if.usp.br \ "
  echo "                 --url srm://sampase.if.usp.br:8446/dpm/if.usp.br/home/biomed \ "
  echo "                 --older-than 6 \ "
  echo "                 --output-dir /home/vapor/public_html/biomed/SE/consistency/20140127-120000"
  echo
  exit 1
}


# ----------------------------------------------------------------------------------------------------
# Check parameters and set environment variables
# ----------------------------------------------------------------------------------------------------

AGE=6		# Default minimum age of zombies to take into account
VO='biomed'
OUTPUT_DIR=
URL=
SE_HOSTNAME=
SILENT=

while [ ! -z "$1" ]
do
  case "$1" in
    --se ) SE_HOSTNAME=$2; shift;;
    --vo ) VO=$2; shift;;
    --older-than ) AGE=$2; shift;;
    --output-dir ) OUTPUT_DIR=$2; shift;;
    --url ) URL=$2; shift;;
    -s | --silent ) SILENT=true;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

if test -z "$SE_HOSTNAME" ; then help; fi
if test -z "$URL" ; then help; fi
if test -z "$OUTPUT_DIR" ; then help; fi

$VO_SUPPORT_TOOLS/SE/lfc-browse-se/LFCBrowseSE $SE_HOSTNAME --vo $VO --sfn > $OUTPUT_DIR/dump_lfc_${SE_HOSTNAME}.txt

if [ $? -ne 0 ];
    then echo "LFCBrowseSE call failed"; exit 1;
fi

if [ ! -e $OUTPUT_DIR/dump_lfc_${SE_HOSTNAME}.txt ];
    then echo "LFC dump file generation failed"; exit 1;
fi

$VO_SUPPORT_TOOLS/SE/consistency/dump-se-files.py --url $URL --output-file $OUTPUT_DIR/dump_gfal2_${SE_HOSTNAME}.txt --debug > ${OUTPUT_DIR}/log_${SE_HOSTNAME}_dump_se_files.txt

if [ $? -ne 0 ];
    then echo "dump-se-files.py call failed"; exit 1;
fi

if [ ! -e $OUTPUT_DIR/dump_gfal2_${SE_HOSTNAME}.txt ];
    then echo "gfal2 dump file generation failed"; exit 1;
fi

$VO_SUPPORT_TOOLS/SE/consistency/diff-se-dump-lfc.sh --se-dump $OUTPUT_DIR/dump_gfal2_${SE_HOSTNAME}.txt --lfc-dump $OUTPUT_DIR/dump_lfc_${SE_HOSTNAME}.txt --older-than $AGE --se $SE_HOSTNAME --output-dir $OUTPUT_DIR > log_${SE_HOSTNAME}_diff_se_dump.txt

if [ $? -ne 0 ];
    then echo "diff lfc gfal2 dumps failed"; exit 1;
fi

exit 0;
