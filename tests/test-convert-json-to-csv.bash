#!/bin/bash

# Unit tests for convert-json-to-csv.bash
# Tests handling of objects with varying properties and structures

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Create a temporary directory for test files
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Path to the script being tested
SCRIPT_PATH="$PROJECT_ROOT/convert-json-to-csv.bash"

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
    local expected_output_file="$4"

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

    # If expected output file is provided, compare the output
    if [ -n "$expected_output_file" ] && [ -f "$expected_output_file" ]; then
        if ! diff -q <(echo "$output") "$expected_output_file" >/dev/null; then
            echo -e "${RED}FAILED${NC}"
            echo "  Output doesn't match expected result"
            echo "  Command: $command"
            echo "  Actual output:"
            echo "$output"
            echo "  Expected output:"
            cat "$expected_output_file"
            echo "  Differences:"
            diff <(echo "$output") "$expected_output_file"
            ((TESTS_FAILED++))
            return 1
        fi
    fi

    echo -e "${GREEN}PASSED${NC}"
    ((TESTS_PASSED++))
    return 0
}

# Function to create test files
create_test_files() {
    # Test 1: Objects with properties in different orders
    echo '[
        {"name": "John", "age": 30, "city": "NYC"},
        {"city": "LA", "name": "Jane", "age": 25},
        {"age": 35, "city": "Chicago", "name": "Bob"}
    ]' > "$TEST_DIR/different_order.json"
    
    echo '"age","city","name"
"30","NYC","John"
"25","LA","Jane"
"35","Chicago","Bob"' > "$TEST_DIR/different_order_expected.txt"

    # Test 2: Objects with missing properties
    echo '[
        {"name": "Alice", "age": 28, "department": "HR"},
        {"name": "Bob", "city": "Boston"},
        {"age": 30, "city": "Denver", "name": "Carol", "country": "USA"}
    ]' > "$TEST_DIR/missing_properties.json"
    
    echo '"age","city","country","department","name"
"28","","","HR","Alice"
"","Boston","","","Bob"
"30","Denver","USA","","Carol"' > "$TEST_DIR/missing_properties_expected.txt"

    # Test 3: Objects with completely different property sets
    echo '[
        {"id": 1, "product": "Laptop", "price": 999},
        {"name": "John", "role": "Manager"},
        {"category": "Electronics", "stock": 50, "supplier": "TechCorp"}
    ]' > "$TEST_DIR/different_properties.json"
    
    echo '"category","id","name","price","product","role","stock","supplier"
"","1","","999","Laptop","","",""
"","","John","","","Manager","",""
"Electronics","","","","","","50","TechCorp"' > "$TEST_DIR/different_properties_expected.txt"

    # Test 4: Single object with sorted keys
    echo '{
        "zebra": "animal",
        "apple": "fruit",
        "car": "vehicle",
        "book": "object"
    }' > "$TEST_DIR/single_object.json"
    
    echo '"apple","book","car","zebra"
"fruit","object","vehicle","animal"' > "$TEST_DIR/single_object_expected.txt"

    # Test 5: Empty properties and null values
    echo '[
        {"name": "Test1", "value": null, "active": true},
        {"name": "Test2", "description": "", "active": false},
        {"name": "Test3", "value": 42}
    ]' > "$TEST_DIR/null_empty_values.json"
    
    echo '"active","description","name","value"
"true","","Test1",""
"false","","Test2",""
"","","Test3","42"' > "$TEST_DIR/null_empty_values_expected.txt"

    # Test 6: Nested object handling (should flatten or handle gracefully)
    echo '[
        {"name": "User1", "profile": {"age": 30, "city": "NYC"}},
        {"name": "User2", "email": "user2@example.com"}
    ]' > "$TEST_DIR/nested_objects.json"
    
    # For nested objects, we expect them to be stringified with proper CSV quote escaping
    echo '"email","name","profile"
"","User1","{""age"":30,""city"":""NYC""}"
"user2@example.com","User2",""' > "$TEST_DIR/nested_objects_expected.txt"

    # Test 7: Array values handling
    echo '[
        {"name": "Item1", "tags": ["red", "small"]},
        {"name": "Item2", "category": "tools", "tags": ["blue"]},
        {"name": "Item3", "category": "books"}
    ]' > "$TEST_DIR/array_values.json"
    
    echo '"category","name","tags"
"","Item1","[""red"",""small""]"
"tools","Item2","[""blue""]"
"books","Item3",""' > "$TEST_DIR/array_values_expected.txt"

    # Test 8: Numbers and booleans
    echo '[
        {"id": 1, "active": true, "score": 95.5},
        {"id": 2, "active": false, "name": "Test"},
        {"score": 87.2, "name": "Another", "id": 3}
    ]' > "$TEST_DIR/mixed_types.json"
    
    echo '"active","id","name","score"
"true","1","","95.5"
"false","2","Test",""
"","3","Another","87.2"' > "$TEST_DIR/mixed_types_expected.txt"

    # Test 9: Unicode and special characters
    echo '[
        {"name": "José", "city": "São Paulo", "emoji": "😀"},
        {"name": "François", "country": "France"},
        {"city": "München", "name": "Hans", "specialty": "Bäcker"}
    ]' > "$TEST_DIR/unicode.json"
    
    echo '"city","country","emoji","name","specialty"
"São Paulo","","😀","José",""
"","France","","François",""
"München","","","Hans","Bäcker"' > "$TEST_DIR/unicode_expected.txt"

    # Test 10: Large number of varying properties
    echo '[
        {"a": 1, "b": 2, "c": 3},
        {"d": 4, "e": 5, "f": 6},
        {"g": 7, "h": 8, "i": 9},
        {"a": 10, "d": 11, "g": 12}
    ]' > "$TEST_DIR/many_properties.json"
    
    echo '"a","b","c","d","e","f","g","h","i"
"1","2","3","","","","","",""
"","","","4","5","6","","",""
"","","","","","","7","8","9"
"10","","","11","","","12","",""' > "$TEST_DIR/many_properties_expected.txt"
}

# Function to run all tests
run_tests() {
    echo "Testing objects with properties in different orders..."
    run_test "Different property order" "$SCRIPT_PATH $TEST_DIR/different_order.json" 0 "$TEST_DIR/different_order_expected.txt"

    echo "Testing objects with missing properties..."
    run_test "Missing properties" "$SCRIPT_PATH $TEST_DIR/missing_properties.json" 0 "$TEST_DIR/missing_properties_expected.txt"

    echo "Testing objects with completely different properties..."
    run_test "Different property sets" "$SCRIPT_PATH $TEST_DIR/different_properties.json" 0 "$TEST_DIR/different_properties_expected.txt"

    echo "Testing single object with key sorting..."
    run_test "Single object key sorting" "$SCRIPT_PATH $TEST_DIR/single_object.json" 0 "$TEST_DIR/single_object_expected.txt"

    echo "Testing null and empty values..."
    run_test "Null and empty values" "$SCRIPT_PATH $TEST_DIR/null_empty_values.json" 0 "$TEST_DIR/null_empty_values_expected.txt"

    echo "Testing nested objects..."
    run_test "Nested objects" "$SCRIPT_PATH $TEST_DIR/nested_objects.json" 0 "$TEST_DIR/nested_objects_expected.txt"

    echo "Testing array values..."
    run_test "Array values" "$SCRIPT_PATH $TEST_DIR/array_values.json" 0 "$TEST_DIR/array_values_expected.txt"

    echo "Testing mixed data types..."
    run_test "Mixed data types" "$SCRIPT_PATH $TEST_DIR/mixed_types.json" 0 "$TEST_DIR/mixed_types_expected.txt"

    echo "Testing unicode and special characters..."
    run_test "Unicode characters" "$SCRIPT_PATH $TEST_DIR/unicode.json" 0 "$TEST_DIR/unicode_expected.txt"

    echo "Testing many varying properties..."
    run_test "Many varying properties" "$SCRIPT_PATH $TEST_DIR/many_properties.json" 0 "$TEST_DIR/many_properties_expected.txt"

    # Test with JSON path extraction
    echo "Testing JSON path with varying properties..."
    echo '{
        "users": [
            {"name": "Alice", "age": 30, "department": "HR"},
            {"name": "Bob", "city": "Boston", "age": 25},
            {"department": "IT", "name": "Carol", "country": "USA"}
        ]
    }' > "$TEST_DIR/path_extraction.json"
    
    echo '"age","city","country","department","name"
"30","","","HR","Alice"
"25","Boston","","","Bob"
"","","USA","IT","Carol"' > "$TEST_DIR/path_extraction_expected.txt"
    
    run_test "JSON path with varying properties" "$SCRIPT_PATH -p '.users' $TEST_DIR/path_extraction.json" 0 "$TEST_DIR/path_extraction_expected.txt"

    # Error cases
    echo "Testing error cases..."
    run_test "Empty array" "$SCRIPT_PATH -p '.[]' <(echo '[]')" 1 ""
    run_test "Non-object array" "$SCRIPT_PATH <(echo '[1, 2, 3]')" 1 ""
    run_test "Invalid JSON" "$SCRIPT_PATH <(echo 'invalid json')" 1 ""
}

# Main execution
echo "Starting comprehensive tests for convert-json-to-csv.bash"
echo "Testing handling of objects with varying properties..."
echo "============================================================"

create_test_files
run_tests

# Summary
echo "============================================================"
echo "Tests completed: $((TESTS_PASSED + TESTS_FAILED))"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

# Exit with failure if any tests failed
[ $TESTS_FAILED -eq 0 ] || exit 1