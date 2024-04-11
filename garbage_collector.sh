#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Function to log errors
log_error() {
    message="$(date +'%Y-%m-%d %H:%M:%S') ERROR: $1"
    echo "$message" | tee -a "$SCRIPT_DIR/logs/$(date +'%Y-%m-%d')_error.log"
}

# Function to log messages
log_message() {
    message="$(date +'%Y-%m-%d %H:%M:%S') INFO: $1"
    echo "$message" | tee -a "$SCRIPT_DIR/logs/$(date +'%Y-%m-%d')_garbage_collector.log"
}

# Function to delete files
delete_file() {
    file="$1"
    log_message "Deleting file: $file"
    # Uncomment the following line to actually delete files
    # rm "$file"
}

marked_for_deletion=()

# Function to process backups in a folder
process_backups() {
    folder="$1"
    date_format="$2"
    extension="$3"
    keeper_policy=["$4","$5","$6","$7"]
    keeper_prefix=["","full-","diff-","incr-"]
    keeper_policy_name=["Standard/Dumps","Full","Differential","Incremental"]

    cd "$folder" || { log_error "Failed to enter directory $folder"; return; }
    log_message "> Entering directory: $folder"
    
    # Loop through files in the directory
    for file in *; do
        # first, checks if the file is a directory
        if [ -d "$file" ]; then
            log_message "> Processing subfolder: $file"
            process_backups "$file" "$date_format" "$extension" "${keeper_policy[@]}"
            continue
        fi

        for keep_policy in "${!keeper_policy[@]}"; do
            if [[ $file == ${keeper_prefix[$keep_policy]}*.$extension ]]; then
                # Extract date from filename
                date_string=$(echo "$file" | grep -oP "\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}")
                if [ -z "$date_string" ]; then
                    log_error "Failed to extract date from filename: $file"
                    continue
                fi
                # Convert date to epoch
                epoch_date=$(date -d "$date_string" +"%s")
                if [ -z "$epoch_date" ]; then
                    log_error "Failed to convert date to epoch: $date_string"
                    continue
                fi
                # Calculate the age of the file
                current_date=$(date '+%s')
                age=$((current_date - epoch_date))
                # Check if the file should be deleted
                if [ $age -gt $((keeper_policy[$keep_policy] * 86400)) ]; then
                    log_message "File $file is older than ${keeper_policy_name[$keep_policy]} policy. Age: $(date -u -d "@$age" +'%d days %H hours %M minutes %S seconds')"
                    marked_for_deletion+=("$file")
                fi
            fi
        done


    done

    cd ..
}


# Check if config.ini exists
if [ ! -f "$SCRIPT_DIR/config.ini" ]; then
    log_error "config.ini file not found. Exiting."
    exit 1
fi

# Check if logs directory exists, if not, create it
if [ ! -d "$SCRIPT_DIR/logs" ]; then
    mkdir "$SCRIPT_DIR/logs" || { log_error "Failed to create logs directory. Exiting."; exit 1; }
fi

# Start logging
start_time=$(date '+%s')
echo "" | tee -a "$SCRIPT_DIR/logs/$(date +'%Y-%m-%d')_garbage_collector.log"
log_message "Starting garbage collection at $(date +'%Y-%m-%d %H:%M:%S') <<<<<<"

# Process backups for each section in the config file
while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ ^\[(.*)\] ]]; then
        section="${BASH_REMATCH[1]}"
        log_message ">>> Processing backups for section: $section <<<"
        # Extract additional variables from config
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ $line =~ ^date_format=(.*) ]]; then
                date_format="${BASH_REMATCH[1]}"
            elif [[ $line =~ ^extension=(.*) ]]; then
                extension="${BASH_REMATCH[1]}"
            elif [[ $line =~ ^keep=(.*) ]]; then
                keep="${BASH_REMATCH[1]}"
            elif [[ $line =~ ^keep_full=(.*) ]]; then
                keep_full="${BASH_REMATCH[1]}"
            elif [[ $line =~ ^keep_diff=(.*) ]]; then
                keep_diff="${BASH_REMATCH[1]}"
            elif [[ $line =~ ^keep_incr=(.*) ]]; then
                keep_incr="${BASH_REMATCH[1]}"
            fi
        done < "$SCRIPT_DIR/config.ini"
        process_backups "$section" "$date_format" "$extension" "$keep" "$keep_full" "$keep_diff" "$keep_incr"
    fi
done < "$SCRIPT_DIR/config.ini"

# End logging
end_time=$(date '+%s')
time_taken=$((end_time - start_time))
log_message "Garbage collection completed. It took $(date -u -d "@$time_taken" +'%H:%M:%S'). <<<<<<"

