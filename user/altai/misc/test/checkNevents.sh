#!/bin/bash

# Check if at least one file is given
if [[ "$#" -eq 0 ]]; then
    echo "Usage: $0 <file1> [file2 ... fileN]"
    exit 1
fi

output_file="summaryNevents.txt"
> "$output_file"  # Clear the output file

# Define color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

# Loop through each file given as argument
for file_path in "$@"; do
    [[ -z "$file_path" ]] && continue  # Skip empty arguments

    if [[ ! -f "$file_path" ]]; then
        echo "Warning: File '$file_path' does not exist. Skipping." | tee -a "$output_file"
        continue
    fi

    filename=$(basename "$file_path")

    # Print header ONLY to stdout, not to the summary file
    echo "----------------------- Processing $filename ------------------"

    # Capture and display output, while extracting values
    mapfile -t raw_lines < <(/home/eic/RICCARDO/altai/eudaq/bin/euCliReader -std -i "$file_path" -e 1 -E -1 | grep NTRGACC)

    # Print raw lines to stdout
    for line in "${raw_lines[@]}"; do
        echo "$line"
    done

    # Extract values
    values=()
    for line in "${raw_lines[@]}"; do
        val=$(echo "$line" | sed -n 's/.*TRGMON_NTRGACC=\([0-9]*\).*/\1/p')
        [[ -n "$val" ]] && values+=("$val")
    done

    if [[ "${#values[@]}" -eq 0 ]]; then
        echo "$filename: No NTRGACC values found" | tee -a "$output_file"
        continue
    fi

    # Find max value
    max="${values[0]}"
    for v in "${values[@]}"; do
        (( v > max )) && max="$v"
    done

    # Filter values equal to max
    max_vals=()
    for v in "${values[@]}"; do
        [[ "$v" == "$max" ]] && max_vals+=("$v")
    done

    # Check if values differ among the max entries
    unique_max_vals=($(printf "%s\n" "${max_vals[@]}" | sort -u))

    if [[ "${#unique_max_vals[@]}" -ne 1 ]]; then
        printf "${GREEN}%s${RESET} ${RED}%s${RESET} (values differ among the lines)\n" "$filename" "$max" | tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$output_file")
    else
        printf "${GREEN}%s${RESET} ${RED}%s${RESET}\n" "$filename" "$max" | tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$output_file")
    fi

done

echo ""
echo "----------------------- Summary as in $output_file -----------------------"
echo ""
echo "Run number                    Nevents"
echo ""
cat "$output_file"
echo ""
echo "----------------------- List of Nevents only: -----------------------"
awk '{print $2}' summaryNevents.txt
