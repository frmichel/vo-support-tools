#!/usr/bin/python
# gocdb-service-status.py, v1.0
# Author: F. Michel, CNRS I3S, biomed VO support
#
# This tool queries the GOCDB for status information (downtime, not monitored, not in production)
# concerning all SEs, CEs and WMSs supporting a VO (defaults to biomed).
# Results are displayed on the standard output either with "pretty" human readable format
# or '|' separator like: service flavour (SE, CE, WMS)|hostname|status list
#
# Requirements: 
#    Python > 2.4, curl (tested with curl-7.15.5-9.el5_6.3)
#    Valid grid proxy certificate
#
# Typically this tool should be run in the cron like:
# 34,10,40 * * * * . /etc/profile; /home/fmichel/biomed-support-tools/gocdb-service-status.py --pretty > /tmp/gocdb-service-status-$$.txt; mv /tmp/gocdb-service-status-$$.txt $HOME/public_html/gocdb-service-status.txt
 
import sys
import os
import commands
import re
import time
from optparse import OptionParser
from xml.sax import parseString
from xml.sax.handler import ContentHandler

optParser = OptionParser(version="%prog 1.0", description="""This tool retrieves status information
(downtime, not monitored, not in production) from the GOCDB, for all SEs supporting
a given VO (defaults to biomed).""")

optParser.add_option("--vo", action="store", dest="vo", default="biomed",
                  help="Virtual Organisation to query. Defaults to \"biomed\"")
optParser.add_option("--nose", action="store_true", dest="noSe", default=False,
                  help="Do not check status of Storage Elements")
optParser.add_option("--noce", action="store_true", dest="noCe", default=False,
                  help="Do not check status of Computing Elements")
optParser.add_option("--nowms", action="store_true", dest="noWms", default=False,
                  help="Do not check status of Workload Management Systems")
optParser.add_option("--pretty", action="store_true", dest="pretty", default=False,
                  help="Format output for human reader")

optParser.add_option("--cert", action="store", dest="cert_file", 
                  default=os.environ['HOME'] + "/.globus/usercert.pem",
                  help="Public key certificate. Defaults to $HOME/.globus/usercert.pem")
optParser.add_option("--key", action="store", dest="key_file", 
                  default=os.environ['HOME'] + "/.globus/userkey.pem",
                  help="Private key. Defaults to $HOME/.globus/userkey.pem")
optParser.add_option("--pass", action="store", dest="passphrase", 
                  default=os.environ['HOME'] + "/.globus/proxy_pass.txt",
                  help="File containing the private key pass phrase. Defaults to $HOME/.globus/proxy_pass.txt")

optParser.add_option("--debug", action="store_true", dest="debug", default=False, 
                     help="Set debug mode on")

# -------------------------------------------------------------------------
# Definitions, global variables
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()

DEBUG = options.debug
VO = options.vo
PRETTY = options.pretty

SE = not options.noSe
CE = not options.noCe
WMS = not options.noWms

CERT_FILE = options.cert_file
KEY_FILE = options.key_file
KEY_PASS = options.passphrase


# The curl is used instead of Python std lib like HTTPSConnection,
# as it does not support key pass phrase nor timeouts (in Python 2.4)
CURL_CMD="curl --silent --insecure --connect-timeout 30 --max-time 60 --pass `cat " + KEY_PASS + "` --cert " + CERT_FILE + " --key " + KEY_FILE + " --url "

GOCDB_DOWNTIME_URL = "https://goc.egi.eu/gocdbpi/private/?method=get_downtime&ongoing_only=yes&topentity="
GOCDB_SERVICE_URL="https://goc.egi.eu/gocdbpi/private/?method=get_service_endpoint&hostname="

# Global variables used during xml parsing
serviceStatus = []

now = time.strftime('%Y-%m-%d %H:%M:%S %Z',time.localtime())  

isInProduction = False
isMonitored = False



# -------------------------------------------------------------------------
# SAX handler for GOCDB downtime response: simple detects the presence of
# a downtimes elements in the xml stream
# -------------------------------------------------------------------------
class SaxDowntimeHandle(ContentHandler):

    def startElement(self, name, attrs):
        global serviceStatus
        if name.lower() == "downtime" and "downtime" not in serviceStatus: 
            serviceStatus.append("downtime")

# -------------------------------------------------------------------------
# SAX handler for GOCDB service response: looks for elements IN_PRODUCTION
# or NODE_MONITORED with value N (=No)
# -------------------------------------------------------------------------
class SaxServiceHandle(ContentHandler):

    def startElement(self, name, attrs):
        global isInProduction, isMonitored, serviceStatus
        isInProduction = False
        if name.lower() == "in_production": isInProduction = True
        isMonitored = False
        if name.lower() == "node_monitored": isMonitored = True

    def characters(self, content):
        global serviceStatus
        if isInProduction and content.lower() == "n": 
            if "not in production" not in serviceStatus: 
                serviceStatus.append("not in production")
        if isMonitored and content.lower() == "n": 
            if "not monitored" not in serviceStatus: 
                serviceStatus.append("not monitored")

# -------------------------------------------------------------------------
# This function sends the requests to the GOCDB, parses the XML response, 
# and prints the results line if any abnormal status is found
# Param: 
#   seHost: hostname of the node to check
# -------------------------------------------------------------------------
def checkStatus(seHost):

    # Check if the node is in status downtime
    cmdString = CURL_CMD + "\"" + GOCDB_DOWNTIME_URL + seHost + "\""
    if DEBUG: print "Command: " + cmdString
    status, output = commands.getstatusoutput(cmdString)
    if DEBUG: print "Response: " + output
    if status <> 0:
        print "Error when querying the GOCDB for downtimes: " + output
    else:
        parseString(output, SaxDowntimeHandle())
    
    # Check if the node is in status "not in production" or "not monitored"
    cmdString = CURL_CMD + "\"" + GOCDB_SERVICE_URL + seHost + "\""
    if DEBUG: print "Command: " + cmdString
    status, output = commands.getstatusoutput(cmdString)
    if DEBUG: print "Response: " + output
    if status <> 0:
        print "Error when querying the GOCDB for service status: " + output
    else:
        parseString(output, SaxServiceHandle())

    # Display the node status
    if len(serviceStatus) <> 0:
        if PRETTY: sys.stdout.write("  %-8s%-48s" % (service, seHost))
        else: sys.stdout.write(service + "|" + seHost + "|")
        isFirst = True
        for status in serviceStatus:
            if isFirst: sys.stdout.write(status)
            else: sys.stdout.write(", " + status)
            isFirst = False
        print

# -------------------------------------------------------------------------
# Program main body
# -------------------------------------------------------------------------

if SE:
    # Get the list of SEs from the BDII
    status, output = commands.getstatusoutput("lcg-infosites --vo " + VO + " space")
    if status <> 0:
        print "lcg-infosites error: ", output
        sys.exit(1)
    # Build the list of SEs: filter out header lines, and keep only hostnames
    listSE = []
    for line in output.splitlines():
        if ("Reserved" not in line) and ("Nearline" not in line) and ("----------" not in line):
            listSE.append(line.split()[-1])

if CE:
    # Get the list of CEs from the BDII
    status, output = commands.getstatusoutput("lcg-infosites --vo " + VO + " -v 2 ce")
    if status <> 0:
        print "lcg-infosites error: ", output
        sys.exit(1)
    # Build the list of CEs: filter out header lines, and keep only hostnames
    listCE = []
    for line in output.splitlines():
        if ("Operating System" not in line) and ("----------" not in line):
            listCE.append(line.split()[-1])

if WMS:
    # Get the list of WMSs from the BDII
    status, output = commands.getstatusoutput("lcg-infosites --vo " + VO + " wms")
    if status <> 0:
        print "lcg-infosites error: ", output
        sys.exit(1)
    # Build the list of WMS: keep only hostnames
    listWMS = []
    matcher = re.compile("https://(.+):")
    for line in output.splitlines():
        match = matcher.match(line)
        if match <> None: listWMS.append(match.group(1))

if DEBUG:
    if SE: print "SEs:", listSE
    if CE: print "CEs:", listCE
    if WMS: print "WMS:", listWMS

# Loop on all nodes and check the GOCDB for each one
if PRETTY:
    print "# " + now + ". VO: " + VO
    print "#--------------------------------------------------------------------------------"
    print "# Service Hostname                                        GOCDB Status"
    print "#--------------------------------------------------------------------------------"

if SE:
    for host in listSE:
        serviceStatus = []
        service = "SE"
        checkStatus(host)
    if PRETTY: print "#--------------------------------------------------------------------------------"
if CE:
    for host in listCE:
        serviceStatus = []
        service = "CE"
        checkStatus(host)
    if PRETTY: print "#--------------------------------------------------------------------------------"
if WMS:
    for host in listWMS:
        serviceStatus = []
        service = "WMS"
        checkStatus(host)
