#!/bin/bash

source "$(dirname "$0")/../lib/core/colors.sh"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
SKIPPED_TESTS=0

# Run all unit tests in a module
run_module_tests() {
    local module="$1"
    echo -e "\n${YELLOW}Running $module tests...${NC}"
    
    # Special handling for utils module to include confirm_execution test
    if [ "$module" = "utils" ]; then
        test_confirm_execution
        case $? in
            0) ((PASSED_TESTS++));;
            2) ((SKIPPED_TESTS++));;
            *) echo -e "${RED}Test failed${NC}"; return 1;;
        esac
        ((TOTAL_TESTS++))
    fi
    
    for test_file in unit/$module/test_*.sh; do
        if [ -f "$test_file" ]; then
            echo -e "\n${YELLOW}Running $test_file${NC}"
            bash "$test_file"
            case $? in
                0) ((PASSED_TESTS++));;
                2) ((SKIPPED_TESTS++));;
                *) echo -e "${RED}Test failed${NC}"; return 1;;
            esac
            ((TOTAL_TESTS++))
        fi
    done
}

# Run all tests
run_all_tests() {
    local modules=("core" "fs" "config" "backup" "ui" "utils")
    
    for module in "${modules[@]}"; do
        if ! run_module_tests "$module"; then
            return 1
        fi
    done
    
    return 0
}

# Print test summary
print_summary() {
    echo -e "\n${YELLOW}Test Summary:${NC}"
    echo -e "Total tests : $TOTAL_TESTS"
    echo -e "Passed      : ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Skipped     : ${YELLOW}$SKIPPED_TESTS${NC}"
    echo -e "Failed      : ${RED}$((TOTAL_TESTS - PASSED_TESTS - SKIPPED_TESTS))${NC}"
}

# Move test_confirm_execution to the top level
test_confirm_execution() {
    source "../lib/utils/confirm-execution.sh"
    
    echo -e "\n${YELLOW}Running confirm_execution tests...${NC}"
    
    # Test with default 'yes'
    echo "y" | confirm_execution "test operation" "y"
    assertEquals "Confirmation with 'y' should return 0" 0 $?
    
    # Test with default 'no'
    echo "n" | confirm_execution "test operation" "n"
    assertEquals "Confirmation with 'n' should return 1" 1 $?
    
    # Test with empty input (should use default)
    echo "" | confirm_execution "test operation" "y"
    assertEquals "Empty input with default 'y' should return 0" 0 $?
    
    # Test with invalid input followed by valid input
    (echo "invalid"; echo "y") | confirm_execution "test operation" "n"
    assertEquals "Invalid then valid input should work" 0 $?
}

# Main
echo -e "${YELLOW}Starting test suite${NC}"

if run_all_tests; then
    print_summary
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    print_summary
    echo -e "\n${RED}Some tests failed${NC}"
    exit 1
fi 