#!/usr/bin/python
# Retrieve the number and size of storage elements available for a VO (defaults to biomed),
# sorted by SRM implementation and version. Cumulative values of used and total sizes are
# calculated per SRM flavour and version.

import sys
import os
import commands
import re
from optparse import OptionParser

DEFAULT_TOPBDII = "cclcgtopbdii01.in2p3.fr:2170"

optParser = OptionParser(version="%prog 1.0", description="""Retrieve the number and size of storage 
elements available for a VO (defaults to biomed), sorted by SRM implementation and version""")

optParser.add_option("--vo", action="store", dest="vo", default="biomed",
                  help="Virtual Organisation to query. Defaults to \"biomed\"")
optParser.add_option("--bdii", action="store", dest="bdii", default=DEFAULT_TOPBDII,
                  help="top BDII hostname and port. Defaults to " + DEFAULT_TOPBDII)
optParser.add_option("--only", action="store", dest="only", default=9999,
                  help="Max number of SE to check. Defaults to all (9999)")

# -------------------------------------------------------------------------
# Definitions, global variables
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()
VO = options.vo
TOPBDII = options.bdii
MAX_SE = int(options.only)

# LDAP Request to get the Storage Element info
ldapSE = "ldapsearch -x -L -s sub -H ldap://%(TOPBDII)s -b mds-vo-name=local,o=grid \"(&(ObjectClass=GlueSE)(GlueSEUniqueID=%(HOST)s))\" | egrep \"GlueSEImplementationName|GlueSEImplementationVersion\""

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

# Build the list of SEs: filter out header lines, and keep only hostnames
listSE = []
nbSE = 0
for line in output.splitlines():
    if ("Reserved" not in line) and ("Nearline" not in line) and ("----------" not in line):
        listSE.append(line.split()[-1])
    if nbSE > MAX_SE: break;
    nbSE += 1


# The result is a multidimensional dictionary:
# SRM name
#    'total': total available size for that SRM implementation, whatever the version
#    'used': space used by the VO for that SRM implementation, whatever the version
#    'nbOcc': number of SEs with that SRM iplem, whatever the version
#    SRM implem version
#        'total': total available size
#        'used': space used by the VO
#        'nbOcc': number of SEs with that SRM iplem and version
result = {}

# Regexp to limit the version number to 2 numbers
matchVer = re.compile("^(\w+.\w+.\w+)")


# -------------------------------------------------------------------------
# For each SE, run an ldap request to get implementation names/versions and storage sizes
for host in listSE:
    print "Checking SE " + host + "..."
    statusSE, outputSE = commands.getstatusoutput(ldapSE % {'TOPBDII': TOPBDII, 'HOST': host})
    statusSA, outputSA = commands.getstatusoutput(ldapSA % {'TOPBDII': TOPBDII, 'HOST': host, 'VO': VO})

    if statusSE <> 0 or statusSA <> 0:
        print "ldapsearch-se.sh error for SE", host, ":", outputSE, outputSA
        continue;
        
    # Parse the result lines
    output = outputSE + "\n" + outputSA
    totalSE = usedSE = 0
    for line in output.splitlines():
        attrib, value = line.split(":")
        if attrib == "GlueSEImplementationName":
            implemName = value.strip()
        if attrib == "GlueSEImplementationVersion":
            implemVer = value.strip()
        if attrib == "GlueSATotalOnlineSize":
            totalSE += int(value.strip())
        if attrib == "GlueSAUsedOnlineSize":
            usedSE += int(value.strip())

    # Consistency checks: ignore 0 of negative values
    if totalSE <= 0 or usedSE <= 0: 
        print "Skipping " + host + " due to inconsistent data."
        continue

    # Limit the version number to only 2 figures, like 1.8 instead of 1.8.2-1
    implemVerCut = implemVer
    match = matchVer.match(implemVer)
    if match <> None: implemVerCut = match.group(1)

    if implemName in result:
        if implemVerCut in result[implemName]:
            # Add SRM implem/version data to the existing entry
            total = result[implemName][implemVerCut]['total']
            used = result[implemName][implemVerCut]['used']
            nbOcc = result[implemName][implemVerCut]['nbOcc']
            result[implemName][implemVerCut] = {'total': total + totalSE, 'used': used + usedSE, 'nbOcc': nbOcc + 1}
        else:
            # Create a new entry for that version
            result[implemName][implemVerCut] = {'total': totalSE, 'used': usedSE, 'nbOcc': 1}
            
        # Update artial results for this implementation name (whatever the version)
        result[implemName]['total'] += totalSE
        result[implemName]['used'] += usedSE
        result[implemName]['nbOcc'] += 1
        
    else:
        # Create a new entry for that implementation and version
        result[implemName] = { implemVerCut: {'total': totalSE, 'used': usedSE, 'nbOcc': 1},
               'total': totalSE, 'used': usedSE, 'nbOcc': 1 }

    # --- End of loop on SE hostnames --- 


# -------------------------------------------------------------------------
# Display the results

# Prepare the finla counts: calculate the total number of SE and storage space (to compute percentages)
nbSETotal = totalTotal = totalUsed = 0 
for implemName, implemDetail in result.iteritems():
    nbSETotal += implemDetail['nbOcc']
    totalTotal += implemDetail['total']
    totalUsed += implemDetail['used']

print "Implementation  Version  NbOcc            Total space             Used space"
print "==================================================================================="
format = "%(implname)-16s%(implver)-8s%(nbOcc)6i%(nbOccPercent)7s%(total)16i%(totalPercent)7s%(used)16i%(usedPercent)7s\n"
for implemName, implemDetail in result.iteritems():
    if implemName <> 'total' and implemName <> 'used' and implemName <> 'nbOcc':
        sys.stdout.write(format % {'implname': implemName,
                                   'implver': "",
                                   'nbOcc': implemDetail['nbOcc'],
                                   'nbOccPercent': "(" + str(implemDetail['nbOcc']*100/nbSETotal) + "%)",
                                   'total': implemDetail['total'],
                                   'totalPercent': "(" + str(implemDetail['total']*100/totalTotal) + "%)",
                                   'used': implemDetail['used'],
                                   'usedPercent': "(" + str(implemDetail['used']*100/totalUsed) + "%)"})
        print "-----------------------------------------------------------------------------------"
        for implemVer, implemVerDetail in implemDetail.iteritems():
            if implemVer <> 'total' and implemVer <> 'used' and implemVer <> 'nbOcc':
                sys.stdout.write(format % {'implname': "",
                                           'implver': implemVer,
                                           'nbOcc': implemVerDetail['nbOcc'],
                                           'nbOccPercent': "",
                                           'total': implemVerDetail['total'],
                                           'totalPercent': "",
                                           'used': implemVerDetail['used'],
                                           'usedPercent': ""})
    print "==================================================================================="

