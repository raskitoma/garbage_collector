#!/bin/bash

# Function to log errors
log_error() {
    message="$(date +'%Y-%m-%d %H:%M:%S') ERROR: $1"
    echo "$message" | tee -a "logs/$(date +'%Y-%m-%d')_error.log"
}

# Function to log messages
log_message() {
    message="$(date +'%Y-%m-%d %H:%M:%S') INFO: $1"
    echo "$message" | tee -a "logs/$(date +'%Y-%m-%d')_garbage_collector.log"
}

# Function to delete files
delete_file() {
    file="$1"
    log_message "Deleting file: $file"
    # Uncomment the following line to actually delete files
    # rm "$file"
}

# Check if config.ini exists
if [ ! -f "config.ini" ]; then
    log_error "config.ini file not found. Exiting."
    exit 1
fi

# Check if logs directory exists, if not, create it
if [ ! -d "logs" ]; then
    mkdir "logs" || { echo "Failed to create logs directory. Exiting."; exit 1; }
fi

# Read config file and process each section
while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ ^\[(.*)\] ]]; then
        section="${BASH_REMATCH[1]}"
        log_message "Entering directory: $section"
        # Enter directory
        if ! cd "$section"; then
            log_error "Failed to enter directory $section"
            continue
        fi
    elif [[ $line =~ ^keep_full=([0-9]+),([0-9]+),([0-9]+),([0-9]+) ]]; then
        full_keep=("${BASH_REMATCH[@]:1}")
    elif [[ $line =~ ^keep_diff=([0-9]+),([0-9]+),([0-9]+),([0-9]+) ]]; then
        diff_keep=("${BASH_REMATCH[@]:1}")
    elif [[ $line =~ ^keep_incr=([0-9]+),([0-9]+),([0-9]+),([0-9]+) ]]; then
        incr_keep=("${BASH_REMATCH[@]:1}")
    elif [[ $line =~ ^keep=([0-9]+),([0-9]+),([0-9]+),([0-9]+) ]]; then
        keep=("${BASH_REMATCH[@]:1}")
        # Process backups for this section
        log_message "Processing backups for section: $section"
        # Determine current date
        current_year=$(date +'%Y')
        current_month=$(date +'%m')
        current_day=$(date +'%d')
        # Process yearly backup
        yearly_backup="$current_year-12-31"
        if [ "$current_month" -eq 12 ] && [ "$current_day" -eq 31 ]; then
            log_message "Keeping yearly backup: $yearly_backup"
        else
            delete_file "$yearly_backup"
        fi
        # Process monthly backups
        for ((month = 1; month <= $current_month; month++)); do
            monthly_backup="$current_year-$(printf "%02d" $month)-$(cal $month $current_year | grep -v "^$" | tail -1 | awk '{print $NF}')"
            if [ "$month" -eq "$current_month" ]; then
                log_message "Keeping monthly backup: $monthly_backup"
            else
                delete_file "$monthly_backup"
            fi
        done
        # Process weekly backups
        for ((day = 0; day < 7; day++)); do
            weekly_backup=$(date -d "last Sunday - $day days" +'%Y-%m-%d')
            if [ $(date -d "$weekly_backup" +'%m') -eq $current_month ]; then
                if [ "$weekly_backup" -ge "$(date +'%Y-%m-%d')" ]; then
                    log_message "Keeping weekly backup: $weekly_backup"
                else
                    delete_file "$weekly_backup"
                fi
            fi
        done
        # Process daily backups
        for ((day = 1; day <= $current_day; day++)); do
            daily_backup="$current_year-$current_month-$(printf "%02d" $day)"
            if [ "$daily_backup" == "$(date +'%Y-%m-%d')" ]; then
                log_message "Keeping daily backup: $daily_backup"
            else
                delete_file "$daily_backup"
            fi
        done
        # Exit directory
        cd ..
    fi
done < "config.ini"

log_message "Garbage collection completed."
