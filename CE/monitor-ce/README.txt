This folder provides tools for monitoring CEs in two ways:
- monitor the ratio of Running (R) and Waiting (W) jobs, scripts:
    collect-ce-job-status.py: collect the data from the BDII (Running, Waiting) for eahc CE queue
    run-collect-ce-job-status.sh: wrapper to run collect-ce-job-status.py
    process-ce-job-status.py: process the data acquired by collect-ce-job-status.py and produce reports
    processors/: compute different views and distribution of R and W
- produce statistic reports from data of the MonCE tool, developped and run by Patric k Guterl (IPHC). Scripts:
    extract-monce-results-per-ce.sh
    extract-monce-results-per-date.sh

--------------------------------------------
To run the stats on the MonCE data:

# Populate the biomed_stats database with a dump file:
mysql --user biomed --password biomed_stats < monCE.sql

# In extract-monce-results-per-ce.sh and extract-monce-results-per-date.sh, set FROM_DATE and TO_DATE to select the timeslot

# Cd to the directory with extract-monce-*.sh and run them. It will ask for the MySQL root password as well as your key passphrase to get root access.
# The result files are results/monce-results-per-ce.csv and monce-results-per-date.csv.

# monce-results-per-date.csv is to be used as is (inserted into an excel sheet).
# monce-results-per-ce.csv is used in processors/running_ratio_bad.py to consolidate data from both sources:
# process the data of MonCE with the data about running ratio R/(R+W):
./process-ce-job-status.py --input-dir ../../../public_html/monitor-ce --from 20121113 --to 20121216 --monce

