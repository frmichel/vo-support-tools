#!/bin/bash

# VO environment must be set before calling this script:
# - source script $VAPO_APP/env-<VO_name>.sh to set variables:
#   $VO_SUPPORT_TOOLS, $SCAN_SE, $LFC_HOST, $VOMS_HOST, $VOMS_PORT
# - set varialbes $THRESHOLD and $USER_MIN_USED.

export TMP=/tmp/$VO/scan-se

$SCANSE/list-suspended-expired-users-voms.sh \
    --vo $VO \
    --voms-host $VOMS_HOST --voms-port $VOMS_PORT \
    --out $TMP/suspended-expired-voms-users.txt \
    > $TMP/suspended-expired-voms-users.log

$SCANSE/list-active-users-voms.sh \
    --vo $VO \
    --voms-host $VOMS_HOST --voms-port $VOMS_PORT \
    --suspended-expired-voms-users $TMP/suspended-expired-voms-users.txt \
    --out $TMP/voms-users.txt\
    > $TMP/voms-users.log

$SCANSE/scan-se-xml.sh \
    --vo $VO \
    --voms-users $TMP/voms-users.txt \
    --suspended-expired-voms-users $TMP/suspended-expired-voms-users.txt \
    --work-dir $TMP --result-dir $HOME/public_html/$VO/scan-se \
    --threshold $THRESHOLD --user-min-used $USER_MIN_USED \
    2>&1 > $TMP/scan-se.log

