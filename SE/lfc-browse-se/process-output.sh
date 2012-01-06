#!/bin/bash
# This script processes the output of the LFCBroswSE with options "--dn --lfn" and sorts the result by user DN
# It is used to provide the users with the list of files when decommissioning an SE.

awk --field-separator " - " '/Progress.*/ {next;} {printf "%s | %s\n",$2,$1; }' $1 | sort

