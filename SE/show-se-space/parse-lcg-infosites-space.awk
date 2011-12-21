# This awk script parses the output of "lcg-infosites space". It displays columns:
# SE_hostname, available space, used space, total space (in GB), %age of used space.
# Multiple entries for the same hostname are consolidated into one single line (sum).
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
  # Check if that hostsname has already been found
  found=0;
  for (i=1; i<=nbHosts; i++) {
    if (values[i, "hostname"] == $8) {
      found=i;
      break;
    }
  }

  # Save current SE or sum values with existing ones if the same host has already been seen
  if (found != 0) {
    values[i, "avail"] += $1;
    values[i, "used"] += $2;
  } else {
    values[nbHosts, "hostname"] = $8;
    values[nbHosts, "avail"] = $1;
    values[nbHosts, "used"] = $2;
    nbHosts ++;
  }
}

# Return SE hostname, available space, used space, total space (GB), %age of used space
END {
  nbHosts --;
  for (i=1; i<=nbHosts; i++) {
    total = values[i, "avail"] + values[i, "used"];
    # Avoid the division by 0, replace by n.a in that case
    if (total == 0)
      percent = "n.a";
    else
      percent = int(100*values[i, "used"]/(total));

    print values[i, "hostname"], values[i, "avail"], values[i, "used"], total, percent;
  }
}
