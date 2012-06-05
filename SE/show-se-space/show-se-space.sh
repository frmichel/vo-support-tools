#!/bin/bash
# show-se-space.sh, v1.3
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This tool computes the SE data provided by lcg-infosites for biomed VO, 
# to allow for sorting the result by column, and calculate the sum of each column:
# available, used and total storage space (in GB), and %age of used space.
# It also provides the GOCDB status of the SE.
#
# ChangeLog:
# 1.0: initial version
# 1.1: use "lcg-infosites space" instead of "lcg-infosites se" to get new attributes
#      GlueSAOnline*Size instead of deprecated attributes GlueState*Size
# 1.2: based on env variable $$SHOW_SE_SPACE to be able to run from anywhere
# 1.3: get downtimes from the GOCDB to display it along with SE space report

help()
{
  echo
  echo "Biomed SE storage space checker:"
  echo "Computes the SE data provided by lcg-infosites for biomed VO,"
  echo "to allow for sorting the result by column, and calculate the sum of each column:"
  echo "available, used and total storage space (in GB), and %age of used space."
  echo "The GOCDB status of the SE is also provided to help support teams."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] [--sort <sort type>] [--reverse] [--max <nblines>] [--multiples]"
  echo "                [--no-sum] [--no-header]"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  -s, --sort {name | avail | used | total | %used}: sort output by hostname, available space,"
  echo "      used space, total space, or %age of used space. Defaults to name"
  echo
  echo "  --r, --reverse: sort in reverse order"
  echo
  echo "  -m, --max <nblines>: display only the given number of lines"
  echo
  echo "  --multiples: display only multiple entries of the same SE"
  echo
  echo "  --no-header: do not display header lines"
  echo
  echo "  --no-sum: do not calculate the final sum of each column"
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Examples:"
  echo "Get all biomed SEs sorted by hostname"
  echo "   $0"
  echo
  echo "Get all biomed SEs sorted by % of used space in reverse order:"
  echo "   $0 --sort %used --reverse"
  echo
  echo "Get the top 10 of the least loaded SEs, for VO vlemed, with no final sum"
  echo "   $0 --vo vlemed --sort avail --reverse --max 10 --no-sum"
  echo
  exit 1
}

# Check environment
if test -z "$VO_SUPPORT_TOOLS"; then
    echo "Please set variable \$VO_SUPPORT_TOOLS before calling $0."
    exit 1
fi
SHOW_SE_SPACE=$VO_SUPPORT_TOOLS/SE/show-se-space

VO=biomed
SORT=name
TMP_LCGINFOSITES=/tmp/show-se-space/list_se_lcginfosites_$$.txt
MAX=10000

mkdir -p /tmp/show-se-space

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    -s | --sort ) SORT=$2; shift;;
    -r | --reverse ) REVERSE=-r;;
    --vo ) VO=$2; shift;;
    --no-header ) NOHEADER="true";;
    --no-sum ) NOSUM="true";;
    --multiples ) MULTIPLES="true";;
    -m | --max ) MAX=$2; shift;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done


if test -z "$NOHEADER"; then
  echo -n "# `date "+%Y-%m-%d %H:%M:%S %Z"`. "
  echo -n "VO $VO. "
  echo
  echo "#---------------------------------------------------------------------------------------------------"
  echo "# Hostname                       Available(GB)   Used(GB)  Total(GB)  %Used   GOCDB Status"
  echo "#---------------------------------------------------------------------------------------------------"
fi

#--- First process: calculate % of used space per SE
AWK_FILE=$SHOW_SE_SPACE/parse-lcg-infosites-space.awk
if test -n "$MULTIPLES"; then
  AWK_FILE=$SHOW_SE_SPACE/parse-lcg-infosites-space-multiples.awk
fi
lcg-infosites --vo $VO space | awk -f $AWK_FILE > $TMP_LCGINFOSITES


#--- Get status of SE from the GOCDB (downtimes, not in producton, not monitored)
echo -n "" > ${TMP_LCGINFOSITES}_tmp
cat $TMP_LCGINFOSITES | while read LINE; do
   SE=`echo $LINE | cut -d'|' -f1`
   SE_STATUS=`grep "$SE" /tmp/show-se-space/gocdb-se-status.txt | cut -d'|' -f3`
   echo $LINE'|'$SE_STATUS >> ${TMP_LCGINFOSITES}_tmp
done
cp ${TMP_LCGINFOSITES}_tmp $TMP_LCGINFOSITES


#--- Select column to sort
case "$SORT" in
  name ) SORT_OPT="--key=1";;
  avail ) SORT_OPT="-g --key=2";;
  used ) SORT_OPT="-g --key=3";;
  total ) SORT_OPT="-g --key=4";;
  %used ) SORT_OPT="-g --key=5";;
esac

sort --field-separator="|" $REVERSE $SORT_OPT $TMP_LCGINFOSITES | awk -f $SHOW_SE_SPACE/pretty-display.awk | head -n $MAX

#--- Final step: make sums of each column and display everything in a pretty format
if test -z "$NOSUM"; then
  if test -z "$NOHEADER"; then
    echo "#--------------------------------------------------------------------------"
  fi

  awk -f $SHOW_SE_SPACE/final-sums.awk $TMP_LCGINFOSITES | awk -f $SHOW_SE_SPACE/pretty-display.awk

  if test -z "$NOHEADER"; then
    echo "#--------------------------------------------------------------------------"
  fi
fi
rm -f $TMP_LCGINFOSITES

