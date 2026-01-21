#!/bin/bash

# Squid Whitelist Domain Processor
# Implements intelligent domain hierarchy logic using pure bash
# No external dependencies required - perfect for GitHub workflows

set -euo pipefail

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to build domain hierarchy
build_domain_hierarchy() {
    local domain="$1"

    # Remove leading dot for processing
    local clean_domain="${domain#.}"

    # Split domain by dots into array
    IFS='.' read -ra PARTS <<< "$clean_domain"

    # Build hierarchy from TLD to full domain
    local hierarchy=""
    local parts_count=${#PARTS[@]}

    for ((i=0; i<parts_count; i++)); do
        # Start from the end (TLD) and work towards full domain
        local start_idx=$((parts_count - 1 - i))
        local domain_parts=""

        for ((j=start_idx; j<parts_count; j++)); do
            if [ -z "$domain_parts" ]; then
                domain_parts="${PARTS[j]}"
            else
                domain_parts="$domain_parts.${PARTS[j]}"
            fi
        done

        hierarchy="$hierarchy.${domain_parts}
"
    done

    echo "$hierarchy"
}

# Check required environment variables
if [ -z "$S3_BUCKET" ] || [ -z "$S3_KEY" ] || [ -z "$NEW_DOMAINS" ]; then
    log_error "Missing required environment variables:"
    log_error "  S3_BUCKET: $S3_BUCKET"
    log_error "  S3_KEY: $S3_KEY"
    log_error "  NEW_DOMAINS: $NEW_DOMAINS"
    exit 1
fi

# Convert comma-separated domains to newline-separated
DOMAINS=$(echo "$NEW_DOMAINS" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | grep -v '^$')

log_info "Configuration loaded:"
log_info "  S3 Bucket: $S3_BUCKET"
log_info "  S3 Key: $S3_KEY"
log_info "  Domains to process: $(echo "$DOMAINS" | wc -l | tr -d ' ')"

# Create squid directory if it doesn't exist
mkdir -p squid

# Download current allowedlist.txt from S3
log_info "Downloading $S3_KEY from s3://$S3_BUCKET"
aws s3 cp "s3://$S3_BUCKET/$S3_KEY" squid/allowedlist.txt

# Check if download was successful
if [ ! -f "squid/allowedlist.txt" ]; then
    log_error "Failed to download allowedlist.txt from S3"
    exit 1
fi

# Count original domains
ORIGINAL_COUNT=$(wc -l < squid/allowedlist.txt | tr -d ' ')
log_info "Current whitelist has $ORIGINAL_COUNT domains"

# Process each domain
PROCESSED_DOMAINS=""
DOMAINS_ADDED=0
TOTAL_PROCESSED=0

while IFS= read -r domain; do
    [ -z "$domain" ] && continue

    TOTAL_PROCESSED=$((TOTAL_PROCESSED + 1))

    # Normalize domain (ensure it starts with dot)
    if [[ ! "$domain" =~ ^\.+ ]]; then
        domain=".$domain"
    fi

    log_info "Processing: $domain"

    # Build domain hierarchy
    HIERARCHY=$(build_domain_hierarchy "$domain")

    # Check if any level in hierarchy exists in current whitelist
    FOUND_PARENT=""
    while IFS= read -r level; do
        if grep -Fxq "$level" squid/allowedlist.txt; then
            FOUND_PARENT="$level"
            break
        fi
    done <<< "$HIERARCHY"

    if [ -n "$FOUND_PARENT" ]; then
        log_warning "Skipped: $domain (covered by $FOUND_PARENT)"
        PROCESSED_DOMAINS="$PROCESSED_DOMAINS{\"original_domain\":\"$domain\",\"action\":\"skipped\",\"reason\":\"Already covered by: $FOUND_PARENT\"},"
    else
        log_success "Added: $domain"
        echo "$domain" >> squid/allowedlist.txt
        DOMAINS_ADDED=$((DOMAINS_ADDED + 1))
        PROCESSED_DOMAINS="$PROCESSED_DOMAINS{\"original_domain\":\"$domain\",\"action\":\"added\",\"reason\":\"No parent domains found in whitelist\"},"
    fi

done <<< "$DOMAINS"

# Sort the whitelist alphabetically (case-insensitive)
log_info "Sorting whitelist alphabetically"
sort -f squid/allowedlist.txt > squid/allowedlist_sorted.txt
mv squid/allowedlist_sorted.txt squid/allowedlist.txt

# Count final domains
FINAL_COUNT=$(wc -l < squid/allowedlist.txt | tr -d ' ')

# Upload back to S3 (commented for testing)
log_info "Uploading updated whitelist to s3://$S3_BUCKET"
aws s3 cp squid/allowedlist.txt "s3://$S3_BUCKET/$S3_KEY"

# Clean up squid folder after upload
log_info "Cleaning up squid folder"
rm -rf squid/

# Processing complete - no need for JSON output since we use direct logging

log_success "Processing complete!"
log_info "📊 Summary:"
log_info "  Original whitelist size: $ORIGINAL_COUNT"
log_info "  Domains processed: $TOTAL_PROCESSED"
log_info "  Domains added: $DOMAINS_ADDED"
log_info "  Final whitelist size: $FINAL_COUNT"
