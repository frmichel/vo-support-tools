#!/bin/bash

help()
{
  echo
  echo "Retrieve a robot certificate from a myproxy server and, unless specified differently, extracts"
  echo "the private key in $HOME/.globus/robotkey.pem, and"
  echo "the public certificate in $HOME/.globus/robotcert.pem."
  echo
  echo "Usage:"
  echo "$0 [-h|--help]"
  echo "$0 [--key <user private key> --cert <certificate>]"
  echo
  echo "  --key <private key>: user private key file. Defaults to \$HOME/.globus/robotkey.pem"
  echo
  echo "  --cert <certificate>: user certificate file. Defaults to \$HOME/.globus/robotcert.pem"
  echo
  echo "  -h, --help: display this help"
  echo
  exit 1
}


. /etc/profile
ROBOT_CERT=$HOME/.globus/robot-certificate.pem
KEY=$HOME/.globus/robotkey.pem
CERT=$HOME/.globus/robotcert.pem
X509_USER_PROXY=/tmp/x509up_biomed_u501

while [ ! -z "$1" ]
do
  case "$1" in
    --vo ) VO=$2; shift;;
    --key ) KEY=$2; shift;;
    --cert ) CERT=$2; shift;;
    -h | --help ) help;;
  esac
  shift
done

# Get the robot certificate
myproxy-get-delegation -s myproxy.renater.fr -d -n -l '/O=GRID-FR/C=FR/O=CNRS/OU=I3S/CN=Robot: VAPOR - Franck Michel' -o ${ROBOT_CERT}_tmp --quiet
if [ $? -ne 0 ]; then
    NOW=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$NOW - Failed to generated a new robot certificate. Keeping previous one."
    exit 1
fi

# Use the new robot certificate
chmod 600 $ROBOT_CERT
mv ${ROBOT_CERT}_tmp $ROBOT_CERT
chmod 400 $ROBOT_CERT

# Split the pem file into a key and cert files
chmod 600 $KEY $CERT
sed -n '/-----BEGIN RSA PRIVATE KEY-----/,/-----END RSA PRIVATE KEY-----/p' $ROBOT_CERT > $KEY
sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' $ROBOT_CERT > $CERT
chmod 400 $KEY $CERT

