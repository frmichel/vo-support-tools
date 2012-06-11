# Awk template: the @SPACE_THRESHOLD@ placeholder must be replaced with an integer value (%) 
#
# Filter the output of show-se-space to select only those SEs which percentage
# of used space is over the threshold. The output is simply the hostname.

$5 >= @SPACE_THRESHOLD@ { print $1 }

