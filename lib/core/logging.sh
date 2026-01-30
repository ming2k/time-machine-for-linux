#!/bin/bash

# Logging configuration
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_DATE=$(date +%Y%m%d)
LOG_FILE="${LOG_DIR}/backup-${LOG_DATE}.log"
MAX_LOG_SIZE=10485760  # 10MB
MAX_LOG_FILES=5

# Ensure log directory exists with proper permissions
init_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    # Set directory permissions (readable by all, writable by owner)
    chmod 755 "$LOG_DIR"
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    # Set file permissions (readable by all, writable by owner)
    chmod 644 "$LOG_FILE"
    
    # Rotate logs if needed
    rotate_logs
}

# Rotate log files
rotate_logs() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -c %s "$LOG_FILE")
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            # Rotate existing logs
            for i in $(seq $((MAX_LOG_FILES-1)) -1 1); do
                if [ -f "${LOG_FILE}.${i}" ]; then
                    mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i+1))"
                fi
            done
            mv "$LOG_FILE" "${LOG_FILE}.1"
            touch "$LOG_FILE"
            chmod 644 "$LOG_FILE"
        fi
    fi
}

# Log message with timestamp and level
log_msg() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to file (always with full format)
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Log to console - only prefix errors/warnings (searchable)
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARN]${NC}  $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}$message${NC}"
            ;;
        "INFO"|*)
            echo -e "$message"
            ;;
    esac
}

# Log command execution
log_cmd() {
    local cmd="$1"
    local description="$2"
    
    log_msg "INFO" "Executing: $description"
    log_msg "INFO" "Command: $cmd"
    
    # Execute command and capture output
    local output
    output=$(eval "$cmd" 2>&1)
    local status=$?
    
    # Log output if any
    if [ -n "$output" ]; then
        log_msg "INFO" "Output: $output"
    fi
    
    # Log status
    if [ $status -eq 0 ]; then
        log_msg "SUCCESS" "Command completed successfully"
    else
        log_msg "ERROR" "Command failed with status $status"
    fi
    
    return $status
}

# Log error and exit
log_error_and_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_msg "ERROR" "$message"
    exit $exit_code
}

# Log warning
log_warning() {
    local message="$1"
    log_msg "WARNING" "$message"
}

# Log success
log_success() {
    local message="$1"
    log_msg "SUCCESS" "$message"
}

# Log info
log_info() {
    local message="$1"
    log_msg "INFO" "$message"
}

# Initialize logging on script start
init_logging

# Use absolute path from LIB_DIR
source "${LIB_DIR}/core/colors.sh"

# Print raw message without timestamp and level (for special formatting)
print_raw() {
    local msg="$1"
    echo -e "$msg"
}

# Print indented message with consistent formatting
print_info() {
    local msg="$1"
    log_msg "INFO" "  ${msg}"
} 