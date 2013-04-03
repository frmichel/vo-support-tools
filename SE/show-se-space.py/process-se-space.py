#!/usr/bin/python
# This tools exploits the csv data files produced by script show-se-space.py,
# to make statistics about the space used on storage elements.
# The following file(s) is/are produced in directory results/ :
# space_history.csv: generate a simple history of the filling rate of each SE
#
# With no option at all, this script processes all data files from the local dir, and writes the output files to
# the <local dir>/results.
#
# ChangeLog:
# 1.0: 2013-04-04 - initial version

import sys
import os
import commands
import csv
import re

from operator import itemgetter, attrgetter
from optparse import OptionParser

import globvars
import processors.space_history

optParser = OptionParser(version="%prog 1.0", description="""This tools exploits the csv data files produced 
by script show-se-space.py, to show a time representation of the filling rate of SEs.
With no option at all, this tool processes all data files from the local dir, and writes the output files to
the local dir.
""")

optParser.add_option("--input-dir", action="store", dest="input_dir", default='.',
                     help="Directory where to look for files to process. Defaults to '.'")

optParser.add_option("--from", action="store", dest="fromDate", default='00000000',
                     help="Starting date, formatted as YYYMMDD. Defaults the origin of time!")

optParser.add_option("--to", action="store", dest="toDate", default='99999999',
                     help="Ending date (inclusive), formatted as YYYMMDD. Defaults to the end of time!")

optParser.add_option("--output-dir", action="store", dest="output_dir", default='results',
                     help="Directory where to write output files. Defaults to './results'.")

optParser.add_option("--decimal-mark", action="store", dest="decimal_mark", default=',',
                     help="The decimal marker. Defaults to comma (','), but some tools may need the dot instead")

optParser.add_option("--debug", action="store_true", dest="debug",
                     help="Add debug traces")

# -------------------------------------------------------------------------
# Definitions, global variables, and parameters check
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()

globvars.DATA_DIR = options.input_dir
globvars.FROM_DATE = options.fromDate
globvars.TO_DATE = options.toDate
globvars.DEBUG = options.debug
DECIMAL_MARK = globvars.DECIMAL_MARK = options.decimal_mark
globvars.OUTPUT_DIR = options.output_dir

if not os.path.isdir(globvars.DATA_DIR):
    print "Input directory " + globvars.DATA_DIR + " is not valid."
    sys.exit(1)
if not os.path.isdir(globvars.OUTPUT_DIR):
    print "Output directory " + globvars.OUTPUT_DIR + " is not valid."
    sys.exit(1)

# -------------------------------------------------------------------------
# Function: dataQualityCheck
# 
# This function checks the quality of data read from a row of a CSV file:
# it returns False if:
# - any space amount is negative
# - the used space is bigger than the total space
# - the filling rate is negative or bigger than 100
# Returns true in any other case.
# -------------------------------------------------------------------------
def dataQualityCheck(structRow):

    seTotal = int(structRow['SE_Total'])
    seUsed = int(structRow['SE_Used'])
    fillingRate = float(structRow['Filling_Rate'].replace(DECIMAL_MARK, '.'))
    if (
        seTotal < 0 or 
        seUsed < 0 or
        seTotal < seUsed or
        fillingRate < 0 or
        fillingRate > 100
       ):
        return False
    else: return True

# -------------------------------------------------------------------------
# Select data files to be processed given the "from date" and "to date" parameters
# -------------------------------------------------------------------------
files = []
sortedDir = sorted(os.listdir(globvars.DATA_DIR))
for fileName in sortedDir:
    if fileName.endswith('csv'):
        if fileName[:8] >= globvars.FROM_DATE and fileName[:8] <= globvars.TO_DATE:
            # It happens that some file are of size 0 (error at colelct time?): ignore them
            if os.stat(globvars.DATA_DIR + os.sep + fileName).st_size > 0:
                files.append(globvars.DATA_DIR + os.sep + fileName)

# -------------------------------------------------------------------------
# Load all selected csv files, and compute per file sums 
# -------------------------------------------------------------------------

# The CSV files have the following columns:
# sitename; SE hostname; SRM impl; SRM ver; total (GB); used (GB); filling rate (%); 
# % of VO total space; % of VO used space
#
# They are loaded into variable 'dataFiles', a list of tuples: 
# 	(fileName, date, rows, sum_total, sum_used)
# where
# - date is only the date part YYYY:MM:DD
# - rows is a dictionnary wich keys are the hostnames and values are another dictionnary with the following keys:
#  'Site', 'ImplName', 'ImplVer', 'SE_Total', 'SE_Used', 'Filling_Rate'
dataFiles = []

# Regexp to extract the date and time from the file name
matchFileName = re.compile(".*/(\d{8})-(\d{6})")

for fileName in files:

    # Parse the file name to get date and time
    match = matchFileName.match(fileName)
    datetime = ""	# the full date and time
    date = ""		# only the date part YYYY:MM:DD
    if match <> None: 
        datetime = match.group(1)
        date = datetime[0:4] + '-' + datetime[4:6] + '-' + datetime[6:8]
    else:
        # If the file name is not corret, skip it
        print "ERROR: " + fileName + " does not match the expected format YYYYMMDD-HHMMSS.csv"
        continue

    # Open the file with a csv reader
    inputf = open(fileName, 'rb')
    reader = csv.reader(inputf, delimiter=';')
    if globvars.DEBUG: print "Loading file", fileName

    rows = {}
    for row in reader:
        if row[0].startswith('#'): continue   # Ignore lines begining with '#' (header line)
        if row[0].startswith('sitename'): continue   # Ignore first line

        host = row[1].strip()
        structRow = {
	        'Site':row[0].strip(),
	        'ImplName':row[2].strip(),
	        'ImplVer':row[3].strip(),
	        'SE_Total':row[4].strip(),
	        'SE_Used':row[5].strip(),
	        'Filling_Rate':row[6].strip(),
         }

        # Check the quality of data before storing it
        if dataQualityCheck(structRow):
            rows[host] = structRow
        else: 
            if globvars.DEBUG: print "QC removing SE", host
        # End of loop of rows

    # Calculate sums
    sum_total, sum_used = 0, 0
    for host, strucRow in rows.iteritems():
        sum_total += int(strucRow['SE_Total'])
        sum_used += int(strucRow['SE_Used'])

    # Finally, add new loaded file to the list of loaded files
    dataFiles.append((fileName, date, rows, sum_total, sum_used))
    if globvars.DEBUG: 
        print "Loaded", len(rows), "rows from " + fileName
        print "sum_total:", sum_total, "- sum_used:", sum_used
    inputf.close()

    # End loop on files

if globvars.DEBUG: print "Loaded", len(dataFiles), "files."


# -------------------------------------------------------------------------
# Generate a simple history of the filling rate of each SE
processors.space_history.process(dataFiles)

