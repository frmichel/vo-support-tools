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
  
  echo " This script check the consistency of all active SEs"
  echo " It sequentially do the following actions by calling the "
  echo " corresponding script:"
  echo " - call list-se-urls.py"
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
  echo "  --vo <vo>: the vo"
  echo
  echo "  --lavoisier-host <host>: The Lavoisier host"
  echo
  echo "  --lavoisier-port <port>: the Lavoisier port"
  echo
  echo "  --older-than <age> : the minimum age of checked files (in months)"
  echo
  echo "  --output-dir <directory>: the output directory"
  echo
  echo "  -h, --help: display this help"
  echo
  echo "  -s, --silence: be as silent as possible"
  echo
  echo "Call example:"
  echo "   ./check-all-ses.sh --vo biomed \ "
  echo "                 --lavoisier-host localhost \ "
  echo "                 --lavoisier-port 8080 \ "
  echo
  exit 1
}


# ----------------------------------------------------------------------------------------------------
# Check parameters and set environment variables
# ----------------------------------------------------------------------------------------------------

AGE=6
VO='biomed'
LAVOISIER_HOST='localhost'
LAVOISIER_PORT='8080'
OUTPUT_DIR=
SILENT=

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --lavoisier-host ) LAVOISIER_HOST=$2; shift;;
    --lavoisier-port ) LAVOISIER_PORT=$2; shift;;
    --older-than ) AGE=$2; shift;;    
    --output-dir ) OUTPUT_DIR=$2; shift;;
    -s | --silent ) SILENT=true;;
    -h | --help ) help;;
    * ) help;;
  esac
  shift
done

if test -z "$OUTPUT_DIR" ; then help; fi

echo "Checking all active SEs consistency"

if [ ! -d $OUTPUT_DIR ];
    then mkdir $OUTPUT_DIR;
fi

./list-se-urls.py --vo $VO --lavoisier-host $LAVOISIER_HOST --lavoisier-port $LAVOISIER_PORT --output-file ${OUTPUT_DIR}/list_ses_urls.txt --xml-output-file ${OUTPUT_DIR}/list_ses_urls.xml --debug > ${OUTPUT_DIR}/log_list_se_urls.txt

if [ $? -ne 0 ];
    then echo "list-se-urls.py call failed";exit 1;
fi

if [ ! -e $OUTPUT_DIR/list_ses_urls.txt ];
    then echo "list SEs urls file generation failed";exit 1;
fi
cat $OUTPUT_DIR/list_ses_urls.txt | while read LINE; do
    SE_HOSTNAME=`echo $LINE | cut -d ' ' -f 1`
    SE_URL=`echo $LINE | cut -d ' ' -f 5`
    echo "Checking SE $SE_HOSTNAME ..."
    ./check-se.sh --vo $VO --se $SE_HOSTNAME --url $SE_URL --older-than $AGE --output-dir $OUTPUT_DIR &
done
DATETIME=`basename $OUTPUT_DIR`
NB_SES=`cat $OUTPUT_DIR/list_ses_urls.txt | wc -l`

if [ -e $OUTPUT_DIR/INFO.xml ];
    then rm $OUTPUT_DIR/INFO.xml;
fi

cat <<EOF >> $OUTPUT_DIR/INFO.xml
<info><datetime>$DATETIME</datetime><olderThan>$AGE</olderThan><nbSEs>$NB_SES</nbSEs></info>
EOF

exit 0; 
