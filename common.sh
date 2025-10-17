#!/bin/bash


## Colors


readonly ESC='\033['

# Reset Style and Color
readonly CLEAR="${ESC}0m"
readonly CLR="${ESC}0m"
# Styles
readonly BOLD="${ESC}1m"
readonly DIM="${ESC}2m"
readonly ITALIC="${ESC}3m"
readonly UNDERLINE="${ESC}4m"
readonly BLINK="${ESC}5m"
readonly REVERSE="${ESC}7m"
readonly HIDDEN="${ESC}8m"
# Standard foreground
readonly BLACK="${ESC}30m"
readonly RED="${ESC}31m"
readonly GREEN="${ESC}32m"
readonly YELLOW="${ESC}33m"
readonly BLUE="${ESC}34m"
readonly MAGENTA="${ESC}35m"
readonly CYAN="${ESC}36m"
readonly WHITE="${ESC}37m"
# Standard background
readonly BG_BLACK="${ESC}40m"
readonly BG_RED="${ESC}41m"
readonly BG_GREEN="${ESC}42m"
readonly BG_YELLOW="${ESC}43m"
readonly BG_BLUE="${ESC}44m"
readonly BG_MAGENTA="${ESC}45m"
readonly BG_CYAN="${ESC}46m"
readonly BG_WHITE="${ESC}47m"
# Bright foreground
readonly LIGHT_BLACK="${ESC}90m" # bright black (often grey)
readonly LIGHT_RED="${ESC}91m"
readonly LIGHT_GREEN="${ESC}92m"
readonly LIGHT_YELLOW="${ESC}93m"
readonly LIGHT_BLUE="${ESC}94m"
readonly LIGHT_MAGENTA="${ESC}95m"
readonly LIGHT_CYAN="${ESC}96m"
readonly LIGHT_WHITE="${ESC}97m"
# Bright backgrounds
readonly BG_LIGHT_BLACK="${ESC}100m"
readonly BG_LIGHT_RED="${ESC}101m"
readonly BG_LIGHT_GREEN="${ESC}102m"
readonly BG_LIGHT_YELLOW="${ESC}103m"
readonly BG_LIGHT_BLUE="${ESC}104m"
readonly BG_LIGHT_MAGENTA="${ESC}105m"
readonly BG_LIGHT_CYAN="${ESC}106m"
readonly BG_LIGHT_WHITE="${ESC}107m"


## Routines


start_message() {
    #
    # Print standard message prefix.
    #
    printf "%b::%b " "${BOLD}${WHITE}" "${CLR}"
}


start_error() {
    #
    # Print standard error message prefix.
    #
    start_message
    printf "%b[ERROR]%b " "${BOLD}${RED}" "${CLR}"
}

start_result()
{
    printf "   %b->%b " "${BOLD}${GREEN}" "${CLR}"
}


info() {
    #
    # Print an info message with standard prefix.
    #
    # Example:
    #   message "Installing configs..."
    #
    start_message
    printf "${DIM}%b${CLR}" "$1"
}


error() {
    #
    # Print an error message with standard prefix.
    #
    # Example:
    #   error "Failed to install configs"
    #
    start_error
    printf "${DIM}%b${CLR}" "$1"
}


warning() {
    #
    # Print a warning message with standard prefix.
    #
    # Example:
    #   warning "Config file already exists, skipping"
    #
    start_warning
    printf "${DIM}%b${CLR}" "$1"
}


log_result() {
    #
    # Print a result message with result prefix.
    #
    # Example:
    #   log_result "Config installed"
    #
    start_result
    printf "${DIM}%b${CLR}" "$1"
}


as_root() {
    #
    # Execute command as root (add sudo if necessary).
    # Returns the exit code of the command.
    #
    # Example:
    #   as_root pacman -Sy gum
    #
    info "$*\n"

    if [ "$EUID" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi

    local exit_code=$?
    echo

    return "$exit_code"
}


assert() {
    #
    # Assert that the given exit code is zero (the first argument);
    # if not, print the given message and exit with code 1.
    #
    # Example:
    #   as_root pacman -Sy gum
    #   assert $? "failed to install gum"
    #
    local exit_code="$1"
    local message="$2"

    if [ "$exit_code" -ne 0 ]; then
        error "${message}\n"
        exit 1
    fi
}


ask_yn() {
    #
    # Ask a yes/no question, return 0 for yes, 1 for no
    #
    # Example:
    #   printf "Install gum? "
    #   if ask_yn; then as_root pacman -Sy gum; fi
    #
    printf "(y/n): "
    read -r -p "" -n 1 reply
    echo

    if [[ $reply =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}


request_package() {
    #
    # Request user to install a package if it's not already installed.
    #
    # Example:
    #   request_package "git"
    #   assert $? "failed to install git"
    #
    local package="$1"

    pacman -Qi "${package}" &> /dev/null && return 0

    as_root pacman -Sy "${package}"
    return $?
}


request_gum() {
    #
    # Request user to install gum if it's not already installed.
    #
    # Example:
    #   gum_request
    #   assert $? "no gum - no fun :("
    #
    command -v gum &> /dev/null && return 0

    info "The UI ${CLR}${BOLD}${MAGENTA}gum${CLR}${DIM} not found. Let's get some? "

    if ask_yn; then
        as_root pacman -Sy gum
        return $?
    else
        return 1
    fi
}


choices_to_indices() {
    #
    # Convert a newline-separated string of choices into their corresponding
    # indices in the provided source array.
    #
    # Example:
    #   indices=($(choices_to_indices "$file_choices" "${CONFIG_FILES[@]}"))
    #
    local choices="$1"
    shift
    local source_array=("$@")

    # Convert choices to array using mapfile
    local selected_items=()
    mapfile -t selected_items <<< "$choices"

    # Find indices
    local indices=()
    for item in "${selected_items[@]}"; do
        [[ -z "$item" ]] && continue  # Skip empty lines
        for i in "${!source_array[@]}"; do
            if [[ "${source_array[$i]}" == "$item" ]]; then
                indices+=("$i")
                break
            fi
        done
    done

    # Return indices as space-separated string
    echo "${indices[@]}"
}


backup_file() {
    #
    # Create a backup of the given file by appending .bakN
    # where N is the next available number.
    #
    # Example:
    #    backup_name=$(backup_file "$file")
    #    assert $? "backup failed for $file"
    #
    local filename="$1"

    if [[ ! -f $filename ]]; then
        # no target file - nothing to back up
        echo ""  # return empty string
        return 0 # no error
    fi

    # Find the next available backup number
    local idx=1
    local backup_name="${filename}.bak${idx}"

    while [[ -f $backup_name ]]; do
        ((idx++))
        backup_name="${filename}.bak${idx}"
    done

    # Create the backup
    if cp "$filename" "$backup_name" 2>/dev/null; then
        echo "${backup_name}" # return backup filename
        return 0
    else
        echo ""  # return empty string - no backup created
        return 1
    fi
}
