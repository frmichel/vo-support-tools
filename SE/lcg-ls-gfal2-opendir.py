#!/usr/bin/python
# This script is an 'ls -l' like list of files and directories from an SURL, using the gfal2 python api.
# The output list the following information for each file:
# - rights
# - creation date
# - last modification date
# - size in bytes
# - full path

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

optParser  =  OptionParser(version = "%prog 1.0", description = """This script is an 'ls -l' like list of files and directories from an SURL, using the gfal2 python api. Outut columns are: unix-like rights, creation date, modification date, size, full path.""")
optParser.add_option("--url", action = "store", dest = "url", default = '',
                     help = "The url of the SE to list. Mandatory.")
optParser.add_option("--debug", action = "store_true", dest = "debug",
                     help = "Add debug traces")
(options, args)  =  optParser.parse_args()

# Check options validity
if options.url == '':
    optParser.error("Option --url is mandatory.")
    exit(1)


# ---------------------------------------------------------------------
# Method that formats a stat.st_mode item into `ls -l` like permissions
# ---------------------------------------------------------------------
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
# Parse the entries (files and directories) of given url
# Parameters:
#   @param url: the current url
#
# The output generated contains lines with the following structure:
# %file permissions% %creation date% %last modification date% %file size% %file full url%
#
# date format is YYYY-MM-DD for all dates
# ------------------------------------------------------------------------------------
def ls(url):
    # Assuming given as arg url is a directory
    entries = ''
    try:
        if options.debug:
            print "DEBUG dir = context.opendir(" + url + ")"
        dir = context.opendir(url)
    except Exception, e:
        print 'Error while listing url: ' + url + ' message: ', e
        return

    while True:
        if options.debug:
            print "DEBUG dir.readpp()"
        (dirent, st) = dir.readpp()
        # Check that filename doesn't begin by '/' (workaround until gfal2.5 version is released)
        if dirent is None:
            break        
        
        print ( mode_to_rights(st.st_mode) + ' ' +
                str(datetime.datetime.fromtimestamp(int(st.st_ctime)).strftime('%Y-%m-%d')) + ' ' +
                str(datetime.datetime.fromtimestamp(int(st.st_mtime)).strftime('%Y-%m-%d')) + ' ' +
                str(st.st_size) + ' ' + url + '/' + dirent.d_name)


# ---------------------------------------------------------------------------------------
# Main block:
# ---------------------------------------------------------------------------------------

# Define gfal2 context as a global variable
global context
context = gfal2.creat_context()

# Get stat item of url given as argument
st = ''
try:
    if options.debug:
        print "DEBUG st = context.lstat(" + options.url + ")"
    st = context.lstat(options.url)
except Exception,e:
    print 'Invalid url: ' + options.url  + ' message: ',e
    sys.exit(1)

# Print the url
print ( mode_to_rights(st.st_mode) + ' ' +
        str(datetime.datetime.fromtimestamp(int(st.st_ctime)).strftime('%Y-%m-%d')) + ' ' +
        str(datetime.datetime.fromtimestamp(int(st.st_mtime)).strftime('%Y-%m-%d')) + ' ' +
        str(st.st_size) + ' ' + options.url)

ls(options.url)

sys.exit(0)

