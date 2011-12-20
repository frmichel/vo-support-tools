#!/bin/bash
# This script s an example of the command to process the output of the LFCBroswSE with options "--dn --name" and sorts the result by user DB
# It is used to provide the users with the list of files when decommissioning an SE.

awk --field-separator " - " '/Progress.*/ {next;} {printf "%s | %s\n",$2,$1; }' $1 | sort

