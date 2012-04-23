#!/usr/bin/python

import sys
import os
import commands
import re
from optparse import OptionParser

DEFAULT_TOPBDII = "cclcgtopbdii01.in2p3.fr:2170"

optParser = OptionParser(version="%prog 1.0", description="""Look for all StoRM and dCache SEs and checks if each 
is a default or close SE of a CE or CREAM CE""")
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

# LDAP Request to get the SE SRM implementation
ldapSRMImplem = "ldapsearch -x -L -s sub -H ldap://%(TOPBDII)s -b mds-vo-name=local,o=grid \"(&(ObjectClass=GlueSE)(GlueSEUniqueID=%(HOST)s))\" | egrep \"GlueSEImplementationName\""

ldapCE = "ldapsearch -x -L -s sub -H ldap://%(TOPBDII)s -b mds-vo-name=local,o=grid \"(|(&(ObjectClass=GlueCESEBind)(GlueCESEBindSEUniqueID=%(HOST)s))(&(ObjectClass=GlueCE)(GlueCEInfoDefaultSE=%(HOST)s)))\" GlueCEUniqueID GlueCESEBindCEUniqueID | egrep \"^GlueCEUniqueID|^GlueCESEBindCEUniqueID\" | cut -d \"/\" -f1 | uniq"

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


# -------------------------------------------------------------------------
# Select only SEs with SRM implem StoRM or dCache
selectedSEs = []
for host in listSE:
    print "Checking SE " + host + "..."
    status, output = commands.getstatusoutput(ldapSRMImplem % {'TOPBDII': TOPBDII, 'HOST': host})
    if status <> 0:
        print "ldapsearch-se.sh error for SE", host, ":", output
        continue;
        
    # Parse the result lines
    for line in output.splitlines():
        attrib, value = line.split(":")
        if attrib == "GlueSEImplementationName":
            implemName = value.strip()
            if implemName == "StoRM" or implemName == "dCache":
                selectedSEs.append(host)
    # --- End of loop on SE hostnames --- 

results = {}

for host in selectedSEs:
    results[host] = {}
    results[host]['closeSEof'] = []
    results[host]['defaultSEof'] = []
    status, output = commands.getstatusoutput(ldapCE % {'TOPBDII': TOPBDII, 'HOST': host})
    if status <> 0:
        print "ldapsearch-se.sh error for SE", host, ":", output
        continue;

    # Parse the result lines
    for line in output.splitlines():
        attrib, ceHost, port = line.split(":")
        if attrib == "GlueCEUniqueID":
            if results[host]['defaultSEof'].count(ceHost.strip()) == 0:
                results[host]['defaultSEof'].append(ceHost.strip())
        if attrib == "GlueCESEBindCEUniqueID":
            if results[host]['closeSEof'].count(ceHost.strip()) == 0:
                results[host]['closeSEof'].append(ceHost.strip())
    # --- End of loop on selected SEs --- 

for se, detail in results.iteritems():
    print se + ":"
    if detail['closeSEof'] != []:
        sys.stdout.write("    close SE of: ")
        for ce in detail['closeSEof']:
            sys.stdout.write(ce + " ")
        print
    if detail['defaultSEof'] != []:
        sys.stdout.write("    default SE of: ")
        for ce in detail['defaultSEof']:
            sys.stdout.write(ce + " ")
        print
