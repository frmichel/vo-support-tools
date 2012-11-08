

# Populate the biomed_stats database with a dump file:
"mysql --user biomed --password biomed_stats < backup_PGT.sql"

# In extract-monce-data.sh, set FROM_DATE and TO_DATE to select the timeslot

# Cd to the directory with extract-monce-data.sh file and run it. It will ask for the MySQL root password.
# The result file is results/extract-monce-data.csv

# Process the data of MonCE with the data about running ratio R/(R+W):
./process-ce-job-status.py --input-dir ../../../public_html/monitor-ce --from 20120829 --to 20120930 --monce


