#!/bin/sh
# Version 1.1
# This tool simply runs a lcg-cr command on a SE and deletes the file afterwards if it worked. 
# It is intended to help daily work for support team of the biomed VO.
#
# ChangeLog:
# Version 1.0: initial version from Univertisy of Valencia
# Version 1.1:
#   - Fix shebang
#   - Fix line-breaks
#   - Fix error messages
#   - Don't over-engineer `set -e`

if test -z "$1" 
then
	echo "$0 registers (lcg-cr) a file small on the given SE and removes it."
	echo "The LFC_HOME variable must be set prior to calling $0."
	echo "Usage: $0 <SE hostname>"
	exit 1
fi

if test -z $LFC_HOME
then
	echo "Please set variable LFC_HOME before calling $0, e.g. export LFC_HOME=/grid/biomed/yourhomedir"
	exit 1
fi

echo "LCG_GFAL_INFOSYS: $LCG_GFAL_INFOSYS"
echo "LFC_HOST: $LFC_HOST"
echo "LFC_HOME: $LFC_HOME"
echo "--------------------------------------------"

filename=shift_`date "+%s_%N"`.txt
date > /tmp/$filename
echo "--- Registering file $filename on SE $1..."

set -xe
lcg-cr -v --connect-timeout 30 --sendreceive-timeout 900 --bdii-timeout 30 --srm-timeout 300 --vo biomed file:///tmp/$filename -l lfn:$LFC_HOME/$filename -d $1
set +xe

echo "--------------------------------------------"
echo "--- Deleting file $filename from SE $1..."

set -xe
lcg-del -a --vo biomed lfn:$LFC_HOME/$filename
set +xe

rm /tmp/$filename

exit 0
