#!/usr/bin/python
# This script lists the srm urls of SEs that are in production.
# This script output is the filename given as argument or stdout if no filename is specified.
# The output dump file list the following information for each file:
#   - the SE
#   - the site
#   - the SA free size
#   - the SA total size
#   - the srm url of the SE
#   - the output file
#   - the xml output file

import sys
import os
import commands
import csv
import re
import stat
import datetime
import xml.dom.minidom

from xml.sax import parseString
from xml.sax.handler import ContentHandler
from operator import itemgetter, attrgetter
from optparse import OptionParser


# Below is an example of the XML stream parsed by the script
# that is get from Lavoisier view find-se-vo-full
#
#<services vo="biomed">
#    <service type="SE" id="ccsrm02.in2p3.fr">
#        <HostName>ccsrm02.in2p3.fr</HostName>
#        <Id>ccsrm02.in2p3.fr</Id>
#        <SiteId>IN2P3-CC</SiteId>
#        <Status>Production</Status>
#        <ImplementationName>dCache</ImplementationName>
#        <SEName>IN2P3-CC</SEName>
#        <ImplementationVersion>2.6.9-1</ImplementationVersion>
#        <SETotalOnlineSize>234971</SETotalOnlineSize>
#        <SESizeFree>110818</SESizeFree>
#        <SEUsedOnlineSize>124153</SEUsedOnlineSize>
#        <SRMv2 id="httpg://ccsrm02.in2p3.fr:8443/srm/managerv2">
#            <Version>2.2.0</Version>
#            <Status>OK</Status>
#            <Port>8443</Port>
#            <SRMUrl>srm://ccsrm02.in2p3.fr:8443</SRMUrl>
#        </SRMv2>
#        <SRMv1 id="httpg://ccsrm02.in2p3.fr:8443/srm/managerv1">
#            <Version>1.1.0</Version>
#            <Status>OK</Status>
#            <Port>8443</Port>
#            <SRMUrl>srm://ccsrm02.in2p3.fr:8443</SRMUrl>
#        </SRMv1>
#        <StorageArea>
#            <SAPath>/pnfs/in2p3.fr/data/biomed/</SAPath>
#            <SATotalOnlineSize>2199</SATotalOnlineSize>
#            <SAUsedOnlineSize>937</SAUsedOnlineSize>
#            <SAReservedOnlineSize>2199</SAReservedOnlineSize>
#            <SAFreeOnlineSize>1262</SAFreeOnlineSize>
#        </StorageArea>
#    </service>
#</services>


optParser = OptionParser(version="%prog 1.0", description="""
This script lists the srm urls of SEs that are in production.
This script output is the filename given as argument or stdout if no filename is specified.
The output dump file list the following information for each file:
the SE, the SA free size, the SA total size, the srm url of the SE
""")

optParser.add_option("--vo", action="store", dest="vo", default='biomed',
                     help="the vo. Defaults to 'biomed'")

optParser.add_option("--lavoisier-host", action="store", dest="lavoisier_host", default='localhost',
                     help="the host where Lavoisier is called")

optParser.add_option("--lavoisier-port", action="store", dest="lavoisier_port", default='8080',
                     help="the port where Lavoisier is called")        

optParser.add_option("--xml-output-file", action="store", dest="xml_output_file", default='',
                     help="xml output file.")

optParser.add_option("--output-file", action="store", dest="output_file", default='',
                     help="output file.")

optParser.add_option("--debug", action="store_true", dest="debug",
                     help="Add debug traces")

# -------------------------------------------------------------------------
# Parameters check
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()

VO = options.vo
LAVOISIER_HOST = options.lavoisier_host
LAVOISIER_PORT = options.lavoisier_port

# Check options validity
if options.output_file == '': 
    optParser.error("Option --output-file must be affected a value")
    exit(1)

# Build the file descriptor for output file
f = ''
try:
    f = open(options.output_file,'w')
except Exception,e:
    print "Can't create output file. Message: ",e
    exit(1)

xml_out = ''
try: 
    xml_out = open(options.xml_output_file,'w')
except Exception,e:
    print "Can't create xml output file. Message: ", e
    exit(1)

# Query Lavoisier find-se-vo-full view
CURL_CMD = "curl --silent --connect-timeout 60 --max-time 120 --url http://"+LAVOISIER_HOST+":"+LAVOISIER_PORT+"/lavoisier/find-se-vo-full/"+VO+"?accept=xml"

# If in debug mode: output Lavoisier query
if options.debug:
    print "lavoisier query: " + CURL_CMD

# Querying Lavoisier
status,output = commands.getstatusoutput(CURL_CMD)

# If debug mode: print Lavoisier output
if options.debug:
    print "Lavoisier output: " + output

# If Lavoisier querying failed: output an error message then exit
if status <> 0:
    print "Error when querying Lavoisier. Lavoisier query: " + CURL_CMD + " Lavoisier output: " + output
    exit(1)        

# Method that return the text content of a Tag
def getText(nodelist):
    rc = []
    for node in nodelist:
        if node.nodeType == node.TEXT_NODE:
            rc.append(node.data)
    return ''.join(rc)

# Build the dom document from curl call output
dom = ''
try:
    dom = xml.dom.minidom.parseString(output)
except Exception,e:
    print "XML parsing error. Message:", e    
    exit(1)

xml_out.write('<ses>\n')
urls = []

# Get the services tags
services = dom.getElementsByTagName("service")

# Iterate on each service
for service in services:

    # Check the Status element
    if service.getElementsByTagName("Status").length == 0:
        print 'Error: no Status element for entry ' + service
        continue
    status = service.getElementsByTagName("Status")[0]

    # Ignore services not in production or in downtime
    if getText(status.childNodes).lower() != "production":
        continue
    if service.getElementsByTagName("Downtime"):
        continue

    # Get the fields to print: HostName, SA Free size, SA Total size, SRM Url
    if service.getElementsByTagName("HostName").length == 0:
        print 'Error: no Hostname element'
        continue
    hostname = getText(service.getElementsByTagName("HostName")[0].childNodes)
    
    if service.getElementsByTagName("SiteId").length == 0:
        print 'Error: no SiteId element for Hostname ' + hostname
        continue
    site = getText(service.getElementsByTagName("SiteId")[0].childNodes)        
    
    if service.getElementsByTagName("StorageArea").length == 0:
        print 'Error: no StorageArea element for Hostname ' + hostname
        continue
    sa = service.getElementsByTagName("StorageArea")[0]
    
    if service.getElementsByTagName("SATotalOnlineSize").length == 0:
        print 'Error: no SATotalOnlineSize element for Hostname ' + hostname
        continue
    satotalsize = getText(sa.getElementsByTagName("SATotalOnlineSize")[0].childNodes)
    
    if service.getElementsByTagName("SAFreeOnlineSize").length == 0:
        print 'Error: no SAFreeOnlineSize element for Hostname ' + hostname
        continue
    safreesize = getText(sa.getElementsByTagName("SAFreeOnlineSize")[0].childNodes)
    
    if service.getElementsByTagName("SRMv2").length == 0 and service.getElementsByTagName("SRMv1").length == 0:
        print 'Error: no SRMv1 nor SRMv2 element for Hostname ' + hostname
        continue

    srmurl = ''
    if service.getElementsByTagName("SRMv2").length != 0:
        if service.getElementsByTagName("SRMv2")[0].getElementsByTagName("SRMUrl").length != 0:
            srmurl = getText(service.getElementsByTagName("SRMv2")[0].getElementsByTagName("SRMUrl")[0].childNodes)    
    if srmurl == '':
        if service.getElementsByTagName("SRMv1").length != 0:
            if service.getElementsByTagName("SRMv1")[0].getElementsByTagName("SRMUrl").length != 0:
                srmurl = getText(service.getElementsByTagName("SRMv1")[0].getElementsByTagName("SRMUrl")[0].childNodes)
    if srmurl == '':
        print 'Error: no SRMv1 nor SRMv2 URL for Hostname ' + hostname
        continue

    # Do not add multiple times the same SURL
    if options.debug:
        if srmurl in urls:
            print "Ignoring duplicate SRM entry: " + srmurl    
    if not srmurl in urls:
        urls.append(srmurl)
        # Write line to output file
        f.write(hostname+' '+site+' '+safreesize+' '+satotalsize+' '+srmurl+'\n')
        xml_out.write('<se><hostname>'+hostname+'</hostname><site>'+site+'</site><freeSpaceBefore>'+safreesize+'</freeSpaceBefore><freeSpaceAfter>N/A</freeSpaceAfter><totalSize>'+satotalsize+'</totalSize><srmUrl>'+srmurl+'</srmUrl><status>ongoing</status></se>\n')

xml_out.write('</ses>')

# Close the file descriptor
f.close()
xml_out.close()

exit(0)

