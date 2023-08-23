#!/bin/bash

################################################################################

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

################################################################################

# Print function for logging
yd_print () {
  echo -e "$(date -u "+%Y-%m-%d_%H%M%S_UTC")": "$@"
}

################################################################################

# Fail & return an error code
set -euo pipefail

# Benchmark names (for benchmark selection)  ###################################

export N_SYSBENCH="sysbench"
export N_MYSQL_TPCC="mysql-tpcc"
export N_COREMARK_STD="coremark-standard"
export N_COREMARK_PRO="coremark-pro"
export N_LINPACK="linpack"

# Benchmark CSV column headings  ###############################################

export H_PROVIDER="Provider"
export H_REGION="Region"
export H_INSTANCE_TYPE="Instance Type"
export H_INSTANCE_PRICE="Price/Hr"
export H_RAM="RAM (GB)"
export H_VCPUS="vCPUs"
export H_CPU_MODEL="CPU Model"
export H_START_TIME="Started At"
export H_END_TIME="Ended At"

export H_SYSBENCH_SC="sysbench Single-Core"
export H_SYSBENCH_MC="sysbench Multi-Core"
export H_SYSBENCH_MEM="sysbench Memory"
export H_SYSBENCH_ST_R="sysbench Storage Reads/sec"
export H_SYSBENCH_ST_W="sysbench Storage Writes/sec"
export H_SYSBENCH_ST_F="sysbench Storage Fsyncs/sec"

export H_MYSQL_TPCC="sysbench MySQL TPC-C TPS"

export H_COREMARK_STD_SC="CoreMark Single-Core"
export H_COREMARK_STD_MC="CoreMark Multi-Core"

export H_COREMARK_PRO_SC="CoreMark-Pro Single-Core"
export H_COREMARK_PRO_MC="CoreMark-Pro Multi-Core"

export H_LINPACK="LINPACK MFLOPS"

################################################################################
