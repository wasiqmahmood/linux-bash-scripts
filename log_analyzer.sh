#!/bin/bash

# Check if file is provided and exists
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
  echo "Usage: $0 /path/to/logfile"
  exit 1
fi

LOG_FILE="$1"
NOW=$(date +"%a %b %d %T %Z %Y")
REPORT_FILE="log_analysis_$(date +"%Y%m%d_%H%M%S").txt"
FILE_SIZE_BYTES=$(stat -c%s "$LOG_FILE")
FILE_SIZE_MB=$(awk "BEGIN {printf \"%.1f\", $FILE_SIZE_BYTES/1024/1024}")

# Count messages
ERROR_COUNT=$(grep -c "ERROR" "$LOG_FILE")
WARN_COUNT=$(grep -c "WARNING" "$LOG_FILE")
INFO_COUNT=$(grep -c "INFO" "$LOG_FILE")

# Top 5 error messages
TOP_ERRORS=$(grep "ERROR" "$LOG_FILE" | sed -E 's/.*ERROR[: ]+//' | sort | uniq -c | sort -nr | head -5)

# Get first and last error timestamps
FIRST_ERROR=$(grep "ERROR" "$LOG_FILE" | head -1)
LAST_ERROR=$(grep "ERROR" "$LOG_FILE" | tail -1)
FIRST_TIME=$(echo "$FIRST_ERROR" | grep -oE '\[[^]]+\]' | head -1)
LAST_TIME=$(echo "$LAST_ERROR" | grep -oE '\[[^]]+\]' | head -1)
FIRST_MSG=$(echo "$FIRST_ERROR" | sed -E 's/.*\] //')
LAST_MSG=$(echo "$LAST_ERROR" | sed -E 's/.*\] //')

# Error frequency by hour ranges
declare -A HOUR_BUCKETS=( ["00-04"]=0 ["04-08"]=0 ["08-12"]=0 ["12-16"]=0 ["16-20"]=0 ["20-24"]=0 )
while read -r line; do
  hour=$(echo "$line" | grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}' | cut -d' ' -f2)
  if [[ $hour -ge 0 && $hour -lt 4 ]]; then ((HOUR_BUCKETS["00-04"]++)); fi
  if [[ $hour -ge 4 && $hour -lt 8 ]]; then ((HOUR_BUCKETS["04-08"]++)); fi
  if [[ $hour -ge 8 && $hour -lt 12 ]]; then ((HOUR_BUCKETS["08-12"]++)); fi
  if [[ $hour -ge 12 && $hour -lt 16 ]]; then ((HOUR_BUCKETS["12-16"]++)); fi
  if [[ $hour -ge 16 && $hour -lt 20 ]]; then ((HOUR_BUCKETS["16-20"]++)); fi
  if [[ $hour -ge 20 && $hour -lt 24 ]]; then ((HOUR_BUCKETS["20-24"]++)); fi
done < <(grep "ERROR" "$LOG_FILE")

# Bar function
bar() {
  local n=$1
  local count=$((n / 3 + 1))
  printf "%s" "$(head -c $count < <(yes "█" | tr -d '\n'))"
}

# Output
{
echo "===== LOG FILE ANALYSIS REPORT ====="
echo "File: $LOG_FILE"
echo "Analyzed on: $NOW"
echo "Size: $FILE_SIZE_MB""MB ($FILE_SIZE_BYTES bytes)"
echo
echo "MESSAGE COUNTS:"
printf "ERROR: %'d messages\n" "$ERROR_COUNT"
printf "WARNING: %'d messages\n" "$WARN_COUNT"
printf "INFO: %'d messages\n" "$INFO_COUNT"
echo
echo "TOP 5 ERROR MESSAGES:"
echo "$TOP_ERRORS" | while read -r count msg; do
  printf " %3d - %s\n" "$count" "$msg"
done
echo
echo "ERROR TIMELINE:"
echo "First error: $FIRST_TIME $FIRST_MSG"
echo "Last error:  $LAST_TIME $LAST_MSG"
echo
echo "Error frequency by hour:"
for range in 00-04 04-08 08-12 12-16 16-20 20-24; do
  printf "%s: %s (%d)\n" "$range" "$(bar "${HOUR_BUCKETS[$range]}")" "${HOUR_BUCKETS[$range]}"
done
echo
echo "Report saved to: $REPORT_FILE"
} | tee "$REPORT_FILE"
