#!/usr/bin/python
#
# This tool exploits the data of csv files produced by script collect-ce-job-status.py, to 
# to compute the running ratio R/(R+W) for each CE, as a function of time.
#
# Results are stored in files named results/CE/<site name>_<CE queue>.csv.

import os
import csv

import globvars

# -------------------------------------------------------------------------
# Try to figure out good and bad CEs: compute the list of CE queues
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
	MONCE = globvars.MONCE

	# -------------------------------------------------------------------------
	# Compute the running ratio per CE as a function of time
	# -------------------------------------------------------------------------
	print "Computing the ratio R/(R+W) per CE as a function of time..."

	# Loop on all data files that were acquired in dataFiles, and build a new table 'queues' that consolidates data per CE queue
	queues = {}
	for (fileName, datetime, date, hour, fileRows, sum_VO_Waiting, sum_VO_Running) in dataFiles:
	    # Loop on all rows of the file
	    for (hostname, row) in fileRows.iteritems():

	        if hostname not in queues: 			# add only one entry for each CE queue
	            queues[hostname] = {'Site': row['Site']}

	        W = float(row['VO_Waiting'])
	        R = float(row['VO_Running'])
	        ratio = -1.0
	        if R+W != 0: ratio = R/(R+W)
	        queues[hostname][datetime] = { 'Waiting': row['VO_Waiting'], 'Running': row['VO_Running'], 'Ratio': ratio }

	# Then for each CE, make a csv file that records the data per date: W, R, R/(R+W)
	for (hostname, data) in queues.iteritems():
	    ceFileName = data['Site'] + "_" + hostname
	    ceFileName = ceFileName.replace(':', '_')
	    ceFileName = ceFileName.replace('/', '_')
	    outputFile = OUTPUT_DIR + os.sep + "CE" + os.sep + ceFileName + ".csv"
	    outputf = open(outputFile, 'wb')
	    writer = csv.writer(outputf, delimiter=';')
	    writer.writerow(["# Date time", "Waiting", "Running", "R/(R+W)"])

	    for (datetime, row) in data.iteritems():
	        if datetime != "Site":
	            strRatio = ""
	            if row['Ratio'] != -1.0: 
	                strRatio = str(round(row['Ratio'], 4)).replace('.', globvars.DECIMAL_MARK)
	            writer.writerow([
	                datetime,
	                row['Waiting'],
	                row['Running'],
	                strRatio
	            ])

	    outputf.close()

