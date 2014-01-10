#!/usr/bin/python
# This tools exploits the csv data files produced by script collect-ce-job-status.py,
# to make statistics about the ratio of running jobs / (running + waiting jobs).
# CEs which status in not normal production are ignored: draining until v1.0, and downtime, 
# GOCDB status 'not in production' or 'not monitored' from v1.1 on.
# The following files are produced in directory results/ :
# running_ratio.csv, running_ratio_day_night.csv, ce_grouped_by_running_ratio.csv, 
# running_ratio_bad.csv, distribute_ce_by_running_ratio.csv,
# and one file per CE queue in results/CE.
#
# With no option at all, this script processes all data files from the local dir, and writes the output files to
# the <local dir>/results.
#
# Author: Franck MICHEL, CNRS, I3S lab. fmichel[at]i3s[dot]unice[dot]fr
# ChangeLog:
# 1.1: 2012-08-25 - take into account the status from the GOCDB to ignore CEs
# 2.0: 2012-11-08 - refactor code in several modules
# 2.1: 2013-03-27 - ignore files of size 0
# 2.2: 2013-08-02 - add booleans to select sub processes to call

import sys
import os
import commands
import csv
import re

from operator import itemgetter, attrgetter
from optparse import OptionParser

import globvars
import processors.running_ratio
import processors.running_ratio_daily
import processors.running_ratio_day_night
import processors.distribute_ce_by_running_ratio
import processors.running_ratio_slices
import processors.running_ratio_bad
import processors.running_ratio_per_ce

optParser = OptionParser(version="%prog 2.1", description="""This tools exploits the csv data files produced by script collect-ce-job-status.py,
to make statistics about the ratio of running jobs / (running + waiting jobs).
CE which status in not normal production are ignored.
Currently the following files are produced: running_ratio.csv, running_ratio_daily.csv, running_ratio_day_night.csv, ce_grouped_by_running_ratio.csv, running_ratio_bad.csv,
and distribute_ce_by_running_ratio.csv. With no option at all, this tool processes all data files from the local dir, and writes the output files to
the local dir.
""")

optParser.add_option("--input-dir", action="store", dest="input_dir", default='.',
                     help="Directory where to look for files to process. Defaults to '.'")

optParser.add_option("--from", action="store", dest="fromDate", default='00000000',
                     help="Starting date, formatted as YYYYMMDD. Defaults the origin of time!")

optParser.add_option("--to", action="store", dest="toDate", default='99999999',
                     help="Ending date (inclusive), formatted as YYYYMMDD. Defaults to the end of time!")

optParser.add_option("--output-dir", action="store", dest="output_dir", default='',
                     help="Directory where to write output files. Defaults to './results'.")

optParser.add_option("--decimal-mark", action="store", dest="decimal_mark", default=',',
                     help="The decimal marker. Defaults to comma (','), but some tools may need the dot instead")

optParser.add_option("--csv-separator", action="store", dest="csv_separator", default=';',
                     help="The CSV field separator. Defaults to semi-column (';'), but some tools may need the comma instead")

optParser.add_option("--monce", action="store_true", dest="monce",
                     help="Insert additional columns for test results of the MonCE tool")

optParser.add_option("--no-running-ratio", action="store_false", dest="run_running_ratio", default=True,
		     help="don't run running_ratio process")

optParser.add_option("--no-running-ratio-daily", action="store_false", dest="run_running_ratio_daily", default=True,
		     help="don't run running_ratio_daily process")

optParser.add_option("--no-running-ratio-day-night", action="store_false", dest="run_running_ratio_day_night", default=True,
		     help="don't run running_ratio_day_night")

optParser.add_option("--no-distribute-ce-by-running-ratio", action="store_false", dest="run_distribute_ce_by_running_ratio", default=True,
		     help="don't run distribute_ce_by_running_ratio process")

optParser.add_option("--no-running-ratio-slices", action="store_false", dest="run_running_ratio_slices", default=True,
		     help="don't run running_ratio_slices process")

optParser.add_option("--no-running-ratio-bad", action="store_false", dest="run_running_ratio_bad", default=True,
		     help="don't run running_ratio_bad process")

optParser.add_option("--no-running-ratio-per-ce", action="store_false", dest="run_running_ratio_per_ce", default=True,
		     help="don't run running_ratio_per_ce process")

optParser.add_option("--stdout", action="store_true", dest="stdout", default=False,
		     help="set script output to stdout. This option is mutually exclusive with output_dir.")

optParser.add_option("--percent", action="store_true", dest="percent", default=False,
		     help="computes running ratio slices rates as percentage.")

optParser.add_option("--debug", action="store_true", dest="debug",
                     help="Add debug traces")

# -------------------------------------------------------------------------
# Definitions, global variables, and parameters check
# -------------------------------------------------------------------------

(options, args) = optParser.parse_args()

if ((options.output_dir != '') and options.stdout) : optParser.error("Options --output-dir and --stdout are mutually exclusive")
if ((not options.stdout) and (options.output_dir == '')) : options.output_dir='results'

globvars.DATA_DIR = options.input_dir
globvars.FROM_DATE = options.fromDate
globvars.TO_DATE = options.toDate
globvars.DEBUG = options.debug
globvars.DECIMAL_MARK = options.decimal_mark
globvars.CSV_DELIMITER = options.csv_separator
globvars.OUTPUT_DIR = options.output_dir
globvars.STDOUT = options.stdout
globvars.MONCE = options.monce
globvars.PERCENT = options.percent

globvars.RUN_RUNNING_RATIO = options.run_running_ratio
globvars.RUN_RUNNING_RATIO_DAILY = options.run_running_ratio_daily
globvars.RUN_RUNNING_RATIO_DAY_NIGHT = options.run_running_ratio_day_night
globvars.RUN_DISTRIBUTE_CE_BY_RUNNING_RATIO = options.run_distribute_ce_by_running_ratio
globvars.RUN_RUNNING_RATIO_SLICES = options.run_running_ratio_slices
globvars.RUN_RUNNING_RATIO_BAD = options.run_running_ratio_bad
globvars.RUN_RUNNING_RATIO_PER_CE = options.run_running_ratio_per_ce


if not os.path.isdir(globvars.DATA_DIR):
    print "Input directory " + globvars.DATA_DIR + " is not valid."
    sys.exit(1)
if ((not globvars.STDOUT) and (not os.path.isdir(globvars.OUTPUT_DIR))):
    print "Output directory " + globvars.OUTPUT_DIR + " is not valid."
    sys.exit(1)

# -------------------------------------------------------------------------
# Function: dataQualityCheck
# 
# This function checks the quality of data read from a row of a CSV file:
# it returns False if:
# - any number of jobs for the VO (total, running or waiting) has
#   a default value starting with '4444' or is empty,
# - any number of jobs for the VO is a negative value
# - the CE is is in status downtime, not in production, not monitired, or draining
# Returns true in any other case.
# -------------------------------------------------------------------------
def dataQualityCheck(structRow):
    status = structRow['CE_Status'].lower()
    run = structRow['VO_Running']
    wait = structRow['VO_Waiting']
    if (
        run.startswith('4444') or
        wait.startswith('4444') or
        run == '' or wait == '' or
        int(run) < 0 or int(wait) < 0 or

        status.find('downtime') != -1 or
        status.find('not in production') != -1 or
        status.find('not monitored') != -1 or
        status.find('draining') != -1
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
# Load all selected csv files, and compute per file sums of waiting and running jobs
# -------------------------------------------------------------------------

# The CSV files have the following columns:
# Site; CE; ImplName; ImplVer; CE Total; VO Total; CE Waiting; VO Waiting; CE Running; VO Running; 
# CE FreeSlots; VO FreeSlots; CE MaxTotal; VO MaxTotal; CE MaxWaiting; VO MaxWaiting; CE MaxRunning; 
# VO MaxRunning; CE WRT; VO WRT; CE ERT; VO ERT"
#
# They are loaded into variable 'dataFiles', a list of tuples: 
# 	(fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running)
# where
# - datetime is formated as "YYYY-MM-DD HH:MM:SS"
# - date is only the date part YYYY:MM:DD, and hour is only the hour HH (used for filtering data in excel file)
# - rows is a dictionnary wich keys are the hostnames and values are another dictionnary with the following keys:
#  'Site'
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
    if globvars.DEBUG: print "Loading file", fileName

    rows = {}
    for row in reader:
        if row[0].startswith('#'): continue   # Ignore lines begining with '#' (header line)

        host = row[1].strip()

        # The CE Status was not acquired in intial version of the collect script
        # => need to test if the column exists before reading it.
        status = ''
        if len(row) >= 23: status = row[22].strip()
        structRow = {
	        'Site':row[0].strip(),
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

        # Check the quality of data before storing it
        if dataQualityCheck(structRow):
            rows[host] = structRow
        else: 
            if globvars.DEBUG: print "QC removing CE", host + ": status=" + structRow['CE_Status']
        # End of loop of rows

    # Calculate sums of number of jobs for the VO
    sum_VO_Waiting, sum_VO_Running = 0, 0
    for host, strucRow in rows.iteritems():
        sum_VO_Waiting += int(strucRow['VO_Waiting'])
        sum_VO_Running += int(strucRow['VO_Running'])

    # Finally, add new loaded file to the list of loaded files
    dataFiles.append((fileName, datetime, date, hour, rows, sum_VO_Waiting, sum_VO_Running))
    if globvars.DEBUG: 
        print "Loaded", len(rows), "rows from " + fileName
        print "sum_VO_Waiting:", sum_VO_Waiting, "- sum_VO_Running:", sum_VO_Running
    inputf.close()

    # End loop on files

if globvars.DEBUG: print "Loaded", len(dataFiles), "files."

if globvars.STDOUT: print "<running_ratio>", 
# -------------------------------------------------------------------------
# Compute the running ratio R/(R+W) as a function of time
if globvars.RUN_RUNNING_RATIO: processors.running_ratio.process(dataFiles)

if globvars.RUN_RUNNING_RATIO_DAILY: processors.running_ratio_daily.process(dataFiles)

# -------------------------------------------------------------------------
# Compute the mean running ratio R/(R+W) during day time (12h, 16h, 20h)
# or night time (0h, 4h, 8h), as a function of time
if globvars.RUN_RUNNING_RATIO_DAY_NIGHT: processors.running_ratio_day_night.process(dataFiles)

# -------------------------------------------------------------------------
# Compute the distribution of CE queues by ratio R/(R+W)
if globvars.RUN_DISTRIBUTE_CE_BY_RUNNING_RATIO: processors.distribute_ce_by_running_ratio.process(dataFiles)

# -------------------------------------------------------------------------
# Compute the number of CEs grouped by ratio R/(R+W) as a function of time:
# between 0 and 0,5, and between 0,5 and 1
if globvars.RUN_RUNNING_RATIO_SLICES: processors.running_ratio_slices.process(dataFiles)

# -------------------------------------------------------------------------
# Try to figure out good and bad CEs: compute the list of CE queues based on the 
# number of times each one has been seen with 0 running jobs, or no activity...
if globvars.RUN_RUNNING_RATIO_BAD: processors.running_ratio_bad.process(dataFiles)

# -------------------------------------------------------------------------
# Compute the running ratio R/(R+W) per CE as a function of time
if globvars.RUN_RUNNING_RATIO_PER_CE: processors.running_ratio_per_ce.process(dataFiles)

if globvars.STDOUT: print "</running_ratio>",

