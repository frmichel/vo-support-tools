#! /usr/bin/python
# Script for extracting a list of files from DPM database
# Inspired from original script by Erming Pei, 2009/11/13
# A. Sartirana 2012/02/16, sartiran@llr.in2p3.fr
# F. Michel 2013/09/04, adapted to match the format of Syncat xml dumps

import sys,os
import datetime, time
import MySQLdb
from optparse import OptionParser

usage = "usage: %prog [options]" 
description = "Dumps the content of DPM storage element into an XML file that can be used for consistency check against LFC."

parser = OptionParser(usage=usage, description=description)
parser.add_option("--dbcfg", action="store", help="Configuration file for db access with the line <user>/<password>@<host>. Defaults are: /opt/lcg/etc/DPMCONFIG and /opt/lcg/etc/NSCONFIG", default='')
parser.add_option("--vo", action="store", help="Virtual Organisation for which this dump is done. Default is 'cms'", default="cms")
parser.add_option("--rootdir", action="store", help="Base directory from which start the list of files. Default is '/dpm'. WARNING: do not put a final '/'.", default="/dpm")
parser.add_option("--delay", action="store", help="Only lists files older than the delay given in seconds. Default is 0.", default='0')
parser.add_option("--out", action="store", help="File where the list of file entry are printed. Default is dump.xml", default="dump.xml")

default_ns_db = 'cns_db'
startdate = time.time()

(options, arguments) = parser.parse_args()
rootdir 	= options.rootdir
xmlfile 	= options.out
cfgfile		= options.dbcfg
startdate	= startdate - int(options.delay)
vo		= options.vo

# Check the config file
if(cfgfile == ''):
	if os.path.exists('/opt/lcg/etc/DPMCONFIG'):
		cfgfile='/opt/lcg/etc/DPMCONFIG'
	else:
		cfgfile='/opt/lcg/etc/NSCONFIG'

ns_host = ns_user = ns_pass = ""
ns_db = default_ns_db
try:
	nsconfig_line = open(cfgfile,'r').readline().strip()
	splitlist = [x.split('/') for x in nsconfig_line.split('@')]
	ns_user = splitlist[0][0]
	ns_pass = splitlist[0][1]
	ns_host = splitlist[1][0]
	if len(splitlist[1]) == 2:
		ns_db = splitlist[1][1]
except IOError:
	sys.stderr.write("Cannot open DPM config file: %s\n" % cfgfile)
	sys.exit(-1)

# Create a connection to the database
try:
	conn = MySQLdb.connect(host=ns_host, user=ns_user, passwd=ns_pass, db=ns_db) 
	sql = "select fileid, parent_fileid, name, filesize, filemode, atime, ctime, csumtype, csumvalue from Cns_file_metadata order by parent_fileid"
	cursor = conn.cursor()
	cursor.execute(sql)
except Exception, e:
	sys.stderr.write("Database connection error: %s\n" % e)
	sys.exit(-1)

curtime = datetime.datetime.isoformat(datetime.datetime.now())
header = '''<?xml version="1.0" encoding="iso-8859-1"?>
<dump recorded="%s">
<for>vo:%s</for>
<entry-set>''' % (curtime, vo)
output = open(xmlfile, 'w')
output.write(header)

fileids = {}
for row in cursor.fetchall():
    fileid, parentid, name, size, filemode, atime, ctime, csumtype, csumvalue = row
    
    if parentid == '' or fileid == '':
        continue   

    if parentid == '0' or parentid == 0L:
        fileids[fileid] = ''
    else:
        try:
            fileids[fileid] = fileids[parentid] + '/' + name 
        except KeyError:
            sys.stderr.write("The file's parent does not exist. Check the DPM database for parents of file with fileid: %s.\n" % str(fileid))
            continue
        except:
            sys.stderr.write("An unkown error occurred for file with fileid: %s.\n" % str(fileid))
            continue

        if int(filemode) > 30000:      # To select files
            # Check that the file is older than the delar
            if (ctime < startdate):
                if (fileids[fileid].find(rootdir)):
                    content = '''<entry name="%s"><size>%s</size><last-accessed>%s</last-accessed><last-modified>%s</last-modified><checksum algorithm="%s">%s</checksum></entry>\n''' % (fileids[fileid], size, atime, ctime, csumtype, csumvalue)
                    output.write(content)

output.write("</entry-set>\n</dump>\n")
output.close()
