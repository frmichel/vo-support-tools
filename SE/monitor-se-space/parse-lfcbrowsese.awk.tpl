# This awk template script parses the output of LFCBrowseSE, converts the used space
# of each user into GB, and filters only those users with more than  @SPACE_THRESHOLD@ in GB used.
# Placeholder  @SPACE_THRESHOLD@ must be replaced by an integer value in GB, and can be less than 1: 0.5 => 500 MB
#
# Output looks like:
#    /O=GRID-FR/C=FR/O=CNRS/OU=I3S/CN=Tristan Glatard|10G


# Remove comment lines
/^Progress/ { next; }
/^Processing/ { next; }
/Distingui/ { next; }
/========/ { next; }
/^#/ { next; }
/^$/ { next; }

{
  # Trim heading and tailing spaces
  gsub("^ ", "");
  gsub(" $", "");

  nb = split($0, line);

  # Rebuild the DN (that may contain spaces)
  dn="";
  for (i=1; i<=length(line)-1; i++) {
    dn = dn line[i]; 
    if (i<length(line)-1)
      dn = dn " ";
  }

  # Convert sise into GB and remove the unit letter K, M or G.
  size = line[length(line)];
  if (index(size, "K"))
    normSize = substr(size, 0, length(size)-1)/1000/1000;
  else if (index(size, "M"))
    normSize = substr(size, 0, length(size)-1)/1000;
  else if (index(size, "G"))
    normSize = substr(size, 0, length(size)-1);
  else
    normSize = 0; # case without unit = bytes, rounded to 0

  # Filter only users with more than 100 MB
  if (normSize>=@SPACE_THRESHOLD@)
    printf "%s|%.2f GB\n", dn, normSize;
}

# Convert sise into GB and remove the unit letter K, M or G.
#$2~/K$/ { printf "%.2f\n", substr($2, 0, length($2)-1)/1000/1000 }
#$2~/M$/ { printf "%.2f\n", substr($2, 0, length($2)-1)/1000 }
#$2~/G$/ { printf "%.2f\n", substr($2, 0, length($2)-1) }
