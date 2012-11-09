#!/usr/bin/python
#
# This tools exploits the data of csv files produced by script collect-ce-job-status.py, to 
# compute the average ratio R/(R+W) during day time (12h, 16h, 20h) or night time (0h, 4h, 8h), 
# as a function of time.
#
# Results are stored in file running_ratio_day_night.csv.

import os
import csv

import globvars

# -------------------------------------------------------------------------
# Compute the mean ratio R/(R+W) during day (12h, 16h, 20h) or night (0h, 4h, 8h)
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

	print "Computing the mean ratio R/(R+W) grouped by day or night as a function of time..."

	outputFile = OUTPUT_DIR + os.sep + "running_ratio_day_night.csv"
	outputf = open(outputFile, 'wb')
	writer = csv.writer(outputf, delimiter=';')
	writer.writerow(["# Date", "Wait 0h", "Run 0h", "R/(R+W) 0h", "Wait 4h", "Run 4h", "R/(R+W) 4h", "Wait 8h", "Run 8h", "R/(R+W) 8h", "Wait 12h", "Run 12h", "R/(R+W) 12h", "Wait 16h", "Run 16h", "R/(R+W) 16h", "Wait 20h", "Run 20h", "R/(R+W) 20h", "Mean Wait night", "Mean Run night", "Mean R/(R+W) night", "Mean Wait day", "Mean Run day", "Mean R/(R+W) day"])

	# First, build the list of dates when we have data
	listDates = []
	for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:
	    if date not in listDates: listDates.append(date)

	# Then for each of these dates, collect data at 0h, 4h, 8h, 12h, 16h and 20h
	for theDate in listDates:

	    W0 = W4 = W8 = W12 = W16 = W20 = 0.0
	    R0 = R4 = R8 = R12 = R16 = R20 = 0.0
	    ratio0 = ratio4 = ratio8 = ratio12 = ratio16 = ratio20 = 0.0

	    # Loop on all files that we have at the given date
	    for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:
	        if date == theDate:
	            R = float(sum_VO_Running)
	            W = float(sum_VO_Waiting)

	            if hour == '00': 
	                W0 = W
	                R0 = R
	                if R+W > 0: ratio0 = R/(R+W)
	            elif hour == '04': 
	                W4 = W
	                R4 = R
	                if R+W > 0: ratio4 = R/(R+W)
	            elif hour == '08': 
	                W8 = W
	                R8 = R
	                if R+W > 0: ratio8 = R/(R+W)
	            elif hour == '12': 
	                W12 = W
	                R12 = R
	                if R+W > 0: ratio12 = R/(R+W)
	            elif hour == '16': 
	                W16 = W
	                R16 = R
	                if R+W > 0: ratio16 = R/(R+W)
	            elif hour == '20': 
	                W20 = W
	                R20 = R
	                if R+W > 0: ratio20 = R/(R+W)
	    # end loop on all files looking for those at the given date

	    ratioNight = ratioDay = 0.0
	    if (W0+W4+W8+R0+R4+R8) > 0: ratioNight = (R0+R4+R8)/(W0+W4+W8+R0+R4+R8)
	    if (W12+W16+W20+R12+R16+R20) > 0: ratioDay = (R12+R16+R20)/(W12+W16+W20+R12+R16+R20)
	    writer.writerow([theDate, 
	                      int(W0), int(R0), str(round(ratio0, 4)).replace('.', DECIMAL_MARK),
	                      int(W4), int(R4), str(round(ratio4, 4)).replace('.', DECIMAL_MARK),
	                      int(W8), int(R8), str(round(ratio8, 4)).replace('.', DECIMAL_MARK),
	                      int(W12), int(R12), str(round(ratio12, 4)).replace('.', DECIMAL_MARK),
	                      int(W16), int(R16), str(round(ratio16, 4)).replace('.', DECIMAL_MARK),
	                      int(W20), int(R20), str(round(ratio20, 4)).replace('.', DECIMAL_MARK),
	                      int((W0+W4+W8)/3), int((R0+R4+R8)/3),str(round(ratioNight, 4)).replace('.', DECIMAL_MARK), 
	                      int((W12+W16+W20)/3), int((R12+R16+R20)/3),str(round(ratioDay, 4)).replace('.', DECIMAL_MARK)
	                    ])
	# end loop on all single dates
	outputf.close()
