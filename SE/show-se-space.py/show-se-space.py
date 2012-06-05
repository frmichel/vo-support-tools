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


# -------------------------------------------------------------------------
# Definitions, global variables
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()
VO = options.vo
TOPBDII = options.bdii
MAX_SE = int(options.limit)
DECIMAL_MARK = options.decimal_mark

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
    if nbSE > MAX_SE: break;
    nbSE += 1


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
    print "Checking SE " + host + "..."
    statusSE, outputSE = commands.getstatusoutput(ldapSE % {'TOPBDII': TOPBDII, 'HOST': host})
    statusSA, outputSA = commands.getstatusoutput(ldapSA % {'TOPBDII': TOPBDII, 'HOST': host, 'VO': VO})

    if statusSE <> 0 or statusSA <> 0:
        print "ldapsearch error for SE", host, ":", outputSE, outputSA
        continue;
        
    # Parse the result lines
    output = outputSE + "\n" + outputSA
    totalSE = usedSE = 0
    for line in output.splitlines():
        attrib, value = line.split(":")
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

totalSpace = usedSpace = nbSE = 0
for site, detailSite in resultSE.iteritems():
    for host, detailHost in detailSite.iteritems():
        nbSE += 1
        totalSpace += detailHost['total']
        usedSpace += detailHost['used']

print "sitename; hostname; SRM impl; SRM ver; total (GB); used (GB); filling rate (%); % of VO total space; % of VO used space"

for site, detailSite in resultSE.iteritems():
    for host, detailHost in detailSite.iteritems():
        sys.stdout.write(site + ";" + host  + ";" + detailHost['implName'] + ";" + detailHost['implVer'] + ";")
        sys.stdout.write(str(detailHost['total']) + ";" + str(detailHost['used']) + ";")

        # Filling rate (%)
        ratio = float(detailHost['used']) * 100 / detailHost['total']
        sys.stdout.write(str(round(ratio, 4)).replace('.', DECIMAL_MARK) + ";")

        # % of VO total space
        ratio = float(detailHost['total']) * 100 / totalSpace
        sys.stdout.write(str(round(ratio, 4)).replace('.', DECIMAL_MARK) + ";")

        # % of VO used space
        ratio = float(detailHost['used']) * 100 / usedSpace
        sys.stdout.write(str(round(ratio, 4)).replace('.', DECIMAL_MARK))
        print
