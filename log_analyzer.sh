#!/bin/bash

# Check if a log file path was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <log_file_path>"
    exit 1
fi

LOG_FILE=$1
REPORT_DATE=$(date)
ANALYSIS_DATE=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="log_analysis_${ANALYSIS_DATE}.txt"
FILE_SIZE=$(du -h "$LOG_FILE" | cut -f1)
FILE_SIZE_BYTES=$(wc -c < "$LOG_FILE" | awk '{printf "%'"'"'d", $1}')

# Check if file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: File $LOG_FILE does not exist"
    exit 1
fi

# Count message types
ERROR_COUNT=$(grep -c -i "ERROR" "$LOG_FILE" | awk '{printf "%'"'"'d", $1}')
WARNING_COUNT=$(grep -c -i "WARNING" "$LOG_FILE" | awk '{printf "%'"'"'d", $1}')
INFO_COUNT=$(grep -c -i "INFO" "$LOG_FILE" | awk '{printf "%'"'"'d", $1}')

# Get top 5 error messages
TOP_ERRORS=$(grep -i "ERROR" "$LOG_FILE" | sed -E 's/.*\[ERROR\] //i; s/.*ERROR:? //i' | sort | uniq -c | sort -nr | head -5)

# Get first and last error timestamps
FIRST_ERROR=$(grep -i -m 1 "ERROR" "$LOG_FILE")
LAST_ERROR=$(grep -i "ERROR" "$LOG_FILE" | tail -1)

# Extract just the timestamp and message for first/last errors
FIRST_ERROR_TS=$(echo "$FIRST_ERROR" | awk -F'[][]' '{print $2}' | head -1)
FIRST_ERROR_MSG=$(echo "$FIRST_ERROR" | sed -E 's/.*\[ERROR\] //i; s/.*ERROR:? //i')

LAST_ERROR_TS=$(echo "$LAST_ERROR" | awk -F'[][]' '{print $2}' | head -1)
LAST_ERROR_MSG=$(echo "$LAST_ERROR" | sed -E 's/.*\[ERROR\] //i; s/.*ERROR:? //i')

# Error frequency by hour
ERROR_HOURS=$(grep -i "ERROR" "$LOG_FILE" | awk -F'[][]' '{print $2}' | awk '{print $1}' | awk -F: '{print $1}')
HOUR_COUNTS=$(echo "$ERROR_HOURS" | sort | uniq -c)

# Initialize hour counts
declare -A HOUR_MAP=(
    ["00-04"]=0 ["04-08"]=0 ["08-12"]=0 
    ["12-16"]=0 ["16-20"]=0 ["20-24"]=0
)

# Count errors by time ranges
while read -r line; do
    hour=$(echo "$line" | awk '{print $2}')
    count=$(echo "$line" | awk '{print $1}')
    
    if [ -z "$hour" ]; then continue; fi
    
    if (( hour >= 0 && hour < 4 )); then
        HOUR_MAP["00-04"]=$((HOUR_MAP["00-04"] + count))
    elif (( hour >= 4 && hour < 8 )); then
        HOUR_MAP["04-08"]=$((HOUR_MAP["04-08"] + count))
    elif (( hour >= 8 && hour < 12 )); then
        HOUR_MAP["08-12"]=$((HOUR_MAP["08-12"] + count))
    elif (( hour >= 12 && hour < 16 )); then
        HOUR_MAP["12-16"]=$((HOUR_MAP["12-16"] + count))
    elif (( hour >= 16 && hour < 20 )); then
        HOUR_MAP["16-20"]=$((HOUR_MAP["16-20"] + count))
    elif (( hour >= 20 && hour < 24 )); then
        HOUR_MAP["20-24"]=$((HOUR_MAP["20-24"] + count))
    fi
done <<< "$HOUR_COUNTS"

# Generate bar chart
BAR_CHART=""
for range in "00-04" "04-08" "08-12" "12-16" "16-20" "20-24"; do
    count=${HOUR_MAP[$range]}
    bars=$(( (count + 5) / 10 )) # Round up to nearest 10 for bar length
    BAR_CHART+="${range}: $(printf '%*s' $bars '' | tr ' ' '█') (${count})\n"
done

# Generate the report
{
echo "===== LOG FILE ANALYSIS REPORT ====="
echo "File: $LOG_FILE"
echo "Analyzed on: $REPORT_DATE"
echo "Size: ${FILE_SIZE} (${FILE_SIZE_BYTES} bytes)"
echo ""
echo "MESSAGE COUNTS:"
echo "ERROR: $ERROR_COUNT messages"
echo "WARNING: $WARNING_COUNT messages"
echo "INFO: $INFO_COUNT messages"
echo ""
echo "TOP 5 ERROR MESSAGES:"
echo "$TOP_ERRORS" | awk '{printf "%4d - %s\n", $1, substr($0, index($0,$2))}'
echo ""
echo "ERROR TIMELINE:"
echo "First error: [$FIRST_ERROR_TS] $FIRST_ERROR_MSG"
echo "Last error:  [$LAST_ERROR_TS] $LAST_ERROR_MSG"
echo ""
echo "Error frequency by hour:"
echo -e "$BAR_CHART"
echo "Report saved to: $REPORT_FILE"
} | tee "$REPORT_FILE"

# Make the counts more readable with thousands separators
sed -i -E "s/([0-9]+)( messages)/$(printf "%'"'"'d\\2" \1)/g" "$REPORT_FILE"