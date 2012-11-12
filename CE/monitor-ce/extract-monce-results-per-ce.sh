#!/bin/bash
# This file extracts data from the biomed_stats MySQL database, and generates a csv file with the following columns:
# CE host name and queue; number of tests OK, number of errors, number of timeouts, total time spent waiting for ok tests.
#
# The database must be populated with the results from the MonCE tool made by Patrick Guterl (IPHC).
#
# Usage:
# - populate the database with the backup file, e.g. "mysql --user biomed --password biomed_stats < backup_PGT.sql"
# - in extract-monce-results-per-ce.sh, set variables FROM_DATE and TO_DATE to select the timeslot
# - cd to the directory with extract-monce-results-per-ce.sh file and run it. It will ask for the MySQL root password.
# - the result file is into ~/results/monce-results-per-ce.csv

FROM_DATE="2012-08-29 00:00:00"
TO_DATE="2012-09-30 23:59:59"

RESULT_FILE=/tmp/monce-results-per-ce.csv

# First remove the last result file in case it exists, as root because it is created by the DIRAC user (that runs mysql)
ssh root@localhost "\rm -f $RESULT_FILE"

mysql --user root --password biomed_stats <<EOF
select ResOK.CE, ResOK.OK, ResError.Error, ResTO.Timeout, ResOK.sumTimeOK
from
(	select concat(concat(host, ":8443"), path) as CE, count(host) as OK, sum(temps) as sumTimeOK
	from monce_vo 
	where 	state="OK" and
		date>="$FROM_DATE" and date<="$TO_DATE"
	group by CE
) ResOK, 
(	select concat(concat(host, ":8443"), path) as CE, count(host) as Error
	from monce_vo 
	where 	state="ERROR" and
		date>="$FROM_DATE" and date<="$TO_DATE"
	group by CE
) ResError,
(	select concat(concat(host, ":8443"), path) as CE, count(host) as Timeout
	from monce_vo 
	where 	state="TIMEOUT" and
		date>="$FROM_DATE" and date<="$TO_DATE"
	group by CE
) ResTO
where
	ResOK.CE=ResError.CE and ResOK.CE=ResTO.CE
order by concat(ResOK.CE)
INTO OUTFILE "$RESULT_FILE"
FIELDS TERMINATED BY ';' LINES TERMINATED BY '\n';
EOF

# Move the result file to the local dir and make me the owner
ssh root@localhost "chown fmichel:fmichel $RESULT_FILE; \mv $RESULT_FILE $PWD/results"
