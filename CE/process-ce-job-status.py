#!/usr/bin/python

import sys
import os
import commands
import csv
import re

from operator import itemgetter, attrgetter
from optparse import OptionParser

optParser = OptionParser(version="%prog 1.0", description="""""")

optParser.add_option("--dir", action="store", dest="dataDir", default='.',
                     help="Directory where to look for files to process. Defaults to '.'")

optParser.add_option("--from", action="store", dest="fromDate", default='00000000',
                     help="Starting date, formatted as YYYMMDD. Defaults the origin of time!")

optParser.add_option("--to", action="store", dest="toDate", default='99999999',
                     help="Ending date (inclusive), formatted as YYYMMDD. Defaults to the end of time!")

optParser.add_option("--debug", action="store_true", dest="debug",
                     help="Add debug traces")

# -------------------------------------------------------------------------
# Definitions, global variables, and parameters check
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()

DATA_DIR=options.dataDir
FROM_DATE = options.fromDate
TO_DATE = options.toDate
DEBUG = options.debug

if not os.path.isdir(DATA_DIR):
    print DATA_DIR + " is not a valid directory."
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
# They are loaded into the multidimensional dictionary dataFiles, which has the following structure:
# dataFiles:
#     fileName => dictionary:
#         'datetime' => value formated as "YYYY-MM-DD HH:MM:SS"
#          hostname => dictionary:
#              'ImplName', 'ImplVer'
#              'ImplName', 'ImplVer'
#              'CE_Total', 'VO_Total'
#              'CE_Running', 'VO_Running'
#              'CE_Waiting', 'VO_Waiting'
#              'CE_Running', 'VO_Running'
#              'CE_FreeSlots', 'VO_FreeSlots'
#              'CE_MaxTotal', 'VO_MaxTotal'
#              'CE_MaxWaiting', 'VO_MaxWaiting'
#              'CE_MaxRunning', 'VO_MaxRunning'
#              'CE_WRT', 'VO_WRT'
#              'CE_MaxTotal', 'VO_MaxTotal'
#              'CE_ERT', 'VO_ERT'
#          'sum_VO_Waiting'
#          'sum_VO_Running'
dataFiles = {}

# Regexp to get the date and time from the file name
matchFileName = re.compile("/(\d{8})-(\d{6})")

for fileName in files:

    reader = csv.reader(open(fileName, 'rb'), delimiter=';')
    if DEBUG: print "Loading file", fileName

    dataFile = {}
    for row in reader:
        if row[0].startswith('#'): continue   # Ignore lines beginning with '#' (header line)

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
            dataFile[host] = structRow
        else: 
            if DEBUG: print "QC removing CE", host
        # End of loop of rows

    # Calculate sums of number of jobs for the VO
    sum_VO_Waiting, sum_VO_Running = 0, 0
    for host, strucRow in dataFile.iteritems():
        sum_VO_Waiting += int(strucRow['VO_Waiting'])
        sum_VO_Running += int(strucRow['VO_Running'])

    dataFile['sum_VO_Waiting'] = sum_VO_Waiting
    dataFile['sum_VO_Running'] = sum_VO_Running

    # Parse the file name to get date and time
    match = matchFileName.match(fileName)
    if match <> None: 
        date = match.group(1)
        time = match.group(2)
        datetime = date[0:4] + '-' + date[4:6] + '-' + date[6:8] + ' ' + time[0:2] + ':' + time[2:4] + ':' + time[4:6]
        dataFile['datetime'] = datetime
    else:
        print "ERROR: " + fileName + " does not match the expected format YYYYMMDD-HHMMSS.csv"
        continue

    # Finally, add new loaded file to the list of loaded files
    dataFiles[fileName] = dataFile
    if DEBUG: 
        print "Loaded", len(dataFile), "rows from " + fileName
        print "sum_VO_Waiting:", sum_VO_Waiting, "- sum_VO_Running:", sum_VO_Running
    # End loop on files

if DEBUG: print "Loaded", len(dataFiles), "files."


# -------------------------------------------------------------------------
# Process data...
# -------------------------------------------------------------------------

outputFile = "output.csv"
f = open(outputFile, 'wb')
writer = csv.writer(f, delimiter=';')
writer.writerow(['# Date time', 'Avg. R/(R+W)'])

for fileName, dataFile in dataFiles.iteritems():
    R = float(dataFile['sum_VO_Running'])
    W = float(dataFile['sum_VO_Waiting'])
    if R+W > 0:
        writer.writerow([dataFile['datetime'], round(R/(R+W), 2)])

f.close()
