#!/usr/bin/python
# For each SE that supports a VO, this tool lists the site, SRM version, the total and used space on that SE, 
# the filling rate of that SE, the %age of total and used space that this SE provides to the VO.

import sys
import os
import commands
import re
from optparse import OptionParser

DEFAULT_TOPBDII = "cclcgtopbdii01.in2p3.fr:2170"


optParser = OptionParser(version="%prog 1.0", description="""For each SE that supports a VO, 
this tool lists the site, SRM version, the total and used space on that SE,
the filling rate of that SE, the %age of total and used space that this SE provides to the VO. """)

optParser.add_option("--vo", action="store", dest="vo", default="biomed",
                  help="Virtual Organisation to query. Defaults to \"biomed\"")
optParser.add_option("--bdii", action="store", dest="bdii", default=DEFAULT_TOPBDII,
                  help="top BDII hostname and port. Defaults to " + DEFAULT_TOPBDII)

optParser.add_option("--limit", action="store", dest="limit", default=9999,
                  help="Max number of SE to check. Defaults to all (9999)")

optParser.add_option("--decimal-mark", action="store", dest="decimal_mark", default=',',
                     help="Decimal marker for csv export. Defaults to comma (','), but some tools may need the dot instead")

optParser.add_option("--no-srm-ver", action="store_true", dest="noversion",
                     help="Do not report SRM implementation version")

optParser.add_option("--csv", action="store", dest="csv", default="",
                     help="Output as CSV format in the gien file, otherwise a human-readable format is displayed on the std output is used.")

optParser.add_option("--debug", action="store_true", dest="debug",
                     help="Add debug traces")

# -------------------------------------------------------------------------
# Definitions, global variables
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()
VO = options.vo
TOPBDII = options.bdii
MAX_SE = int(options.limit)
DECIMAL_MARK = options.decimal_mark
SRM_VER = not options.noversion
CSV = options.csv
DEBUG = options.debug

# LDAP Request to get the Storage Element info
ldapSE = "ldapsearch -x -L -s sub -H ldap://%(TOPBDII)s -b mds-vo-name=local,o=grid \"(&(ObjectClass=GlueSE)(GlueSEUniqueID=%(HOST)s))\" | egrep \"GlueSEImplementationName|GlueSEImplementationVersion|GlueForeignKey: GlueSiteUniqueID=\""

# LDAP Request to get the Storage Area info
ldapSA = "ldapsearch -x -L -s sub -H ldap://%(TOPBDII)s -b mds-vo-name=local,o=grid \"(&(ObjectClass=GlueSA)(GlueChunkKey=GlueSEUniqueID=%(HOST)s)(|(GlueSAAccessControlBaseRule=VO:%(VO)s*)(GlueSAAccessControlBaseRule=%(VO)s*)))\" | egrep \"GlueSATotalOnlineSize|GlueSAUsedOnlineSize\""

# -------------------------------------------------------------------------
# Program main body
# -------------------------------------------------------------------------

# Get the list of SEs from the BDII
status, output = commands.getstatusoutput("lcg-infosites --vo " + VO + " space")
if status <> 0:
    print "lcg-infosites error: ", output
    sys.exit(1)

# Build the list of SE hostnames: filter out header lines, and keep only hostnames
seHostNames = []
nbSE = 0
for line in output.splitlines():
    if ("Reserved" not in line) and ("Nearline" not in line) and ("----------" not in line):
        seHostNames.append(line.split()[-1])
        nbSE += 1
    if nbSE >= MAX_SE: break;


# The result is a multidimensional dictionary:
# site name:
#    hostname:
#        'total': total available size for that SRM implementation, whatever the version
#        'used': space used by the VO for that SRM implementation, whatever the version
resultSE = {}

# Regexp to limit the version number to 3 numbers
matchVer = re.compile("^(\w+.\w+.\w+)")

# -------------------------------------------------------------------------
# For each SE, run an ldap request to get implementation names/versions and storage sizes

for host in seHostNames:
    if DEBUG: print "Checking SE " + host + "..."
    statusSE, outputSE = commands.getstatusoutput(ldapSE % {'TOPBDII': TOPBDII, 'HOST': host})
    statusSA, outputSA = commands.getstatusoutput(ldapSA % {'TOPBDII': TOPBDII, 'HOST': host, 'VO': VO})

    if statusSE <> 0 or statusSA <> 0:
        print "ldapsearch error for SE", host, ":", outputSE, outputSA
        continue;
        
    # Parse the result lines
    output = outputSE + "\n" + outputSA
    totalSE = usedSE = 0
    for line in output.splitlines():
        attrib, value = line.split(":", 1)
        if attrib == "GlueForeignKey":	# line of type: "GlueForeignKey: GlueSiteUniqueID=UKI-LT2-IC-HEP"
            attrib, value = line.split("=")
            siteName = value.strip()
        if attrib == "GlueSEImplementationName":
            implemName = value.strip()
        if attrib == "GlueSEImplementationVersion":
            implemVer = value.strip()
        if attrib == "GlueSATotalOnlineSize":
            totalSE += int(value.strip())
        if attrib == "GlueSAUsedOnlineSize":
            usedSE += int(value.strip())

    # Consistency checks: ignore 0 or negative values
    if totalSE <= 0 or usedSE < 0: 
        print "Skipping " + host + " due to inconsistent data: totalSE=" + str(totalSE) + ", usedSE=" + str(usedSE)
        continue

    # Limit the version number to only 2 figures, like 1.8 instead of 1.8.2-1
    implemVerCut = implemVer
    match = matchVer.match(implemVer)
    if match <> None: implemVerCut = match.group(1)

    # Store results about individual SEs
    if siteName in resultSE:
        resultSE[siteName][host] = {'total': totalSE, 'used': usedSE, 'implName': implemName, 'implVer': implemVerCut }
    else:
        # Create a new entry for that site name
        resultSE[siteName] = { host: {'total': totalSE, 'used': usedSE, 'implName': implemName, 'implVer': implemVerCut } }

# End of loop on SE hostnames


# -------------------------------------------------------------------------
# Display the results

# Calculate the nb of SEs, the total space, and the total used space
totalSpace = usedSpace = nbSE = 0
for site, detailSite in resultSE.iteritems():
    for host, detailHost in detailSite.iteritems():
        nbSE += 1
        totalSpace += detailHost['total']
        usedSpace += detailHost['used']


if CSV != "":
    #--- Display the output in CSV format
    if DEBUG: print "Saving results to " + CSV
    outputf = open(CSV, 'wb')
    outputf.write("sitename; SE hostname; SRM impl; SRM ver; total (GB); used (GB); filling rate (%); % of VO total space; % of VO used space\n")

    for site, detailSite in resultSE.iteritems():
        for host, detailHost in detailSite.iteritems():
            outputf.write(site + ";" + host  + ";" + detailHost['implName'] + ";" + detailHost['implVer'] + ";")
            outputf.write(str(detailHost['total']) + ";" + str(detailHost['used']) + ";")
    
            # Filling rate (%)
            ratio = float(detailHost['used']) * 100 / detailHost['total']
            outputf.write(str(round(ratio, 4)).replace('.', DECIMAL_MARK) + ";")

            # % of VO total space
            ratio = float(detailHost['total']) * 100 / totalSpace
            outputf.write(str(round(ratio, 4)).replace('.', DECIMAL_MARK) + ";")

            # % of VO used space
            ratio = float(detailHost['used']) * 100 / usedSpace
            outputf.write(str(round(ratio, 4)).replace('.', DECIMAL_MARK))
            outputf.write("\n")
    outputf.close()

else:
    #--- Display the output in pretty uhman-readable format

    # Prepare the format of lines to display
    format = "%(site)-24s %(host)-35s %(implname)-6s "
    if SRM_VER: format += "%(implver)-6s "
    format += "%(free)7s %(used)7s %(total)7s "
    format += "%(fillingrate)9s  %(percentVOTotal)9s  %(percentVOUsed)9s\n"
    
    # Header lines
    print "=================================================================================================================================================="
    sys.stdout.write(format % {'site':'Site', 'host':'Hostname', 'implname':'SRM', 'implver':'SRM',
                                   'free':'Free', 'used':'Used', 'total':'Total', 'fillingrate':'Filling',
                                   'percentVOTotal':'% of VO', 'percentVOUsed':'% of VO'})

    sys.stdout.write(format % {'site':'', 'host':'', 'implname':'implem', 'implver':'version',
                                   'free':'space', 'used':'space', 'total':'space', 'fillingrate':'rate',
                                   'percentVOTotal':'total sp.', 'percentVOUsed':'used sp.'})
    sys.stdout.write(format % {'site':'', 'host':'', 'implname':'', 'implver':'',
                                   'free':'(GB)', 'used':'(GB)', 'total':'(GB)', 'fillingrate':'',
                                   'percentVOTotal':'', 'percentVOUsed':''})
    print "=================================================================================================================================================="

    for site, detailSite in resultSE.iteritems():
        for host, detailHost in detailSite.iteritems():
    
            freeSpace = detailHost['total'] - detailHost['used']
            fillingRate = float(detailHost['used']) * 100 / detailHost['total']
            percentVOTotal = float(detailHost['total']) * 100 / totalSpace
            percentVOUsed = float(detailHost['used']) * 100 / usedSpace

            sys.stdout.write(format % {'site':site, 'host':host, 'implname':detailHost['implName'], 'implver':detailHost['implVer'],
                                       'free':freeSpace, 'used':detailHost['used'], 'total':detailHost['total'], 'fillingrate':"%3.2f%%" % fillingRate,
                                       'percentVOTotal':"%3.2f%%" % percentVOTotal, 'percentVOUsed':"%3.2f%%" % percentVOUsed})
