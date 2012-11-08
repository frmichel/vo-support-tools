#!/usr/bin/python
#
# This tools exploits the data of csv files produced by script collect-ce-job-status.py, to 
# compute the distribution of CE queues by ratio R/(R+W).
#
# Results are stored in file distribute_ce_by_running_ratio.csv.

import os
import csv

import globvars

# -------------------------------------------------------------------------
# Compute the the distribution of CE queues by ratio R/(R+W)
# Input:
#     dataFiles: list of tuples: (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running)
#     where
#     - datetime is formated as "YYYY-MM-DD HH:MM:SS"
#     - date is only the date part YYYY:MM:DD, and hour is only the hour HH (used for filtering data in excel file)
#     - rows is a dictionnary wich keys are the hostnames and values are another dictionnary with the following keys:
#      'Site'
#      'ImplName', 'ImplVer'
#      'CE_Total', 'VO_Total'
#      'CE_Running', 'VO_Running'
#      'CE_Waiting', 'VO_Waiting'
#      'CE_Running', 'VO_Running'
#      'CE_FreeSlots', 'VO_FreeSlots'
#      'CE_MaxTotal', 'VO_MaxTotal'
#      'CE_MaxWaiting', 'VO_MaxWaiting'
#      'CE_MaxRunning', 'VO_MaxRunning'
#      'CE_WRT', 'VO_WRT'
#      'CE_MaxTotal', 'VO_MaxTotal'
#      'CE_ERT', 'VO_ERT'
#      'CE_Status'
# -------------------------------------------------------------------------

def process(dataFiles):
	# Global variables
	DECIMAL_MARK = globvars.DECIMAL_MARK
	DEBUG = globvars.DEBUG
	OUTPUT_DIR = globvars.OUTPUT_DIR

	# -------------------------------------------------------------------------
	# Loop on all data files that were acquired in dataFiles, 
	# and build a new table 'queues' that consolidates data per CE queue
	# -------------------------------------------------------------------------
	queues = {}
	for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:

	    # Loop on all rows of the file
	    for (hostname, structRow) in rows.iteritems():

	        if hostname not in queues: 			# add only one entry for each CE queue
	            queues[hostname] = {
	                    'Running': 0,
	                    'Waiting': 0,
	                    'avgRatio': -1.0, 			# mean ratio R/(R+W)
	                     }	

	        queues[hostname]['Waiting'] += float(structRow['VO_Waiting'])
	        queues[hostname]['Running'] += float(structRow['VO_Running'])

	# Compute the mean R/(R+W)
	for hostname in queues:
	    R = float(queues[hostname]['Running'])
	    W = float(queues[hostname]['Waiting'])
	    if R+W != 0: 
	        queues[hostname]['avgRatio'] = R/(W+R)

	# -------------------------------------------------------------------------
	# Compute the distribution of CE queues by ratio R/(R+W)
	# -------------------------------------------------------------------------
	print "Computing the distribution of CE queues by ratio R/(R+W)..."

	outputFile = globvars.OUTPUT_DIR + os.sep + "distribute_ce_by_running_ratio.csv"
	outputf = open(outputFile, 'wb')
	writer = csv.writer(outputf, delimiter=';')
	writer.writerow(["0.0 to 0.1", "0.1 to 0.2", "0.2 to 0.3", "0.3 to 0.4", "0.4 to 0.5", "0.5 to 0.6", "0.6 to 0.7", "0.7 to 0.8", "0.8 to 0.9", "0.9 to 1.0", "n.a"])

	# Loop on all data files that were acquired in dataFiles, and build a new table 'queues' that consolidates data per CE queue
	distrib = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for hostname in queues:
	    ratio = queues[hostname]['avgRatio']
	    if ratio >= 0.0 and ratio < 0.1: distrib[0] += 1
	    if ratio >= 0.1 and ratio < 0.2: distrib[1] += 1
	    if ratio >= 0.2 and ratio < 0.3: distrib[2] += 1
	    if ratio >= 0.3 and ratio < 0.4: distrib[3] += 1
	    if ratio >= 0.4 and ratio < 0.5: distrib[4] += 1
	    if ratio >= 0.5 and ratio < 0.6: distrib[5] += 1
	    if ratio >= 0.6 and ratio < 0.7: distrib[6] += 1
	    if ratio >= 0.7 and ratio < 0.8: distrib[7] += 1
	    if ratio >= 0.8 and ratio < 0.9: distrib[8] += 1
	    if ratio >= 0.9 and ratio < 1.0: distrib[9] += 1
	    if ratio == -1.0: distrib[10] += 1

	writer.writerow([
	    str(round(distrib[0]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[1]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[2]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[3]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[4]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[5]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[6]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[7]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[8]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[9]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	    str(round(distrib[10]/len(queues), 4)).replace('.', globvars.DECIMAL_MARK),
	                ]) 
	outputf.close()

