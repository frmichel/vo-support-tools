#!/usr/bin/python
# This script lists the files of a SE using the gfal2 python api.
# The SE whose file are listed is the one corresponding to the url given as argument.
# This script output is the filename given as argument or stdout if no filename is specified.
# The output dump file list the following information for each file:
#   - the type: file or directory
#   - the creation date
#   - the last modification date
#   - the size
#   - the full file path
# 
# Fault tolerance mechanisms:
# - in case a query to the SE fails, a maximum of 4 retries is performed, with 30 seconds wait in between.
#   Only after the 5th failed attempt shall we report the error.
# - in case more than 100 failures are reported, we give up the process with an error status.

import sys
import os
import commands
import csv
import re
import gfal2
import stat
import datetime
import time

from operator import itemgetter, attrgetter
from optparse import OptionParser

optParser  =  OptionParser(version = "%prog 1.0", description = """This script lists the files of a SE using the gfal2 python api.
The SE whose file are listed is the one corresponding to the url given as argument.
This script output is the filename given as argument or stdout if no filename is specified.
The output dump file list the following information for each file:
the type: file or directory, the creation date, the last modification date,
the size, the full file path.""")

optParser.add_option("--url", action = "store", dest = "url", default = '',
                     help = "The url of the SE to analyse. Mandatory.")

optParser.add_option("--output-file", action = "store", dest = "output_file", default = '',
                     help = "output file to write results. Defaults to stdout")


# -------------------------------------------------------------------------
# Parameters check
# -------------------------------------------------------------------------

(options, args)  =  optParser.parse_args()

# Check options validity
if options.url == '':
    optParser.error("Option --url is mandatory.")
    sys.exit(1)

outputToFile = options.output_file != ''

# Gfal2 context global variable
global context
context = gfal2.creat_context()

# Max number of retries when an exception is raised
global MAX_GFAL2_REQUEST_TRY
MAX_GFAL2_REQUEST_TRY = 5

# Waiting time in seconds when retry
global MAX_RETRY_WAITING_TIME
MAX_RETRY_WAITING_TIME = 30

# Number of errors caught during the process, and max number of errors caught overall
global MAX_ERRORS, errorCount
MAX_ERRORS = 100
errorCount = 0

# ---------------------------------------------------------------
# Method that format a stat.st_mode item into `ls -l` like permissions
# Parameters:
#   @param st_mode: permissions to format
# ---------------------------------------------------------------
def mode_to_rights(st_mode) :

    # Variable containing the result permission string
    permstr  =  ''

    # Set the file type:
    # d for directory
    # l for symbolic link
    # - for files
    if stat.S_ISDIR(st_mode):
        permstr +=  'd'
    else:
        if stat.S_ISLNK(st_mode):
            permstr +=  'l'
        else:
            permstr +=  '-'
    # Loops to call the S_IRUSR, S_IWUSR etc... attribute of st_mode item
    # to affect r,w or x permission to user, group and other
    usertypes  =  ['USR', 'GRP', 'OTH']
    for usertype in usertypes:
        perm_types  =  ['R', 'W', 'X']
        for permtype in perm_types:
            perm  =  getattr(stat, 'S_I%s%s' % (permtype, usertype))
            if st_mode & perm:
                permstr +=  permtype.lower()
            else:
                permstr +=  '-'
    # Return the permissions string
    return permstr


# ------------------------------------------------------------------------------------
# Recursive method that goes through the files tree of given url.
# Parameters:
#   @param url: the current url, this must be a directory, not a simple file
#   @param f: the output file descriptor
#       if f =  = '' then output is written to stdout
# The recursion algorithm is:
# 1. list the entries of the url directory
# 2. build the map (directory name  => stat object)
# 3. for each entry of the map whose type is file: print the file
# 4. for each entry of the map whose type is directory:
# 4.1. print the directory
# 4.2. recursively call the algorithm on url: {current url}/{current entry directory}
# N.B. The recursion stops when the url directory contains no directory
#      i.e. contains only files.
#
# The output generated contains lines with the following structure:
# %file permissions% %creation date% %last modification date% %file size% %file full url%
#
# date format is YYYY-MM-DD for all dates
# ------------------------------------------------------------------------------------

def ls_rec(url,f) :
    global errorCount

    # List the content of the current directory
    dir = ''
    isOpSuccess = False
    nbAttempts = 1
    while not isOpSuccess:
        try:
            dir = context.opendir(url)
            isOpSuccess = True
        except Exception, e:
            nbAttempts += 1
            if nbAttempts > MAX_GFAL2_REQUEST_TRY:
                print 'Exception caught when calling opendir on url: ' + url + '. Message: ', e
                errorCount += 1
                if errorCount >= MAX_ERRORS:
                    print 'Too many errors (' + str(MAX_ERRORS) + ') caught. Giving up process.'
                    sys.exit(1)
                return
            else:
                time.sleep(MAX_RETRY_WAITING_TIME)    

    # Build a map (directory name  => stat object)
    entries_map = {}

    # Check each entry of the current directory
    while True:
        isOpSuccess = False
        nbAttempts = 1
        dirent = st = ''
        while not isOpSuccess:
            try:
                (dirent, st) = dir.readpp()
                isOpSuccess = True
            except Exception, e:
                nbAttempts += 1
                if nbAttempts > MAX_GFAL2_REQUEST_TRY:
                    print 'Exception caught when calling readpp on url: ' + url + '. Message: ', e
                    # We stop looking for this entry but will continue to check other entries of the directory
                    errorCount += 1
                    if errorCount >= MAX_ERRORS:
                        print 'Too many errors (' + str(MAX_ERRORS) + ') caught. Giving up process.'
                        sys.exit(1)
                    break
                else:
                    time.sleep(MAX_RETRY_WAITING_TIME)    

        if isOpSuccess:
            # Stop if we reached the last entry
            if dirent is None:
                break
            # Current entry is valid, get its stat item and continue
            entries_map[dirent.d_name] = st
    # End of the while loop to read each entry of the current directory

    # Look for file entries and print them
    for (entry_key, entry_st) in entries_map.iteritems():
        # Check if entry is a file
        if not stat.S_ISDIR(entry_st.st_mode):
            f.write( mode_to_rights(entry_st.st_mode) + ' ' +
                 str(datetime.datetime.fromtimestamp(int(entry_st.st_ctime)).strftime('%Y-%m-%d')) + ' ' +
                 str(datetime.datetime.fromtimestamp(int(entry_st.st_mtime)).strftime('%Y-%m-%d')) + ' ' +
                 str(entry_st.st_size) + ' ' + url + '/' + entry_key + '\n')

    # Look for directory entries, for each print it then recursively call the function on this directory
    for (entry_key,entry_st) in entries_map.iteritems():
        # check entry is a directory
        if stat.S_ISDIR(entry_st.st_mode):
            # print the directory line
            f.write( mode_to_rights(entry_st.st_mode) + ' ' +
                 str(datetime.datetime.fromtimestamp(int(entry_st.st_ctime)).strftime('%Y-%m-%d')) + ' ' +
                 str(datetime.datetime.fromtimestamp(int(entry_st.st_mtime)).strftime('%Y-%m-%d')) + ' ' +
                 str(entry_st.st_size) + ' ' + url +
                 '/' + entry_key + '\n')

            # Recursively call the method on current entry directory
            ls_rec(url + '/' + entry_key, f)
    
    # End of function ls_rec

# ---------------------------------------------------------------------------------------
# Main block:
# ---------------------------------------------------------------------------------------

try:
    # Build the file descriptor if specified in argument
    f = ''
    if outputToFile:
        try:
            f = open(options.output_file, 'w')
        except Exception,e:
            print 'Exception when opening output file: ' + options.output_file + ' Message: ', e
            sys.exit(1)
    else:
        f = sys.stdout
        
    # Get stat item of the url given as argument
    st = ''
    isLStatSuccess = False
    attemptLStat = 1
    while not isLStatSuccess:
        try:
            st = context.lstat(options.url)
            isLStatSuccess = True
        except Exception, e:
            attemptLStat += 1
            if attemptLStat > MAX_GFAL2_REQUEST_TRY:
                print 'Exception caught in lstat on url: ' + options.url  + '. Message: ', e
                sys.exit(1)
            else:
                time.sleep(MAX_RETRY_WAITING_TIME)

    # Print the url
    f.write( mode_to_rights(st.st_mode) + ' ' + 
        str(datetime.datetime.fromtimestamp(int(st.st_ctime)).strftime('%Y-%m-%d')) + ' ' + 
        str(datetime.datetime.fromtimestamp(int(st.st_mtime)).strftime('%Y-%m-%d')) + ' ' + 
        str(st.st_size) + ' ' + 
        options.url + '\n')

    # Start the recursive process
    ls_rec(options.url,f)

    # Final cleanup
    if outputToFile:
        f.close()
        
except Exception,e:
    print 'Unexpected exception caught when computing url: ' + options.url  + '. Message: ', e
    sys.exit(1)
    
sys.exit(0)

