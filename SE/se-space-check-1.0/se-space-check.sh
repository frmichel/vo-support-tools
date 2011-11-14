#!/bin/bash
# se-space-check.sh, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This tool computes the SE data provided by lcg-infosites for biomed VO, 
# to allow for sorting the result by column, and calculate the sum of each column:
# available, used and total storage space (in GB), and %age of used space.

help()
{
  echo
  echo "Biomed SE storage space checker:"
  echo "Computes the SE data provided by lcg-infosites for biomed VO,"
  echo "to allow for sorting the result by column, and calculate the sum of each column:"
  echo "available, used and total storage space (in GB), and %age of used space."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] [--sort <sort type>] [--reverse] [--max <nblines>] [--no-sum] [--no-header]"
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
  echo "  --no-header: do not display header lines"
  echo
  echo "  --no-sum: do not calculate the final sum of each column"
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Examples:"
  echo "Get all SEs supporting VO biomed, sorted by hostname:"
  echo "   $0"
  echo
  echo "Get all SEs supporting VO biomed, sorted by percentage of used space in reverse order:"
  echo "   $0 --sort %used --reverse"
  echo
  echo "Get the top 10 of the least loaded SEs supporting VO vlemed, with no final sum:"
  echo "   $0 --vo vlemed --sort avail --reverse --max 10 --no-sum"
  echo
  exit 1
}

VO=biomed
SORT=name
TMP_LCGINFOSITES=/tmp/list_se_lcginfosites_$$.txt
MAX=10000

while [ ! -z "$1" ]
do
  case "$1" in
    -s | --sort ) SORT=$2; shift;;
    -r | --reverse ) REVERSE=-r;;
    --vo ) VO=$2; shift;;
    --no-header ) NOHEADER=true;;
    --no-sum ) NOSUM=true;;
    -m | --max ) MAX=$2; shift;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

if test -z "$NOHEADER"; then
  echo -n "# `date "+%Y-%m-%d %H:%M:%S %Z"`. "
  echo -n "VO $VO. "
  #echo -n "Sort by \"$SORT\". "
  #if test -n "$REVERSE"; then
  #   echo -n "Reverse order. "
  #fi
  #if test -n "$MAX"; then
  #   echo -n "Max $MAX lines. "
  #fi
  echo
  echo "#--------------------------------------------------------------------------"
  echo "# Hostname                       Available(GB)   Used(GB)  Total(GB)  %Used"
  echo "#--------------------------------------------------------------------------"
fi

#--- First process: convert into GB, calculate % of used spacer per SE
lcg-infosites --vo $VO se | awk -f parse-lcg-infosites-se.awk > $TMP_LCGINFOSITES

#--- Select column to sort
case "$SORT" in
  name ) SORT_OPT="--key=1";;
  avail ) SORT_OPT="-g --key=2";;
  used ) SORT_OPT="-g --key=3";;
  total ) SORT_OPT="-g --key=4";;
  %used ) SORT_OPT="-g --key=5";;
esac

sort $REVERSE $SORT_OPT $TMP_LCGINFOSITES | awk -f pretty-display.awk | head -n $MAX

#--- Final step: make sums of each column
if test -z "$NOSUM"; then
  if test -z "$NOHEADER"; then
    echo "#--------------------------------------------------------------------------"
  fi

  awk -f final-sums.awk $TMP_LCGINFOSITES | awk -f pretty-display.awk

  if test -z "$NOHEADER"; then
    echo "#--------------------------------------------------------------------------"
  fi
fi
rm -f $TMP_LCGINFOSITES

