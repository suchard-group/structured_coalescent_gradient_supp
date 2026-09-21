#!/usr/bin/env bash

# -----------------------------------------
# Configuration
# -----------------------------------------

# Set path to BEAST jar
BEAST_JAR="~/beast-mcmc/build/dist/beast.jar"

# Where the BEAGLE library was installed
BEAGLE_LIB="/usr/local/lib"

# Path to your XML files: the gradient comparisons and the scaling grid
XML_FOLDER="$(dirname "$0")"

# Where to write all outputs and logs
OUTPUT_FOLDER="$XML_FOLDER/results"

# Thread counts to test: 999 = beagle gpu, others = that many OpenMP threads.
# These are the settings reported in the manuscript: the scaling grid was timed
# at 1, 4, 12, 26 and 32 threads and on the GPU, on a cluster node with one
# NVIDIA H100 and a 26-core (52-thread) Intel Xeon Platinum 8481C.
THREAD_COUNTS=(1 4 12 26 32 999)

# -----------------------------------------
# Prepare output directory and results file
# -----------------------------------------

mkdir -p "$OUTPUT_FOLDER"
RESULTS_FILE="$OUTPUT_FOLDER/benchmark_results.txt"

echo "Benchmark results — $(date)" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# -----------------------------------------
# Benchmark loop
# -----------------------------------------

for xml_file in "$XML_FOLDER"/gradient/*.xml "$XML_FOLDER"/scaling/*.xml; do
    [ -e "$xml_file" ] || continue
    base_name=$(basename "$xml_file" .xml)

    for thread_count in "${THREAD_COUNTS[@]}"; do
        echo "Processing ${base_name} with ${thread_count} thread(s)..."

        if [ "$thread_count" -eq 1 ]; then
            # No threading
            COMMON_OPTIONS="-seed 666 -beagle_threading none -overwrite"
        elif [ "$thread_count" -eq 999 ]; then
            COMMON_OPTIONS="-seed 666 -beagle_gpu -overwrite"
        else
            # OpenMP threading
            COMMON_OPTIONS="-seed 666 -beagle_threading openmp -beagle_basta_threads ${thread_count} -overwrite"
        fi

        output_file="$OUTPUT_FOLDER/${base_name}_t${thread_count}_out.txt"

        # Run BEAST
        java -Djava.library.path="$BEAGLE_LIB" -jar "$BEAST_JAR" $COMMON_OPTIONS -working "$xml_file" \
            > "$output_file" 2>&1

        # Extract the per-operation timing table
        timing_block=$(awk '
          /Operation Timing Table \(Average time per call\):/ { block=""; inblock=1 }
          inblock { block = block $0 "\n" }
          /^$/ && inblock { inblock=0 }
          END { printf "%s", block }
        ' "$output_file")

        # Append to summary
        {
            echo "${base_name} (threads=${thread_count}):"
            if [ -n "$timing_block" ]; then
                echo "$timing_block"
            else
                echo "  Operation Timing Table not found"
            fi
            echo ""
        } >> "$RESULTS_FILE"
    done
done

echo "Benchmarking completed. Results saved in $RESULTS_FILE."
