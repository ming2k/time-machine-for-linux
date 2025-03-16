#!/bin/bash

# Color definitions - only declare if not already defined
if [ -z "$RED" ]; then
    export RED='\033[0;31m'
    export GREEN='\033[0;32m'
    export YELLOW='\033[1;33m'
    export BLUE='\033[0;34m'
    export MAGENTA='\033[0;35m'
    export CYAN='\033[0;36m'
    export BOLD='\033[1m'
    export NC='\033[0m'
fi 