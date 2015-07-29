# Transform the raw SE dump received from a site admin into a dump with a different format.
# The expected format is that of SE storm-01.roma3.infn.it provided by INFN-Pisa, with 
# each directory followed by the files in it:
#    ./persistent:
#    -rw-rwx---+ 1 storm storm    232381 Mar  5 15:18 testfile-put-1401728565-c6c250379889.txt
# The target format lists files with data and SURL, as follows:
#    2014-03-05 srm://stormfe1.pi.infn.it:8444/biomed/persistent/testfile-put-1401728565-c6c250379889.txt

BEGIN { currentPath = ""; }

# Basic cleanup: remove empty lines, lines like "total 123", and lines about directories like "drwxrwx--- ..."
/^$|^d|^total/ { next }

# Find lines that gives the current path and remember it
match($0, /^\.(.*):$/) { 
    currentPath = substr($0, RSTART+1, RLENGTH-2) 
    # print "--", $0
    # print "-- New current path:", currentPath
}

/^-/ { 
        # "$6 $7 $8" should look like "Apr 28  2011" or "Mar  5 15:19"
        cmd = "date -d \""$6" "$7" "$8"\" \"+%Y-%m-%d\""
        cmd | getline formattedDate
        print formattedDate, "@SRM_URL@"currentPath"/"$9
        close(cmd)
}


