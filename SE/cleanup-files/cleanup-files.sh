#!/bin/bash
# This script helps remove files of users either unknown or who left the VO.
# In input, it uses the list of files produced by "LFCBrowseSE --lfn --dn".
#
# Example:
# ./cleanup-files.sh --vo biomed --se dpm.cyf-kr.edu.pl --files dpm.cyf-kr.edu.pl_files 2>&1 | tee -a /tmp/cleanup-files/dpm.cyf-kr.edu.pl.log

help()
{
  echo
  echo "This script removes files of users either unknown either who left the VO."
  echo "It uses the output of LFCBrowseSE --lfn --dn."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] --se <SE hostname> --files <list of files>"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --se <SE hostname>: the storage element host name"
  echo
  echo "  --files <filename>: name of the file with the output of LFCBrowseSE --lfn --dn"
  echo
  echo "  -h, --help: display this help"
  echo
  exit 1
}

# Check environment
if test -z "$VO_SUPPORT_TOOLS"; then
    echo "Please set variable \$VO_SUPPORT_TOOLS before calling $0."
    exit 1
fi
CLEANUP_FILES=$VO_SUPPORT_TOOLS/SE/cleanup-files

VO=biomed
SE=""
FILES_LIST=""
mkdir -p /tmp/cleanup-files

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --se ) SE=$2; shift;;
    --files ) FILES_LIST=$2; shift;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

if test -z "$SE"; then
    echo "Option --se must be provided.."
    help
    exit 1
fi
if test -z "$FILES_LIST"; then
    echo "Option --files must be provided."
    help
    exit 1
fi

# Remove empty lines and lines with Progress or Processing keywords
TMP_FILE=/tmp/cleanup-files/$FILES_LIST.$$
cat $FILES_LIST | sed '/^$/d' | egrep -v "Processing|Progress" > $TMP_FILE

USERS_TO_REMOVE=all_users_remove_list.txt
if test ! -f $CLEANUP_FILES/$USERS_TO_REMOVE; then
   echo "Error: file $CLEANUP_FILES/$USERS_TO_REMOVE does not exist."
   exit 1
fi

DN_LIST=`cat $CLEANUP_FILES/$USERS_TO_REMOVE`
let nblines=`wc -l $TMP_FILE | cut -d' ' -f1`
echo "$nblines files total."
let nblines=`cat $TMP_FILE | egrep "$DN_LIST" | wc -l | cut -d' ' -f1`
echo "$nblines files to remove."

index=0
for file in `cat $TMP_FILE | egrep "$DN_LIST" | cut -d'[' -f1`; do

  # Remove only the replica on that SE
  #lcg-del -v --connect-timeout 30 --sendreceive-timeout 60 --vo $VO --se $SE lfn:$file

  # Remove all replicas
  lcg-del -v --connect-timeout 30 --sendreceive-timeout 60 --bdii-timeout 300 --vo $VO -a lfn:$file

  let rate="$index * 100 / $nblines"
  echo "$$: done $rate%. $file"
  let index++
done

rm $TMP_FILE

