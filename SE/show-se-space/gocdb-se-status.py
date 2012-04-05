#!/usr/bin/python
# gocdb-se-status.py, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This tool queries the GOCDB for downtime and status information (not monitored, not in production),
# concerning all SEs supporting biomed.
# Results are displayed on the standard output, one SE/line: se_hostname|comma-separated list of statuses

import sys, os, commands
import httplib, urllib2
from xml.sax import make_parser
from xml.sax.handler import ContentHandler

# ----- Environement ----------------------------------------

VO = "biomed"
GOCDB_DOWNTIME_URL = "https://goc.egi.eu/gocdbpi/private/?method=get_downtime&ongoing_only=yes&topentity="
GOCDB_SERVICE_URL="https://goc.egi.eu/gocdbpi/private/?method=get_service_endpoint&hostname="
CNX_TIMEOUT = 30 # unused for now, only available in HTTPSConnection of Python >2.6

PROXY_PASS = "/home/fmichel/.globus/proxy_pass.txt" # no way to pass it automatically, TBC
CERT_FILE = "/home/fmichel/.globus/usercert.pem"
KEY_FILE = "/home/fmichel/.globus/userkey.pem"

seStatus = []

#-------- Classes & functions ----------------------------------------------------

# HTTPS Client Auth solution for urllib2, inspired by
# http://bugs.python.org/issue3466 and improved by David Norton of Three Pillar Software. 
# In this implementation, we use properties passed in rather than static module fields.
class HTTPSClientAuthHandler(urllib2.HTTPSHandler):
    def __init__(self, key, cert):
        urllib2.HTTPSHandler.__init__(self)
        self.key = key
        self.cert = cert
    def https_open(self, req):
        # Rather than pass in a reference to a connection class, we pass in
        # a reference to a function which, for all intents and purposes,
        # will behave as a constructor
        return self.do_open(self.getConnection, req)
    def getConnection(self, host):
        return httplib.HTTPSConnection(host, key_file=self.key, cert_file=self.cert)

# SAX handlerfor GOCDB downtime response: simple detects the presence of a downtimes elements in the xml stream
class SaxDowntimeHandle(ContentHandler):
    def startElement(self, name, attrs):
        if name.lower() == "downtime":
            if "downtime" not in seStatus: seStatus.append("downtime")

#-----------------------------------------------------------

# This function sends the requests to the GOCDB, parses the XML response, 
# and prints the results line if any abnormal status is found
# Param: 
#   seHost: hostname of the SE to check
def checkSEStatus(seHost):
    # Check if SE is in status downtime
    opener = urllib2.build_opener(HTTPSClientAuthHandler(KEY_FILE, CERT_FILE))
    urllib2.install_opener(opener)
    response = urllib2.urlopen(GOCDB_DOWNTIME_URL + seHost)
    if response.code <> 200:
        print "HTTP error when connecting to GOCDB: " + response.code + ", can't read status of SE " + seHost
    else:
        parser = make_parser()
        parser.setContentHandler(SaxDowntimeHandle())
        parser.parse(response)
    
    # Display the SE status
    if len(seStatus) <> 0:
        sys.stdout.write(seHost + "|")
        isFirst = True
        for status in seStatus:
            if isFirst: sys.stdout.write(status)
            else: sys.stdout.write(", " + status)
            isFirst = False
        print

#----------- Program main body ----------------------------------------------

# Test with one SE, comment out these 2 lines for real case
checkSEStatus("darkmass.wcss.wroc.pl")
sys.exit()

# Get the list of SEs from the BDII
status, output = commands.getstatusoutput("lcg-infosites --vo " + VO + " space")
if status <> 0:
    print "lcg-infosites error: ", output
    sys.exit(1)

# Build the list of SEs: filter out header lines, and keep only SE hostnames
listSE = []
for line in output.splitlines():
    if ("Reserved" not in line) and ("Nearline" not in line) and ("----------" not in line):
        listSE.append(line.split()[-1])

# Loop on all SEs and check the GOCDB for each one
for seHost in listSE:
    seStatus = []
    checkSEStatus(seHost)
