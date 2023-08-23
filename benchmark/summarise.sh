#!/bin/bash

source $WR_NAME/common.sh

################################################################################

yd_print "Set up Python for report generation"
yd_print "Python version: $(python3 --version)"
python3 -m venv py
source py/bin/activate
pip install -Uq matplotlib==3.7.1 \
                pandas==2.0.1 \
                fpdf2==2.7.3 \
                tabulate==0.9.0 \
                requests
echo

# CSV Summary Generation  ######################################################

# Collect the per-instance summaries in the 'summary.txt' files and combine
# into a single CSV file with a header row

CURRENT_DIR="$(pwd)"

OUTPUT_CSV=$CURRENT_DIR/summary.csv
yd_print "Generating" $OUTPUT_CSV "..."

# Create the CSV header row

# Mandatory columns
echo -n "$H_PROVIDER, $H_INSTANCE_TYPE, $H_REGION, $H_CPU_MODEL, $H_VCPUS, \
$H_RAM" > $OUTPUT_CSV

# Optional columns
if [[ $BENCHMARKS == *$N_SYSBENCH* ]]
then
  echo -n ", $H_SYSBENCH_SC, $H_SYSBENCH_MC, $H_SYSBENCH_MEM, \
$H_SYSBENCH_ST_R, $H_SYSBENCH_ST_W, $H_SYSBENCH_ST_F" >> $OUTPUT_CSV
fi
if [[ $BENCHMARKS == *$N_MYSQL_TPCC* ]]
then
  echo -n ", $H_MYSQL_TPCC" >> $OUTPUT_CSV
fi
if [[ $BENCHMARKS == *$N_COREMARK_STD* ]]
then
  echo -n ", $H_COREMARK_STD_SC, $H_COREMARK_STD_MC" >> $OUTPUT_CSV
fi
if [[ $BENCHMARKS == *$N_COREMARK_PRO* ]]
then
  echo -n ", $H_COREMARK_PRO_SC, $H_COREMARK_PRO_MC" >> $OUTPUT_CSV
fi
if [[ $BENCHMARKS == *$N_LINPACK* ]]
then
  echo -n ", $H_LINPACK" >> $OUTPUT_CSV
fi

# Final header row columns
echo ", $H_START_TIME, $H_END_TIME, $H_INSTANCE_PRICE" >> $OUTPUT_CSV

# CSV rows, one per instance
for SUMMARY in $(find $WR_NAME -name summary.txt)
do
  yd_print "Adding $SUMMARY"
  PROVIDER=$(cat $SUMMARY | awk -F ", " '{print $1}')
  INSTANCE_TYPE=$(cat $SUMMARY | awk -F ", " '{print $2}')
  REGION=$(cat $SUMMARY | awk -F ", " '{print $3}')
  # Fetch the on-demand hourly price of the instance from the YellowDog
  # Cloud Info service
  PRICE=$(python $WR_NAME/get_instance_price.py $PROVIDER \
          $REGION $INSTANCE_TYPE )
  yd_print "Adding instance price: $PRICE"
  echo "$(cat $SUMMARY), $PRICE" >> $OUTPUT_CSV
done

echo

# Generate Charts and PDF report  ##############################################

yd_print "Run 'charts.py' ..."
python "$WR_NAME/charts.py" $OUTPUT_CSV
echo

yd_print "Run 'pdf_report.py' ..."
REPORT="$CURRENT_DIR/report.pdf"
cd "$WR_NAME" || exit
python pdf_report.py $CURRENT_DIR $OUTPUT_CSV $REPORT
cd "$CURRENT_DIR" || exit
echo

################################################################################

yd_print "Done!"

################################################################################
