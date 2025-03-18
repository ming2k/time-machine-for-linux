#!/bin/bash

confirm_execution() {
    local operation_name="$1"
    local default_response="${2:-n}"  # Default to 'n' if not specified
    
    # Convert default response to lowercase
    default_response=$(echo "$default_response" | tr '[:upper:]' '[:lower:]')
    
    # Set prompt based on default response
    if [ "$default_response" = "y" ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    
    while true; do
        read -p "Do you want to proceed with ${operation_name}? ${prompt} " response
        
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
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Export the function so it's available to sourced scripts
export -f confirm_execution
