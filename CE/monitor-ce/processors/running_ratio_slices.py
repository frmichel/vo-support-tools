#!/usr/bin/python
#
# This tools exploits the data of csv files produced by script collect-ce-job-status.py, to 
# compute the number of CEs grouped by slice of ratio R/(R+W) as a function of time:
# between 0 and 0,5, and between 0,5 and 1, exactly 1 or not calculable.
#
# Results are stored in file running_ratio_slices.csv.

import os
import csv
import sys
import globvars

# -------------------------------------------------------------------------
# Compute the number of CEs grouped by ratio R/(R+W) as a function of time
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

	writer=''
	if globvars.STDOUT:
	    writer = csv.writer(sys.stdout, delimiter=globvars.CSV_DELIMITER,lineterminator=';')
	    print('<'+os.path.splitext(os.path.basename(__file__))[0]+'>'),
	    writer.writerow(["Date time", "Nb queues", "0", "0 to 0.5", "0.5 to 1", "1", "n/a"])
	else:
	    print "Computing the number of CEs grouped by slice of ratio R/(R+W) as a function of time..."
	    outputFile = OUTPUT_DIR + os.sep + "running_ratio_slices.csv"
	    outputf = open(outputFile, 'wb')
	    writer = csv.writer(outputf, delimiter=globvars.CSV_DELIMITER)
	    writer.writerow(["# Date time", "Nb queues", "0", "0 to 0.5", "0.5 to 1", "1", "n/a"])
	# Loop on all data files that were acquired
	for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:
	    nb_0 = nb_0_05 = nb_05_1 = nb_1 = nb_na = 0.0
	    #Loop on all rows of the file
	    for (hostname, structRow) in rows.iteritems():
		W = float(structRow['VO_Waiting'])
	    	R = float(structRow['VO_Running'])

		if R+W == 0:
		    nb_na += 1
		else:
		    ratio = R/(R+W)
		    if ratio == 0: nb_0 += 1
		    if ratio >= 0 and ratio < 0.5: nb_0_05 += 1
		    else: 
		        if ratio >= 0.5 and ratio <= 1: nb_05_1 += 1
		    if ratio == 1: nb_1 += 1

	    if globvars.STDOUT:	    
		if globvars.PERCENT:
		    nbQ = len(rows)
		    writer.writerow([datetime, nbQ,
		    str(round(nb_0*100/nbQ,2)).replace('.', DECIMAL_MARK),
		    str(round(nb_0_05*100/nbQ,2)).replace('.', DECIMAL_MARK),
		    str(round(nb_05_1*100/nbQ,2)).replace('.', DECIMAL_MARK),
		    str(round(nb_1*100/nbQ,2)).replace('.', DECIMAL_MARK),
                    str(round(nb_na*100/nbQ,2)).replace('.', DECIMAL_MARK)
                    ])
	
		else:
		    nbQ = len(rows)
		    writer.writerow([datetime, nbQ, 
		    str(round(nb_0/nbQ, 4)).replace('.', DECIMAL_MARK), 
		    str(round(nb_0_05/nbQ, 4)).replace('.', DECIMAL_MARK), 
		    str(round(nb_05_1/nbQ, 4)).replace('.', DECIMAL_MARK), 
		    str(round(nb_1/nbQ, 4)).replace('.', DECIMAL_MARK), 
		    str(round(nb_na/nbQ, 4)).replace('.', DECIMAL_MARK) 
		    ])
	    else:
		if globvars.PERCENT:
		    nbQ = len(rows)
		    writer.writerow([datetime, nbQ,
		    str(round(nb_0*100/nbQ,2)).replace('.', DECIMAL_MARK),
		    str(round(nb_0_05*100/nbQ,2)).replace('.', DECIMAL_MARK),
		    str(round(nb_05_1*100/nbQ,2)).replace('.', DECIMAL_MARK),
		    str(round(nb_1*100/nbQ,2)).replace('.', DECIMAL_MARK),
		    str(round(nb_na*100/nbQ,2)).replace('.', DECIMAL_MARK)
		    ])

		else:
		    nbQ = len(rows)
		    writer.writerow([datetime, nbQ,
		    str(round(nb_0/nbQ, 4)).replace('.', DECIMAL_MARK),
		    str(round(nb_0_05/nbQ, 4)).replace('.', DECIMAL_MARK),
		    str(round(nb_05_1/nbQ, 4)).replace('.', DECIMAL_MARK),
		    str(round(nb_1/nbQ, 4)).replace('.', DECIMAL_MARK),
		    str(round(nb_na/nbQ, 4)).replace('.', DECIMAL_MARK)
		    ])
 
	if globvars.STDOUT: print('</'+os.path.splitext(os.path.basename(__file__))[0]+'>')
	if not globvars.STDOUT: outputf.close()
	
	
