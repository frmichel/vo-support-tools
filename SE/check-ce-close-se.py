#!/usr/bin/python
# List all SEs supporting the given VO (defaults to biomed), and for each SE, 
# display the list or number of CEs that refer to that SE as a close or default SE.
# Also display the SRM implementation and version, total and used space. 
# Types of implementation can be selected (DPM, dCache, StoRM).

import sys
import os
import commands
import re
from operator import itemgetter, attrgetter
from optparse import OptionParser

DEFAULT_TOPBDII = "cclcgtopbdii01.in2p3.fr:2170"

optParser = OptionParser(version="%prog 1.0", description="""List all SEs supporting the given VO, and
display the list or number of (CREAM)CEs that refer to each SE as a close or default SE. Also display the SRM
implementation and version, total and used space. """)

optParser.add_option("--vo", action="store", dest="vo", default="biomed",
                     help="Virtual Organisation to query. Defaults to \"biomed\"")
optParser.add_option("--bdii", action="store", dest="bdii", default=DEFAULT_TOPBDII,
                     help="top BDII hostname and port. Defaults to " + DEFAULT_TOPBDII)

optParser.add_option("--limit", action="store", dest="limit", default=9999,
                     help="Max number of SE to check. Defaults to all (9999)")

optParser.add_option("--count-ce", action="store_true", dest="countce",
                     help="Do not list all refering CEs but just count them")

optParser.add_option("--no-dpm", action="store_true", dest="nodpm",
                     help="Do not check DPM storage elements")
optParser.add_option("--no-storm", action="store_true", dest="nostorm",
                     help="Do not check StoRM storage elements")
optParser.add_option("--no-dcache", action="store_true", dest="nodcache",
                     help="Do not check dCache storage elements")

optParser.add_option("--no-ver", action="store_true", dest="noversion",
                     help="Do not report SRM implementation version")

# -------------------------------------------------------------------------
# Definitions, global variables
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()
VO = options.vo
TOPBDII = options.bdii
MAX_SE = int(options.limit)
LIST_CE = not options.countce

CHECK_DPM = not options.nodpm
CHECK_STORM = not options.nostorm
CHECK_DCACHE = not options.nodcache
SRM_VER = not options.noversion

# LDAP Request to get the SE SRM implementation name/version, the site name (GlueForeignKey)
ldapSRMImplem = "ldapsearch -x -L -s sub -H ldap://%(TOPBDII)s -b mds-vo-name=local,o=grid \"(&(ObjectClass=GlueSE)(GlueSEUniqueID=%(HOST)s))\" | egrep \"GlueSEImplementationName|GlueSEImplementationVersion|GlueForeignKey\""

# LDAP Request to get the Storage Area info: used and total space for the biomed
ldapSA = "ldapsearch -x -L -s sub -H ldap://%(TOPBDII)s -b mds-vo-name=local,o=grid \"(&(ObjectClass=GlueSA)(GlueChunkKey=GlueSEUniqueID=%(HOST)s)(|(GlueSAAccessControlBaseRule=VO:%(VO)s*)(GlueSAAccessControlBaseRule=%(VO)s*)))\" | egrep \"GlueSATotalOnlineSize|GlueSAUsedOnlineSize\""

# LDAP Request to get CEs which an SE is a close or default SE:
# - look for GlueCESEBind with attribute GlueCESEBindSEUniqueID => close SE
# - look for GlueCE object with attribute GlueCEInfoDefaultSE => default SE
ldapCE = "ldapsearch -x -L -s sub -H ldap://%(TOPBDII)s -b mds-vo-name=local,o=grid \"(|(&(ObjectClass=GlueCESEBind)(GlueCESEBindSEUniqueID=%(HOST)s))(&(ObjectClass=GlueCE)(GlueCEInfoDefaultSE=%(HOST)s)))\" GlueCEUniqueID GlueCESEBindCEUniqueID | egrep \"^GlueCEUniqueID|^GlueCESEBindCEUniqueID\" | cut -d \"/\" -f1 | uniq"

# -------------------------------------------------------------------------
# Make the list of SE from the BDII
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
# For each SE, retieve site name, total and used space,
# -------------------------------------------------------------------------

# The selectedSEs is a multidimensional dictionary:
# SE hostname
#    'site' : the site name
#    'implimpl' : SRM implementation (SRM, dCache...)
#    'implver' : SRM version
#    'total': total available size for that SE
#    'used': space used by the VO for that SRM implementation, whatever the version
#    'closeSEof' : list of CEs for which the SE is a close SE
#    'defaultSEof': list of CEs for which the SE is a default SE
selectedSEs = {}

# Regexp to limit the version number to 3 numbers
matchVer = re.compile("^(\w+.\w+.\w+)")

for host in listSE:
    print "Checking SE " + host + "..."
    statusSE, outputSE = commands.getstatusoutput(ldapSRMImplem % {'TOPBDII': TOPBDII, 'HOST': host})
    statusSA, outputSA = commands.getstatusoutput(ldapSA % {'TOPBDII': TOPBDII, 'HOST': host, 'VO': VO})
    if statusSE <> 0 or statusSA <> 0:
        print "ldapsearch error for SE", host, ":", outputSE, outputSA
        print "GlueSE LDAP request:", ldapSRMImplem % {'TOPBDII': TOPBDII, 'HOST': host}
        print "GlueSA LDAP request:", ldapSA % {'TOPBDII': TOPBDII, 'HOST': host, 'VO': VO}
        selectedSEs[host]['implname'] = 'ERROR'
        continue;
        
    output = outputSE + "\n" + outputSA
    totalSE = usedSE = 0
    selectedSEs[host] = {'site':'', 'implname':'', 'implver':'', 'total':'', 
                         'used':'', 'closeSEof':[], 'defaultSEof':[]}

    # Loop on the output of the 2 ldap requests
    for line in output.splitlines():
        #attrib, value = line.split(":")
        listStr = []
        listStr = line.split(":")
        attrib = listStr[0]
        value = listStr[1]

        # The site line is formated like this: GlueForeignKey: GlueSiteUniqueID=INFN-PISA
        if attrib == "GlueForeignKey":
            attribSite, site = line.split("=")
            selectedSEs[host]['site'] = site.strip()

        if attrib == "GlueSEImplementationName":
            selectedSEs[host]['implname'] = value.strip()

        if attrib == "GlueSEImplementationVersion":
            implemVer = value.strip()
            match = matchVer.match(implemVer)
            if match <> None: implemVer = match.group(1)
            selectedSEs[host]['implver'] = implemVer

        if attrib == "GlueSATotalOnlineSize":
            totalSE += int(value.strip())
        if attrib == "GlueSAUsedOnlineSize":
            usedSE += int(value.strip())
    # End loop on the result of the LDAP requests --- 

    selectedSEs[host]['total'] = str(totalSE)
    selectedSEs[host]['used'] = str(usedSE)

# End of loop on SE hostnames --- 


# -------------------------------------------------------------------------
# For each SE selected above, look for CEs for which the SE is a close or default SE
# -------------------------------------------------------------------------

for host in listSE:

    impl = selectedSEs[host]['implname']
    if impl == 'ERROR': continue
    cond = (impl=='DPM' and CHECK_DPM) or (impl=='StoRM' and CHECK_STORM) or (impl=='dCache' and CHECK_DCACHE)
    if not cond: continue # Skipping SE

    print "Looking for CE that uses SE " + host + "..."

    status, output = commands.getstatusoutput(ldapCE % {'TOPBDII': TOPBDII, 'HOST': host})
    if status <> 0:
        print "ldapsearch error for SE", host, ":", output
        continue;

    # Parse the result lines formated as: <attributeName>: <ceHostname>:<port>
    for line in output.splitlines():
        attrib, ceHost, port = line.split(":")

        if attrib == "GlueCESEBindCEUniqueID":
            # GlueCESEBindCEUniqueID is part of GlueCESEBind object => close SE
            if selectedSEs[host]['closeSEof'].count(ceHost.strip()) == 0:     # do not make duplicates
                selectedSEs[host]['closeSEof'].append(ceHost.strip())

        if attrib == "GlueCEUniqueID":
            # GlueCEUniqueID is part of GlueCE object => default SE
            if selectedSEs[host]['defaultSEof'].count(ceHost.strip()) == 0:   # do not make duplicates
                selectedSEs[host]['defaultSEof'].append(ceHost.strip())

# End of loop on selected SEs

# -------------------------------------------------------------------------
# Display the results
# -------------------------------------------------------------------------

formatShort = "%(site)-26s %(host)-36s %(implname)-7s "
if SRM_VER: formatShort += "%(implver)-7s "
formatShort += "%(total)9s %(used)9s %(percent)5s"
if LIST_CE: 
    format = formatShort + "  %(closeSEof)-33s %(defaultSEof)-33s\n"
else:
    format = formatShort + "  %(closeSEof)8s %(defaultSEof)10s\n"

print "=========================================================================================================================================================================="
if SRM_VER:
    sys.stdout.write(format % {'site':'Site', 'host':'Hostname', 'implname':'Implem.', 'implver':'Version',
                               'total':'Total', 'used':'Used', 'percent':'%age',
                               'closeSEof':'Close SE', 'defaultSEof':'Default SE'})
    sys.stdout.write(format % {'site':'', 'host':'', 'implname':'', 'implver':'',
                               'total':'space(GB)', 'used':'space(GB)', 'percent':'used',
                               'closeSEof':'of CE', 'defaultSEof':'of CE'})
else:
    sys.stdout.write(format % {'site':'Site', 'host':'Hostname', 'implname':'Implem.',
                               'total':'Total', 'used':'Used', 'percent':'%age',
                               'closeSEof':'Close SE', 'defaultSEof':'Default SE'})
    sys.stdout.write(format % {'site':'', 'host':'', 'implname':'',
                               'total':'space(GB)', 'used':'space(GB)', 'percent':'used',
                               'closeSEof':'of CE', 'defaultSEof':'of CE'})
print "=========================================================================================================================================================================="

def sortBySite(el1, el2):
    if el1[1]['site'] > el2[1]['site']: return 1
    if el1[1]['site'] < el2[1]['site']: return -1
    return 0

# Sort result by site name
sortedBySite = sorted(selectedSEs.iteritems(), sortBySite)

for host, detail in sortedBySite:
    impl = detail['implname']
    cond = (impl=='DPM' and CHECK_DPM) or (impl=='StoRM' and CHECK_STORM) or (impl=='dCache' and CHECK_DCACHE)
    if not cond:
        # Skipping SE
        continue

    if LIST_CE: 
        # Display all CEs refering to that SE
        closeSEof = defaultSEof = ''
        if detail['closeSEof'] != []: closeSEof = detail['closeSEof'][0]
        if detail['defaultSEof'] != []: defaultSEof = detail['defaultSEof'][0]
        sys.stdout.write(format % {'host': host, 'site': detail['site'],
                               'implname': detail['implname'], 'implver': detail['implver'],
                               'total': detail['total'], 'used': detail['used'],
                               'percent': str(int(detail['used'])*100/int(detail['total']))+ "%",
                               'closeSEof': closeSEof, 'defaultSEof': defaultSEof})

        # Display other CEs 
        index = 1	# start at second element (first element is at index 0)
        while index < max(len(detail['closeSEof']), len(detail['defaultSEof'])):
            closeSEof = defaultSEof = ''
            if index < len(detail['closeSEof']): closeSEof = detail['closeSEof'][index]
            if index < len(detail['defaultSEof']): defaultSEof = detail['defaultSEof'][index]

            sys.stdout.write(format % {'host': '', 'site': '', 'implname': '', 'implver': '',
                                       'total': '', 'used': '', 'percent':'',
                                       'closeSEof': closeSEof, 'defaultSEof': defaultSEof})
            index += 1        

    else:
        # Display the number of CEs refering to that SE
        sys.stdout.write(format % {'host': host, 'site': detail['site'],
                               'implname': detail['implname'], 'implver': detail['implver'],
                               'total': detail['total'], 'used': detail['used'],
                               'percent': str(int(detail['used'])*100/int(detail['total']))+ "%",
                               'closeSEof': len(detail['closeSEof']),
                               'defaultSEof': len(detail['defaultSEof']) })

# End of loop on sorted list of SEs
