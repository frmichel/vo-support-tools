# Transform the raw SE dump received from the admin, that gives each
# directory followed by the files in it, like this:
# ./persistent:
# -rw-rwx---+ 1 storm storm    232381 Mar  5 15:18 testfile-put-1401728565-c6c250379889.txt
# ... into another dump where all files are given with data and  SURL, as follows:
# 1970-01-01 srm://stormfe1.pi.infn.it:8444/biomed/persistent/testfile-put-1401728565-c6c250379889.txt

BEGIN { currentPath = ""; }

# Basic cleanup: remove empty lines, lines like "total 123", and lines about directories like "drwxrwx--- ..."
/^$|^d|^total/ { next }

# Find lines that gives the current path and remember it
match($0, /^\.(.*):$/) { 
    currentPath = substr($0, RSTART+1, RLENGTH-2) 
    # print "--", $0
    # print "-- New current path:", currentPath
}

/^-/ { print "1970-01-01", "@SRM_URL@"currentPath"/"$9 }


