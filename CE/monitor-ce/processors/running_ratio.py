#!/usr/bin/python
#
# This tools exploits the data of csv files produced by script collect-ce-job-status.py, to 
# compute the running ratio R/(R+W) as a function of time
#
# Results are stored in file running_ratio.csv.

import os
import csv

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

	print "Computing the mean ratio R/(R+W) as a function of time..."

	outputFile = globvars.OUTPUT_DIR + os.sep + "running_ratio.csv"
	outputf = open(outputFile, 'wb')
	writer = csv.writer(outputf, delimiter=';')
	writer.writerow(["# Date time", "Waiting", "Running", "R/(R+W)"])

	# Loop on all data files that were acquired
	for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:
	    R = float(sum_VO_Running)
	    W = float(sum_VO_Waiting)
	    if R+W > 0:
	        writer.writerow([datetime, sum_VO_Waiting, sum_VO_Running, str(round(R/(R+W), 4)).replace('.', globvars.DECIMAL_MARK) ])

	outputf.close()


