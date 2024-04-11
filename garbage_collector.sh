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
            # get index of the current policy
            my_index=$(awk -F'[^0-9]+' '{print $2}' <<< "$keep_policy")

            log_message "my index: $my_index"

            # Check if policy is set (not empty)
            if [ -z "${keeper_policy[$keep_policy]}" ]; then
                log_message "> Policy ${keeper_policy_name[$my_index]} is not set. Skipping."
                continue
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

