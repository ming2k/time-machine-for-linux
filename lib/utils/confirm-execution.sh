#!/bin/bash

# Confirm execution with optional preflight check capability
# Usage: confirm_execution "operation_name" "default_response" ["backup_type" "dest_path" "snapshot_path" "sources_array_name"]
confirm_execution() {
    local operation_name="$1"
    local default_response="${2:-n}"  # Default to 'n' if not specified
    local backup_type="$3"            # Optional: for preflight checks
    local dest_path="$4"              # Optional: for preflight checks
    local snapshot_path="$5"          # Optional: for preflight checks
    local sources_array_name="$6"     # Optional: for preflight checks

    # Convert default response to lowercase
    default_response=$(echo "$default_response" | tr '[:upper:]' '[:lower:]')

    # Determine if preflight checks are available
    local preflight_available=false
    if [ -n "$backup_type" ] && [ -n "$dest_path" ] && [ -n "$snapshot_path" ]; then
        preflight_available=true
    fi

    # Set prompt based on whether preflight is available
    local prompt
    if [ "$preflight_available" = true ]; then
        if [ "$default_response" = "y" ]; then
            prompt="[Y/n/c]"
        else
            prompt="[y/N/c]"
        fi
    else
        if [ "$default_response" = "y" ]; then
            prompt="[Y/n]"
        else
            prompt="[y/N]"
        fi
    fi

    while true; do
        # Build the question
        local question="Do you want to proceed with ${operation_name}? ${prompt}"
        if [ "$preflight_available" = true ]; then
            question="${question} (c=check preflight info)"
        fi

        read -p "$question " response

        # If empty response, use default
        if [ -z "$response" ]; then
            response=$default_response
        fi

        # Convert response to lowercase
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

        case $response in
            y|yes)
                return 0
                ;;
            n|no)
                echo "Operation cancelled by user."
                return 1
                ;;
            c|check)
                if [ "$preflight_available" = true ]; then
                    # Run preflight checks and display info
                    run_preflight_checks "$backup_type" "$dest_path" "$snapshot_path" "$sources_array_name"
                    show_preflight_info
                    echo ""  # Add spacing before returning to prompt
                    # Loop continues to ask again
                else
                    echo "Preflight checks not available for this operation."
                fi
                ;;
            *)
                if [ "$preflight_available" = true ]; then
                    echo "Please answer yes, no, or check."
                else
                    echo "Please answer yes or no."
                fi
                ;;
        esac
    done
}

# Export the function so it's available to sourced scripts
export -f confirm_execution
