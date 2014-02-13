#!/bin/bash
# This script checks the consistency of a SE and cleans up eombie files.
# It sequentially does the following actions by calling the 
# corresponding scripts:
# - call LFCBrowseSE to get an LFC dump of the se files
# - call dump-se-files.py to get a dump of the SE files
# - call diff-se-dump-lfc.sh to list the differeneces between lfc dump and SE dump
# - call cleanup-dark-data.sh to clean zombies files
#
# This script takes as arguments:
# - the SE hostname
# - the vo
# - the SURL of the SE
# - the minimum age of files to check

help()
{
  echo " This script checks the consistency of a SE."
  echo " It sequentially does the following actions by calling the "
  echo " corresponding scripts:"
  echo " - call LFCBrowseSE to get an LFC-based dump of the SE files"
  echo " - call dump-se-files.py to get a dump of the SE files"
  echo " - call diff-se-dump-lfc.sh to list the differeneces between LFC-based dump and SE dump"
  echo " - call cleanup-dark-data.sh to clean zombies files"
  echo 
  echo " This script takes as arguments:"
  echo " - the SE hostname"
  echo " - the srm url of the SE"
  echo " - the output directory of the check"
  echo " - the vo"
  echo " - the minimum age of files to check"
  echo " - the cleanup dark data option"
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 --se <SE hostname> --url <url> [--vo VO] [--older-than <age>] "
  echo "   [--work-dir <work directory>] [--result-dir <result directory>]"  
  echo
  echo "  --se <SE hostname>: the storage element host name. Mandatory."
  echo
  echo "  --url <url>: The url to call of the SE. Mandatory."
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --older-than <age> : the minimum age of checked files (in months). Defaults to 12 months."
  echo
  echo "  --work-dir <work directory>: where to store temporary files. Defaults to '.'."
  echo
  echo "  --result-dir <result directory>: where to store result files. Defaults to '.'."
  echo
  echo "  --cleanup-dark-data : remove the dark datadetected. Optionnal,"
  echo "                        no removal is run if option is not present. The Dark data removal"
  echo "                        is a not reversible,  be sure of what you do before specifying"
  echo "                        this option!"
  echo
  echo "  --simulate : Does not do any action, just sleep for 1 minute."
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Call example:"
  echo "   ./check-se.sh --se sampase.if.usp.br \ "
  echo "                 --url srm://sampase.if.usp.br:8446/dpm/if.usp.br/home/biomed \ "
  echo "                 --older-than 6 \ "
  echo "                 --result-dir \$HOME/public_html/myVO/cleanup-se/20140127-120000 \ "
  echo "                 --cleanup-dark-data"
  echo
  exit 1
}


# ----------------------------------------------------------------------------------------------------
# Check parameters and set environment variables
# ----------------------------------------------------------------------------------------------------

if test -z "$VO_SUPPORT_TOOLS"; then
    echo "Please set variable \$VO_SUPPORT_TOOLS before calling $0."
    exit 1
fi
if test -z "$LFC_HOST"; then
    echo "Please set variable \$LFC_HOST before calling $0, e.g. export LFC_HOST=lfc-biomed.in2p3.fr"
    exit 1
fi

CLEANUPSE=$VO_SUPPORT_TOOLS/SE/cleanup-se
CLEANUP_DARK_DATA=false
SIMULATE=false
WDIR=`pwd`
RESDIR=`pwd`
VO=biomed
AGE=12		# Default minimum age of zombies to take into account

while [ ! -z "$1" ]
do
  case "$1" in
    --se ) SE_HOSTNAME=$2; shift;;
    --vo ) VO=$2; shift;;
    --older-than ) AGE=$2; shift;;
    --result-dir ) RESDIR=$2; shift;;
    --work-dir ) WDIR=$2; shift;;
    --url ) URL=$2; shift;;
    --cleanup-dark-data ) CLEANUP_DARK_DATA=true;;
    --simulate ) SIMULATE=true;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

if test -z "$SE_HOSTNAME" ; then echo "Option --se is mandatory."; help; fi
if test -z "$URL" ; then echo "Option --url is mandatory."; help; fi


mkdir -p $WDIR

NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# --------------------------------------------"
echo "# $NOW - Starting check of SE ${SE_HOSTNAME}"
echo "# --------------------------------------------"

if [ "$SIMULATE" == "true" ]; then
    echo "# Simulating check of SE ${SE_HOSTNAME}..."
    sleep 60
    exit 0
fi

# ------------------------------------------------------
# Dump the list of files on the SE based on the catalog
# ------------------------------------------------------
LFCDUMP=$WDIR/${SE_HOSTNAME}_dump_lfc.txt
NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# $NOW - Running LFCBrowseSE on SE ${SE_HOSTNAME}..."
$VO_SUPPORT_TOOLS/SE/lfc-browse-se/LFCBrowseSE $SE_HOSTNAME --vo $VO --sfn > $LFCDUMP
if [ $? -ne 0 ];
    then echo "LFCBrowseSE call failed"; exit 1
fi
if [ ! -e $LFCDUMP ];
    then echo "LFC dump file generation failed, cannot read file ${LFCDUMP}."; exit 1
fi


# ------------------------------------------------------
# Dump the list of files on the SE based on the SE itself
# ------------------------------------------------------
SEDUMP=$WDIR/${SE_HOSTNAME}_dump_se.txt
NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# $NOW - Running dump-se-files.py on SE ${SE_HOSTNAME}..."
$CLEANUPSE/dump-se-files.py --url $URL --output-file $SEDUMP --debug
if [ $? -ne 0 ];
    then echo "Computation of the difference between LFC and SE failed."; exit 1
fi
if [ ! -e $SEDUMP ];
    then echo "SE dump file generation failed, cannot read ${SEDUMP}."; exit 1
fi


# ------------------------------------------------------
# Run the difference between both dumps LFC and SE
# ------------------------------------------------------
NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# $NOW - Computing difference between LFC and SE for SE ${SE_HOSTNAME}..."
$CLEANUPSE/diff-se-dump-lfc.sh --se-dump $SEDUMP --lfc-dump $LFCDUMP --older-than $AGE --se $SE_HOSTNAME --work-dir $WDIR --result-dir $RESDIR
if [ $? -ne 0 ];
    then echo "Difference betwen LFC and SE dumps failed."; exit 1
fi


# ------------------------------------------------------
# Cleanup dark data found out by the diff script
# ------------------------------------------------------
if [ "$CLEANUP_DARK_DATA" == "true" ] ; then
    echo "# Starting removing dark data files listed in file ${RESDIR}/${SE_HOSTNAME}.cleanup_dark_data.log"
    # ${CLEANUPSE}/cleanup-dark-data.sh --vo $VO --se $SE_HOSTNAME --surls ${RESDIR}/${SE_HOSTNAME}.cleanup_dark_data.log
    if [ $? -ne 0 ];
        then echo "Cleanup of dark data failed."; exit 1
    fi
else
    echo "# Dark data cleanup is deactivated."
fi

NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# --------------------------------------------"
echo "# $NOW - Exiting $0"
echo "# --------------------------------------------"
exit 0

