#!/bin/bash
# This script is a wrapper around the cleanup-files.sh: it will run it in parralel using a set of files with files to remove.
# The set of files is typically built by applying the split command the the output of "LFCBrowseSE --sfn --dn".
# Constraint: all files must be named after the scheme "<SE hostname>_files_*".
#
# Example:
# $ LFCBrowseSE dpm.cyf-kr.edu.pl --vo biomed --sfn --dn > dpm.cyf-kr.edu.pl_files
# $ split --lines 10000 dpm.cyf-kr.edu.pl_files dpm.cyf-kr.edu.pl_files_
#            -> this will produce files dpm.cyf-kr.edu.pl_files_*
# $ cleanup-files-loop.sh --vo biomed --se dpm.cyf-kr.edu.pl 2>&1 | tee -a /tmp/cleanup-files/dpm.cyf-kr.edu.pl.log

help()
{
  echo
  echo "This script is a wrapper around the cleanup-files.sh: it will run it in parralel using a set of files with SRMs to remove."
  echo 'The set of files is typically built by applying the split command the the output of "LFCBrowseSE --sfn --dn".'
  echo 'Each file should be in the local (calling) dir, and named after the scheme "<SE hostname>_files_*"'
  echo "Typically files would be produced by the "split --lines n..." command."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] --se <SE hostname>"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --se <SE hostname>: the storage element host name"
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
mkdir -p /tmp/cleanup-files

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --se ) SE=$2; shift;;
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

for FILE in `ls ${SE}_files_*`; do
   echo "-----------------------------------"
   echo "Processing file $FILE..."
   $CLEANUP_FILES/cleanup-files.sh --vo $VO --se $SE --files $FILE 2>&1 | tee -a /tmp/cleanup-files/${FILE}.log &
   sleep 20
done

