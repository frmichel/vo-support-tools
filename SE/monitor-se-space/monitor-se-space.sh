#!/bin/bash
# monitor-se-space.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This script monitors the free space all the SEs supporting a given VO.
# For all SEs with more than 95% space used, it runs the LFCBrowseSE tool to
# collect the VO users who have more than 1 GB of data on that SE, and then
# produces the list of DNs, used space, and email addresses of those users.
#
# All parameters default to biomed specific values, but can be specified using the options.a
#
# Example: ./monitor-se-space.sh --vo biomed --threshold 95
#
# Algo:
#   Get the list of SEs sorted by %age of used space
#   Select only SEs with used space over $SPACE_THRESHOLD
#   For each one:
#      Run the LFCBrosweSE tool to get the list of users (summary)
#      For each user above a given threshold
#         Get user's email address from the VOMS server
#         Send a mail notification


# Threshold of used space over which to run the procedure
SPACE_THRESHOLD=95

NOW=`date "+%Y%m%d-%H%M%S"`
WDIR=`pwd`/$NOW

VO=biomed
VOMS_USERS=`pwd`/voms-users.txt

TMP_LIST_SE=$WDIR/list-se.txt
TMP_PARSE_AWK=$WDIR/parse-show-se-space.awk

help()
{
  echo
  echo "This script monitors the free space the SEs supporting a given VO."
  echo "For all SEs with more than 95% space used, it runs the LFCBrowseSE tool to"
  echo "collect the VO users who have more than 1 GB of data on that SE, then"
  echo "produces the list of DNs, used space, and email addresses of those users."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] [--voms-users <file name>] [--dir <work directory>] [--threshold <percentage>]"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --voms-users <file name>: list of users extracted from the VOMS server."
  echo "                            Defaults to './voms-users.txt'."
  echo
  echo "  --dir <work directory>: where to store results. Defaults to './<date>'."
  echo
  echo "  --threshold <percentage>: percentage of used space over which a SE will be monitored. Defaults to 95."
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Examples:"
  echo "Check SEs supporting biomed with used space over 95%"
  echo "   $0"
  echo
  echo "Check SEs supporting VO myVO with used space over 90%"
  echo "   ./monitor-se-space.sh --vo myVo --voms-hostname voms.myvo.org --voms-port 9999 --threshold 90"
  echo
  exit 1
}

# Check environment
if test -z "$VO_SUPPORT_TOOLS"; then
    echo "Please set variable \$VO_SUPPORT_TOOLS before calling $0."
    exit 1
fi
MONITOR_SE_SPACE=$VO_SUPPORT_TOOLS/monitor-se-space
SHOW_SE_SPACE=$VO_SUPPORT_TOOLS/show-se-space

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --voms-users ) VOMS_USERS=$2; shift;;
    --dir ) WDIR=$2/$NOW; shift;;
    --threshold ) SPACE_THRESHOLD=$2; shift;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

mkdir -p $WDIR

# Make the list of SEs that use space over the given threshold (95% by default)
sed "s/@SPACE_THRESHOLD@/$SPACE_THRESHOLD/" $MONITOR_SE_SPACE/parse-show-se-space.awk > $TMP_PARSE_AWK
$SHOW_SE_SPACE/show-se-space.sh --vo $VO --sort %used --reverse --max 30 --no-header --no-sum | awk -f $TMP_PARSE_AWK | sort | uniq > $TMP_LIST_SE

# Run the analisys on each SE in parallel
for SEHOSTNAME in `cat $TMP_LIST_SE`
do
  echo "Starting analysis of SE $SEHOSTNAME..."
  $MONITOR_SE_SPACE/se-heavy-users.sh --vo $VO --voms-users $VOMS_USERS --dir $WDIR $SEHOSTNAME &
  sleep 5
done
echo "Started analysis of all SEs."

# Clean up
#rm -f $TMP_LIST_SE
rm -f $TMP_PARSE_AWK


