#!/usr/bin/python
#
# This tools exploits the data of csv files produced by script show-se-space.py, to 
# generate a simple history of the filling rate of each SE
#
# Results are stored in file space_history.csv.

import os
import csv

import globvars

# -------------------------------------------------------------------------
# Generate a simple history of the filling rate of each SE
#
# Input:
#   dataFiles: list of tuples: (fileName, date, rows, sum_total, sum_used) where
#   - date is only the date part YYYY:MM:DD
#   - rows is a dictionnary wich keys are the hostnames and values are another dictionnary with the following keys:
#     'Site', 'ImplName', 'ImplVer', 'SE_Total', 'SE_Used', 'Filling_Rate'
# -------------------------------------------------------------------------

def process(dataFiles):
	# Global variables
	DECIMAL_MARK = globvars.DECIMAL_MARK
	DEBUG = globvars.DEBUG
	OUTPUT_DIR = globvars.OUTPUT_DIR

	print "Generate the history representation of the filling rate of SEs..."

        # Build the list of SEs encountered in all files: a SE may be available one day and not the next one. 
        # So that all days must be parsed to consolidate the full list.
        listSEs = {}
	for (fileName, date, rows, sum_total, sum_used) in dataFiles:
            for (host, row) in rows.iteritems():
                if host not in listSEs:
                    listSEs[host] = row['Site']

        # Initialise the result matrix: one line for each SE, one column for each date
        matrixTotal = {}
        matrixUsed = {}
        nbDates = len(dataFiles)
        for (host, site) in listSEs.iteritems():
            matrixTotal[host] = ['' for i in range(nbDates)]
            matrixUsed[host] = ['' for i in range(nbDates)]

        # Now browse all data files and hosts to fill in the result matrix
        dateIndex = 0
	for (fileName, date, rows, sum_total, sum_used) in dataFiles:
            for (host, row) in rows.iteritems():
                matrixTotal[host][dateIndex] = row['SE_Total']
                matrixUsed[host][dateIndex] = row['SE_Used']
            dateIndex += 1

        # Create the result file
	ofTotal = open(globvars.OUTPUT_DIR + os.sep + "space_history_total.csv", 'wb')
	writerTotal = csv.writer(ofTotal, delimiter=';')
	ofUsed = open(globvars.OUTPUT_DIR + os.sep + "space_history_used.csv", 'wb')
	writerUsed = csv.writer(ofUsed, delimiter=';')

        # Init the first line with all dates
        listDates = ['site', 'hostname']
	for (fileName, date, rows, sum_total, sum_used) in dataFiles:
            listDates.append(date)
        if DEBUG: print "All dates: ", listDates
        writerTotal.writerow(listDates)
        writerUsed.writerow(listDates)

        for (host, data) in matrixTotal.iteritems():
            writerTotal.writerow([listSEs[host], host] + data)
        for (host, data) in matrixUsed.iteritems():
            writerUsed.writerow([listSEs[host], host] + data)

	ofTotal.close()
	ofUsed.close()
