#!/usr/bin/python
# This tools exploits the csv data files produced by script collect-ce-job-status.py,
# to make statistics about the ratio of running jobs / (running + waiting jobs).
# CE which status in not normal production are ignored: draining until v1.0, and downtime, 
# not in production or not monitored from v1.1 on.
# Currently 3 files are produced: service_ratio.csv, service_ratio_day_night.csv
# and distrib_ce_by_service_ratio.csv.
#
# With no option at all, it processes all data files from the local dir, and writes the output files to
# the local dir.

import sys
import os
import commands
import csv
import re

from operator import itemgetter, attrgetter
from optparse import OptionParser

optParser = OptionParser(version="%prog 1.1", description="""This tools exploits the csv data files produced by script collect-ce-job-status.py,
to make statistics about the ratio of running jobs / (running + waiting jobs).
CE which status in not normal production are ignored.
Currently 3 files are produced: service_ratio.csv, service_ratio_day_night.csv and distrib_ce_by_service_ratio.csv.
With no option at all, this tool processes all data files from the local dir, and writes the output files to
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
                     help="The decimal marker. Defaults to comma (','), but some tools may need the dot instead")

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
# it returns False if:
# - any number of jobs for the VO (total, running or waiting) has
#   a default value starting with '4444' or is empty,
# - the CE is is in status downtime, not i production, not monitired, or draining
# Returns true in any other case.
# -------------------------------------------------------------------------
def dataQualityCheck(structRow):
    status = structRow['CE_Status'].lower()
    if (
        structRow['VO_Running'].startswith('4444') or
        structRow['VO_Waiting'].startswith('4444') or
        structRow['VO_Running'] == '' or
        structRow['VO_Waiting'] == '' or

        status.find('downtime') != -1 or
        status.find('not in production') != -1 or
        status.find('not monitored') != -1 or
        status.find('draining') != -1
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
# They are loaded into variable 'dataFiles', a list of tuples: 
# (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running), where
# - datetime is formated as "YYYY-MM-DD HH:MM:SS"
# - date is only the date part YYYY:MM:DD, and hour is nly the hour HH (used for filtering data in excel file)
# - rows is a dictionnary with the following keys:
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
#  'CE_Status'
dataFiles = []

# Regexp to extract the date and time from the file name
matchFileName = re.compile(".*/(\d{8})-(\d{6})")

for fileName in files:

    # Parse the file name to get date and time
    match = matchFileName.match(fileName)
    datetime = ""	# the full date and time
    date = ""		# only the date part YYYY:MM:DD
    hour = ""		# only the hour HH (used for filtering data in excel file)
    if match <> None: 
        date = match.group(1)
        time = match.group(2)
        datetime = date[0:4] + '-' + date[4:6] + '-' + date[6:8] + ' ' + time[0:2] + ':' + time[2:4] + ':' + time[4:6]
        date = date[0:4] + '-' + date[4:6] + '-' + date[6:8]
        hour = time[0:2]
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

        # The CE Status was not acquired in intial version => need to test if the column exists
        status = ''
        if len(row) >= 23: status = row[22].strip()

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
        'VO_ERT':row[21].strip(),
        'CE_Status':status
         }

        if dataQualityCheck(structRow):
            rows[host] = structRow
        else: 
            if DEBUG: print "QC removing CE", host + ": status=" + structRow['CE_Status']
        # End of loop of rows

    # Calculate sums of number of jobs for the VO
    sum_VO_Waiting, sum_VO_Running = 0, 0
    for host, strucRow in rows.iteritems():
        sum_VO_Waiting += int(strucRow['VO_Waiting'])
        sum_VO_Running += int(strucRow['VO_Running'])

    # Finally, add new loaded file to the list of loaded files
    dataFiles.append((fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running))
    if DEBUG: 
        print "Loaded", len(rows), "rows from " + fileName
        print "sum_VO_Waiting:", sum_VO_Waiting, "- sum_VO_Running:", sum_VO_Running
    inputf.close()

    # End loop on files

if DEBUG: print "Loaded", len(dataFiles), "files."

# -------------------------------------------------------------------------
# Compute the ratio R/(R+W) as a function of time
# -------------------------------------------------------------------------
if DEBUG: print "Computing the average ratio R/(R+W) as a function of time..."

outputFile = OUTPUT_DIR + os.sep + "service_ratio.csv"
outputf = open(outputFile, 'wb')
writer = csv.writer(outputf, delimiter=';')
writer.writerow(["# Date time", "Waiting", "Running", "R/(R+W)"])

# Loop on all data files that were acquired
for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:
    R = float(sum_VO_Running)
    W = float(sum_VO_Waiting)
    if R+W > 0:
        writer.writerow([datetime, sum_VO_Waiting, sum_VO_Running, str(round(R/(R+W), 4)).replace('.', DECIMAL_MARK) ])

outputf.close()


# -------------------------------------------------------------------------
# Compute the average ratio R/(R+W) during day (12h, 16h, 20h) or night (0h, 4h, 8h)
# -------------------------------------------------------------------------
if DEBUG: print "Computing the average ratio R/(R+W) during day or night..."

outputFile = OUTPUT_DIR + os.sep + "service_ratio_day_night.csv"
outputf = open(outputFile, 'wb')
writer = csv.writer(outputf, delimiter=';')
writer.writerow(["# Date", "Wait 0h", "Run 0h", "R/(R+W) 0h", "Wait 4h", "Run 4h", "R/(R+W) 4h", "Wait 8h", "Run 8h", "R/(R+W) 8h", "Wait 12h", "Run 12h", "R/(R+W) 12h", "Wait 16h", "Run 16h", "R/(R+W) 16h", "Wait 20h", "Run 20h", "R/(R+W) 20h", "Avg Wait night", "Avg Run night", "Avg R/(R+W) night", "Avg Wait day", "Avg Run day", "Avg R/(R+W) day"])

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

# -------------------------------------------------------------------------
# Compute the distribution of CEs by ratio R/(R+W) as a function of time
# -------------------------------------------------------------------------
if DEBUG: print "Computing the distribution of CEs by ratio R/(R+W) as a function of time..."

outputFile = OUTPUT_DIR + os.sep + "distrib_ce_by_service_ratio.csv"
outputf = open(outputFile, 'wb')
writer = csv.writer(outputf, delimiter=';')

writer.writerow(["# Date time", "Nb queues", "0", "0 to 0,5", "0,5 to 1", "1", "n/a"])

# Loop on all data files that were acquired
for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:

    nb_0 = nb_0_05 = nb_05_1 = nb_1 = nb_na = 0.0
    # Loop on all rows of the file
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


# -------------------------------------------------------------------------
# Compute the list of CEs queues based on the number of times each has been seen with 0 running jobs
# -------------------------------------------------------------------------
if DEBUG: print "Compute the list of worst CEs queues..."

outputFile = OUTPUT_DIR + os.sep + "service_ratio_bad.csv"
outputf = open(outputFile, 'wb')
writer = csv.writer(outputf, delimiter=';')
writer.writerow(["CE queue", "nb measures", "Avg Running", "Avg Waiting", "Avg W/R" , "Avg R/(R+W)" , "nb times R=0 and W>0", "% times R=0 and W>0", "nb times R+W=0", "% times R+W=0"])

# Loop on all data files that were acquired
queues = {}
for (fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running) in dataFiles:

    # Loop on all rows of the file
    for (hostname, structRow) in rows.iteritems():

        if hostname not in queues: 
            queues[hostname] = {'Running': 0, 'Waiting': 0, 'nb_measures':0, 'nb_0':0, 'nb_na': 0}

        W = float(structRow['VO_Waiting'])
        R = float(structRow['VO_Running'])
        queues[hostname]['nb_measures'] += 1
        queues[hostname]['Waiting'] += W
        queues[hostname]['Running'] += R
        if R+W == 0: queues[hostname]['nb_na'] += 1
        else:
            if R == 0: queues[hostname]['nb_0'] += 1

for hostname in queues:
    R = float(queues[hostname]['Running'])
    W = float(queues[hostname]['Waiting'])
    W_div_R = "n.a"
    if R != 0: W_div_R = str(round(W/R, 2)).replace('.', DECIMAL_MARK)
    ratio = "n.a"
    if R+W != 0: ratio = str(round(R/(W+R), 2)).replace('.', DECIMAL_MARK)
    nb = queues[hostname]['nb_measures']
    nb_0 = queues[hostname]['nb_0']
    nb_na = queues[hostname]['nb_na']
    writer.writerow([hostname, nb, 
                     str(round(R/nb, 2)).replace('.', DECIMAL_MARK),
                     str(round(W/nb, 2)).replace('.', DECIMAL_MARK),
                     W_div_R,
                     ratio,
                     nb_0, str(round(float(nb_0)/nb, 4)).replace('.', DECIMAL_MARK), 
                     nb_na, str(round(float(nb_na)/nb, 4)).replace('.', DECIMAL_MARK)
                     ])
outputf.close()
