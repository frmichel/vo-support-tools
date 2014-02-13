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

import sys
import os
import commands
import csv
import re
import gfal2
import stat
import datetime

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

optParser.add_option("--debug", action = "store_true", dest = "debug",
                     help = "Add debug traces")

# -------------------------------------------------------------------------
# Parameters check
# -------------------------------------------------------------------------

(options, args)  =  optParser.parse_args()

# Check options validity
if options.url == '':
    optParser.error("Option --url is mandatory.")
    exit(1)

outputToFile = options.output_file != ''

# Define gfal2 context as a global variable
global context
context = gfal2.creat_context()

# Method that format a stat.st_mode item into `ls -l` like permissions
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
#   @param url: the current url
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
    # Assuming given as arg url is a directory
    # List the content of the current url directory
    entries = ''
    try:
        entries = context.listdir(url)
    except Exception, e:
        print 'Exception caught while calling listdir on url: ' + url + '. Message: ', e
        return

    # Build a map (directory name  => stat object)
    entries_map = {}

    # Check each entry in the current directory
    for entry in entries:
        # check that filename doesn't begin by '/' (workaround until gfal2.5 version is released)
        if entry[0] != '/':
            # current entry is valid, get its stat item
            st = ''
            try:
                st = context.lstat(url + '/' + entry)
            except Exception,e:
                print 'Exception caught while calling lstat on url: ' + url  + '/' + entry + '. Message: ',e
                continue
            # store the entry with its stat item
            entries_map[entry] = st

    # Look for files entries and print them
    for (entry_key,entry_st) in entries_map.iteritems():
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
            ls_rec(url + '/' + entry_key,f)

# ---------------------------------------------------------------------------------------
# Main block:
# ---------------------------------------------------------------------------------------

# Build the file descriptor if specified in argument
f = ''
if outputToFile:
    f = open(options.output_file,'w')
else:
    f = sys.stdout

# Get stat item of url given as argument
st = ''
try:
    st = context.lstat(options.url)
except Exception,e:
    print 'Exception caught when while lstat on url: ' + options.url  + '. Message: ',e
    sys.exit(1)

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

sys.exit(0)

