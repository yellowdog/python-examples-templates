#!/bin/bash

source $WR_NAME/common.sh

################################################################################

START_TIME=$(date -u "+%Y-%m-%d_%H%M%S_UTC")
TASK_DIR=$(pwd)

# Start the timer
SECONDS=0

#  Gather general instance information  ########################################

# Gather values from the Agent's application.yaml file
YDA_CONFIG=$YD_AGENT_HOME/application.yaml
VCPUS=$(cat $YDA_CONFIG | grep vcpus | awk '{print $2}')
INSTANCE_TYPE=$(cat $YDA_CONFIG | grep instanceType | awk '{print $2}' \
                | sed 's/"//g')

# Create and switch into a directory named after the instance type. (This is
# just to signal the instance type.)
yd_print "Creating directory:" $INSTANCE_TYPE
mkdir -p "$INSTANCE_TYPE"
cd "$INSTANCE_TYPE" || exit

INSTANCE_INFO="instance-info.txt"
CPU_INFO="cpu-info.txt"

# Save CPU & instance info
yd_print "Saving cpu-info and instance-info"
cat /proc/cpuinfo > $CPU_INFO
awk '/yda.provider/,/yda.workerTag/' $YDA_CONFIG | sed 's/yda.//' > \
    $INSTANCE_INFO

RAM=$(cat $INSTANCE_INFO | grep ram | \
      awk '{print $2}' | sed 's/"//g')
PROVIDER=$(cat $INSTANCE_INFO | grep provider | \
           awk '{print $2}' | sed 's/"//g')
REGION=$(cat $INSTANCE_INFO | grep region | \
         awk '{print $2}' | sed 's/"//g')
CPU_MODEL=$(cat $CPU_INFO | grep "model name" -m 1 | \
            awk '{print $4 " " $5 " " $6}')

echo

# Set up summary CSV file line  ################################################

CSV_SUMMARY_FILE="$PWD/summary.txt"

# Add initial row entries
echo -n "$PROVIDER, $INSTANCE_TYPE, $REGION, $CPU_MODEL, $VCPUS, $RAM" > \
     $CSV_SUMMARY_FILE

# The rest of the columns will be populated by the selected benchmarks

# Run sysbench  ################################################################

if [[ $BENCHMARKS == *$N_SYSBENCH* ]]
then
  # Single core
  SYSBENCH_CMD="sysbench cpu --cpu-max-prime=100000 run"
  yd_print "Running sysbench single core"
  mkdir -p sysbench
  cd sysbench || exit
  OUTPUT="sysbench-singlecore_out.txt"
  echo "Instance Type =" $INSTANCE_TYPE > $OUTPUT
  echo >> $OUTPUT
  echo "sysbench Command:" $SYSBENCH_CMD >> $OUTPUT
  echo >> $OUTPUT
  $SYSBENCH_CMD >> $OUTPUT
  SYSBENCH_SINGLE=$(cat $OUTPUT | \
      grep "events per second" | awk '{print $4}')
  echo -n ", $SYSBENCH_SINGLE" >> $CSV_SUMMARY_FILE
  cd ..

  # Multicore
  SYSBENCH_CMD="sysbench --threads=$VCPUS cpu --cpu-max-prime=100000 run"
  yd_print "Running sysbench multicore with" $VCPUS "threads"
  mkdir -p sysbench
  cd sysbench || exit
  OUTPUT="sysbench-multicore_out.txt"
  echo "Instance Type =" $INSTANCE_TYPE > $OUTPUT
  echo "VCPUs =" $VCPUS >> $OUTPUT
  echo >> $OUTPUT
  echo "sysbench Command:" $SYSBENCH_CMD >> $OUTPUT
  echo >> $OUTPUT
  $SYSBENCH_CMD >> $OUTPUT
  SYSBENCH_MULTI=$(cat $OUTPUT | \
      grep "events per second" | awk '{print $4}')
  echo -n ", $SYSBENCH_MULTI" >> $CSV_SUMMARY_FILE
  cd ..

  # Memory
  SYSBENCH_CMD="sysbench --memory-block-size=1M --memory-total-size=10G \
  --threads=$VCPUS memory run"
  yd_print "Running sysbench memory test"
  mkdir -p sysbench
  cd sysbench || exit
  OUTPUT="sysbench-memory_out.txt"
  echo "Instance Type =" $INSTANCE_TYPE > $OUTPUT
  echo "VCPUs =" $VCPUS >> $OUTPUT
  echo >> $OUTPUT
  echo "sysbench Command:" $SYSBENCH_CMD >> $OUTPUT
  echo >> $OUTPUT
  $SYSBENCH_CMD >> $OUTPUT
  SYSBENCH_MEMORY=$(cat $OUTPUT | \
    grep "Total operations" | awk '{print $4}' | tr -d "(")
  echo -n ", $SYSBENCH_MEMORY" >> $CSV_SUMMARY_FILE
  cd ..

  # Storage
  # 60 second test run
  SYSBENCH_CMD="sysbench --file-total-size=1G --file-test-mode=rndrw --time=60 \
  --threads=$VCPUS --max-requests=0 fileio run"
  yd_print "Running sysbench storage test"
  mkdir -p sysbench
  cd sysbench || exit
  # Create test files
  sysbench --file-total-size=1G fileio prepare > /dev/null
  OUTPUT="sysbench-storage_out.txt"
  echo "Instance Type =" $INSTANCE_TYPE > $OUTPUT
  echo "VCPUs =" $VCPUS >> $OUTPUT
  echo >> $OUTPUT
  echo "sysbench Command:" $SYSBENCH_CMD >> $OUTPUT
  echo >> $OUTPUT
  # Run the benchmark
  $SYSBENCH_CMD >> $OUTPUT
  # Cleanup test files
  sysbench --file-total-size=1G fileio cleanup > /dev/null
  SYSBENCH_STORAGE_READS_SEC=$(cat $OUTPUT | \
      grep "reads/s" | awk '{print $2}')
  SYSBENCH_STORAGE_WRITES_SEC=$(cat $OUTPUT | \
      grep "writes/s" | awk '{print $2}')
  SYSBENCH_STORAGE_FSYNCS_SEC=$(cat $OUTPUT | \
      grep "fsyncs/s" | awk '{print $2}')
  echo -n ", $SYSBENCH_STORAGE_READS_SEC, $SYSBENCH_STORAGE_WRITES_SEC,\
  $SYSBENCH_STORAGE_FSYNCS_SEC" >> $CSV_SUMMARY_FILE
  cd ..
  echo
fi

# Run MySQL TPC-C (Sysbench)  ##################################################

if [[ $BENCHMARKS == *$N_MYSQL_TPCC* ]]
then
  # MySQL TPC-C : Requires >= 2GB RAM
  if (( $(echo "$RAM >= 2.0" | bc -l) ))
  then
    yd_print "Running sysbench MySQL TPC-C"
    yd_print "Installing package 'mysql-server'"
    sudo apt-get install -y mysql-server &> /dev/null
    mkdir -p sysbench
    cd sysbench || exit
    OUTPUT="sysbench-mysql-tpcc_out.txt"
    yd_print "Downloading the Percona TPC-C sysbench scripts from GitHub"
    git clone https://github.com/Percona-Lab/sysbench-tpcc &> /dev/null
    cd sysbench-tpcc || exit
    yd_print "Creating the database"
    DB_NAME=sysbench
    DB_USER=root
    sudo mysql -u $DB_USER -e "CREATE DATABASE $DB_NAME"
    # Benchmark scaling parameters
    DB_TABLES=1
    DB_SCALE=1
    DB_SETUP_TIME=30
    DB_RUN_TIME=30
    DB_THREADS=16
    yd_print "Using: tables=$DB_TABLES, scale=$DB_SCALE, threads=$DB_THREADS"
    # Setup the state
    yd_print "Setting up data"
    DB_SOCKET=$(sudo mysqladmin -u root variables | \
                grep " socket " | awk '{print $4}')
    sudo ./tpcc.lua --mysql-socket=$DB_SOCKET --mysql-user=$DB_USER \
          --mysql-db=$DB_NAME --time=$DB_SETUP_TIME --threads=$DB_THREADS \
          --report-interval=1 \
          --tables=$DB_TABLES --scale=$DB_SCALE --db-driver=mysql prepare \
          > /dev/null
    yd_print "Running the benchmark"
    sudo ./tpcc.lua --mysql-socket=$DB_SOCKET --mysql-user=$DB_USER \
          --mysql-db=$DB_NAME --time=$DB_RUN_TIME --threads=$DB_THREADS \
          --report-interval=1 \
          --tables=$DB_TABLES --scale=$DB_SCALE --db-driver=mysql run \
          > $OUTPUT
    yd_print "Deleting database contents"
    sudo mysql -u $DB_USER -e "DROP DATABASE IF EXISTS $DB_NAME"
    SYSBENCH_MYSQL_TPCC_TPS=$(cat $OUTPUT | \
        grep "transactions:" | awk '{print $3}' | sed -e 's/(//')
    cd ../..
  else
    yd_print "Not running MySQL TPC-C (requires >= 2.0GB of RAM)"
    SYSBENCH_MYSQL_TPCC_TPS="0"
  fi
  yd_print "Transactions per Second = $SYSBENCH_MYSQL_TPCC_TPS"
  echo -n ", $SYSBENCH_MYSQL_TPCC_TPS" >> $CSV_SUMMARY_FILE
  echo
fi

# Run CoreMark  ################################################################

if [[ $BENCHMARKS == *$N_COREMARK_STD* ]]
then
  yd_print "Downloading CoreMark from GitHub"
  git clone https://github.com/eembc/coremark.git &> /dev/null

  # Single core
  cd coremark || exit
  yd_print "Running CoreMark single threaded"
  make &> build_output.txt
  sed  -i "1i Instance Type = $INSTANCE_TYPE\n" run1.log
  sed  -i "1i Instance Type = $INSTANCE_TYPE\n" run2.log
  mv run1.log singlecore-run1_out.txt
  mv run2.log singlecore-run2_out.txt
  COREMARK_SINGLE=$(cat ./singlecore-run1_out.txt | \
    grep "CoreMark 1.0" | awk '{print $4}')
  echo -n ", $COREMARK_SINGLE" >> $CSV_SUMMARY_FILE
  cd ..

  # Multicore
  cd coremark || exit
  make clean > /dev/null
  yd_print "Running CoreMark with" $VCPUS "threads"
  make XCFLAGS="-DMULTITHREAD=$VCPUS -DUSE_PTHREAD -pthread" &>> build_output.txt
  sed  -i "1i Instance Type = $INSTANCE_TYPE\n" run1.log
  sed  -i "1i Instance Type = $INSTANCE_TYPE\n" run2.log
  mv run1.log multicore-run1_out.txt
  mv run2.log multicore-run2_out.txt
  COREMARK_MULTI=$(cat ./multicore-run1_out.txt | \
      grep "CoreMark 1.0" | awk '{print $4}')
  echo -n ", $COREMARK_MULTI" >> $CSV_SUMMARY_FILE
  cd ..
  echo
fi

# Run CoreMark Pro  ############################################################

if [[ $BENCHMARKS == *$N_COREMARK_PRO* ]]
then
  yd_print "Downloading CoreMark Pro from GitHub"
  git clone https://github.com/eembc/coremark-pro.git &> /dev/null
  cd coremark-pro || exit
  yd_print "Building CoreMark Pro"
  make build &> build_output.txt
  yd_print "Running CoreMark Pro"
  make TARGET=linux64 XCMD='-c4' certify-all &> benchmark_output.txt
  OUTPUT="coremark-pro_out.txt"
  awk '/WORKLOAD/,/CoreMark-PRO/' benchmark_output.txt > $OUTPUT
  sed  -i "1i Instance Type = $INSTANCE_TYPE\n" $OUTPUT
  COREMARK_PRO=$(cat $OUTPUT | grep CoreMark-PRO | \
    awk '{print $3 ", " $2}')
  echo -n ", $COREMARK_PRO" >> $CSV_SUMMARY_FILE
  cd ..
  echo
fi

# Run LINPACK  #################################################################

if [[ $BENCHMARKS == *$N_LINPACK* ]]
then
  LINPACK_DIR="linpack"
  mkdir -p $LINPACK_DIR
  cd $LINPACK_DIR || exit
  yd_print "Compiling LINPACK"
  gcc "$(find $TASK_DIR -name linpack_bench.c)" -o linpack
  yd_print "Running LINPACK"
  OUTPUT="linpack_out.txt"
  ./linpack > $OUTPUT
  sed  -i "1i Instance Type = $INSTANCE_TYPE\n" $OUTPUT
  LINPACK_MFLOPS=$(cat $OUTPUT | sed '/^$/d' | \
    awk '/Factor/{ f = 1; next } /LINPACK_BENCH/{ f = 0 } f' | awk '{print $4}')
  echo -n ", $LINPACK_MFLOPS" >> $CSV_SUMMARY_FILE
  cd ..
  echo
fi

# Finalise CSV summary line ####################################################

END_TIME=$(date -u "+%Y-%m-%d_%H%M%S_UTC")
echo ", $START_TIME, $END_TIME" >> $CSV_SUMMARY_FILE

# Ensure a Minimum Duration  ###################################################

# This mitigates multiple benchmarks being sent to the same node because other
# nodes are not yet ready.

MINIMUM_DURATION=90
REMAINING_DURATION=$((MINIMUM_DURATION-SECONDS))
if [[ $REMAINING_DURATION -gt 0 ]]
then
  yd_print "Sleeping for $REMAINING_DURATION seconds before finishing"
  sleep $REMAINING_DURATION
fi

################################################################################

yd_print "Done!"

################################################################################
