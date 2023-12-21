#!/bin/bash

###############################################################################
# The Bash script can launch arbitrary actions and processes.
# If a Task is aborted, the script should clean up. The following exit trap will
# terminate any child processes. Depending on your script, you may need to
# perform other cleanup actions (e.g., killing a slurm job or stopping a
# container).

cleanup_child_procs() {
  local PIDS
  PIDS=$(jobs -p)
  if [ -n "$PIDS" ]
  then
    echo "Cleaning up child processes [$PIDS]"
    kill $PIDS &>/dev/null
  fi
}
trap cleanup_child_procs EXIT

###############################################################################

# Example commands below:

# Inspect local directory structure
echo "Current directory:" $PWD
echo "Directory contents (recursive):"
echo
ls -lR
echo

# Report arguments
echo "Arguments supplied to the Task:" "$@"
echo

echo "Listing YellowDog environment variables:"
echo
set | grep "YD"
echo

# Sleep for 30-60 seconds in lieu of doing real work ...
SLEEP_TIME="$(($RANDOM%30))"
let SLEEP_TIME=$SLEEP_TIME+30
echo -n "Sleeping for $SLEEP_TIME seconds ... "
sleep $SLEEP_TIME
echo "Done"

###############################################################################