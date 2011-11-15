# This awk script parses the output of "lcg-infosites space". It displays columns:
# SE_hostname, available space, used space, total space (in GB), %age of used space
#
# As a reminder, "lcg-infosites space" output is like this:
#    Free     Used Reserved     Free     Used Reserved Tag                    SE
#  Online   Online   Online Nearline Nearline Nearline
#-------------------------------------------------------------------------------
#     1696      467        0        0        0        0 -                      arc.univ.kiev.ua
#
# Usage:
#     lcg-infosites --vo biomed space | awk -f parse-lcg-infosites-space.awk
#
# NOTE: the GLUE specification uses: 1GB = 10^3 MB = 10^6 KB... and not 2^10, 2^20.

BEGIN { avail=0; used=0; }

# Remove two first lines:
/Reserved/ { next; }
/Nearline/ { next; }
/--------/ { next; }

# Return SE hostname, available space, used space, total space (GB), %age of used space
{   
   total= $1 + $2;
   if (total==0)
       print $8, $1, $2, total, "n.a";
   else 
       print $8, $1, $2, total, int(100*$2/(total)) ; 
   avail += $1; used += $2; 
}

