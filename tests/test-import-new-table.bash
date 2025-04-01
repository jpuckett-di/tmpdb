#!/bin/bash

# Unit test for import.bash
# This script tests the CSV file checking and column reading functionality

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Create a temporary directory for test files
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Path to the script being tested (using absolute path)
SCRIPT_PATH="$PROJECT_ROOT/import.bash"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_exit_code="$3"
    local expected_output_pattern="$4"

    echo -n "Running test: $test_name... "

    # Run the command and capture output and exit code
    output=$(eval "$command" 2>&1)
    exit_code=$?

    # Check exit code
    if [ "$exit_code" -ne "$expected_exit_code" ]; then
        echo -e "${RED}FAILED${NC}"
        echo "  Expected exit code $expected_exit_code, got $exit_code"
        echo "  Command: $command"
        echo "  Output: $output"
        ((TESTS_FAILED++))
        return 1
    fi

    # Check output pattern if provided
    if [ -n "$expected_output_pattern" ]; then
        if ! echo "$output" | grep -q "$expected_output_pattern"; then
            echo -e "${RED}FAILED${NC}"
            echo "  Output doesn't match expected pattern: $expected_output_pattern"
            echo "  Command: $command"
            echo "  Output: $output"
            ((TESTS_FAILED++))
            return 1
        fi
    fi

    echo -e "${GREEN}PASSED${NC}"
    ((TESTS_PASSED++))
    return 0
}

# Create test files
create_test_files() {
    # Valid CSV file
    echo "name,age,city,country" > "$TEST_DIR/valid.csv"
    echo "John Doe,30,New York,USA" >> "$TEST_DIR/valid.csv"
    echo "Jane Smith,25,London,UK" >> "$TEST_DIR/valid.csv"

    # Empty CSV file
    touch "$TEST_DIR/empty.csv"

    # Non-CSV file
    echo "This is not a CSV file" > "$TEST_DIR/not_csv.txt"

    # Unreadable CSV file
    echo "header1,header2" > "$TEST_DIR/unreadable.csv"
    chmod -r "$TEST_DIR/unreadable.csv"

    # CSV file with special characters in column names
    echo "first name,last-name,email@address,123numeric" > "$TEST_DIR/special_chars.csv"
    echo "John,Doe,john@example.com,12345" >> "$TEST_DIR/special_chars.csv"

    # CSV file with a numeric filename
    echo "col1,col2" > "$TEST_DIR/123data.csv"
    echo "value1,value2" >> "$TEST_DIR/123data.csv"

    # CSV file with special characters in filename
    echo "col1,col2" > "$TEST_DIR/special-file_name.csv"
    echo "value1,value2" >> "$TEST_DIR/special-file_name.csv"

    # CSV file with empty column name
    echo "valid_name,,another_name" > "$TEST_DIR/empty_column.csv"
    echo "value1,value2,value3" >> "$TEST_DIR/empty_column.csv"

    # Create test input files for interactive mode
    # For custom table name (need responses for all columns too)
    echo "custom_table" > "$TEST_DIR/input_custom_table.txt"
    # Add default responses for all columns (4 columns in valid.csv)
    echo "" >> "$TEST_DIR/input_custom_table.txt"  # default type for name
    echo "4" >> "$TEST_DIR/input_custom_table.txt"  # no constraints
    echo "" >> "$TEST_DIR/input_custom_table.txt"  # default type for age
    echo "4" >> "$TEST_DIR/input_custom_table.txt"  # no constraints
    echo "" >> "$TEST_DIR/input_custom_table.txt"  # default type for city
    echo "4" >> "$TEST_DIR/input_custom_table.txt"  # no constraints
    echo "" >> "$TEST_DIR/input_custom_table.txt"  # default type for country
    echo "4" >> "$TEST_DIR/input_custom_table.txt"  # no constraints

    # For custom column type
    echo "" > "$TEST_DIR/input_custom_type.txt"  # default table name
    echo "INT" >> "$TEST_DIR/input_custom_type.txt"  # INT type for first column
    echo "4" >> "$TEST_DIR/input_custom_type.txt"  # no constraints
    echo "" >> "$TEST_DIR/input_custom_type.txt"  # default type for age
    echo "4" >> "$TEST_DIR/input_custom_type.txt"  # no constraints
    echo "" >> "$TEST_DIR/input_custom_type.txt"  # default type for city
    echo "4" >> "$TEST_DIR/input_custom_type.txt"  # no constraints
    echo "" >> "$TEST_DIR/input_custom_type.txt"  # default type for country
    echo "4" >> "$TEST_DIR/input_custom_type.txt"  # no constraints

    # For NOT NULL constraint
    echo "" > "$TEST_DIR/input_not_null.txt"  # default table name
    echo "" >> "$TEST_DIR/input_not_null.txt"  # default type for first column
    echo "1" >> "$TEST_DIR/input_not_null.txt"  # NOT NULL constraint
    echo "n" >> "$TEST_DIR/input_not_null.txt"  # no more constraints
    echo "" >> "$TEST_DIR/input_not_null.txt"  # default type for age
    echo "4" >> "$TEST_DIR/input_not_null.txt"  # no constraints
    echo "" >> "$TEST_DIR/input_not_null.txt"  # default type for city
    echo "4" >> "$TEST_DIR/input_not_null.txt"  # no constraints
    echo "" >> "$TEST_DIR/input_not_null.txt"  # default type for country
    echo "4" >> "$TEST_DIR/input_not_null.txt"  # no constraints

    # Input file for accepting all defaults
    echo "d" > "$TEST_DIR/input_defaults.txt"

    # Input file for custom table and then defaults
    echo "my_custom_table" > "$TEST_DIR/input_table_then_defaults.txt"
    echo "d" >> "$TEST_DIR/input_table_then_defaults.txt"

    # Input file for custom column type and then defaults
    echo "" > "$TEST_DIR/input_type_then_defaults.txt"  # Use default table name
    echo "INT" >> "$TEST_DIR/input_type_then_defaults.txt"  # Custom type for first column
    echo "d" >> "$TEST_DIR/input_type_then_defaults.txt"  # Defaults for rest

    # Create a test file for auto-increment ID option
    echo "name,age,city" > "$TEST_DIR/auto_id_test.csv"
    echo "John,30,New York" >> "$TEST_DIR/auto_id_test.csv"
    echo "Jane,25,London" >> "$TEST_DIR/auto_id_test.csv"

    # CSV file with MySQL reserved keywords as column names
    echo "select,from,where,order" > "$TEST_DIR/reserved_keywords.csv"
    echo "value1,value2,value3,value4" >> "$TEST_DIR/reserved_keywords.csv"

    # Create input file for reserved keywords test with custom column name
    echo "reserved_keywords" > "$TEST_DIR/input_reserved_keywords_custom.txt"
    echo "my_select_column" >> "$TEST_DIR/input_reserved_keywords_custom.txt"  # Custom name for the reserved keyword column
    echo "d" >> "$TEST_DIR/input_reserved_keywords_custom.txt"  # Use defaults for remaining questions
}

# Run tests
run_tests() {
    # Test 1: No arguments provided
    run_test "No arguments" "$SCRIPT_PATH" 1 "No CSV file provided"

    # Test 2: Non-existent file
    run_test "Non-existent file" "$SCRIPT_PATH -n $TEST_DIR/nonexistent.csv" 1 "not found"

    # Test 3: Non-CSV file
    run_test "Non-CSV file" "$SCRIPT_PATH -n $TEST_DIR/not_csv.txt" 1 "not a CSV file"

    # Test 4: Unreadable file
    run_test "Unreadable file" "$SCRIPT_PATH -n $TEST_DIR/unreadable.csv" 1 "Cannot read file"

    # Test 5: Empty CSV file
    run_test "Empty CSV file" "$SCRIPT_PATH -cn $TEST_DIR/empty.csv" 0 "Total columns: 0"

    # Test 6: Valid CSV file
    run_test "Valid CSV file" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "Columns detected:"

    # Test 7: Check column detection
    run_test "Column detection" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "0: name"

    # Test 8: Check total columns
    run_test "Total columns" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "Total columns: 4"

    # Test 9: SQL generation with valid column names
    run_test "SQL generation - valid columns" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "CREATE TABLE valid"

    # Test 10: Check SQL output is displayed
    run_test "SQL output display" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "CREATE TABLE valid"

    # Test 11: SQL generation with special characters in column names
    run_test "SQL generation - special chars in columns" "$SCRIPT_PATH -cn $TEST_DIR/special_chars.csv" 0 "first_name VARCHAR(255)"

    # Test 12: SQL generation with numeric filename (should prepend t_)
    run_test "SQL generation - numeric filename" "$SCRIPT_PATH -cn $TEST_DIR/123data.csv" 0 "CREATE TABLE t_123data"

    # Test 13: SQL generation with special characters in filename
    run_test "SQL generation - special chars in filename" "$SCRIPT_PATH -cn $TEST_DIR/special-file_name.csv" 0 "CREATE TABLE special_file_name"

    # Test 14: SQL generation with empty column name
    run_test "SQL generation - empty column name" "$SCRIPT_PATH -cn $TEST_DIR/empty_column.csv" 0 "c_1_"

    # Test 15: Verify all columns are included with VARCHAR(255) type
    run_test "SQL generation - all columns included" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "name VARCHAR(255)"
    run_test "SQL generation - age column included" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "age VARCHAR(255)"
    run_test "SQL generation - city column included" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "city VARCHAR(255)"
    run_test "SQL generation - country column included" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "country VARCHAR(255)"

    # Test 16: Interactive mode with custom table name
    run_test "Interactive - custom table name" "cat $TEST_DIR/input_custom_table.txt | $SCRIPT_PATH -i -n $TEST_DIR/valid.csv" 0 "CREATE TABLE custom_table"

    # Test 17: Interactive mode with custom column type
    run_test "Interactive - custom column type" "cat $TEST_DIR/input_custom_type.txt | $SCRIPT_PATH -i -n $TEST_DIR/valid.csv" 0 "name INT"

    # Test 18: Interactive mode with NOT NULL constraint
    run_test "Interactive - NOT NULL constraint" "cat $TEST_DIR/input_not_null.txt | $SCRIPT_PATH -i -n $TEST_DIR/valid.csv" 0 "NOT NULL"

    # Test 19: Interactive mode with all defaults
    run_test "Interactive - all defaults" "cat $TEST_DIR/input_defaults.txt | $SCRIPT_PATH -i -n $TEST_DIR/valid.csv" 0 "Using defaults for all remaining questions"

    # Test 20: Interactive mode with custom table then defaults
    run_test "Interactive - custom table then defaults" "cat $TEST_DIR/input_table_then_defaults.txt | $SCRIPT_PATH -i -n $TEST_DIR/valid.csv" 0 "CREATE TABLE my_custom_table"

    # Test 21: Interactive mode with custom type then defaults
    run_test "Interactive - custom type then defaults" "cat $TEST_DIR/input_type_then_defaults.txt | $SCRIPT_PATH -i -n $TEST_DIR/valid.csv" 0 "name INT"

    # Test 22: Verify pre-population message appears when using defaults
    run_test "Interactive - pre-population message" "cat $TEST_DIR/input_defaults.txt | $SCRIPT_PATH -i -n $TEST_DIR/valid.csv" 0 "Pre-populating remaining columns with defaults"

    # Test 23: Check command runs successfully in interactive mode
    run_test "Interactive - command success" "cat $TEST_DIR/input_defaults.txt | $SCRIPT_PATH -i -n $TEST_DIR/valid.csv" 0 ""

    # Test for auto-increment ID option
    run_test "Auto-increment ID option" "$SCRIPT_PATH -a -n $TEST_DIR/auto_id_test.csv" 0 "id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY"

    # Test for auto-increment ID with proper comma placement
    run_test "Auto-increment ID comma placement" "$SCRIPT_PATH -a -n $TEST_DIR/auto_id_test.csv" 0 "PRIMARY KEY,"

    # Test for auto-increment ID with DROP TABLE statement
    run_test "Auto-increment ID with DROP TABLE" "$SCRIPT_PATH -a -n $TEST_DIR/auto_id_test.csv" 0 "DROP TABLE IF EXISTS auto_id_test"

    # Test for auto-increment ID with interactive mode
    run_test "Auto-increment ID with interactive" "echo 'd' | $SCRIPT_PATH -a -i -n $TEST_DIR/auto_id_test.csv" 0 "id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY"

    # Test for dry run message
    run_test "Dry run message" "$SCRIPT_PATH -cn $TEST_DIR/valid.csv" 0 "Dry run specified - no data imported"

    # Test for create table option
    run_test "Create table option" "$SCRIPT_PATH -c -n $TEST_DIR/valid.csv" 0 "CREATE TABLE valid"

    # Test for TEXT option
    run_test "TEXT option" "$SCRIPT_PATH -cT -n $TEST_DIR/valid.csv" 0 "name TEXT"

    # Test for reserved keyword handling in non-interactive mode
    run_test "Reserved keyword handling" "$SCRIPT_PATH -cn $TEST_DIR/reserved_keywords.csv" 0 "WARNING: 'select' is a MySQL reserved keyword"

    # Test for proper renaming of reserved keywords
    run_test "Reserved keyword renaming" "$SCRIPT_PATH -cn $TEST_DIR/reserved_keywords.csv" 0 "col_select VARCHAR(255)"

    # Test for multiple reserved keywords in the same file
    run_test "Multiple reserved keywords" "$SCRIPT_PATH -cn $TEST_DIR/reserved_keywords.csv" 0 "col_from VARCHAR(255)"
    run_test "Multiple reserved keywords" "$SCRIPT_PATH -cn $TEST_DIR/reserved_keywords.csv" 0 "col_where VARCHAR(255)"
    run_test "Multiple reserved keywords" "$SCRIPT_PATH -cn $TEST_DIR/reserved_keywords.csv" 0 "col_order VARCHAR(255)"

    # Test for interactive mode with reserved keywords and custom column name
    run_test "Interactive - custom reserved keyword name" "cat $TEST_DIR/input_reserved_keywords_custom.txt | $SCRIPT_PATH -i -n $TEST_DIR/reserved_keywords.csv" 0 "my_select_column VARCHAR(255)"
}

# Main execution
echo "Starting unit tests for import.bash"
create_test_files
run_tests

# Summary
echo "Tests completed: $((TESTS_PASSED + TESTS_FAILED))"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

# Exit with failure if any tests failed
[ $TESTS_FAILED -eq 0 ] || exit 1
