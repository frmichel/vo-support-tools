#!/usr/bin/python
# This script lists the access URLs of SEs in production. Access URLs are preferably gsiftp, or srm otherwise.
# This script output is the filename given as argument or stdout if no filename is specified.
# The output dump file list the following information for each SE:
#   - SE hostname
#   - site name
#   - SA free size
#   - SA total size
#   - srm URL
#   - gsiftp URL if any
# In addition, an xml file is produced with the list of SEs, free and available space on each, and site names.

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


# Below is an example of the XML stream retrieved from Lavoisier view find-se-vo-full
# and parsed by this script.
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
#        <GridFTPAccessProtocol id="GFTP-ccdcacli022@gridftp-ccdcacli022Domain">
#            <Version>1.0.0</Version>
#            <Endpoint>gsiftp://ccdcacli022.in2p3.fr:2811</Endpoint>
#            <GsiftpUrl>gsiftp://ccdcacli022.in2p3.fr:2811/pnfs/in2p3.fr/data/biomed/</GsiftpUrl>
#        </GridFTPAccessProtocol>#        <StorageArea>
#            <SAPath>/pnfs/in2p3.fr/data/biomed/</SAPath>
#            <SATotalOnlineSize>2199</SATotalOnlineSize>
#            <SAUsedOnlineSize>937</SAUsedOnlineSize>
#            <SAReservedOnlineSize>2199</SAReservedOnlineSize>
#            <SAFreeOnlineSize>1262</SAFreeOnlineSize>
#        </StorageArea>
#    </service>
#</services>


optParser = OptionParser(version="%prog 1.0", description="""
This script lists the access URLs of SEs in production. Access URLs are preferably gsiftp, or srm if gsiftp is not supported.
This script output is the filename given as argument or stdout if no filename is specified.
The output lists the following information for each SE:
SE hostname, SA free size, SA total size, srm URL, gsiftp URL is any.
An xml output file dedicated for web status display lists the SEs, free space, available space, and site names. It 
""")

optParser.add_option("--vo", action="store", dest="vo", default='biomed',
                     help="the vo. Defaults to 'biomed'")

optParser.add_option("--lavoisier-host", action="store", dest="lavoisier_host", default='localhost',
                     help="the host where Lavoisier is called. Defaults to localhost.")

optParser.add_option("--lavoisier-port", action="store", dest="lavoisier_port", default='8080',
                     help="the port where Lavoisier is called. Defaults to 8080.")

optParser.add_option("--use-srm-url", action="store_true", dest="use_srm_url",
                     help="For SEs with no gsiftp URL, use the SRM as the access URL instead. By default, only SEs with a gsiftp URL are taken into account.")

optParser.add_option("--xml-output-file", action="store", dest="xml_output_file", default='',
                     help="xml output file. Mandatory.")

optParser.add_option("--output-file", action="store", dest="output_file", default='',
                     help="output file. Mandatory.")

optParser.add_option("--max", action="store", dest="maxNbSEs", default='9999',
                     help="Maximum number of SEs to list. Defaults to 9999 = none.")

optParser.add_option("--debug", action="store_true", dest="debug",
                     help="Add debug traces")

# -------------------------------------------------------------------------
# Parameters check
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()

VO = options.vo
LAVOISIER_HOST = options.lavoisier_host
LAVOISIER_PORT = options.lavoisier_port
USE_SRM_URL = options.use_srm_url

# Check options validity
if options.output_file == '': 
    optParser.error("Option --output-file is mandatory.")
    exit(1)

if options.xml_output_file == '':
    optParser.error("Option --xml-output-file is mandatory.")
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
srmUrls = []
gsiftpUrls = []
nbSEs = 0

# Get the services tags
services = dom.getElementsByTagName("service")

# Iterate on each service
for service in services:

    if nbSEs >= int(options.maxNbSEs):
        if options.debug:
            print 'Reached ' + str(nbSEs) +' SEs. Stopping.'
        break

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

    # Read the gsiftp URL if any
    gsiftpUrl = ''
    if service.getElementsByTagName("GridFTPAccessProtocol").length == 1:
        if service.getElementsByTagName("GridFTPAccessProtocol")[0].getElementsByTagName("GsiftpUrl").length ==1:
            gsiftpUrl = getText(service.getElementsByTagName("GridFTPAccessProtocol")[0].getElementsByTagName("GsiftpUrl")[0].childNodes)

    # Read the srm URL first in SRMv2 and SRMv1 otherwise
    srmUrl=''
    if service.getElementsByTagName("SRMv2").length == 1:
            if service.getElementsByTagName("SRMv2")[0].getElementsByTagName("SRMUrl").length == 1:
                srmUrl = getText(service.getElementsByTagName("SRMv2")[0].getElementsByTagName("SRMUrl")[0].childNodes)    
    if srmUrl == '':
        if service.getElementsByTagName("SRMv1").length == 1:
            if service.getElementsByTagName("SRMv1")[0].getElementsByTagName("SRMUrl").length == 1:
                srmUrl = getText(service.getElementsByTagName("SRMv1")[0].getElementsByTagName("SRMUrl")[0].childNodes)

    if srmUrl == '':
        print 'Error: no SRMv1 nor SRMv2 urls for Hostname ' + hostname
        continue
    else:
        # In case there is no gsiftp URL, we use the SRM url as the access url (if option --use-srm-url is present)
        if gsiftpUrl == '':
            if USE_SRM_URL:
                gsiftpUrl = srmUrl
            else:
                # Ignore SEs with no an gsiftp URL
                continue
 
    # Do not add multiple times the same SURL
    if options.debug:
        if ((srmUrl in srmUrls) or (gsiftpUrl in gsiftpUrls)):
            print "Ignoring duplicate url entry: " + srmUrl + " " + gsiftpUrl
    if ((not srmUrl in srmUrls) and (not gsiftpUrl in gsiftpUrls)):
        srmUrls.append(srmUrl)
        gsiftpUrls.append(gsiftpUrl)
        # Write line to output file
        f.write(hostname + ' ' + site + ' ' + safreesize + ' ' + satotalsize + ' ' + srmUrl + ' ' + gsiftpUrl + '\n')
        xml_out.write('<se>\n' +
            '  <hostname>' + hostname + '</hostname>\n' +
            '  <site>' + site + '</site>\n' +
            '  <freeSpaceBefore>' + safreesize + '</freeSpaceBefore>\n' +
            '  <freeSpaceAfter>N/A</freeSpaceAfter>\n' +
            '  <totalSize>' + satotalsize + '</totalSize>\n' +
            '  <url>' + gsiftpUrl + '</url>\n' +
            '  <status>Ongoing</status>\n' +
            '</se>\n')

        # Count the number of SEs listed so far
        nbSEs += 1
        
    # end of the for loop

xml_out.write('</ses>')

# Close the file descriptors
f.close()
xml_out.close()

exit(0)

