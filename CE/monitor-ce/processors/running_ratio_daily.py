#!/usr/bin/python
#
# This tools exploits the data of csv files produced by script collect-ce-job-status.py, to 
# compute the running ratio R/(R+W) as a function of time. Time meaning days: each day, the 
# mean measure is computed, as opposed to running_ratio.py that provides 6 measures per day.
#
# Results are stored in file running_ratio_daily.csv.

import os
import csv
import sys
import globvars

# -------------------------------------------------------------------------
# Compute the running ratio R/(R+W) as a function of time
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
	CSV_DELIMITER = globvars.CSV_DELIMITER
	STDOUT = globvars.STDOUT

	# Consolidate the data by summing per day measures of W and R
	dataPerDate = {}
	for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:
	    R = float(sum_VO_Running)
	    W = float(sum_VO_Waiting)
	    if date not in dataPerDate:
	        dataPerDate[date] = {'NbMeasures': 0, 'Waiting': 0.0, 'Running': 0.0}
	    dataPerDate[date]['NbMeasures'] += 1
	    dataPerDate[date]['Waiting'] += W
	    dataPerDate[date]['Running'] += R

        outStream = sys.stdout
	if STDOUT:
	    outStream = sys.stdout
	else:
	    outputFile = OUTPUT_DIR + os.sep + "running_ratio_daily.csv"
	    outStream = open(outputFile, 'wb')
 
	writer = csv.writer(outStream, delimiter=CSV_DELIMITER,lineterminator=';')
	# Write the separator followed the name of the script called
	if STDOUT:
	    print('<'+os.path.splitext(os.path.basename(__file__))[0]+'>'),
	else:
	    print "Computing the mean ratio R/(R+W) as a function of time (daily)..."

	writer.writerow(["Date", "Waiting", "Running", "R/(R+W)"])

	# Loop on all data files that were acquired
	for (date, data) in dataPerDate.iteritems():
	    nbMeasures = dataPerDate[date]['NbMeasures']
	    W = data['Waiting']
	    R = data['Running']
	    if R+W > 0:
		writer.writerow([
		date,
		str(round(W/nbMeasures, 1)).replace('.', DECIMAL_MARK),
		str(round(R/nbMeasures, 1)).replace('.', DECIMAL_MARK),
		str(round(R/(R+W), 4)).replace('.', DECIMAL_MARK) ])
	if STDOUT: print('</'+os.path.splitext(os.path.basename(__file__))[0]+'>')
	if not STDOUT: outStream.close()
	
	
