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

# Function to process backups in a folder
process_backups() {
    folder="$1"
    cd "$folder" || { log_error "Failed to enter directory $folder"; return; }
    log_message "Entering directory: $folder"
    
    # Loop through files in the directory
    for file in *; do
        log_message "Processing file: $file"
        # Check if the file matches the pattern (yyyy-mm-dd)
        if [[ $file =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            backup_date="${BASH_REMATCH[1]}"
            current_year=$(date +'%Y')
            current_month=$(date +'%m')
            current_day=$(date +'%d')
            
            # Check if the file is a yearly backup
            if [[ "$backup_date" == "${current_year}-12-31" ]]; then
                log_message "Keeping yearly backup: $file"
                continue
            fi
            
            # Check if the file is a monthly backup
            if [[ "$backup_date" =~ ^${current_year}-[0-9]{2}- ]]; then
                if [[ "$backup_date" =~ ^${current_year}-${current_month}- ]]; then
                    log_message "Keeping monthly backup: $file"
                else
                    delete_file "$file"
                fi
                continue
            fi
            
            # Check if the file is a weekly backup
            if [[ "$backup_date" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
                year="${BASH_REMATCH[1]}"
                month="${BASH_REMATCH[2]}"
                day="${BASH_REMATCH[3]}"
                week_day=$(date -d "$year-$month-$day" +%u)
                if [[ "$week_day" -ge 1 ]] && [[ "$week_day" -le 7 ]]; then
                    if [[ "$month" == "$current_month" ]] && [[ "$day" -ge $((current_day - (week_day - 1))) ]]; then
                        if [[ "$backup_date" == "$(date +'%Y-%m-%d')" ]]; then
                            log_message "Keeping weekly backup: $file"
                        else
                            delete_file "$file"
                        fi
                    else
                        delete_file "$file"
                    fi
                else
                    delete_file "$file"
                fi
                continue
            fi
            
            # Check if the file is a daily backup
            if [[ "$backup_date" =~ ^${current_year}-${current_month}- ]]; then
                if [[ "$backup_date" =~ ^${current_year}-${current_month}-[0-9]{2}$ ]]; then
                    if [[ "$backup_date" == "$(date +'%Y-%m-%d')" ]]; then
                        log_message "Keeping daily backup: $file"
                    else
                        delete_file "$file"
                    fi
                else
                    delete_file "$file"
                fi
                continue
            fi
        fi
    done
    
    # Process subfolders recursively
    for subfolder in */; do
        if [ -d "$subfolder" ]; then
            process_backups "$subfolder"
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
echo "" | tee -a "$SCRIPT_DIR/logs/$(date +'%Y-%m-%d')_garbage_collector.log"
log_message "Starting garbage collection at $(date +'%Y-%m-%d %H:%M:%S') <<<<<<"


# Process backups for each section in the config file
while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ ^\[(.*)\] ]]; then
        section="${BASH_REMATCH[1]}"
        log_message ">>> Processing backups for section: $section"
        echo "====================" | tee -a "$SCRIPT_DIR/logs/$(date +'%Y-%m-%d')_garbage_collector.log"
        process_backups "$section"
    fi
done < "$SCRIPT_DIR/config.ini"

# End logging
start_time=$(date -d "$(head -n 2 "$SCRIPT_DIR/logs/$(date +'%Y-%m-%d')_garbage_collector.log" | tail -n 1 | cut -d' ' -f5-)" '+%s')
end_time=$(date '+%s')
time_taken=$((end_time - start_time))
log_message "Garbage collection completed. It took $(date -u -d "@$time_taken" +'%H:%M:%S'). <<<<<<"

