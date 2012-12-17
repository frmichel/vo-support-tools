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

RESULT_FILE='/tmp/monce-results-per-ce-per-date.csv'


# First build the list of CE queues from the database
CE_QUEUES='/tmp/monce-ce-queues.csv'
ssh root@localhost "\rm -f $CE_QUEUES"

mysql --user root --password biomed_stats <<EOF
select concat(concat(host, ":8443"), path) as CE
	from monce_vo 
	where date>="2012-08-29 00:00:00" and date<="2012-09-30 23:59:59"
	group by concat(concat(host, ":8443"), path)
	order by concat(concat(host, ":8443"), path)
INTO OUTFILE "$CE_QUEUES"
FIELDS TERMINATED BY ';' LINES TERMINATED BY '\n';
EOF



for CE in `cat $CE_QUEUES`
do
  filename=${CE/:/_}
  filename=${filename/\//_}
  echo $filename
done

exit 0


## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# NOT FINISHED ##### NEEDS MORE COMPLEX STUFF, to BE DONE WITH PYTHON+MYSQL
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Remove the last result file in case it exists, as root because it is created by the user that runs mysql (dirac in my case)
ssh root@localhost "\rm -f $RESULT_FILE"

mysql --user root --password biomed_stats <<EOF
EOF

select ResOK.date, ResError.date, ResTO.date, (ResOK.OK + ResError.Error + ResTO.Timeout) as nb_measures,
    ResOK.OK, ResError.Error, ResTO.Timeout, 
    FLOOR(ResOK.sumTimeOK / ResOK.OK) as avg_TimeOK,
    FLOOR(ResOK.OK * 100       / (ResOK.OK + ResError.Error + ResTO.Timeout)) as percentOK,	
    FLOOR(ResError.Error * 100 / (ResOK.OK + ResError.Error + ResTO.Timeout)) as percentError,
    FLOOR(ResTO.Timeout * 100  / (ResOK.OK + ResError.Error + ResTO.Timeout)) as percentTimeout
from
( select DATE(date) as date, count(host) as OK, sum(temps) as sumTimeOK
	from monce_vo 
	where 	state="OK" and
		date>="2012-08-29 00:00:00" and date<="2012-09-30 23:59:59" and
		concat(concat(host, ":8443"), path) = "cccreamceli09.in2p3.fr:8443/cream-sge-long"
	group by DATE(date)
) ResOK,
( select DATE(date) as date, count(host) as Error
	from monce_vo 
	where 	state="ERROR" and
		date>="2012-08-29 00:00:00" and date<="2012-09-30 23:59:59" and
		concat(concat(host, ":8443"), path) = "cccreamceli09.in2p3.fr:8443/cream-sge-long"
	group by DATE(date)
) ResError,
( select DATE(date) as date, count(host) as Timeout
	from monce_vo 
	where 	state="TIMEOUT" and
		date>="2012-08-29 00:00:00" and date<="2012-09-30 23:59:59" and
		concat(concat(host, ":8443"), path) = "cccreamceli09.in2p3.fr:8443/cream-sge-long"
	group by DATE(date)
) ResTO
where
	ResOK.date=ResError.date and ResOK.date=ResTO.date
order by ResOK.date










# Move the result file to the local dir and make me the owner
ssh root@localhost "chown fmichel:fmichel $RESULT_FILE; \mv $RESULT_FILE $PWD/results"

ssh root@localhost "\rm -f $CE_QUEUES"
