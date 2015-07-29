# Transform the raw SE dump received from a site admin into a dump with a different format.
# The expected format is that of SE storm-01.roma3.infn.it provided by INFN-Roma, like this:
#    168672  Jun 9 2013       generated/2013-06-09/file2c1deaf1-54d6-476f-8989
# The target format lists files with data and SURL, as follows:
#    2013-06-09 srm://storm-01.roma3.infn.it:8444/biomed/generated/2013-06-09/file2c1deaf1-54d6-476f-8989

BEGIN { currentPath = ""; }

# Remove empty lines
/^$/ { next }

{ 
        # "$2 $3 $4" should look like "Apr 28  2011" or "Mar  5 15:19"
        cmd = "date -d \""$2" "$3" "$4"\" \"+%Y-%m-%d\""
        cmd | getline formattedDate
        print formattedDate, "@SRM_URL@"currentPath"/"$5
        close(cmd)
}

