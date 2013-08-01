#!/usr/bin/python

import ldap
import re
import datetime
import sys

flavors = ['org.glite.ce.CREAM', 'org.glite.ce.Monitor', 'org.glite.RTEPublisher', 'org.glite.wms.WMProxy', 'local-data-location-interface', 'SRM']

def convertServiceFlavour(flav):
    flav = flav.replace('org.glite.ce.CREAM', 'CREAM-CE')
    flav = flav.replace('org.glite.ce.Monitor', 'CREAM-CE')
    flav = flav.replace('org.glite.RTEPublisher', 'CREAM-CE')
    flav = flav.replace('org.glite.wms.WMProxy', 'WMS')
    flav = flav.replace('SRM','SRMv2')
    flav = flav.replace('local-data-location-interface','Local-LFC')
    return flav

def useServiceFlavour(flav):
    return flav in flavors

l = ldap.initialize('ldap://topbdii.grif.fr:2170')
r = l.search_s('mds-vo-name=local,o=grid',ldap.SCOPE_SUBTREE,'(GlueServiceAccessControlBaseRule=VO:biomed)',['GlueServiceType','GlueForeignKey','GlueServiceEndpoint'])

if r == {}:
    print "Error, no feed generate"
    sys.exit(1)

sites = {};
for dn,entry in r:
   site_name   = entry['GlueForeignKey'][0].replace('GlueSiteUniqueID=','');
   service_name= entry['GlueServiceType'][0];
   endpoint    = re.search('(?<=//).*:',entry['GlueServiceEndpoint'][0]);
   endpoint_str = "";
   try:
     endpoint_str=endpoint.group(0).replace(':','');
   except:
     pass;
   if endpoint_str != "" :
     try :
       sites[site_name][endpoint_str]=entry['GlueServiceType'][0];
     except KeyError:
       sites[site_name]={endpoint_str : entry['GlueServiceType'][0]};

print "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>";
print "<root xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"atp_vo_feed_schema.xsd\">";
print "  <title>BIOMED topology for SAM</title>"
print "  <description>Groups of services defined by BIOMED VO to be used by the SAM/Nagios monitoring infrastructure</description>";
print "  <feed_responsible name=\"Franck Michel\" dn=\"/O=GRID-FR/C=FR/O=CNRS/OU=I3S/CN=Franck Michel\"/>";
print "  <last_update>" + datetime.datetime.now().strftime('%Y-%m-%dT%XZ%Z') + "</last_update>"
print "  <vo>biomed</vo>";

for site in sorted(sites):
  if not re.match('Glue.*',site) :
    print "  <atp_site name=\""+site+"\">";
    for box in sites[site]:
      if useServiceFlavour(sites[site][box]):
        print "    <service hostname=\""+box+"\" flavour=\""+convertServiceFlavour(sites[site][box])+"\"/>";
    print "    <group name=\"Tier-2\" type=\"biomed_Tier\" />";
    print "    <group name=\""+site+"\" type=\"biomed_Site\" />";
    print "  </atp_site>";

print "</root>";

