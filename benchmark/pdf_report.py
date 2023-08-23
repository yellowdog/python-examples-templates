"""
Generate a PDF report from benchmark data.
- First command line parameter is the directory containing the chart images.
- Second command line parameter is the pathname of the summary CSV file.
- Third command line parameter is the pathname of the PDF report to generate.
"""

from dataclasses import dataclass
from datetime import datetime
from os import getenv, path
from sys import argv
from typing import List, Optional

import pandas as pd
from tabulate import tabulate

from yellowdog_pdf import YellowPDF

# Input Data setup  ############################################################

# Command line inputs
try:
    chart_directory = argv[1]
    csv_summary_file = argv[2]
    pdf_report = argv[3]
except IndexError as e:
    print(f"Exception: {e}. Missing command line argument. Aborting")
    exit(1)

# Benchmark selection string
env_benchmarks = getenv("BENCHMARKS", "")

now = datetime.utcnow()


# Utility functions and classes  ###############################################


def performance_table(df: pd.DataFrame, benchmark_headers: List[str]) -> Optional[str]:
    """
    Find the best and worst performing instances for each benchmark.
    Return the tabulated results.
    """
    if len(benchmark_headers) == 0:
        return None

    headings = ["Benchmark", "Best-Performing", "Worst-Performing"]

    results = []
    for benchmark_header in benchmark_headers:
        df.sort_values(by=benchmark_header, ascending=True, inplace=True)
        worst = (
            f"{df[getenv('H_PROVIDER')].iloc[0]} / {df[getenv('H_REGION')].iloc[0]} /"
            f" {df[getenv('H_INSTANCE_TYPE')].iloc[0]}"
        )
        best = (
            f"{df[getenv('H_PROVIDER')].iloc[-1]} / {df[getenv('H_REGION')].iloc[-1]} /"
            f" {df[getenv('H_INSTANCE_TYPE')].iloc[-1]}"
        )
        results.append([benchmark_header, best, worst])

    return tabulate(
        results, headers=headings, showindex="never", tablefmt="pretty", numalign="left"
    )


class DocNumbers:
    """
    Keep track of section & reference numbers.
    """

    def __init__(self):
        self.section_number = 0
        self.reference_number = 1  # Automatic counting starts at 2

    @property
    def next_section(self) -> str:
        self.section_number += 1
        return str(self.section_number)

    @property
    def next_reference(self) -> str:
        self.reference_number += 1
        return str(self.reference_number)


doc_numbers = DocNumbers()


@dataclass
class Reference:
    """
    Defines a reference
    """

    ref_number: str
    ref_text: str
    ref_link: Optional[str] = None


@dataclass
class Section:
    """
    Defines a section in the document.
    """

    page_break_before: bool = True
    heading: Optional[str] = None
    paragraphs_1: Optional[List[str]] = None
    bulleted_list_1: Optional[List[str]] = None
    table_text: Optional[str] = None
    charts: Optional[List[str]] = None
    paragraphs_2: Optional[List[str]] = None
    bulleted_list_2: Optional[List[str]] = None
    page_break_after: bool = False
    reference: Optional[Reference] = None


# Define main document sections  ###############################################


sections = [
    Section(
        page_break_before=False,
        heading="Methodology",
        paragraphs_1=[
            "The benchmarks illustrated in this report were generated "
            "using the YellowDog Platform. YellowDog offers its customers this "
            "complimentary benchmarking tool to aid in the selection of "
            "optimal compute while demonstrating the power of the YellowDog "
            "Platform. Customers are free to enhance, optimise and customise "
            "the benchmarks for their own application workloads and compute "
            "choices."
        ],
        page_break_after=False,
    ),
    Section(
        page_break_before=False,
        heading="Compute Selection",
        paragraphs_1=[
            "Compute instance types to benchmark are selected via a YellowDog Dynamic"
            " Compute Template. This approach enables compute selection based on a"
            " range of dynamic constraints and preferences such as 'instances must"
            " have 8 VCPUs', or 'instances must be in Europe, with a preference for"
            " the most RAM'. For more information on customising Dynamic Compute"
            " Templates please see the YellowDog Documentation"
            f" [{doc_numbers.next_reference}]."
        ],
        page_break_after=False,
        reference=Reference(
            ref_number=str(doc_numbers.reference_number),
            ref_text="YellowDog Dynamic Compute Requirement Templates:",
            ref_link="https://docs.yellowdog.co/#/the-platform/dynamic-templates",
        ),
    ),
    Section(
        page_break_before=False,
        heading="Benchmark Selection",
        paragraphs_1=[
            (
                "Specific benchmarks can be selected from the full set of "
                "benchmarks available using the configuration file for the "
                "benchmark Work Requirement, or by using environment or command "
                "line variables. Please see the the benchmark documentation for "
                "more details."
            ),
            "The available benchmark names that can be selected are:",
        ],
        bulleted_list_1=[
            "sysbench",
            "mysql-tpcc",
            "coremark-standard",
            "coremark-pro",
            "linpack",
        ],
        page_break_after=False,
    ),
    Section(
        page_break_before=False,
        heading="Benchmark Optimisation",
        paragraphs_1=[
            "No attempts have been made to optimise compute instances or their "
            "software stacks for the purposes of running the benchmarks. "
            "Requirements vary significantly between users, workloads, and "
            "environments, and tuning is often required to achieve the best "
            "benchmark results. Instances are tested as per the default "
            "configuration applied by the given cloud provider and with "
            "'vanilla' software installations. If you have specific "
            "configurations or optimisations that you wish to apply to "
            "instances prior to benchmarking, this can be achieved by applying "
            "cloud configuration via YellowDog user data when "
            f"provisioning [{doc_numbers.next_reference}]."
        ],
        page_break_after=False,
        reference=Reference(
            ref_number=str(doc_numbers.reference_number),
            ref_text="YellowDog User Data Support:",
            ref_link="https://docs.yellowdog.co/#/the-platform/user-data",
        ),
    ),
]

# Load benchmark data into a DataFrame
data = pd.read_csv(csv_summary_file, skipinitialspace=True)
df = pd.DataFrame(data)

# Accumulate the selected benchmark sections
benchmark_list: List[str] = []
benchmark_headers: List[str] = []

if getenv("N_SYSBENCH") in env_benchmarks:
    sections.append(
        Section(
            heading="Sysbench CPU Benchmark",
            paragraphs_1=[
                (
                    f"Sysbench [{doc_numbers.next_reference}] is a scriptable,"
                    " multi-threaded benchmark tool based on LuaJIT. It is most"
                    " frequently used for database benchmarks, but can also be used to"
                    " create arbitrarily complex workloads that do not involve a"
                    " database server, as well as general tests on memory and storage"
                    " performance."
                ),
                (
                    "When benchmarking the CPU performance of your selected "
                    "instance types we run sysbench in two modes, measuring "
                    "single-core and multi-core (one thread per vCPU) performance."
                ),
            ],
            charts=["sysbench-single.png", "sysbench-multi.png"],
            reference=Reference(
                ref_number=str(doc_numbers.reference_number),
                ref_text="Sysbench Wikipedia:",
                ref_link="https://en.wikipedia.org/wiki/Sysbench",
            ),
        )
    )
    sections.append(
        Section(
            heading="Sysbench Memory Benchmark",
            paragraphs_1=[
                "The Sysbench memory benchmark is run with a 1MB memory block size and"
                " a total memory throughput of 10GB, using one thread per vCPU."
            ],
            charts=["sysbench-memory.png"],
        )
    )
    sections.append(
        Section(
            heading="Sysbench Storage Benchmark",
            paragraphs_1=[
                "The Sysbench storage ('fileio') benchmark is run with a total file"
                " size of 1GB, a duration of 60s, and one thread per vCPU."
            ],
            charts=[
                "sysbench-storage-reads.png",
                "sysbench-storage-writes.png",
                "sysbench-storage-fsyncs.png",
            ],
        )
    )
    benchmark_list += ["Sysbench CPU", "Sysbench Memory", "Sysbench Storage"]
    benchmark_headers += [
        getenv("H_SYSBENCH_SC"),
        getenv("H_SYSBENCH_MC"),
        getenv("H_SYSBENCH_MEM"),
        getenv("H_SYSBENCH_ST_R"),
        getenv("H_SYSBENCH_ST_W"),
        getenv("H_SYSBENCH_ST_F"),
    ]

if getenv("N_MYSQL_TPCC") in env_benchmarks:
    sections.append(
        Section(
            heading="MySQL TPC-C (Sysbench) Benchmark",
            paragraphs_1=[
                (
                    "The MySQL TPC-C benchmark uses Sysbench and the Percona TPC-C"
                    f" benchmark scripts [{doc_numbers.next_reference}]. MySQL and the"
                    " benchmark itself run on the same instance. The benchmark is"
                    " reduced in scale to allow it run on instances with"
                    " standard-sized root volumes, and to conclude in a reasonable"
                    " duration."
                ),
                "The following values are used:",
            ],
            bulleted_list_1=[
                "tables = 1",
                "time = 30 (setup), 60 (benchmark run)",
                "scale = 1",
                "threads = 16",
            ],
            charts=["sysbench-mysql-tpcc.png"],
            paragraphs_2=[
                "Note: If TPS is zero then the instance doesn't have "
                "enough memory (2GB) to run MySQL, and the benchmark "
                "was omitted."
            ],
            reference=Reference(
                ref_number=str(doc_numbers.reference_number),
                ref_text="Sysbench MySQL TPC-C:",
                ref_link="https://github.com/Percona-Lab/sysbench-tpcc",
            ),
        )
    )
    benchmark_list.append("MySQL TPC-C (Sysbench)")
    benchmark_headers.append(getenv("H_MYSQL_TPCC"))

if getenv("N_COREMARK_STD") in env_benchmarks:
    sections.append(
        Section(
            heading="CoreMark Benchmark",
            paragraphs_1=[
                f"The CoreMark benchmark [{doc_numbers.next_reference}] stresses the"
                " CPU pipeline. The benchmark is compiled and run twice, once in"
                " single-threaded form, and once in a form compiled to run with"
                " multiple threads, one per vCPU."
            ],
            charts=["coremark-single.png", "coremark-multi.png"],
            reference=Reference(
                ref_number=str(doc_numbers.reference_number),
                ref_text="CoreMark:",
                ref_link="https://github.com/eembc/coremark.git",
            ),
        ),
    )
    benchmark_list.append("CoreMark")
    benchmark_headers += [getenv("H_COREMARK_STD_SC"), getenv("H_COREMARK_STD_MC")]

if getenv("N_COREMARK_PRO") in env_benchmarks:
    sections.append(
        Section(
            heading="CoreMark Pro Benchmark",
            paragraphs_1=[
                (
                    f"The CoreMark Pro benchmark [{doc_numbers.next_reference}] tests"
                    " the entire processor, adding comprehensive support for"
                    " multi-core technology, a combination of integer and"
                    " floating-point workloads, and data sets for utilising larger"
                    " memory subsystems."
                ),
                "The benchmark is compiled on the target instance before it's run.",
            ],
            charts=["coremark-pro-single.png", "coremark-pro-multi.png"],
            reference=Reference(
                ref_number=str(doc_numbers.reference_number),
                ref_text="CoreMark Pro:",
                ref_link="https://github.com/eembc/coremark-pro.git",
            ),
        )
    )
    benchmark_list.append("CoreMark Pro")
    benchmark_headers += [getenv("H_COREMARK_PRO_SC"), getenv("H_COREMARK_PRO_MC")]

if getenv("N_LINPACK") in env_benchmarks:
    sections.append(
        Section(
            heading="LINPACK Benchmark",
            paragraphs_1=[
                (
                    f"The LINPACK benchmark [{doc_numbers.next_reference}] is a test"
                    " problem used to rate the performance of a computer on a simple"
                    " linear algebra problem. The benchmark reports the number of"
                    " millions of floating point operations per second (MFLOPS)."
                ),
                "The benchmark is compiled on the target instance before being run.",
            ],
            charts=["linpack.png"],
            reference=Reference(
                ref_number=str(doc_numbers.reference_number),
                ref_text="LINPACK:",
                ref_link="https://people.sc.fsu.edu/~jburkardt/c_src/linpack_bench/linpack_bench.html",
            ),
        )
    )
    benchmark_list.append("LINPACK")
    benchmark_headers.append(getenv("H_LINPACK"))

# Concluding sections
sections += [
    Section(
        heading="Overall Summary of Results",
        paragraphs_1=[
            "The table below shows the best and worst performing instance types for the"
            " benchmark(s) performed."
        ],
        table_text=performance_table(df, benchmark_headers),
    ),
    Section(
        page_break_before=False,
        heading="Disclaimer",
        paragraphs_1=[
            "While YellowDog does its best to provide helpful and accurate results, the"
            " benchmark(s) presented in this report are intended to be illustrative"
            " only, and do not necessarily represent the performance that would be"
            " achieved under real world conditions. Results should be independently"
            " confirmed with representative compute instances, software and workloads,"
            " before decisions are made."
        ],
    ),
]

# Create the PDF document object  ##############################################

pdf = YellowPDF()

# Title  #######################################################################

pdf.print_title("YellowDog Benchmark Report")

# Introductory Sections  #######################################################

pdf.print_heading(f"{doc_numbers.next_section}. Introduction")
pdf.print_paragraph(
    "This is an automatically generated benchmark report created using the "
    f"YellowDog Platform, produced on {now.strftime('%A, %d %B')} at "
    f"{now.strftime('%H:%M')} UTC."
)
pdf.print_horizontal_line()
pdf.print_paragraph(
    "As organisations accelerate the migration of workloads to the cloud it becomes"
    " increasingly important to ensure optimisation of cloud compute choices for these"
    " workloads.  YellowDog has visibility of thousands of different compute instance"
    " types across the major cloud providers. Compute needs vary across cloud"
    " consumers, with a range of motivations to optimise for cost, performance,"
    " environmental impact, and geographic locality."
)
pdf.print_paragraph(
    "This complimentary report has been generated by YellowDog's benchmarking tool. To"
    " discuss more complex benchmarking needs, please speak to our support team [1]."
)

# Report the benchmarks that were run
pdf.print_heading(f"{doc_numbers.next_section}. Benchmarks and Instances")
benchmarks = ""
for index, benchmark in enumerate(benchmark_list):
    if index == len(benchmark_list) - 1 and len(benchmark_list) != 1:
        benchmarks += "and "
    benchmarks = f"{benchmarks}**{benchmark}**"
    if index < len(benchmark_list) - 1:
        if len(benchmark_list) > 2:
            benchmarks += ", "
        else:
            benchmarks += " "
if len(benchmark_list) == 0:
    pdf.print_paragraph(f"No benchmarks were selected.")
elif len(benchmark_list) == 1:
    pdf.print_paragraph(f"The following benchmark was selected: {benchmarks}.")
else:
    pdf.print_paragraph(f"The following benchmarks were selected: {benchmarks}.")

# Report data on the instance types that were used
df.sort_values(by=[getenv("H_RAM"), getenv("H_VCPUS")], ascending=True, inplace=True)
if len(df) == 1:
    pdf.print_paragraph(f"The following instance was provisioned:")
else:
    pdf.print_paragraph(f"The following **{len(df)} instances** were provisioned:")

# Create and print the instance table
headers = [
    getenv("H_PROVIDER"),
    getenv("H_REGION"),
    getenv("H_INSTANCE_TYPE"),
    getenv("H_RAM"),
    getenv("H_VCPUS"),
    getenv("H_CPU_MODEL"),
    getenv("H_INSTANCE_PRICE"),
]
table = tabulate(
    df[headers], headers=headers, showindex="never", tablefmt="pretty", numalign="left"
)

table_width = table.index("\n")
if table_width > 110:
    table_font = 7.0
elif table_width > 99:
    table_font = 7.75
elif table_width > 88:
    table_font = 8.0
else:
    table_font = 9.0
pdf.print_paragraph(
    table, align="C", font_size=table_font, bold=True, fixed_width=True, markdown=False
)
pdf.print_paragraph(
    "The 'Price/Hr' is the on-demand price for the Instance Type, for the "
    "given Provider and Region, and for an OS image without additional "
    "licensing fees.",
    font_size=9.0,
    italic=True,
)
# Main Sections  ###############################################################

for benchmark in sections:
    if benchmark.page_break_before:
        pdf.insert_page_break()
    if benchmark.heading is not None:
        pdf.print_heading(f"{doc_numbers.next_section}. {benchmark.heading}")
    if benchmark.paragraphs_1 is not None:
        for paragraph in benchmark.paragraphs_1:
            pdf.print_paragraph(paragraph)
    if benchmark.table_text is not None:
        pdf.print_paragraph(
            benchmark.table_text,
            align="C",
            font_size=8.0,
            bold=True,
            fixed_width=True,
            markdown=False,
        )
    if benchmark.bulleted_list_1 is not None:
        for bulleted_list_item in benchmark.bulleted_list_1:
            pdf.print_bulleted_text(bulleted_list_item)
    if benchmark.charts is not None:
        for chart in benchmark.charts:
            pdf.print_image(f"{chart_directory}/{chart}")
    if benchmark.paragraphs_2 is not None:
        for paragraph in benchmark.paragraphs_2:
            pdf.print_paragraph(paragraph)
    if benchmark.bulleted_list_2 is not None:
        for bulleted_list_item in benchmark.bulleted_list_2:
            pdf.print_bulleted_text(bulleted_list_item)
    if benchmark.page_break_after:
        pdf.insert_page_break()


# References  ##################################################################


def print_reference(ref_number: str, ref_text: str, ref_link: str):
    """
    Print a reference with its hyperlink
    """
    pdf.print_paragraph(
        f"[{ref_number}] {ref_text}",
        align="L",
        after=0.1,
    )
    pdf.print_hyperlink(
        indent=6,
        before=0.1,
        url_text=ref_link,
        url=ref_link,
    )


pdf.insert_page_break()
pdf.print_heading(f"{doc_numbers.next_section}. References")
print_reference(
    "1",
    "Contact YellowDog:",
    "https://yellowdog.co/contact",
)
for section in sections:
    if section.reference is not None:
        print_reference(
            str(section.reference.ref_number),
            section.reference.ref_text,
            section.reference.ref_link,
        )

# Generate the document  #######################################################

print(f"Generating '{path.basename(pdf_report)}'")
pdf.generate_pdf_file(pdf_report)

################################################################################
