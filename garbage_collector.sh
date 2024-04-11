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

        # Check if keeper_policy is set
        if [ -n "${keeper_policy[0]}" ]; then
            # Assign policy values
            keep_yearly="${keeper_policy[0]}"
            keep_monthly="${keeper_policy[1]}"
            keep_weekly="${keeper_policy[2]}"
            keep_daily="${keeper_policy[3]}"

            expected_filename_template=${keeper_prefix[1]}[0-9]{4}$date_format\.$extension$

            log_message "processing file: $file with current policy: ${keeper_policy[@]} as ${keeper_prefix[@]} with date format: $date_format and extension: $extension"
            log_message "with expected filename template: $expected_filename_template"
            log_message "Yearly is set to $keep_yearly, Monthly is set to $keep_monthly, Weekly is set to $keep_weekly, Daily is set to $keep_daily"

            # Yearly keeper policy
            if [ "$keep_yearly" -gt 0 ]; then
                # Check if the file matches the format and decide whether to keep it based on the policy
                if [[ $file =~ ^${keeper_prefix[1]}[0-9]{4}$date_format\.$extension$ ]]; then
                    log_message "processing file: $file"

                    # lets check if the file is the last one in the year
                    year="${file:5:4}"
                    if [ ! -f "${keeper_prefix[1]}$(($year + 1))$date_format.$extension" ]; then
                        marked_for_deletion+=("$file")
                    else 
                        log_message "keeping file: $file"
                    fi
                    


                fi
            fi
            
            # Your logic to handle the file based on the keeper policy goes here
            # For example:
            # Check if the file matches the format and decide whether to keep it based on the policy
        fi



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

