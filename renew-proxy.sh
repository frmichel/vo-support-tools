#!/bin/bash
# Generate a proxy certificate with a VO extension.
# The proxy file name is /tmp/x509_up_${VO}_u$[USERID}, e.g. /tmp/x509up_biomed_u499
#
# This script is intended to be run by a cron job, like:
# 0 0,8,16 * * * /path/vo-support-tools/renew-proxy.sh --vo biomed --key $HOME/.globus/userkey.pem --cert $HOME/.globus/usecert.pem --pass $HOME/.globus/cert_pass.txt

help()
{
  echo
  echo "Generate a proxy certificate with a VO extension."
  echo "The proxy file name is /tmp/x509_up_\${VO}_u\${USERID}, e.g. /tmp/x509up_biomed_u499".
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--vo <VO> ---key <user private key> --cert <certificate> --pass <passphrase file>]"
  echo
  echo "  --vo <VO>: the Virtual Organisation for which to generate an extension. Defaults to biomed. "
  echo
  echo "  --key <private key>: user private key file. Defaults to \$HOME/.globus/userkey.pem"
  echo
  echo "  --cert <certificate>: user certificate file. Defaults to \$HOME/.globus/usercert.pem"
  echo
  echo "  --pass <VO>: passphrase file. Defaults to \$HOME/.globus/usercertpass.txt"
  echo
  echo "  -h, --help: display this help"
  echo
  exit 1
}


. /etc/profile
# Set the default VO
VO=biomed

# Make sure file .globus/userpass.txt is private (rights 600)
PASS=$HOME/.globus/userpass.txt

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --key ) KEY="-key $2"; shift;;
    --cert ) CERT="-cert $2"; shift;;
    --pass ) PASS=$2; shift;;
    -h | --help ) help;;
  esac
  shift
done

PROXY_FILE=$X509_USER_PROXY
if test -z "$PROXY_FILE"; then
    USERID=`id --user`
    PROXY_FILE=/tmp/x509up_${VO}_u${USERID}
fi
voms-proxy-init -quiet -out ${PROXY_FILE}_tmp -voms $VO $CERT $KEY -pwstdin < $PASS 2>&1

if [ $? -ne 0 ]; then
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$NOW - Failed to generated a new proxy. Keeping previous one."
    exit 1
fi

# Use the new proxy file
mv ${PROXY_FILE}_tmp ${PROXY_FILE}

