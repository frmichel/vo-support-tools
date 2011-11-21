# This awk script parses the output of "lcg-infosites se". It displays columns:
# SE_hostname, available space, used space, total space (in GB), %age of used space
#
# Usage:
#     lcg-infosites --vo biomed se | awk -f parse-lcg-infosites-se.awk
#
# NOTE: the GLUE specification uses: 1GB = 10^3 MB = 10^6 KB... and not 2^10, 2^20.

BEGIN { avail=0; used=0; }

# Remove two first lines:
/Avail Space/ { next; }
/---------/ { next; }

# Skip lines with value "n.a"
$1~/n.a/ { next; }
$2~/n.a/ { next; }

# Replace values "n.a" by 0
#$1~/n.a/ { $1=0; $2=0; }
#$2~/n.a/ { $1=0; $2=0; }

# Return SE hostname, available space, used space, total space (GB), %age of used space
{ total=$1+$2; if (total==0) {total = 1}; print $4, int($1/1000000), int($2/1000000), int((total)/1000000),  int(100*$2/(total)) ; avail += $1; used += $2; }

