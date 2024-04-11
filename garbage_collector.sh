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
    
    # Loop through files in the directory
    for file in *; do
        # first, checks if the file is a directory
        if [ -d "$file" ]; then
            log_message "> Processing subfolder: $file with policy: (std: $4 | full: $5 | diff: $6 | incr: $7)"
            process_backups "$file" "$date_format" "$extension" "$4" "$5" "$6" "$7"
            continue
        fi

        # Iterate through each value in keeper_policy
        for ((i = 0; i < ${#keeper_policy[@]}; i++)); do
            # Get the index
            index=$i
            # Check if keeper_policy value is empty
            if [[ -z "${keeper_policy[$i]}" ]]; then
                log_message "${keeper_policy_name[$index]} is disabled."
            else
                log_message "${keeper_policy_name[$index]} is enabled as ${keeper_prefix[$index]}${keeper_policy[$i]}."

                # Define the template
                template_for_file_name="${keeper_prefix[$index]// /.}*.$extension"

                # Remove spaces from the template
                template_for_file_name="${template_for_file_name// /.}"

                log_message "Template for file name: $template_for_file_name"

                # Check if the file matches the template expression
                if [[ "$file" =~ $template_for_file_name ]]; then
                    log_message "$file matches the template expression."
                else
                    log_message "$file doesn't have a matching template expression. Skipping file."
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

