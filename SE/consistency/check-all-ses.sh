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
  echo "$0 [-s|--silent] [--older-than <age>] --se <SE hostname> --url <url> --datetime <datetime>"
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
  echo "  -h, --help: display this help"
  echo
  echo "Call example:"
  echo "   ./check-all-ses.sh --vo biomed \ "
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
CLEANUPSE=$VO_SUPPORT_TOOLS/SE/consistency

NOW=`date "+%Y%m%d-%H%M%S"`
WDIR=`pwd`/$NOW
RESDIR=`pwd`/$NOW

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
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

echo "Starting cleanup of all active SEs..."
mkdir -p $WDIR $RESDIR

LISTSE=$WDIR/list_ses_urls.txt
LISTSEXML=$RESDIR/list_ses_urls.xml
echo "Retreiving the list of SE supporting the VO..."
$CLEANUPSE/list-se-urls.py --vo $VO --lavoisier-host $LAVOISIER_HOST --lavoisier-port $LAVOISIER_PORT --output-file ${LISTSE} --xml-output-file ${LISTSEXML} --debug > ${WDIR}/list_se_urls.log
if [ $? -ne 0 ];
    then echo "list-se-urls.py call failed, check ${WDIR}/list_se_urls.log."; exit 1
fi
if [ ! -e $LISTSE ];
    then echo "List of SEs URLs cannot be found: $LISTSE."; exit 1
fi

nb=0
# Run the analisys on each SE in parallel
cat $LISTSE | while read LINE; do
    SE_HOSTNAME=`echo $LINE | cut -d ' ' -f 1`
    SE_URL=`echo $LINE | cut -d ' ' -f 5`
    echo "Running cleanup process on SE ${SE_HOSTNAME}..."
    $CLEANUPSE/check-se.sh --vo $VO --se $SE_HOSTNAME --url $SE_URL --older-than $AGE --work-dir $WDIR --result-dir $RESDIR > $WDIR/check-se.log &
    # Wait for 10 minites between each run
    
    # ###### DEBUG ########
    #nb=`expr $nb + 1`
    #if [ "$nb" -gt "10" ]; then
    #    break
    #fi
    # ###### DEBUG ########
    
    sleep 600
done

# Prepare web report with date and parameters
rm -f $RESDIR/INFO.xml
NB_SES=`cat $LISTSE | wc -l`
cat <<EOF >> $RESDIR/INFO.xml
<info><datetime>$NOW</datetime><olderThan>$AGE</olderThan><nbSEs>$NB_SES</nbSEs></info>
EOF

exit 0

