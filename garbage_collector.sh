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

    # let's check if it has subfolders excluding YY, MM, and WW
    subfolders=($(find . -mindepth 1 -maxdepth 1 -type d -not \( -name "YY" -o -name "MM" -o -name "WW" \)))
    if [ ${#subfolders[@]} -gt 0 ]; then
        log_message "Directory has subfolders. Processing subfolders."
        for subfolder in "${subfolders[@]}"; do
            process_backups "$subfolder" "$date_format" "$extension" "$4" "$5" "$6" "$7"
        done
    fi


    # if the directory is not empty, check if this subfolder has subfolders YY, MM, WW. If not, create them.
    if [ "$(ls -A)" ]; then
        # Check if there are no subdirectories
        if [ -z "$(find . -maxdepth 1 -type d -not -name '.' -not -name 'YY' -not -name 'MM' -not -name 'WW')" ]; then
            # Create subdirectories YY, MM, and WW
            mkdir "YY" || { log_error "Failed to create YY directory. Exiting."; cd ..; return; }
            mkdir "MM" || { log_error "Failed to create MM directory. Exiting."; cd ..; return; }
            mkdir "WW" || { log_error "Failed to create WW directory. Exiting."; cd ..; return; }
        else
            echo "Subdirectories exist. Skipping creation of YY, MM, and WW."
        fi
    else
        echo "Directory is empty."
    fi

    # if the directory is not empty, then process policies:
    for ((i = 0; i < ${#keeper_policy[@]}; i++)); do
        # Get the index
        index=$i
        # Check if keeper_policy value is empty
        if [[ -z "${keeper_policy[$i]}" ]]; then
            log_message "> ${keeper_policy_name[$index]} is disabled."
        else
            log_message "> ${keeper_policy_name[$index]} is enabled as ${keeper_prefix[$index]}${keeper_policy[$i]}."

            # get all files, not directories, that start with ${keeper_prefix[$index]} and end with $extension
            files=($(ls -1 | grep -E "^${keeper_prefix[$index]}.*$extension$"))

            # if there is no files, then skip
            if [ ${#files[@]} -eq 0 ]; then
                log_message "No ${keeper_policy_name[$index]} backups found. Skipping."
                continue
            fi

            # let's check each policy, each policy, if available will be a set of 4 flags, first flag being yearly, second being monthly, third being weekly, fourth being daily
            # yearly means keep the last backup file of each year if yearly is 1
            # monthly means keep the last backup file of each month if monthly is 1 for current year
            # weekly means keep the last backup file of each week if weekly is 1 for current month
            # daily means keep the last backup file of each day if daily is 1 for current week

            pol_yy=${keeper_policy[$i]:0:1}
            pol_mm=${keeper_policy[$i]:1:1}
            pol_ww=${keeper_policy[$i]:2:1}
            pol_dd=${keeper_policy[$i]:3:1}

            # let's get the current year, month, week and day
            current_year=$(date +'%Y')
            current_month=$(date +'%m')
            current_week=$(date +'%U')
            current_day=$(date +'%d')

            # let's process the yearly if enabled
            if [ $pol_yy -eq 1 ]; then
                # let's get the list of files actually stored in the YY subfolder
                yy_files=($(ls -1 YY | grep -E "^${keeper_prefix[$index]}.*$extension$"))

                checked_files=()
                # get the last backup file for current year from files array.
                # The file has the date in the format specified in the config file inside it filename
                # so we need to check the files array and find the file with the latest date in its naming
                for file in "${files[@]}"; do
                    # get the date from the file name
                    file_date=$(echo "$file" | grep -oP "(\d{4}-\d{2}-\d{2})")
                    # get the year from the date
                    file_year=$(date -d "$file_date" +'%Y')
                    # if the year is the current year, then add it to th
                    if [ "$file_year" -eq "$current_year" ]; then
                        checked_files+=("$file")
                    fi
                done

                # if there are no files for the current year, then skip
                if [ ${#checked_files[@]} -eq 0 ]; then
                    log_message "No ${keeper_policy_name[$index]} backups found for the current year. Skipping."
                    continue
                fi

                # let's get the latest file for the current year
                latest_file=$(printf "%s\n" "${checked_files[@]}" | sort -r | head -n 1)

                # log the new latest file and the yy_files
                log_message "Latest ${keeper_policy_name[$index]} backup for the current year: $latest_file"

                # let's check if the new latest file is already in the YY folder if not, check if we have for the current year a previous lastest_file. If we have, then mark the previous latest_file for deletion and copy the new latest file to the YY folder
                if [ ! -f "YY/$latest_file" ]; then
                    # let's check if we have a previous latest file for the current year
                    if [ ${#yy_files[@]} -gt 0 ]; then
                        # let's mark the previous latest file for deletion
                        for yy_file in "${yy_files[@]}"; do
                            if [ "$yy_file" != "$latest_file" ]; then
                                marked_for_deletion+=("YY/$yy_file")
                            fi
                        done
                    fi
                    # let's copy the new latest file to the YY folder
                    cp "$latest_file" "YY/$latest_file"
                fi

                # list the files marked for deletion
                if [ ${#marked_for_deletion[@]} -gt 0 ]; then
                    log_message "Marked for deletion: ${marked_for_deletion[@]}"
                fi
                
                


            

                


            fi

            
            



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

