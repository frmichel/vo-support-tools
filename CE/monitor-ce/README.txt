

# Populate the biomed_stats database with a dump file:
"mysql --user biomed --password biomed_stats < backup_PGT.sql"

# In extract-monce-results-per-ce.sh and extract-monce-results-per-date.sh, set FROM_DATE and TO_DATE to select the timeslot

# Cd to the directory with extract-monce-*.sh and run them. It will ask for the MySQL root password as well as your key passphrase to get root access.
# The result files are results/monce-results-per-ce.csv and monce-results-per-date.csv.

# monce-results-per-date.csv is to be used as is (inserted into an excel sheet).
# monce-results-per-ce.csv is used in processors/running_ratio_bad.py to consolidate data from both sources:
# process the data of MonCE with the data about running ratio R/(R+W):
./process-ce-job-status.py --input-dir ../../../public_html/monitor-ce --from 20120829 --to 20120930 --monce

