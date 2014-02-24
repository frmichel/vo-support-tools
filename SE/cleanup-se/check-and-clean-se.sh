#!/bin/bash
# This script checks the consistency of a SE and cleans up zombie files.
# It sequentially does the following actions by calling the 
# corresponding scripts:
# - call check-se.sh to get the list of dark data files and lost files
# - if check-se.sh raised no error and the --cleanup-dark-data option is specified
#   then call cleanup-dark-data.sh
#
# This script takes as arguments:
# - the SE hostname
# - the vo
# - the SURL of the SE
# - the minimum age (in months) of the files to check
# - the cleanup dark data option
# - the working directory
# - the result directory

help()
{
  echo "This script checks the consistency of a SE and cleans up zombie files."
  echo "It sequentially does the following actions by calling the corresponding scripts:"
  echo "  - call check-se.sh to get the list of dark data files and lost files;"
  echo "  - if check-se.sh raised no error and the --cleanup-dark-data option is specified" 
  echo "    then call cleanup-dark-data.sh."
  echo 
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 --se <SE hostname> --url <url> [--vo VO] [--older-than <age>] [--cleanup-dark-data]"
  echo "   [--work-dir <work directory>] [--result-dir <result directory>]"  
  echo
  echo "  --se <SE hostname>: the storage element host name. Mandatory."
  echo
  echo "  --url <url>: The url with access protocol of the SE,"
  echo "               e.g. srm://hostname:8446/path or gsiftp://hostname:2811/path. Mandatory."
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --older-than <age> : the minimum age of checked files (in months). Defaults to 12 months."
  echo
  echo "  --cleanup-dark-data : indicate that dark data will be effectively removed,"
  echo "                        in the case no error was raised when listing files. Optional."
  echo "                        Not done by default."
  echo 
  echo "  --work-dir <work directory>: where to store temporary files. Defaults to '.'."
  echo
  echo "  --result-dir <result directory>: where to store result files. Defaults to '.'."
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Call example:"
  echo "   ./check-and-clean-se.sh --se sampase.if.usp.br \ "
  echo "                 --url srm://sampase.if.usp.br:8446/dpm/if.usp.br/home/biomed \ "
  echo "                 --older-than 6 \ "
  echo "                 --vo myVo"
  echo "                 --result-dir \$HOME/public_html/myVO/cleanup-se/20140127-120000 \ "
  echo "                 --work-dir /tmp/myVo/cleanup-se"
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
CLEANUP_DARK_DATA="false"
WDIR=`pwd`
RESDIR=`pwd`
VO=biomed
AGE=12		# Default minimum age of zombies to take into account
SE_HOSTNAME=
URL=

while [ ! -z "$1" ]
do
  case "$1" in
    --se ) SE_HOSTNAME=$2; shift;;
    --vo ) VO=$2; shift;;
    --older-than ) AGE=$2; shift;;
    --result-dir ) RESDIR=$2; shift;;
    --work-dir ) WDIR=$2; shift;;
    --url ) URL=$2; shift;;
    --cleanup-dark-data ) CLEANUP_DARK_DATA="true";;
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
echo "# $NOW - Starting $(basename $0) for SE ${SE_HOSTNAME}"
echo "# --------------------------------------------"


# Initiate the xml output file
XML_OUTPUT_FILE=${RESDIR}/${SE_HOSTNAME}_cleanup_result.xml
touch $XML_OUTPUT_FILE
echo "<hostname>${SE_HOSTNAME}</hostname>" > $XML_OUTPUT_FILE
echo "<url>${URL}</url>" >> $XML_OUTPUT_FILE

# -----------------------------------------------------
# Check SE consistency between SE files and LFC registered files
# -----------------------------------------------------

${CLEANUPSE}/check-se.sh --vo $VO --se $SE_HOSTNAME --url $URL --older-than $AGE --work-dir $WDIR --result-dir $RESDIR 2>&1 > $WDIR/${SE_HOSTNAME}.log 
if [ $? -ne 0 ]; then
    echo "# Execution of check-se.sh failed. See Logs in file $WDIR/${SE_HOSTNAME}.log"; exit 1
fi

# Analyse check-se.sh log file to see if any error was raised: 
# all comment lines start with "#", any other line is considered an error.

NB_LINES_IN_ERROR=`egrep -v "^# |^$" ${WDIR}/${SE_HOSTNAME}.log | wc -l`
if [ $NB_LINES_IN_ERROR -ne 0 ]; 
then
	echo "# Execution of check-se.sh returned errors (logged in $WDIR/${SE_HOSTNAME}.log)."
	echo "# Removal of dark data will NOT be performed."
	
	echo "<freeSpaceAfter>N/A</freeSpaceAfter>" >> $XML_OUTPUT_FILE
	echo "<status>Completed with errors</status>" >> $XML_OUTPUT_FILE
	echo "<errorsFile>$RESDIR/${SE_HOSTNAME}.errors</errorsFile>" >> $XML_OUTPUT_FILE
	
	# Copy error lines into a report file for web display
	egrep -v "^# |^$" $WDIR/${SE_HOSTNAME}.log > $RESDIR/${SE_HOSTNAME}.errors
	exit 0
fi

# ------------------------------------------------------
# Remove dark data as no error was raised by check-se.sh
# ------------------------------------------------------

if [ $CLEANUP_DARK_DATA == "true" ]; then
    echo "# Starting removing dark data files listed in file $RESDIR/${SE_HOSTNAME}.output_se_dark_data"
    ${CLEANUPSE}/cleanup-dark-data.sh --vo $VO --se $SE_HOSTNAME --surls $RESDIR/${SE_HOSTNAME}.output_se_dark_data
    if [ $? -ne 0 ];
        then echo "# Cleanup of dark data failed."; exit 1
    fi
else
    echo "# Removal of dark data files is not activated."
fi

# Wait 10 minutes before reading the space again from the SE (hopefully sufficient for space update in the BDII)
sleep 600
FREE_SPACE_AFTER=`lcg-infosites --vo $VO space | egrep "Reserved|Online|$SE_HOSTNAME" | tail -n 1 | awk '{ print $1}'`

echo "<freeSpaceAfter>${FREE_SPACE_AFTER}</freeSpaceAfter>" >> $XML_OUTPUT_FILE
echo "<status>Completed</status>" >> $XML_OUTPUT_FILE
echo "<errorsFile>N/A</errorsFile>" >> $XML_OUTPUT_FILE  


NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# --------------------------------------------"
echo "# $NOW - Exiting $(basename $0)"
echo "# --------------------------------------------"
exit 0

