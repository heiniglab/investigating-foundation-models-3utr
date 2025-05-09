#!/bin/bash

#################################################################
# wrapper for multi-gpu training                                #
# kills all processes when an error in the log file is reported #
#                                                               #
#################################################################

train_script='./train_whole.sh'

errorfile=$(sed  -nr 's/output_dir=(.*)/\1/p' $train_script|sed 's/'\''//g')/log

submit_res=$(sbatch $train_script)

echo $submit_res

job_id=$(echo $submit_res|cut -d" " -f4)

function finish {
  scancel $job_id
}

trap finish EXIT #cancel job on forced exit

while true; do
  sleep 120 #interval between checks, s
  running_jobs=( $(squeue --me -o "%i"|tail -n+2) ) #get all currently running jobs
  if [[ ${running_jobs[@]} =~ $job_id ]]; then
    grep "Exited\|error" $errorfile && scancel $job_id && echo "exiting due to job error messages, see $errorfile" && exit 1 #if error in job output, kill all job processes
  else
    echo 'job finished with no error messages in log file, exiting...'
    exit 0
  fi
done
