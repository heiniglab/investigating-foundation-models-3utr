#!/bin/bash

#################################################################
# wrapper for multi-gpu training                                #
# kills all processes when an error in the log file is reported #
#                                                               #
#################################################################

model_name=$1

if [ -z "${model_name}" ];then
  echo "Please select a model name,e.g. v2-250m, v2-100m, etc. "
  exit
fi

train_script='./run.sh'

eval $(cat run.sh |grep 'test_name=')
eval $(cat run.sh |grep 'output_dir=')

errorfile=$output_dir/log

function start_job {
  dt=$(date '+_%y-%m-%dat%H-%M');
  mv $errorfile "${errorfile}${dt}.back"
  job_id=$(sbatch -J $model_name $train_script|cut -d" " -f4 )
  echo "job id: $job_id"
}

function end_job {
  scancel $job_id
}

trap end_job EXIT #cancel job on forced exit

start_job

oom_restarts=0

while true; do
  sleep 120 #interval between checks, s
  if [ ! -z "$(grep 'Exited\|error' $errorfile)" ]; then
    scancel $job_id
    echo "exiting due to job error messages, see $errorfile"
    if [ ! -z "$(grep 'CUDA out of memory' $errorfile)" ] && [ $oom_restarts -lt $OOM_RESTARTS_MAX ]; then
      oom_restarts=$((oom_restarts+1))
      echo "restarting due to an OOM error ($oom_restarts/$OOM_RESTARTS_MAX)"
      start_job
    else
      exit 1
    fi
  else
    running_jobs=( $(squeue --me -o "%i"|tail -n+2) ) #get all currently running jobs
    if [[ ! ${running_jobs[@]} =~ $job_id ]]; then
      echo 'job finished with no error messages in log file, exiting...'
      exit 0
    fi
  fi
done
