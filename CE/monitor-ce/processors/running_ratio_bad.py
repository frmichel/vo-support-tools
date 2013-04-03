#!/usr/bin/python
#
# This tools exploits the data of csv files produced by script collect-ce-job-status.py,
# to figure out good and bad CEs: compute the list of CE queues based on the 
# number of times each one has been seen with 0 running jobs, or no activity...
# Optionally it loads test results of tool MonCE that runs jobs on CE regularly, and adds these
# results as additional columns of the result file. The results from MonCE should be present 
# in file ~/results/monce-results-per-ce.csv.
#
# Results are stored in file running_ratio_bad.csv.

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
	# Load the test results of the MonCE tool
	# -------------------------------------------------------------------------
	if MONCE:
	    if DEBUG: print "Loading test results from MonCE..."

	    # Open the file with a csv reader
	    fileName = "results/monce-results-per-ce.csv"
	    inputf = open(fileName, 'rb')
	    reader = csv.reader(inputf, delimiter=';')
	    if DEBUG: print "Loading file", fileName

	    monCE = {}
	    for row in reader:
	        if row[0].startswith('#'): continue   # Ignore lines begining with '#' (header line)
	        host = row[0].strip()
	        nbOK = int(row[1].strip())
	        nbKO = int(row[2].strip())
	        nbTO = int(row[3].strip())
	        timeOK = int(row[4].strip())
	        nbTotal = nbOK + nbKO + nbTO
	        if nbTotal == 0: contnue

	        monCE[host] = { 
	            'percentOK': str(round(float(nbOK)/nbTotal, 4)).replace('.', DECIMAL_MARK),
	            'percentKO': str(round(float(nbKO)/nbTotal, 4)).replace('.', DECIMAL_MARK),
	            'percentTO': str(round(float(nbTO)/nbTotal, 4)).replace('.', DECIMAL_MARK),
	            'total': nbTotal,
	            'avgTimeOk': str(timeOK/nbOK)
	        }
	    inputf.close()

	# -------------------------------------------------------------------------
	# Try to figure out good and bad CEs: compute the list of CE queues based on the 
	# number of times each one has been seen with 0 running jobs, or no activity...
	# -------------------------------------------------------------------------
	print "Computing the list of bad and good CE queues..."

	outputFile = OUTPUT_DIR + os.sep + "running_ratio_bad.csv"
	outputf = open(outputFile, 'wb')
	writer = csv.writer(outputf, delimiter=';')
	if MONCE:
	    writer.writerow(["Site", "CE queue", "nb measures W,R", "Mean Running", "Mean Waiting", "Mean W/R" , "Mean R/(R+W)" , "% times R/(R+W)<=0.1", "% times R+W=0", "MonCE nb measures", "MonCE % OK", "MonCE % Error", "MonCE % timeout", "MonCE OK mean resp time"])
	else:
	    writer.writerow(["Site", "CE queue", "nb measures W,R", "Mean Running", "Mean Waiting", "Mean W/R" , "Mean R/(R+W)" , "% times R/(R+W)<=0.1", "% times R+W=0"])

	# Loop on all data files that were acquired in dataFiles, and build a new table 'queues' that consolidates data per CE queue
	queues = {}
	for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:

	    # Loop on all rows of the file
	    for (hostname, structRow) in rows.iteritems():

	        if hostname not in queues: 			# add only one entry for each CE queue
	            queues[hostname] = {
	                    'Site': structRow['Site'], 'Running': 0, 'Waiting': 0, 
	                    'nb_measures':0, 			# number of measures of that CE queue over the period
	                    'nb_inf_01': 0, 'nb_na': 0, 	# number of measures with R/(R+W)<0.1, or R/(R+W) not calculable 
	                    'avgRatio': -1.0, 			# mean ratio R/(R+W)
	                    'sumDeviation': 0.0,		# sum of the deviation from the mean value of R/(R+W)
	                    'nbDeviation': 0			# nb of values summed in sumDeviation (to calculate the mean deviation)
	                     }	

	        W = float(structRow['VO_Waiting'])
	        R = float(structRow['VO_Running'])
	        queues[hostname]['nb_measures'] += 1
	        queues[hostname]['Waiting'] += W
	        queues[hostname]['Running'] += R
	        if R+W == 0: queues[hostname]['nb_na'] += 1
	        else:
	            if R/(R+W) <= 0.1: queues[hostname]['nb_inf_01'] += 1

	# Compute the mean R/(R+W)
	for hostname in queues:
	    R = float(queues[hostname]['Running'])
	    W = float(queues[hostname]['Waiting'])
	    if R+W != 0: 
	        queues[hostname]['avgRatio'] = R/(W+R)

	# Compute the mean deviation of R/(R+W)
	for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:
	    for (hostname, structRow) in rows.iteritems():
	        W = float(structRow['VO_Waiting'])
	        R = float(structRow['VO_Running'])
	        if R+W != 0: 
	            queues[hostname]['sumDeviation'] += abs(R/(R+W) - queues[hostname]['avgRatio'])
	            queues[hostname]['nbDeviation'] += 1

	# Print the results in the output file
	nbNotFoundMonCE = 0
	for hostname in queues:
	    R = float(queues[hostname]['Running'])
	    W = float(queues[hostname]['Waiting'])

	    W_div_R = "n.a"
	    if R != 0: W_div_R = str(round(W/R, 2)).replace('.', DECIMAL_MARK)

	    ratio = "n.a"
	    if queues[hostname]['avgRatio'] != -1.0: 
	        ratio = str(round(queues[hostname]['avgRatio'], 4)).replace('.', DECIMAL_MARK)

	    deviation_ratio = "n.a"
	    if queues[hostname]['nbDeviation'] != 0: 
	        deviation_ratio = str(round(queues[hostname]['sumDeviation'] / queues[hostname]['nbDeviation'], 4)).replace('.', DECIMAL_MARK)

	    nb = queues[hostname]['nb_measures']
	    nb_inf_01 = queues[hostname]['nb_inf_01']
	    nb_na = queues[hostname]['nb_na']

	    #if "ce01.grid.auth.gr" in hostname:
	    #    print "nb = " + str(nb) + " - nb_inf_01 = " + str(nb_inf_01) + " - nb_na = " + str(nb_na)

	    meanR = str(round(R/nb, 4)).replace('.', DECIMAL_MARK)
	    meanW = str(round(W/nb, 4)).replace('.', DECIMAL_MARK)
	    pctMsBad = str(round(float(nb_inf_01)/nb, 4)).replace('.', DECIMAL_MARK) 	# % of measures of R/(R+W) < 0.1
	    pctMsNul = str(round(float(nb_na)/nb, 4)).replace('.', DECIMAL_MARK)	# % of measures of R+W=0 n.a

	    if MONCE and hostname in monCE:
	        writer.writerow([queues[hostname]['Site'], hostname, nb, 
	                     meanR, meanW,						# mean R and mean W
	                     W_div_R,							# mean W/R
	                     ratio, 							# mean R/(R+W)
	                     # deviation_ratio,						# mean R/(R+W) std deviation
	                     pctMsBad,							# % of measures of R/(R+W) < 0.1
	                     pctMsNul,							# % of measures of R+W=0 n.a
	                     monCE[hostname]['total'],
	                     monCE[hostname]['percentOK'],
	                     monCE[hostname]['percentKO'],
	                     monCE[hostname]['percentTO'],
	                     monCE[hostname]['avgTimeOk']
	                     ])
	    else:
	        if DEBUG: print "Warning:", hostname, "not in MonCE results"
	        nbNotFoundMonCE += 1
	        writer.writerow([queues[hostname]['Site'], hostname, nb, 
	                     meanR, meanW,						# mean R and mean W
	                     W_div_R,							# mean W/R
	                     ratio, 							# mean R/(R+W)
	                     # deviation_ratio,						# mean R/(R+W) std deviation
	                     pctMsBad,							# % of measures of R/(R+W) < 0.1
	                     pctMsNul							# % of measures of R+W=0 n.a
	                     ])


	if MONCE:
	    print "Computed " + str(len(queues)) + " CE queues. " + str(nbNotFoundMonCE) + " not found in MonCE results."
	outputf.close()

