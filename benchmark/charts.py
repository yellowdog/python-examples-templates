#!/usr/bin/env python3

"""
Generate visuals from the CSV benchmark data. Expects the CSV file as the
first argument.
"""

import os
import sys
from dataclasses import dataclass

import matplotlib.pyplot as plt
import pandas as pd


@dataclass
class Benchmark:
    column_title: str
    chart_title: str
    y_axis_label: str
    output_file: str
    x_axis_label: str = "Instance Types"
    colour: str = os.getenv("CHART_COLOR", "b")


# Set up all the included benchmarks. If the column header has been defined
# in the environment of the calling script, the benchmark is assumed to be
# present.
benchmarks = []
BENCHMARKS = os.getenv("BENCHMARKS", "")
if os.getenv("N_SYSBENCH") in BENCHMARKS:
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_SYSBENCH_SC"),
            chart_title="sysbench Single-Core Benchmark",
            y_axis_label="Events per Second",
            output_file="sysbench-single.png",
        )
    )
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_SYSBENCH_MC"),
            chart_title="sysbench Multicore Benchmark",
            y_axis_label="Events per Second",
            output_file="sysbench-multi.png",
        )
    )
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_SYSBENCH_MEM"),
            chart_title="sysbench Memory Benchmark",
            y_axis_label="Operations per Second",
            output_file="sysbench-memory.png",
        )
    )
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_SYSBENCH_ST_R"),
            chart_title="sysbench Storage Read Performance",
            y_axis_label="Read Ops per Second",
            output_file="sysbench-storage-reads.png",
        )
    )
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_SYSBENCH_ST_W"),
            chart_title="sysbench Storage Write Performance",
            y_axis_label="Write Ops per Second",
            output_file="sysbench-storage-writes.png",
        )
    )
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_SYSBENCH_ST_F"),
            chart_title="sysbench Storage Fsync Performance",
            y_axis_label="Fsync Ops per Second",
            output_file="sysbench-storage-fsyncs.png",
        )
    )
if os.getenv("N_MYSQL_TPCC") in BENCHMARKS:
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_MYSQL_TPCC"),
            chart_title="sysbench MySQL TPC-C TPS",
            y_axis_label="Transactions per Second",
            output_file="sysbench-mysql-tpcc.png",
        )
    )
if os.getenv("N_COREMARK_STD") in BENCHMARKS:
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_COREMARK_STD_SC"),
            chart_title="CoreMark Single-Core Benchmark",
            y_axis_label="Benchmark Score",
            output_file="coremark-single.png",
        )
    )
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_COREMARK_STD_MC"),
            chart_title="CoreMark Multicore Benchmark",
            y_axis_label="Benchmark Score",
            output_file="coremark-multi.png",
        )
    )
if os.getenv("N_COREMARK_PRO") in BENCHMARKS:
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_COREMARK_PRO_SC"),
            chart_title="CoreMark-Pro Single-Core Benchmark",
            y_axis_label="Benchmark Score",
            output_file="coremark-pro-single.png",
        )
    )
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_COREMARK_PRO_MC"),
            chart_title="CoreMark-Pro Multicore Benchmark",
            y_axis_label="Benchmark Score",
            output_file="coremark-pro-multi.png",
        )
    )
if os.getenv("N_LINPACK") in BENCHMARKS:
    benchmarks.append(
        Benchmark(
            column_title=os.getenv("H_LINPACK"),
            chart_title="LINPACK MFLOPS",
            y_axis_label="MFLOPS",
            output_file="linpack.png",
        )
    )

data = pd.read_csv(sys.argv[1], skipinitialspace=True)
df = pd.DataFrame(data)

# Create aggregated 'Instance Type / Region' column
instance_type = os.getenv("H_INSTANCE_TYPE")
region = os.getenv("H_REGION")
inst_type_region = f"{instance_type} / {region}"
df[inst_type_region] = df.apply(lambda x: f"{x[instance_type]} / {x[region]}", axis=1)

# Disambiguate identical 'Instance Type / Region' rows using an appended numeral
df.sort_values(by=[inst_type_region], inplace=True, ignore_index=True)
current_duplicate = ""
duplicate_counter = 1
for index, row in enumerate(df.duplicated(keep=False, subset=[inst_type_region])):
    if row is True:
        if df.iloc[index][inst_type_region] != current_duplicate:
            current_duplicate = df.iloc[index][inst_type_region]
            duplicate_counter = 1
        df.at[index, inst_type_region] = f"{current_duplicate} ({duplicate_counter})"
        duplicate_counter += 1

for benchmark in benchmarks:
    try:
        df.sort_values(by=[benchmark.column_title], ascending=False, inplace=True)
    except Exception as e:
        print(f"Error: {e}")
        continue
    x = list(df[inst_type_region])
    y = list(df[benchmark.column_title])
    plt.figure(figsize=(10, 6))
    plt.bar(x, y, color=benchmark.colour)
    plt.title(benchmark.column_title)
    plt.xlabel(benchmark.x_axis_label)
    plt.ylabel(benchmark.y_axis_label)
    plt.xticks(rotation="vertical")
    plt.tight_layout()
    print(f"Generating '{benchmark.output_file}'")
    plt.savefig(benchmark.output_file)
