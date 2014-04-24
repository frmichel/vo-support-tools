#!/bin/bash
# This script checks the consistency of a SE.
# It sequentially does the following actions by calling the 
# corresponding scripts:
# - call LFCBrowseSE to get an LFC dump of the se files
# - call dump-se-files.py to get a dump of the SE files
# - call diff-se-dump-lfc.sh to list the differeneces between lfc dump and SE dump
# - call cleanup-dark-data.sh to clean zombies files
#
# This script takes as arguments:
# - the SE hostname
# - the VO name
# - the SRM and access URLs of the SE (they may be the same)
# - the path to the space reserved in the storage area, which is a substring of the SRM and access paths
# - the minimum age of dark data files to list

help()
{
  echo "This script checks the consistency of a SE: it lists files from the SE and from"
  echo "the catalog. Then it compares both to come up with the list of dark data files"
  echo "(files on the SE but no longer registered in the catalog), and lost files"
  echo "(files registered in the catalog but that no longer on the SE)."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 --se <SE hostname> --srm-url <url> --access-url <accessUrl>"
  echo "   [--vo VO] [--older-than <age>]"
  echo "   [--work-dir <work directory>] [--result-dir <result directory>]"  
  echo
  echo "  --se <SE hostname>: the storage element host name. Mandatory."
  echo
  echo "  --srm-url <srmUrl>: The srm url to call of the SE. Mandatory."
  echo
  echo "  --access-url <accessUrl>: The URL used to list files through an access protocol supported by the SE"
  echo
  echo "  --vo-sa-path <path>: The relative path to the space reserved for the VO. In the BDII this is either "
  echo "                       the VOInfo/VOInfoPath or GlueSA/GlueSAPath. Mandatory."
  echo 
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --older-than <age> : the minimum age of checked files (in months). Defaults to 12 months."
  echo
  echo "  --work-dir <work directory>: where to store temporary files. Defaults to '.'."
  echo
  echo "  --result-dir <result directory>: where to store result files. Defaults to '.'."
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Call example:"
  echo "   ./check-se.sh \ "
  echo "                 --vo myVo"
  echo "                 --se sampase.if.usp.br \ "
  echo "                 --srm-url srm://sampase.if.usp.br:8446/dpm/if.usp.br/home/biomed \ "
  echo "                 --access-url gsiftp://sampase.if.usp.br:2811/dpm/if.usp.br/home/biomed \ "
  echo "                 --vo-sa-path /dpm/if.usp.br/home/biomed \ "
  echo "                 --older-than 6 \ "
  echo "                 --result-dir \$HOME/public_html/myVO/cleanup-se/20140127-120000 "
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

CLEANUPSE=${VO_SUPPORT_TOOLS}/SE/cleanup-se
WDIR=`pwd`
RESDIR=`pwd`
VO=biomed
AGE=12		# Default minimum age of zombies to take into account
SRM_URL=
ACCESS_URL=
VOSAPATH=

while [ ! -z "$1" ]
do
  case "$1" in
    --se ) SE_HOSTNAME=$2; shift;;
    --vo ) VO=$2; shift;;
    --older-than ) AGE=$2; shift;;
    --result-dir ) RESDIR=$2; shift;;
    --work-dir ) WDIR=$2; shift;;
    --srm-url ) SRM_URL=$2; shift;;
    --access-url ) ACCESS_URL=$2; shift;;
    --vo-sa-path ) VOSAPATH=$2; shift;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

if test -z "$SE_HOSTNAME" ; then echo "Option --se is mandatory."; help; fi
if test -z "$SRM_URL" ; then echo "Option --srm-url is mandatory."; help; fi
if test -z "$ACCESS_URL" ; then echo "Option --access-url is mandatory."; help; fi
if test -z "$VOSAPATH" ; then echo "Option --vo-sa-path is mandatory."; help; fi

mkdir -p $WDIR

NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# --------------------------------------------"
echo "# $NOW - Starting $(basename $0) for SE ${SE_HOSTNAME}"

# ------------------------------------------------------
# Dump the list of files on the SE according to the LFC
# ------------------------------------------------------
LFCDUMP=${WDIR}/${SE_HOSTNAME}_dump_lfc.txt
LFCDUMPTMP=${LFCDUMP}_tmp
NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# $NOW - Running LFCBrowseSE on SE ${SE_HOSTNAME}..."
${VO_SUPPORT_TOOLS}/SE/lfc-browse-se/LFCBrowseSE $SE_HOSTNAME --vo $VO --sfn > $LFCDUMPTMP
if [ $? -ne 0 ]; then
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$NOW - Command LFCBrowseSE failed to build the LFC dump."
    exit 1
fi
if [ ! -e $LFCDUMPTMP ]; then
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$NOW - LFC dump file generation failed, cannot read file ${LFCDUMPTMP}."
    exit 1
fi

# LFC dump clean-up:
# - the current LFCBrowseSE returns files for all VOs => we filter (grep) only the URLs that contain the $VOSAPATH.
# - remove empty lines and lines with comments, like: Processing... Progress...
# - remove the port number like ":8446" in case it exists.
grep $VOSAPATH $LFCDUMPTMP | awk -- '/^$/{next} /^Pro/{next} {print $2}' | sed 's/:[0-9]\{4\}//g' > $LFCDUMP
rm -f $LFCDUMPTMP

# ------------------------------------------------------
# Dump the list of files on the SE based on the SE itself
# ------------------------------------------------------
SEDUMP=$WDIR/${SE_HOSTNAME}_dump_se.txt
NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# $NOW - Running dump-se-files.py on SE ${SE_HOSTNAME}..."
${CLEANUPSE}/dump-se-files.py --url $ACCESS_URL --output-file $SEDUMP --debug 2>&1
if [ $? -ne 0 ]; then
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$NOW - Failed to dump the list of files on the SE."
    exit 1
fi
if [ ! -e $SEDUMP ]; then
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$NOW - SE dump file generation failed, cannot read ${SEDUMP}."
    exit 1
fi


# ------------------------------------------------------
# Run the difference between both dumps LFC and SE
# ------------------------------------------------------
${CLEANUPSE}/diff-se-dump-lfc.sh \
    --se $SE_HOSTNAME \
    --se-dump $SEDUMP \
    --lfc-dump $LFCDUMP \
    --older-than $AGE \
    --srm-url $SRM_URL \
    --access-url $ACCESS_URL \
    --work-dir $WDIR \
    --result-dir $RESDIR
    
if [ $? -ne 0 ]; then
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$NOW - Difference betwen LFC and SE dumps failed."
    exit 1
fi

NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# $NOW - Exiting $(basename $0)"
exit 0

