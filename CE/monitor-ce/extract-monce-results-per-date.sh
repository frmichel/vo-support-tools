#!/bin/bash
# This file extracts data from the biomed_stats MySQL database, and generates a csv file with the following columns:
# date; total number of tests; number of tests OK; number of errors; number of timeouts; average time spent waiting for ok tests;
# % of test OK; % of errors; % of test timeouts
#
# The database must be populated with the results from the MonCE tool made by Patrick Guterl (IPHC).
#
# Usage:
# - populate the database with the backup file: "mysql --user biomed --password biomed_stats < backup_PGT.sql"
# - in extract-monce-results-per-date.sh, set FROM_DATE and TO_DATE to select the timeslot
# - cd to the directory with extract-monce-results-per-date.sh file and run it. It will ask for the MySQL root password.
# - the result file is into ~/results/monce-results-per-date.csv

FROM_DATE="2012-11-13 00:00:00"
TO_DATE="2012-12-16 23:59:59"

RESULT_FILE='/tmp/monce-results-per-date.csv'

# First remove the last result file in case it exists, as root because it is created by the DIRAC user (that runs mysql)
ssh root@localhost "\rm -f $RESULT_FILE"

mysql --user root --password biomed_stats <<EOF

select ResOK.date, 
    (ResOK.OK + ResError.Error + ResTO.Timeout) as nb_measures,
    ResOK.OK, ResError.Error, ResTO.Timeout, 
    FLOOR(ResOK.sumTimeOK / ResOK.OK) as avg_TimeOK,
    FLOOR(ResOK.OK * 100       / (ResOK.OK + ResError.Error + ResTO.Timeout)) as percentOK,	
    FLOOR(ResError.Error * 100 / (ResOK.OK + ResError.Error + ResTO.Timeout)) as percentError,
    FLOOR(ResTO.Timeout * 100  / (ResOK.OK + ResError.Error + ResTO.Timeout)) as percentTimeout
from
(	select DATE(date) as date, count(host) as OK, sum(temps) as sumTimeOK
	from monce_vo 
	where 	state="OK" and
		date>="$FROM_DATE" and date<="$TO_DATE"
	group by DATE(date)
) ResOK, 
(	select DATE(date) as date, count(host) as Error
	from monce_vo 
	where 	state="ERROR" and
		date>="$FROM_DATE" and date<="$TO_DATE"
	group by DATE(date)
) ResError,
(	select DATE(date) as date, count(host) as Timeout
	from monce_vo 
	where 	state="TIMEOUT" and
		date>="$FROM_DATE" and date<="$TO_DATE"
	group by DATE(date)
) ResTO
where
	ResOK.date=ResError.date and ResOK.date=ResTO.date
order by ResOK.date
INTO OUTFILE "$RESULT_FILE"
FIELDS TERMINATED BY ';' LINES TERMINATED BY '\n';
EOF

# Move the result file to the local dir and make me the owner
ssh root@localhost "chown fmichel:fmichel $RESULT_FILE; \mv $RESULT_FILE $PWD/results"
