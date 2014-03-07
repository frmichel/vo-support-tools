#!/bin/bash
# se-heavy-users.sh
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This script looks for users who have more that 100 MB of data on the given SE.
# It provides the list of such users as well as their email address.
#
# All parameters default to biomed specific values, but can be specified using the options.
#
# This version returns the results as xml files, that are later exploited by php scripts in ./web_display.

VO=biomed
WDIR=`pwd`
RESDIR=`pwd`
VOMS_USERS=$WDIR/voms-users.txt
SUSPENDED_EXPIRED_VOMS_USERS=$WDIR/suspended-expired-voms-users.txt
USER_MIN_SPACE=0.1

help()
{
  echo
  echo "This script looks for users of the given VO who have more that 100 MB of data on the given SE."
  echo "It provides the list of such users as well as their email address."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO>] [--voms-users <file name>] [--user-min-used  <space in GB>]"
  echo "          [--work-dir <work directory>] [--result-dir <result directory>] <SE hostname>"
  echo
  echo "  --vo <VO>: the Virtual Organisation to query. Defaults to biomed."
  echo
  echo "  --voms-users <file name>: list of users extracted from the VOMS server."
  echo "          Defaults to './voms-users.txt'."
  echo
  echo "  --suspended-expired-voms-users <file name>: list of suspended or expired users extracted from the VOMS server."
  echo "          Defaults to './suspended-expired-voms-users.txt'."
  echo
  echo "  --work-dir <work directory>: where to store temporary files. Defaults to '.'."
  echo
  echo "  --result-dir <result directory>: where to store result files, that is <hostname>_email."
  echo "          Defaults to '.'."
  echo
  echo "  --user-min-used <space in GB>: minimum used space (in GB) for a user to be reported. Defaults to 0.1 = 100 MB."
  echo
  echo "  -h, --help: display this help"
  echo
  exit 1
}

# Check environment
if test -z "$VO_SUPPORT_TOOLS"; then
    echo "Please set variable \$VO_SUPPORT_TOOLS before calling $0."
    exit 1
fi
MONITOR_SE_SPACE=$VO_SUPPORT_TOOLS/SE/scan-se
LFC_BROWSE_SE_BIN=$VO_SUPPORT_TOOLS/SE/lfc-browse-se/LFCBrowseSE

# Check parameters
while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --voms-users ) VOMS_USERS=$2; shift;;
    --suspended-expired-voms-users ) SUSPENDED_EXPIRED_VOMS_USERS=$2; shift;;
    --work-dir ) WDIR=$2; shift;;
    --result-dir ) RESDIR=$2; shift;;
    --user-min-used ) USER_MIN_SPACE=$2; shift;;
    -h | --help ) help;;
    *) SEHOSTNAME=$1;;
  esac
  shift
done

mkdir -p $WDIR
if test -z "$SEHOSTNAME" ; then
    help
fi


# -------------------------------------------------------------
# --- Check additional environment
# -------------------------------------------------------------

if test -z "$LFC_HOST"; then
    echo "Please set variable LFC_HOST before calling $0, e.g. export LFC_HOST=lfc-biomed.in2p3.fr"
    exit 1
fi

LBS_OUT=$WDIR/${SEHOSTNAME}.lst

#--- The hostname_status file will help display the status of the analysis on the web report
USED_PERCENT=`lcg-infosites --vo $VO space | awk -f $VO_SUPPORT_TOOLS/SE/show-se-space/parse-lcg-infosites-space.awk | grep "^$SEHOSTNAME" | cut -d"|"  -f5`

RESULT_STATUS=$RESDIR/${SEHOSTNAME}_status.xml

SPACE=`lcg-infosites --vo $VO space | awk -f $VO_SUPPORT_TOOLS/SE/show-se-space/parse-lcg-infosites-space.awk | grep "^$SEHOSTNAME"`
USED_SPACE=`echo $SPACE | cut -d"|" -f3`
FREE_SPACE=`echo $SPACE | cut -d"|" -f2`
TOTAL_SPACE=`echo $SPACE | cut -d"|" -f4`

echo "<HostName>${SEHOSTNAME}</HostName>" > $RESULT_STATUS
echo "<UsedSpace>${USED_SPACE}</UsedSpace>" >> $RESULT_STATUS
echo "<FreeSpace>${FREE_SPACE}</FreeSpace>" >> $RESULT_STATUS
echo "<TotalSpace>${TOTAL_SPACE}</TotalSpace>" >> $RESULT_STATUS
echo "<UsedSpacePercentage>${USED_PERCENT}</UsedSpacePercentage>" >> $RESULT_STATUS
echo "<Status>Ongoing</Status>" >> $RESULT_STATUS


# -------------------------------------------------------------
# --- Read the catalog: get all VO users having files there
# -------------------------------------------------------------

touch $LBS_OUT
echo -n "# Starting LFCBrowseSE at " >> $LBS_OUT
DATE_FORMAT="+%Y-%m-%d %H:%M:%S %Z"
date "$DATE_FORMAT" >> $LBS_OUT

#--- Run the LFCBrowseSE tool
$LFC_BROWSE_SE_BIN $SEHOSTNAME --vo $VO --summary 2>&1 >> $LBS_OUT
if test $? -ne 0; then
    echo "$(basename $LFC_BROWSE_SE_BIN) failed to retrieve files for SE ${SEHOSTNAME}. Exiting."
    
    echo "<HostName>${SEHOSTNAME}</HostName>" > $RESULT_STATUS
    echo "<UsedSpace>${USED_SPACE}</UsedSpace>" >> $RESULT_STATUS
    echo "<FreeSpace>${FREE_SPACE}</FreeSpace>" >> $RESULT_STATUS
    echo "<TotalSpace>${TOTAL_SPACE}</TotalSpace>" >> $RESULT_STATUS
    echo "<UsedSpacePercentage>${USED_PERCENT}</UsedSpacePercentage>" >> $RESULT_STATUS
    echo "<Status>Error</Status>" >> $RESULT_STATUS
    exit 0
fi

echo -n "# LFCBrowseSE completed at " >> $LBS_OUT
date "$DATE_FORMAT" >> $LBS_OUT

# -------------------------------------------------------------
# --- For each user with more than x GB, get his email address from the VOMS
# -------------------------------------------------------------

RESULT=$WDIR/${SEHOSTNAME}_users.xml
NOTFOUND=$WDIR/${SEHOSTNAME}_unknown.xml
SUSPENDED_EXPIRED=$WDIR/${SEHOSTNAME}_suspended-expired.xml
RESULT_EMAIL=$RESDIR/${SEHOSTNAME}_email.xml


# Parse the result of the LFCBrowseSE, and select only DNs with more than x GB
TMP_PARSE_AWK=$WDIR/parse-lfcbrowsese_$$.awk
echo  "<emails>" >> $RESULT_EMAIL
sed "s/@SPACE_THRESHOLD@/$USER_MIN_SPACE/" $MONITOR_SE_SPACE/parse-lfcbrowsese.awk.tpl > $TMP_PARSE_AWK
awk -f $TMP_PARSE_AWK $LBS_OUT | while read LINE ; do
  dn=`echo $LINE | cut -d"|" -f1`
  used=`echo $LINE | cut -d"|" -f2`
  
  # Loop on line with DNs, DNs start with: "/ANYWORD="
  if [[ $dn =~ ^/[a-zA-Z]+= ]]
  then
    # Is the user among the active users?
    voms_user=`grep "$dn" $VOMS_USERS`
    if test $? -eq 0; then
        echo -n "<email>" >> $RESULT_EMAIL
        # Retreive the email address: it is separated from the DN by a '-' or a ',' depending on the voms-admin version
        echo -n $voms_user |  awk '{ printf "%s", gensub("^.+,([^ ]+@[^ ]+)$", "\\1", 1); }' >> $RESULT_EMAIL 
        echo  "</email>" >> $RESULT_EMAIL
        echo -n "<User><DN>$dn</DN><UsedSpace>" >> $RESULT
        echo -n $used | cut -d ' ' -f 1 | tr -d '\n' >> $RESULT
        echo "</UsedSpace></User>" >> $RESULT
    else
      # Is the user among the suspended or expired users?
      suspendedExpiredVomsUser=`grep "$dn" $SUSPENDED_EXPIRED_VOMS_USERS`
      if test $? -eq 0; then
          echo -n "<email>" >> $RESULT_EMAIL
          # Retreive the email address: it is separated from the DN by a '-' or a ',' depending on the voms-admin version
          echo -n $suspendedExpiredVomsUser | awk '{ printf "%s", gensub("^.+,([^ ]+@[^ ]+)$", "\\1", 1); }'  >> $RESULT_EMAIL
          echo  "</email>" >> $RESULT_EMAIL
          echo -n "<User><DN>$dn</DN><UsedSpace>" >> $SUSPENDED_EXPIRED
          echo -n $used | cut -d ' ' -f 1 | tr -d '\n' >> $SUSPENDED_EXPIRED
          echo  "</UsedSpace></User>" >> $SUSPENDED_EXPIRED
      else
          # The user is not active, suspended nor expired => he is unknown
          echo -n "<User><DN>$dn</DN><UsedSpace>" >> $NOTFOUND
          echo -n $used | cut -d ' ' -f 1 | tr -d '\n' >> $NOTFOUND
          echo -n "</UsedSpace></User>" >> $NOTFOUND
      fi
    fi
  fi
done

echo "</emails>" >> $RESULT_EMAIL

# -------------------------------------------------------------
# --- Convert the result into a file preparing the email to send to users
# -------------------------------------------------------------

mkdir -p $RESDIR
#--- Export the result file to the result dir in a more readable form
if test -f $RESULT; then
    cp $RESULT $RESDIR/${SEHOSTNAME}_users.xml
fi
if test -f $SUSPENDED_EXPIRED; then
    cp $SUSPENDED_EXPIRED $RESDIR/${SEHOSTNAME}_suspended-expired.xml
fi

#--- Export the list of unkown users to the result dir in a more readable form
if test -f $NOTFOUND; then
    cp $NOTFOUND $RESDIR/${SEHOSTNAME}_unknown.xml
fi


# -------------------------------------------------------------
# --- Make the final status line giving the used space percentage 
# --- and the link to the list of users
# -------------------------------------------------------------

SPACE=`lcg-infosites --vo $VO space | awk -f $VO_SUPPORT_TOOLS/SE/show-se-space/parse-lcg-infosites-space.awk | grep "^$SEHOSTNAME"`        

USED_SPACE=`echo $SPACE | cut -d"|" -f3`
FREE_SPACE=`echo $SPACE | cut -d"|" -f2`
TOTAL_SPACE=`echo $SPACE | cut -d"|" -f4`

echo "<HostName>${SEHOSTNAME}</HostName>" > $RESULT_STATUS
echo "<UsedSpace>${USED_SPACE}</UsedSpace>" >> $RESULT_STATUS
echo "<FreeSpace>${FREE_SPACE}</FreeSpace>" >> $RESULT_STATUS
echo "<TotalSpace>${TOTAL_SPACE}</TotalSpace>" >> $RESULT_STATUS
echo "<UsedSpacePercentage>${USED_PERCENT}</UsedSpacePercentage>" >> $RESULT_STATUS
echo "<Status>Completed</Status>" >> $RESULT_STATUS
rm -f $TMP_PARSE_AWK

