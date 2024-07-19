#!/bin/bash

# Check if the file containing domains is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <domains_file>"
  exit 1
fi

DOMAINS_FILE=$1

# Check if the file exists
if [ ! -f "$DOMAINS_FILE" ]; then
  echo "File not found: $DOMAINS_FILE"
  exit 1
fi

# Create a unique directory for this run
TIMESTAMP=$(date +"%Y-%m-%d")
TIMESTAMP2=$(date +"%H-%M-%S")
WAYBACK_OUTPUT_DIR="Waybackurls_Results"
XSPEAR_OUTPUT_DIR="XSpear_Results"
FINAL_XSPEAR_IF_NEW="$XSPEAR_OUTPUT_DIR/$TIMESTAMP/$TIMESTAMP2"
mkdir -p "$WAYBACK_OUTPUT_DIR"
mkdir -p "$XSPEAR_OUTPUT_DIR"
mkdir -p "$FINAL_XSPEAR_IF_NEW"

# Create a single file to collect all endpoints
ALL_ENDPOINTS_FILE="$WAYBACK_OUTPUT_DIR/all_endpoints.txt"

# Clear the all_endpoints.txt file if it already exists
> "$ALL_ENDPOINTS_FILE"

# Read domains from the file
while IFS= read -r DOMAIN; do
  echo "Scanning domain: $DOMAIN"

  # Using Waybackurls
  WAYBACK_FILE="$WAYBACK_OUTPUT_DIR/${DOMAIN//[^a-zA-Z0-9]/_}_waybackurls.txt"
  echo "Wayback file: $WAYBACK_FILE"

  waybackurls "$DOMAIN" | grep "=" | bhedak "" > "$WAYBACK_FILE"

  if [ ! -f "$WAYBACK_FILE" ]; then
    echo "Failed to create wayback file: $WAYBACK_FILE"
    continue
  fi

  # Using Archive
  CURL_OUTPUT_FILE="$WAYBACK_OUTPUT_DIR/${DOMAIN//[^a-zA-Z0-9]/_}_curl.txt"
  echo "Curl output file: $CURL_OUTPUT_FILE"

  curl -s "https://web.archive.org/cdx/search/cdx?url=*.${DOMAIN}&fl=original&collapse=urlkey" | grep "=" | bhedak "" > "$CURL_OUTPUT_FILE"

  if [ ! -f "$CURL_OUTPUT_FILE" ]; then
    echo "Failed to create curl output file: $CURL_OUTPUT_FILE"
  fi

  # Append waybackurls and curl output to the single file
  cat "$WAYBACK_FILE" "$CURL_OUTPUT_FILE" >> "$ALL_ENDPOINTS_FILE"

  # Remove old files
  rm "$WAYBACK_FILE" "$CURL_OUTPUT_FILE"

done < "$DOMAINS_FILE"

# Determine the count for the final merged file
COUNTER=1
FINAL_MERGED_FILE="$WAYBACK_OUTPUT_DIR/final_endpoints_${COUNTER}.txt"

# Increment counter until we find a file name that doesn't exist
while [ -f "$FINAL_MERGED_FILE" ]; do
  COUNTER=$((COUNTER + 1))
  FINAL_MERGED_FILE="$WAYBACK_OUTPUT_DIR/final_endpoints_${COUNTER}.txt"
done

# Merge and remove duplicates
echo "Final merged file: $FINAL_MERGED_FILE"
sort -u "$ALL_ENDPOINTS_FILE" > "$FINAL_MERGED_FILE"

# Remove the aggregated file after processing
rm "$ALL_ENDPOINTS_FILE"

# Scan with XSpear
COUNTER=1
while IFS= read -r URL; do
  echo "Scanning URL with XSpear: $URL"
  XSpear -u "$URL" -v 2 -a -t 20 -o html

  if [ -f "report.html" ]; then
    OUTPUT_FILE="$FINAL_XSPEAR_IF_NEW/report_${COUNTER}.html"
    mv report.html "$OUTPUT_FILE"
    echo "XSpear output saved: $OUTPUT_FILE"
  else
    echo "Failed to create XSpear output for URL: $URL"
  fi

  COUNTER=$((COUNTER + 1))
done < "$FINAL_MERGED_FILE"

# Zip the output directory if it contains files
if [ "$(ls -A $FINAL_XSPEAR_IF_NEW)" ]; then
  ZIP_FILE="/home/kali/Desktop/XSpear_output_$TIMESTAMP.zip"

  if zip -r "$ZIP_FILE" "$FINAL_XSPEAR_IF_NEW" > /dev/null; then
    echo "Zip file created successfully: $ZIP_FILE"
  else
    echo "Failed to create zip file"
    exit 1
  fi
else
  echo "No files to zip in $FINAL_XSPEAR_IF_NEW"
fi

echo "Scanning completed."
