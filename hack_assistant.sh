#!/bin/bash
# Ethical Hacking Assistant - Enhanced Version
# Features: API integration, command validation, logging, and safety mechanisms

# Configuration
CONFIG_FILE="$HOME/.hack_assistant.conf"
LOG_FILE="$HOME/hack_assistant.log"
MAX_HISTORY=50
ALLOWED_COMMANDS=("nmap" "gobuster" "sublist3r" "curl")  # Command allow-list

# Initialize environment
trap cleanup EXIT
set -o noclobber

# Load API key from config (secure storage example)
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "API_KEY=your_api_key_here" > "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi
}

# Security functions
sanitize_input() {
    echo "$1" | sed 's/[^a-zA-Z0-9 .-]//g'
}

validate_command() {
    local cmd="$1"
    for allowed in "${ALLOWED_COMMANDS[@]}"; do
        if [[ "$cmd" == "$allowed"* ]]; then
            return 0
        fi
    done
    return 1
}

# API Integration
api_get_command() {
    local query="$1"
    local response=""
    
    response=$(curl -sS --max-time 10 -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"prompt\": \"$query\", \"max_tokens\": 100}" \
        "https://api.openai.com/v1/engines/davinci/completions")
    
    if [ $? -ne 0 ]; then
        log "API request failed"
        return 1
    fi
    
    echo "$response" | jq -r '.choices[0].text' | awk -F'```' '{print $2}'
}

# Execution functions
safe_execute() {
    local cmd="$1"
    if validate_command "$cmd"; then
        echo "[+] Executing: $cmd" | tee -a "$LOG_FILE"
        /bin/bash -c "$cmd" 2>> "$LOG_FILE"
        return $?
    else
        log "Blocked restricted command: $cmd"
        return 1
    fi
}

# Logging system
log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# User Interface
show_help() {
    echo -e "\nAvailable commands:"
    echo "  scan <target>            - Perform nmap scan"
    echo "  dirscan <target>         - Directory enumeration"
    echo "  subdomains <domain>      - Find subdomains"
    echo "  history                  - Show command history"
    echo "  help                     - Show this help"
    echo "  exit                     - Quit program"
}

# Command history
manage_history() {
    history_file="$HOME/.hack_history"
    if [ ! -f "$history_file" ]; then
        touch "$history_file"
        chmod 600 "$history_file"
    fi
    
    if [ "$1" == "add" ]; then
        echo "$2" >> "$history_file"
        # Maintain history size
        tail -n "$MAX_HISTORY" "$history_file" > "$history_file.tmp"
        mv "$history_file.tmp" "$history_file"
    elif [ "$1" == "show" ]; then
        nl "$history_file"
    fi
}

# Main execution flow
main() {
    load_config
    echo -e "Ethical Hacking Assistant - Secure Version\n"
    
    while true; do
        read -r -p "hackGPT# " user_query
        user_query=$(sanitize_input "$user_query")
        
        case "$user_query" in
            help)
                show_help
                ;;
            history)
                manage_history show
                ;;
            exit)
                echo "Exiting..."
                exit 0
                ;;
            *)
                generated_command=$(api_get_command "$user_query")
                if [ -z "$generated_command" ]; then
                    echo "Error: No valid command generated"
                    continue
                fi
                
                manage_history add "$generated_command"
                
                echo -e "\nGenerated command:"
                echo -e "\033[32m$generated_command\033[0m"
                
                while true; do
                    read -r -p "Execute? (y/n/edit/help/exit) " confirm
                    case "$confirm" in
                        y|Y)
                            safe_execute "$generated_command"
                            break
                            ;;
                        n|N)
                            echo "Command canceled"
                            break
                            ;;
                        e|E)
                            read -r -p "Edit command: " generated_command
                            generated_command=$(sanitize_input "$generated_command")
                            ;;
                        help)
                            show_help
                            ;;
                        exit)
                            exit 0
                            ;;
                        *)
                            echo "Invalid option"
                            ;;
                    esac
                done
                ;;
        esac
    done
}

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -f /tmp/.tempcmd.*
}

# Start main program
main
