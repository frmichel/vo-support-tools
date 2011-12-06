#!/bin/bash
#
# Shortcut to the lcg-infosites command for VO biomed, either for CE, SE or SPACE
#
# Usage:
#   info.sh se <SE hostname>
#   info.sh space <SE hostname>
#   info.sh ce <CE hostname>

if test "$1" = "se"; then
    lcg-infosites --vo biomed se | egrep "Avail Spa|$2"
    exit 0
fi

if test "$1" = "space"; then
    lcg-infosites --vo biomed space | egrep "Reserved|Online|$2"
    exit 0
fi

if test "$1" = "ce"; then
    lcg-infosites --vo biomed ce | egrep "ComputingElement|$2"
    exit 0
fi

lcg-infosites --vo biomed $1 | egrep "$2"


