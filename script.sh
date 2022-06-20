#!/bin/bash

# Maintained by Maitraya Baliyan
# This script will start the celery workers based on the number of queues required.
# Celery multi start example:
  # $ celery multi start -A betteropinions 3 -Q:1,1 QUEUE_1 -Q:2,2 QUEUE_2 -Q:3,3 QUEUE_3 --pool=solo

# Advanced example starting 10 workers in the background:
#   * Three of the workers processes the images and video queue
#   * Two of the workers processes the data queue with loglevel DEBUG
#   * the rest processes the default' queue.
#   $ celery multi start 10 -l INFO -Q:1-3 images,video -Q:4,5 data -Q default -L:4,5 DEBUG

PROJECT_NAME="betteropinions"
LOG_FILE="/var/log/celery/multi-workers.log"

# creating log folder for celery workers
if [ ! -d /var/log/celery ]; then
  mkdir -p /var/log/celery;
fi

# Getting worker counts from environment variables

EVENT_WORKERS="${NO_OF_EVENT_WORKERS:-1}" # will be used for event expiry
OPINION_WORKERS="${NO_OF_OPINION_WORKERS:-1}" # will be used for opinion matching
LEDGER_WORKERS="${NO_OF_LEDGER_WORKERS:-1}" # will b$e used for ledger entry
MISC_WORKERS="${NO_OF_MISC_WORKERS:-1}" # will be used for all other async tasks i.e. notifications,  send otp
TOTAL_WORKER_COUNT=$(( $EVENT_WORKERS + $OPINION_WORKERS + $LEDGER_WORKERS +  $MISC_WORKERS))

# Prefix of the workers processes
CMD="celery multi start -A $PROJECT_NAME $TOTAL_WORKER_COUNT -f $LOG_FILE --loglevel=INFO "

WORKER_COUNT=1 # counter for workers
dynamic_workers() {
  local NUMBER_OF_WORKERS=$1
  local QUEUE_NAME=$2

  if [ ${NUMBER_OF_WORKERS} == 1 ] || [ ${NUMBER_OF_WORKERS} == 2 ]
  then
    # As the format for 1 and 2 workers is different
    CMD="$CMD -Q:${WORKER_COUNT},$(( $WORKER_COUNT + $NUMBER_OF_WORKERS - 1 )) $QUEUE_NAME"
  else
    CMD="$CMD -Q:${WORKER_COUNT}-$(( $WORKER_COUNT + $NUMBER_OF_WORKERS - 1 )) $QUEUE_NAME"
  fi

  WORKER_COUNT=$(( $WORKER_COUNT + $NUMBER_OF_WORKERS ))
}

# This will genrate dynamic celery multi start command
# If need to create new worker for the queue add here.
dynamic_workers $EVENT_WORKERS 'EVENT_QUEUE'
dynamic_workers $OPINION_WORKERS 'OPINION_QUEUE'
dynamic_workers $LEDGER_WORKERS 'LEDGER_QUEUE'
dynamic_workers $MISC_WORKERS 'MISC_QUEUE'

CMD="$CMD --pool:1-$(( $TOTAL_WORKER_COUNT))=solo"

echo $CMD
eval $CMD
