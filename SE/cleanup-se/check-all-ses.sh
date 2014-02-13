#!/bin/bash
# This script check the consistency of all active SEs
# It sequentially do the following actions by calling the 
# corresponding script:
# - call list-se-urls.py
# - for each SE of the list:
# 	- call check-se.sh
#
# This script takes as arguments:
# - the vo
# - the Lavoisier host
# - the Lavoisier port
# - the mninimum age of checked files (in months)
# - the output directory

help()
{  
  echo " This script checks the consistency of all active SEs."
  echo " It sequentially does the following actions by calling the"
  echo " corresponding scripts:"
  echo " - call list-se-urls.py: get the SURLs of all SEs supporting the VO."
  echo " - for each SE of the list:"
  echo "       - call check-se.sh"
  echo 
  echo " This script takes as arguments:"
  echo " - the vo"
  echo " - the Lavoisier host"
  echo " - the Lavoisier port"
  echo " - the minimum age of checked files (in months)"
  echo " - the output directory"
  echo 
  echo 
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 --se <SE hostname> --url <url> --datetime <datetime> [--vo VO] [--older-than <age>] "
  echo "   [--work-dir <work directory>] [--result-dir <result directory>]"
  echo "   [--lavoisier-host <hostname>] [--lavoisier-port <port>]"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --lavoisier-host <host>: Lavoisier hostname, defaults to localhost."
  echo
  echo "  --lavoisier-port <port>: Lavoisier port, defaults to 8080."
  echo
  echo "  --older-than <age> : the minimum age of checked files (in months). Defaults to 6 months."
  echo
  echo "  --work-dir <work directory>: where to store temporary files. The date is appended to the directory,"
  echo "           formatted as <work directory>/YYYYMMDD-HHMMSS. Defaults to './<date>'."
  echo
  echo "  --result-dir <result directory>: where to store result files, that is <hostname>_email."
  echo "           The date is appended to the directory, formatted as <result directory>/YYYYMMDD-HHMMSS."
  echo "           Defaults to './<date>'."
  echo
  echo "  --simulate : Used for debug. Does not do any action, just list SEs to check,"
  echo "               for each SE the check will sleep 1 minute."
  echo
  echo "  -h, --help: display this help"
  echo
  echo "Call example:"
  echo "   ./check-all-ses.sh --vo biomed --older-than 6 \ "
  echo "                 --lavoisier-host localhost \ "
  echo "                 --lavoisier-port 8080 \ "
  echo "                 --work-dir /tmp/myVo/cleanup-se"
  echo '                 --result-dir $HOME/public_html/myVo/cleanup-se'
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
CLEANUPSE=$VO_SUPPORT_TOOLS/SE/cleanup-se

NOW=`date "+%Y%m%d-%H%M%S"`
WDIR=`pwd`/$NOW
RESDIR=`pwd`/$NOW
SIMULATE=

VO=biomed
AGE=6
LAVOISIER_HOST='localhost'
LAVOISIER_PORT='8080'

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --lavoisier-host ) LAVOISIER_HOST=$2; shift;;
    --lavoisier-port ) LAVOISIER_PORT=$2; shift;;
    --older-than ) AGE=$2; shift;;    
    --work-dir ) WDIR=$2/$NOW; shift;;
    --result-dir ) RESDIR=$2/$NOW; shift;;
    --simulate ) SIMULATE=--simulate;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# --------------------------------------------"
echo "# $NOW - Starting cleanup of all active SEs: $(basename $0)"
echo "# --------------------------------------------"
mkdir -p $WDIR $RESDIR

# ----------------------------------------------------------------------------------------------------
# Build the list of SEs to cleanup
# ----------------------------------------------------------------------------------------------------
LISTSE=$WDIR/list_ses_urls.txt
LISTSEXML=$RESDIR/list_ses_urls.xml
NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# $NOW - Retreiving the list of SE supporting the VO..."
$CLEANUPSE/list-se-urls.py --vo $VO --lavoisier-host $LAVOISIER_HOST --lavoisier-port $LAVOISIER_PORT --output-file ${LISTSE} --xml-output-file ${LISTSEXML} --debug 2>&1 > ${WDIR}/list_ses_urls.log
if [ $? -ne 0 ];
    then echo "Script list-se-urls.py failed, check ${WDIR}/list_se_urls.log."; exit 1
fi
if [ ! -e $LISTSE ];
    then echo "List of SEs URLs cannot be found: ${LISTSE}."; exit 1
fi

# ----------------------------------------------------------------------------------------------------
# Prepare web report with date and parameters
# ----------------------------------------------------------------------------------------------------
rm -f $RESDIR/INFO.xml
NB_SES=`cat $LISTSE | wc -l`
cat <<EOF >> $RESDIR/INFO.xml
<info>
<datetime>$NOW</datetime>
<olderThan>$AGE</olderThan>
<nbSEs>$NB_SES</nbSEs>
</info>
EOF


# ----------------------------------------------------------------------------------------------------
# Loop to start checks of all SEs in parralel
# ----------------------------------------------------------------------------------------------------

# Limit the number of SE checks run in parralel
MAX_PARALLEL_CHECKS=20

# Limit the total number of SE to check (debug feature, set 99999 for no limit)
MAX_CHECKS_TOTAL=30

# Run the analysis on each SE in parallel
NB_CHECKS=0
cat $LISTSE | while read LINE; do

    # Limit the number of checks running in parralel: if over the limit, simply wait for others to complete
    NB_CHECK_PARRALEL=`ps h -fHu vapor | grep "check-se.sh --vo $VO" | grep -v "grep check-se.sh --vo $VO" | wc -l`
    while [ $NB_CHECK_PARRALEL -gt $MAX_PARALLEL_CHECKS ]; do
        NOW=`date "+%Y-%m-%d %H:%M:%S"`
        echo "# $NOW - Currently $NB_CHECK_PARRALEL checks running. Waiting 10mn for some to complete before running a new one."
        # Wait 10 minutes until the next attempt
        sleep 600
        NB_CHECK_PARRALEL=`ps h -fHu vapor | grep "check-se.sh --vo $VO" | grep -v "grep check-se.sh --vo $VO" | wc -l`
    done

    SE_HOSTNAME=`echo $LINE | cut -d ' ' -f 1`
    SE_URL=`echo $LINE | cut -d ' ' -f 5`
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "# $NOW - Running cleanup process on SE ${SE_HOSTNAME}..."
    $CLEANUPSE/check-se.sh --vo $VO --se $SE_HOSTNAME --url $SE_URL --older-than $AGE --work-dir $WDIR --result-dir $RESDIR $SIMULATE 2>&1 > $WDIR/${SE_HOSTNAME}.log &
    
    if [ "$NB_CHECKS" -ge "$MAX_CHECKS_TOTAL" ]; then
        break
    fi
    NB_CHECKS=`expr $NB_CHECKS + 1`
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "# $NOW - $NB_CHECKS SE checks started."
    
    # Wait for 1 minute between each run
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "# $NOW - Waiting 1mn before starting the next SE check."
    sleep 60
done

NOW=`date "+%Y-%m-%d %H:%M:%S"`
echo "# --------------------------------------------"
echo "# $NOW - Exiting $(basename $0)"
echo "# --------------------------------------------"

exit 0

