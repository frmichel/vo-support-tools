#!/usr/bin/python
# This tools exploits the csv data files produced by script collect-ce-job-status.py,
# to make statistics about the ratio of running jobs / (running + waiting jobs).
#
# Currently two files are produced: job_service_ratio.csv and distrib_ce_by_service_ratio.csv
#
# With no option at all, it processes all data files from the local dir, and write the output files to
# the local dir.

import sys
import os
import commands
import csv
import re

from operator import itemgetter, attrgetter
from optparse import OptionParser

optParser = OptionParser(version="%prog 1.0", description="""This tools exploits the csv data files produced by script collect-ce-job-status.py,
to make statistics about the ratio of running jobs / (running + waiting jobs).
Currently two files are produced: average_job_service_ratio.csv and distrib_ce_by_service_ratio.csv.
With no option at all, it processes all data files from the local dir, and write the output files to
the local dir.
""")

optParser.add_option("--input-dir", action="store", dest="input_dir", default='.',
                     help="Directory where to look for files to process. Defaults to '.'")

optParser.add_option("--from", action="store", dest="fromDate", default='00000000',
                     help="Starting date, formatted as YYYMMDD. Defaults the origin of time!")

optParser.add_option("--to", action="store", dest="toDate", default='99999999',
                     help="Ending date (inclusive), formatted as YYYMMDD. Defaults to the end of time!")

optParser.add_option("--output-dir", action="store", dest="output_dir", default='.',
                     help="Directory where to write output files. Defaults to '.'.")

optParser.add_option("--decimal-mark", action="store", dest="decimal_mark", default=',',
                     help="The decimal marker. Default to comma (','), but some tools may need the dot instead")

optParser.add_option("--debug", action="store_true", dest="debug",
                     help="Add debug traces")

# -------------------------------------------------------------------------
# Definitions, global variables, and parameters check
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()

DATA_DIR=options.input_dir
FROM_DATE = options.fromDate
TO_DATE = options.toDate
DEBUG = options.debug
DECIMAL_MARK = options.decimal_mark
OUTPUT_DIR = options.output_dir

if not os.path.isdir(DATA_DIR):
    print "Input directory " + DATA_DIR + " is not valid."
    sys.exit(1)
if not os.path.isdir(OUTPUT_DIR):
    print "Output directory " + OUTPUT_DIR + " is not valid."
    sys.exit(1)

# -------------------------------------------------------------------------
# Function: dataQualityCheck
# 
# This function checks the quality of data read from a row of a CSV file:
# it returns False if any number of jobs for the VO (total, running or waiting) has
# a default value starting with '4444' or is empty.
# Returns true in any other case.
# -------------------------------------------------------------------------
def dataQualityCheck(structRow):
    if (
        structRow['VO_Running'].startswith('4444') or
        structRow['VO_Waiting'].startswith('4444') or
        structRow['VO_Running'] == '' or
        structRow['VO_Waiting'] == ''
       ):
        return False
    else: return True

# -------------------------------------------------------------------------
# Select data files to be processed
# -------------------------------------------------------------------------
files = []
sortedDir = sorted(os.listdir(DATA_DIR))
for fileName in sortedDir:
    if fileName.endswith('csv'):
        if fileName[:8] >= FROM_DATE and fileName[:8] <= TO_DATE:
            files.append(DATA_DIR + os.sep + fileName)

# -------------------------------------------------------------------------
# Load all selected csv files, and compute per file sums of wiating and running jobs
# -------------------------------------------------------------------------

# The CSV files have the following columns:
# Site; CE; ImplName; ImplVer; CE Total; VO Total; CE Waiting; VO Waiting; CE Running; VO Running; 
# CE FreeSlots; VO FreeSlots; CE MaxTotal; VO MaxTotal; CE MaxWaiting; VO MaxWaiting; CE MaxRunning; 
# VO MaxRunning; CE WRT; VO WRT; CE ERT; VO ERT"
#
# They are loaded into dataFiles, a list of tuples (fileName, datetime, rows, sum_VO_Waiting, sum_VO_Running)
# where datetime is formated as "YYYY-MM-DD HH:MM:SS", and rows is a dictionnary with the following keys:
#  'ImplName', 'ImplVer'
#  'ImplName', 'ImplVer'
#  'CE_Total', 'VO_Total'
#  'CE_Running', 'VO_Running'
#  'CE_Waiting', 'VO_Waiting'
#  'CE_Running', 'VO_Running'
#  'CE_FreeSlots', 'VO_FreeSlots'
#  'CE_MaxTotal', 'VO_MaxTotal'
#  'CE_MaxWaiting', 'VO_MaxWaiting'
#  'CE_MaxRunning', 'VO_MaxRunning'
#  'CE_WRT', 'VO_WRT'
#  'CE_MaxTotal', 'VO_MaxTotal'
#  'CE_ERT', 'VO_ERT'
dataFiles = []

# Regexp to extract the date and time from the file name
matchFileName = re.compile(".*/(\d{8})-(\d{6})")

for fileName in files:

    # Parse the file name to get date and time
    match = matchFileName.match(fileName)
    datetime = ""
    if match <> None: 
        date = match.group(1)
        time = match.group(2)
        datetime = date[0:4] + '-' + date[4:6] + '-' + date[6:8] + ' ' + time[0:2] + ':' + time[2:4] + ':' + time[4:6]
    else:
        # If the file name is not corret, skip it
        print "ERROR: " + fileName + " does not match the expected format YYYYMMDD-HHMMSS.csv"
        continue

    # Open the file with a csv reader
    inputf = open(fileName, 'rb')
    reader = csv.reader(inputf, delimiter=';')
    if DEBUG: print "Loading file", fileName

    rows = {}
    for row in reader:
        if row[0].startswith('#'): continue   # Ignore lines begining with '#' (header line)

        host = row[1].strip()
        structRow = {'Site':row[0].strip(),
        'ImplName':row[2].strip(),
        'ImplVer':row[3].strip(),
        'CE_Total':row[4].strip(),
        'VO_Total':row[5].strip(),
        'CE_Waiting':row[6].strip(),
        'VO_Waiting':row[7].strip(),
        'CE_Running':row[8].strip(),
        'VO_Running':row[9].strip(),
        'CE_FreeSlots':row[10].strip(),
        'VO_FreeSlots':row[11].strip(),
        'CE_MaxTotal':row[12].strip(),
        'VO_MaxTotal':row[13].strip(),
        'CE_MaxWaiting':row[14].strip(),
        'VO_MaxWaiting':row[15].strip(),
        'CE_MaxRunning':row[16].strip(),
        'VO_MaxRunning':row[17].strip(),
        'CE_WRT':row[18].strip(),
        'VO_WRT':row[19].strip(),
        'CE_ERT':row[20].strip(),
        'VO_ERT':row[21].strip() }

        if dataQualityCheck(structRow):
            rows[host] = structRow
        else: 
            if DEBUG: print "QC removing CE", host
        # End of loop of rows

    # Calculate sums of number of jobs for the VO
    sum_VO_Waiting, sum_VO_Running = 0, 0
    for host, strucRow in rows.iteritems():
        sum_VO_Waiting += int(strucRow['VO_Waiting'])
        sum_VO_Running += int(strucRow['VO_Running'])

    # Finally, add new loaded file to the list of loaded files
    dataFiles.append((fileName, datetime, rows, sum_VO_Waiting, sum_VO_Running))
    if DEBUG: 
        print "Loaded", len(rows), "rows from " + fileName
        print "sum_VO_Waiting:", sum_VO_Waiting, "- sum_VO_Running:", sum_VO_Running
    inputf.close()

    # End loop on files

if DEBUG: print "Loaded", len(dataFiles), "files."

# -------------------------------------------------------------------------
# Compute the average ratio R/(R+W) as a function of time
# -------------------------------------------------------------------------
if DEBUG: print "Computing the average ratio R/(R+W) as a function of time..."

outputFile = OUTPUT_DIR + os.sep + "job_service_ratio.csv"
outputf = open(outputFile, 'wb')
writer = csv.writer(outputf, delimiter=';')
writer.writerow(["# Date time", "Waiting", "Running", "R/(R+W)"])

for (fileName, datetime, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:
    R = float(sum_VO_Running)
    W = float(sum_VO_Waiting)
    if R+W > 0:
        writer.writerow([datetime, sum_VO_Waiting, sum_VO_Running, str(round(R/(R+W), 4)).replace('.', DECIMAL_MARK) ])

outputf.close()

# -------------------------------------------------------------------------
# Compute the distribution of CEs by ratio R/(R+W) as a function of time
# -------------------------------------------------------------------------
if DEBUG: print "Computing the distribution of CEs by ratio R/(R+W) as a function of time..."

outputFile = OUTPUT_DIR + os.sep + "distrib_ce_by_service_ratio.csv"
outputf = open(outputFile, 'wb')
writer = csv.writer(outputf, delimiter=';')

writer.writerow(["# Date time", "Nb queues", "0", "0 to 0,5", "0,5 to 1", "1", "n/a"])

for (fileName, datetime, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:

    nb_0 = nb_0_05 = nb_05_1 = nb_1 = nb_na = 0.0
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
    nbQ = len(rows)
    writer.writerow([datetime, nbQ, 
                     str(round(nb_0/nbQ, 4)).replace('.', DECIMAL_MARK), 
                     str(round(nb_0_05/nbQ, 4)).replace('.', DECIMAL_MARK), 
                     str(round(nb_05_1/nbQ, 4)).replace('.', DECIMAL_MARK), 
                     str(round(nb_1/nbQ, 4)).replace('.', DECIMAL_MARK), 
                     str(round(nb_na/nbQ, 4)).replace('.', DECIMAL_MARK) 
                     ])

outputf.close()
