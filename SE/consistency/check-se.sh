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
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [-s|--silent] [--older-than <age>] --se <SE hostname> --url <url> --datetime <datetime>"
  echo
  echo "  --se <SE hostname>: the storage element host name. Mandatory."
  echo
  echo "  --url <url>: The url to call of the SE. Mandatory."
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --older-than <age> : the minimum age of checked files (in months). Defaults to 6 months."
  echo
  echo "  --work-dir <work directory>: where to store temporary files. Defaults to '.'."
  echo
  echo "  --result-dir <result directory>: where to store result files. Defaults to '.'."
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Call example:"
  echo "   ./check-se.sh --se sampase.if.usp.br \ "
  echo "                 --url srm://sampase.if.usp.br:8446/dpm/if.usp.br/home/biomed \ "
  echo "                 --older-than 6 \ "
  echo "                 --result-dir $HOME/public_html/myVO/cleanup-se/20140127-120000"
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
    echo "Please set variable $\LFC_HOST before calling $0, e.g. export LFC_HOST=lfc-biomed.in2p3.fr"
    exit 1
fi

CLEANUPSE=$VO_SUPPORT_TOOLS/SE/consistency

WDIR=`pwd`
RESDIR=`pwd`
VO=biomed
AGE=6		# Default minimum age of zombies to take into account

while [ ! -z "$1" ]
do
  case "$1" in
    --se ) SE_HOSTNAME=$2; shift;;
    --vo ) VO=$2; shift;;
    --older-than ) AGE=$2; shift;;
    --result-dir ) RESDIR=$2; shift;;
    --work-dir ) WDIR=$2; shift;;
    --url ) URL=$2; shift;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

if test -z "$SE_HOSTNAME" ; then echo "Option --se is mandatory."; help; fi
if test -z "$URL" ; then echo "Option --url is mandatory."; help; fi
mkdir -p $WDIR

# Dump the list of files on the SE based on the catalog
LFCDUMP=$WDIR/dump_lfc_${SE_HOSTNAME}.txt
echo "Running LFCBrowseSE on SE ${SE}..."
$VO_SUPPORT_TOOLS/SE/lfc-browse-se/LFCBrowseSE $SE_HOSTNAME --vo $VO --sfn > $LFCDUMP
if [ $? -ne 0 ];
    then echo "LFCBrowseSE call failed"; exit 1
fi
if [ ! -e $LFCDUMP ];
    then echo "LFC dump file generation failed, cannot read file ${LFCDUMP}."; exit 1;
fi


# Dump the list of files on the SE based on the SE itself
SEDUMP=$WDIR/dump_se_${SE_HOSTNAME}.txt
echo "Running dump-se-files.py on SE ${SE}..."
$CLEANUPSE/dump-se-files.py --url $URL --output-file $SEDUMP --debug > ${WDIR}/log_${SE_HOSTNAME}_dump_se_files.txt
if [ $? -ne 0 ];
    then echo "dump-se-files.py call failed. Check ${WDIR}/log_${SE_HOSTNAME}_dump_se_files.txt."; exit 1
fi
if [ ! -e $SEDUMP ];
    then echo "SE dump file generation failed, cannot read ${SEDUMP}."; exit 1
fi

# Run the difference between both dumps LFC and SE
$CLEANUPSE/diff-se-dump-lfc.sh --se-dump $SEDUMP --lfc-dump $LFCDUMP --older-than $AGE --se $SE_HOSTNAME --work-dir $WDIR --result-dir $RESDIR > ${WDIR}/log_${SE_HOSTNAME}_diff_se_dump.txt
if [ $? -ne 0 ];
    then echo "Difference betwen LFC and SE dumps failed. Check file ${WDIR}/log_${SE_HOSTNAME}_diff_se_dump.txt."; exit 1;
fi

exit 0

