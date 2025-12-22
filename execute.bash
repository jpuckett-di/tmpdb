#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to display usage information
show_usage() {
    echo "Usage: $0 [-n] <sql_file>"
    echo ""
    echo "Arguments:"
    echo "  sql_file    - Path to the SQL file to execute"
    echo ""
    echo "Options:"
    echo "  -n          - Dry run: Show the SQL content without executing"
    echo "  -h, --help  - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 queries/my_query.sql"
    echo "  $0 -n schema.sql"
    echo "  $0 /path/to/script.sql"
    echo ""
    echo "Note: The script can be run from any directory."
    exit 1
}

# Parse command line options
DRY_RUN=false

# Handle long options first
ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_usage
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
set -- "${ARGS[@]}"

# Parse short options
while getopts "nh" opt; do
    case $opt in
        n) DRY_RUN=true ;;
        h) show_usage ;;
        *) show_usage ;;
    esac
done

# Shift the options so that $1 refers to the first non-option argument
shift $((OPTIND-1))

# Function to check if a SQL file was provided as the first argument
check_sql_file() {
    # Check if an argument was provided
    if [ $# -eq 0 ]; then
        echo "Error: No SQL file provided" >&2
        show_usage
    fi

    # Check if too many arguments were provided
    if [ $# -gt 1 ]; then
        echo "Error: Too many arguments provided" >&2
        show_usage
    fi

    # Check if the file exists
    if [ ! -f "$1" ]; then
        echo "Error: File '$1' not found" >&2
        exit 1
    fi

    # Check if the file has a .sql extension
    if [[ "$1" != *.sql ]]; then
        echo "Error: File '$1' is not a SQL file" >&2
        echo "Please provide a file with .sql extension" >&2
        exit 1
    fi

    # Check if the file is readable
    if [ ! -r "$1" ]; then
        echo "Error: Cannot read file '$1'" >&2
        exit 1
    fi

    echo "SQL file check passed: $1"
}

# Function to execute SQL file against the database
execute_sql_file() {
    local sql_file="$1"
    local db_service="db"  # Default service name in docker-compose.yml

    echo "Executing SQL file: $sql_file"

    # Check if docker compose is available
    if ! command -v docker &> /dev/null; then
        echo "Error: docker command not found" >&2
        echo "Please install Docker to use the database execution feature" >&2
        exit 1
    fi

    # Check if docker-compose.yml exists in script directory
    if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        echo "Error: docker-compose.yml not found in $SCRIPT_DIR" >&2
        echo "Make sure you're running this script from the project directory or using the correct path" >&2
        exit 1
    fi

    # Get the absolute path of the SQL file
    local abs_sql_path=$(realpath "$sql_file")
    local container_sql_path="/tmp/$(basename "$sql_file")"

    # If dry run, just show the SQL content
    if [ "$DRY_RUN" = true ]; then
        echo "Dry run - SQL file content:"
        echo "----------------------------------------"
        cat "$sql_file"
        echo "----------------------------------------"
        echo "Dry run completed. SQL was not executed."
        return 0
    fi

    # Copy the SQL file to the container
    echo "Copying SQL file to container..."
    if ! docker compose -f "$SCRIPT_DIR/docker-compose.yml" cp "$abs_sql_path" "$db_service:$container_sql_path"; then
        echo "Error: Failed to copy SQL file to container" >&2
        exit 1
    fi

    # Execute the SQL file
    echo "Executing SQL commands..."
    if ! docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T $db_service bash -c "mysql -u root -p\${MYSQL_ROOT_PASSWORD:-password} -D db < '$container_sql_path'"; then
        echo "Error: Failed to execute SQL file" >&2
        # Clean up the container file
        docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T $db_service rm -f "$container_sql_path" 2>/dev/null || true
        exit 1
    fi

    # Clean up the container file
    echo "Cleaning up..."
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T $db_service rm -f "$container_sql_path" 2>/dev/null || true

    echo "SQL execution completed successfully!"
}

# Main execution
check_sql_file "$@"
execute_sql_file "$1"
