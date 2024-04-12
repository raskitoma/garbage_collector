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
    keeper_policy=("$4" "$5" "$6" "$7")
    keeper_prefix=("" "full-" "diff-" "incr-")
    keeper_policy_name=("Standard/Dumps" "Full" "Differential" "Incremental")

    cd "$folder" || { log_error "Failed to enter directory $folder"; return; }
    log_message "> Entering directory: $folder"
    
    # Check if the directory is empty
    if [ -z "$(ls -A)" ]; then
        log_message "Directory is empty. Exiting."
        cd ..
        return
    fi

    # let's check if it has subfolders
    subfolders=($(find . -mindepth 1 -maxdepth 1 -type d))
    if [ ${#subfolders[@]} -gt 0 ]; then
        log_message "Directory has subfolders. Processing subfolders."
        for subfolder in "${subfolders[@]}"; do
            process_backups "$subfolder" "$date_format" "$extension" "$4" "$5" "$6" "$7"
        done
    fi

    # if the directory is not empty, then process policies:
    for ((i = 0; i < ${#keeper_policy[@]}; i++)); do
        # Get the index
        index=$i
        # Check if keeper_policy value is empty
        if [[ -z "${keeper_policy[$i]}" ]]; then
            log_message "${keeper_policy_name[$index]} is disabled."
        else
            log_message "${keeper_policy_name[$index]} is enabled as ${keeper_prefix[$index]}${keeper_policy[$i]}."

            # get all files, not directories, that start with ${keeper_prefix[$index]} and end with $extension
            files=($(ls -1 | grep -E "^${keeper_prefix[$index]}.*$extension$"))
            log_message "files: ${files[@]}"
            log_message "files count: ${#files[@]}"

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

# Initialize variables
date_format=""
extension=""
keep=""
keep_full=""
keep_diff=""
keep_incr=""

# Process backups for each section in the config file
while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ ^\[(.*)\] ]]; then
        section="${BASH_REMATCH[1]}"
        log_message ">>> Processing backups for section: $section <<<"
        
        # Escape special characters in the section name
        escaped_section=$(printf '%s\n' "$section" | sed 's/[]\/$*.^|[]/\\&/g')
        
        # Use file descriptor to read config file without restarting from the beginning
        while IFS= read -r line2 || [ -n "$line2" ]; do
            if [[ $line2 =~ ^date_format=(.*) ]]; then
                date_format="${BASH_REMATCH[1]}"
            elif [[ $line2 =~ ^extension=(.*) ]]; then
                extension="${BASH_REMATCH[1]}"
            elif [[ $line2 =~ ^keep=(.*) ]]; then
                keep="${BASH_REMATCH[1]}"
            elif [[ $line2 =~ ^keep_full=(.*) ]]; then
                keep_full="${BASH_REMATCH[1]}"
            elif [[ $line2 =~ ^keep_diff=(.*) ]]; then
                keep_diff="${BASH_REMATCH[1]}"
            elif [[ $line2 =~ ^keep_incr=(.*) ]]; then
                keep_incr="${BASH_REMATCH[1]}"
            fi
        done < <(awk "/^\[$escaped_section\]/,/^$/ {print}" "$SCRIPT_DIR/config.ini")
        
        log_message "Variables: date_format=$date_format, extension=$extension, keep=$keep, keep_full=$keep_full, keep_diff=$keep_diff, keep_incr=$keep_incr"
        process_backups "$section" "$date_format" "$extension" "$keep" "$keep_full" "$keep_diff" "$keep_incr"
        
        # Reset variables for the next section
        date_format=""
        extension=""
        keep=""
        keep_full=""
        keep_diff=""
        keep_incr=""
    fi
done < "$SCRIPT_DIR/config.ini"



# End logging
end_time=$(date '+%s')
time_taken=$((end_time - start_time))
log_message "Garbage collection completed. It took $(date -u -d "@$time_taken" +'%H:%M:%S'). <<<<<<"

