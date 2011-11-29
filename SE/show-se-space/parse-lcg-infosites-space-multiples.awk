# This awk script parses the output of "lcg-infosites space" and filter only multiple
# entries of the same SE. It displays columns:
# SE_hostname, available space, used space, total space (in GB), %age of used space.
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

BEGIN { nbHosts=1; }

# Remove two first lines:
/Reserved/ { next; }
/Nearline/ { next; }
/--------/ { next; }

{   
  # Save current SEa
  hostname = $8
  values[nbHosts, "hostname"] = hostname;
  values[nbHosts, "avail"] = $1;
  values[nbHosts, "used"] = $2;

  # Count the number of occurences of each
  if (hostname in occurences)
    occurences[hostname] += 1;
  else
    occurences[hostname] = 1;

  nbHosts ++;
}

# Return SE hostname, available space, used space, total space (GB), %age of used space
END {
  nbHosts --;

  for (i=1; i<=nbHosts; i++) {
    # Select only those with more that one occurence (ie. multiples)
    if (occurences[values[i, "hostname"]] > 1) {
      total = values[i, "avail"] + values[i, "used"];
      # Avoid the division by 0, replace by n.a in that case
      if (total == 0)
        percent = "n.a";
      else
        percent = int(100*values[i, "used"]/(total));

      print values[i, "hostname"], values[i, "avail"], values[i, "used"], total, percent;
    }
  }
}
