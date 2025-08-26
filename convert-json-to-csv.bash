#!/bin/bash

set -e

# Script to convert JSON file to CSV format
# Usage: ./convert-json-to-csv.bash [OPTIONS] input.json [output.csv]

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] input.json [output.csv]"
    echo ""
    echo "  input.json    - Path to the input JSON file"
    echo "  output.csv    - Optional path to output CSV file (defaults to stdout)"
    echo ""
    echo "Options:"
    echo "  -p, --path PATH   - JSON path to extract before conversion (jq syntax)"
    echo "  -h, --help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 data.json"
    echo "  $0 data.json output.csv"
    echo "  $0 -p '.data.users' nested.json"
    echo "  $0 --path '.results[]' api-response.json output.csv"
    echo "  $0 data.json > output.csv"
    echo ""
    echo "JSON Path Examples:"
    echo "  .data.users       - Extract users array from data object"
    echo "  .results[]        - Extract each item from results array"
    echo "  .response.items   - Extract items from response object"
    exit 1
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    echo "On Ubuntu/Debian: sudo apt-get install jq"
    echo "On CentOS/RHEL: sudo yum install jq"
    echo "On macOS: brew install jq"
    exit 1
fi

# Initialize variables
JSON_PATH=""
INPUT_FILE=""
OUTPUT_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--path)
            JSON_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        -*)
            echo "Error: Unknown option $1"
            show_usage
            ;;
        *)
            if [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
            elif [ -z "$OUTPUT_FILE" ]; then
                OUTPUT_FILE="$1"
            else
                echo "Error: Too many arguments"
                show_usage
            fi
            shift
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$INPUT_FILE" ]; then
    echo "Error: Input file is required"
    show_usage
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' does not exist."
    exit 1
fi

# Check if input file is readable
if [ ! -r "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' is not readable."
    exit 1
fi

# Function to convert JSON to CSV
convert_json_to_csv() {
    local input_file="$1"
    local output_file="$2"
    local json_path="$3"

    # Create jq filter based on whether a path is specified
    local jq_filter=""
    if [ -n "$json_path" ]; then
        jq_filter="$json_path"
    else
        jq_filter="."
    fi

    # Extract the relevant JSON data using the specified path
    local extracted_json
    extracted_json=$(jq "$jq_filter" "$input_file" 2>/dev/null)
    local jq_exit_code=$?

    if [ $jq_exit_code -ne 0 ]; then
        echo "Error: Invalid JSON path '$json_path' or malformed JSON in input file."
        exit 1
    fi

    # Check if the extracted result is null or empty
    if [ "$extracted_json" = "null" ] || [ -z "$extracted_json" ]; then
        echo "Error: JSON path '$json_path' returned null or empty result."
        exit 1
    fi

    # Determine the structure of the extracted JSON
    local json_type=$(echo "$extracted_json" | jq -r 'type')

    if [ "$json_type" = "array" ]; then
        # Handle array of objects
        local first_object=$(echo "$extracted_json" | jq -r '.[0] // empty')
        if [ -z "$first_object" ] || [ "$first_object" = "null" ]; then
            echo "Error: JSON array is empty or contains no valid objects."
            exit 1
        fi

        # Check if array contains objects
        local first_type=$(echo "$extracted_json" | jq -r '.[0] | type')
        if [ "$first_type" != "object" ]; then
            echo "Error: Array must contain objects to convert to CSV."
            exit 1
        fi

        # Extract headers from the first object
        local headers=$(echo "$extracted_json" | jq -r '.[0] | keys_unsorted | @csv')

        # Convert to CSV
        if [ -n "$output_file" ]; then
            {
                echo "$headers"
                echo "$extracted_json" | jq -r '.[] | [.[] | tostring] | @csv'
            } > "$output_file"
        else
            echo "$headers"
            echo "$extracted_json" | jq -r '.[] | [.[] | tostring] | @csv'
        fi

    elif [ "$json_type" = "object" ]; then
        # Handle single object - convert to single row CSV
        local headers=$(echo "$extracted_json" | jq -r 'keys_unsorted | @csv')
        local values=$(echo "$extracted_json" | jq -r '[.[] | tostring] | @csv')

        if [ -n "$output_file" ]; then
            {
                echo "$headers"
                echo "$values"
            } > "$output_file"
        else
            echo "$headers"
            echo "$values"
        fi

    else
        echo "Error: Extracted JSON must be either an object or an array of objects."
        echo "Found type: $json_type"
        exit 1
    fi
}

# Main execution
convert_json_to_csv "$INPUT_FILE" "$OUTPUT_FILE" "$JSON_PATH"

# Success message if output file was specified
if [ -n "$OUTPUT_FILE" ]; then
    echo "Successfully converted '$INPUT_FILE' to '$OUTPUT_FILE'"
    if [ -n "$JSON_PATH" ]; then
        echo "Using JSON path: $JSON_PATH"
    fi
fi
