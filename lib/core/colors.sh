#!/bin/bash

# Color support detection
# Disable colors if:
# - NO_COLOR env is set (https://no-color.org/)
# - stdout is not a terminal
# - TERM is "dumb"
_use_colors() {
    [[ -n "${NO_COLOR:-}" ]] && return 1
    [[ ! -t 1 ]] && return 1
    [[ "${TERM:-}" == "dumb" ]] && return 1
    return 0
}

# Color definitions - only declare if not already defined
if [ -z "$RED" ]; then
    if _use_colors; then
        export RED='\033[0;31m'
        export GREEN='\033[0;32m'
        export YELLOW='\033[1;33m'
        export BLUE='\033[0;34m'
        export MAGENTA='\033[0;35m'
        export CYAN='\033[0;36m'
        export BOLD='\033[1m'
        export DIM='\033[2m'
        export NC='\033[0m'
    else
        # No colors
        export RED=''
        export GREEN=''
        export YELLOW=''
        export BLUE=''
        export MAGENTA=''
        export CYAN=''
        export BOLD=''
        export DIM=''
        export NC=''
    fi
fi 