#!/bin/bash
# This file retrieves output of jobs whom ID is listed in _jobids.txt.
# When output is successful, file _jobids_ce_dir.txt is appended with job id, CE name and output directory.

OUTPUT=_jobids_ce_dir.txt
rm -f $OUTPUT

for job in `cat _jobids.txt | grep -v '^#'`;
do
    echo "Retrieving output for job $job ..."
    if glite-wms-job-output $job > /tmp/glite-wms-job-output; then
        dir=`cat /tmp/glite-wms-job-output | grep '/tmp/jobOutput'`
        # Retrieve the CE to which the job was submitted
        ce=`glite-wms-job-logging-info --noint $job | awk -F'=' '/- Dest id/{sub(/^[ ]+/, "", $2); print $2}'`
        echo "$job - $ce - $dir" >> $OUTPUT
    else echo "$job - failed to retrieve output" >> $OUTPUT
    fi
done
echo "Done. Check out file $OUTPUT: CE name, job ID and output directory."

