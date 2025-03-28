#!/bin/bash

set -e

# Function to display usage information
show_usage() {
    echo "Usage: $0 [-i] [-d] [-r] <csv_file>"
    echo "Options:"
    echo "  -i    Interactive mode: Allows customizing column data types and constraints"
    echo "  -d    Database import: Import the data into the database after creating the table"
    echo "  -r    Recreate table: Drop the table first if it exists"
    exit 1
}

# Parse command line options
INTERACTIVE=false
DB_IMPORT=false
RECREATE=false
while getopts "idr" opt; do
    case $opt in
        i) INTERACTIVE=true ;;
        d) DB_IMPORT=true ;;
        r) RECREATE=true ;;
        *) show_usage ;;
    esac
done

# Shift the options so that $1 refers to the first non-option argument
shift $((OPTIND-1))

# Function to check if a CSV file was provided as the first argument
check_csv_file() {
    # Check if an argument was provided
    if [ $# -eq 0 ]; then
        echo "Error: No CSV file provided"
        show_usage
    fi

    # Check if the file exists
    if [ ! -f "$1" ]; then
        echo "Error: File '$1' not found"
        exit 1
    fi

    # Check if the file has a .csv extension
    if [[ "$1" != *.csv ]]; then
        echo "Error: File '$1' is not a CSV file"
        echo "Please provide a file with .csv extension"
        exit 1
    fi

    # Check if the file is readable
    if [ ! -r "$1" ]; then
        echo "Error: Cannot read file '$1'"
        exit 1
    fi

    echo "CSV file check passed: $1"
}

# Call the function with all script arguments
check_csv_file "$@"

# Function to read and display the columns of the CSV file
read_csv_columns() {
    local csv_file="$1"

    # Read the header line to get column names
    header=$(head -n 1 "$csv_file")

    # Display column information
    echo "Columns detected:"

    # Convert the header line to an array of column names
    IFS=',' read -ra columns <<< "$header"

    # Display each column with its index
    for i in "${!columns[@]}"; do
        echo "  $i: ${columns[$i]}"
    done

    # Return the number of columns
    echo "Total columns: ${#columns[@]}"

    # Store columns array for later use
    CSV_COLUMNS=("${columns[@]}")
}

# Read the columns from the CSV file
read_csv_columns "$1"

# Function to interactively define column properties
define_column_properties() {
    # Arrays to store column properties
    COLUMN_TYPES=()
    COLUMN_CONSTRAINTS=()

    echo "Interactive mode: Define table properties"
    echo "At any prompt, enter 'd' to accept defaults for all remaining questions"
    echo ""

    # Get the raw table name from the CSV filename
    local csv_file="$1"
    local raw_table_name=$(basename "$csv_file" .csv)

    # Sanitize table name (replace spaces and hyphens with underscores and remove other special characters)
    local default_table_name=$(echo "$raw_table_name" | tr ' -' '_' | tr -cd '[:alnum:]_')

    # If table name doesn't start with a letter or underscore, prepend 't_'
    if [[ ! $default_table_name =~ ^[a-zA-Z_] ]]; then
        default_table_name="t_$default_table_name"
    fi

    # Prompt for table name
    read -p "Table name [$default_table_name]: " CUSTOM_TABLE_NAME
    CUSTOM_TABLE_NAME=${CUSTOM_TABLE_NAME:-$default_table_name}

    # Check if user wants to use defaults for everything
    if [[ "$CUSTOM_TABLE_NAME" == "d" ]]; then
        CUSTOM_TABLE_NAME=$default_table_name
        USE_DEFAULTS=true
        echo "Using defaults for all remaining questions."
    else
        USE_DEFAULTS=false
    fi

    echo ""
    echo "Define column properties"
    echo "For each column, you'll specify the data type and constraints"
    echo "Available data types: TEXT, VARCHAR(n), INT, FLOAT, DATE, DATETIME, etc."
    echo "Available constraints: NOT NULL, UNIQUE, PRIMARY KEY"
    echo ""

    for i in "${!CSV_COLUMNS[@]}"; do
        # Clean column name
        local column_name=$(echo "${CSV_COLUMNS[$i]}" | tr ' ' '_' | tr -cd '[:alnum:]_')

        # If column name is empty or doesn't start with a letter or underscore, prepend 'c_'
        if [[ -z $column_name || ! $column_name =~ ^[a-zA-Z_] ]]; then
            column_name="c_${i}_$column_name"
        fi

        echo "Column $i: $column_name"

        # Default data type
        local default_type="TEXT"

        if [ "$USE_DEFAULTS" = true ]; then
            # Use defaults
            COLUMN_TYPES[$i]=$default_type
            COLUMN_CONSTRAINTS[$i]=""
            echo "  Using default: $default_type"
        else
            # Ask for data type
            read -p "  Data type [$default_type]: " data_type

            # Check if user wants to use defaults for everything from here
            if [[ "$data_type" == "d" ]]; then
                USE_DEFAULTS=true
                data_type=$default_type
                COLUMN_TYPES[$i]=$data_type
                COLUMN_CONSTRAINTS[$i]=""
                echo "  Using defaults for all remaining questions."
                echo "  Using default: $default_type"
            else
                data_type=${data_type:-$default_type}
                COLUMN_TYPES[$i]=$data_type

                # Ask for constraints
                local constraints=""
                local add_constraint="y"

                while [[ "$add_constraint" == "y" ]]; do
                    echo "  Current constraints: ${constraints:-None}"
                    echo "  Available constraints:"
                    echo "    1) NOT NULL"
                    echo "    2) UNIQUE"
                    echo "    3) PRIMARY KEY"
                    echo "    4) None/Done"
                    echo "    d) Use defaults for all remaining questions"

                    read -p "  Add constraint [4]: " constraint_choice
                    constraint_choice=${constraint_choice:-4}

                    if [[ "$constraint_choice" == "d" ]]; then
                        USE_DEFAULTS=true
                        add_constraint="n"
                        echo "  Using defaults for all remaining questions."
                    else
                        case $constraint_choice in
                            1)
                                if [[ "$constraints" != *"NOT NULL"* ]]; then
                                    [ -n "$constraints" ] && constraints="$constraints "
                                    constraints="${constraints}NOT NULL"
                                fi
                                ;;
                            2)
                                if [[ "$constraints" != *"UNIQUE"* ]]; then
                                    [ -n "$constraints" ] && constraints="$constraints "
                                    constraints="${constraints}UNIQUE"
                                fi
                                ;;
                            3)
                                if [[ "$constraints" != *"PRIMARY KEY"* ]]; then
                                    [ -n "$constraints" ] && constraints="$constraints "
                                    constraints="${constraints}PRIMARY KEY"
                                fi
                                ;;
                            4)
                                add_constraint="n"
                                ;;
                            *)
                                echo "  Invalid choice. Please try again."
                                ;;
                        esac

                        if [[ "$constraint_choice" != "4" && "$add_constraint" == "y" ]]; then
                            read -p "  Add another constraint? (y/n) [n]: " add_another

                            if [[ "$add_another" == "d" ]]; then
                                USE_DEFAULTS=true
                                add_constraint="n"
                                echo "  Using defaults for all remaining questions."
                            else
                                add_constraint=${add_another:-n}
                            fi
                        fi
                    fi
                done

                COLUMN_CONSTRAINTS[$i]=$constraints
            fi
        fi

        echo ""

        # If using defaults, pre-populate the remaining columns
        if [ "$USE_DEFAULTS" = true ] && [ $i -lt $((${#CSV_COLUMNS[@]} - 1)) ]; then
            echo "Pre-populating remaining columns with defaults..."
            for j in $(seq $((i + 1)) $((${#CSV_COLUMNS[@]} - 1))); do
                # Clean column name for display
                local next_col_name=$(echo "${CSV_COLUMNS[$j]}" | tr ' ' '_' | tr -cd '[:alnum:]_')
                if [[ -z $next_col_name || ! $next_col_name =~ ^[a-zA-Z_] ]]; then
                    next_col_name="c_${j}_$next_col_name"
                fi

                COLUMN_TYPES[$j]=$default_type
                COLUMN_CONSTRAINTS[$j]=""
                echo "Column $j: $next_col_name"
                echo "  Using default: $default_type"
                echo ""
            done
            break
        fi
    done
}

# Function to generate a CREATE TABLE SQL command
generate_create_table_sql() {
    local csv_file="$1"
    local raw_table_name=$(basename "$csv_file" .csv)
    local db_name="db"  # Hardcoded database name

    # Determine table name - use custom name if provided in interactive mode
    local table_name
    if [ "$INTERACTIVE" = true ] && [ -n "$CUSTOM_TABLE_NAME" ]; then
        table_name="$CUSTOM_TABLE_NAME"
    else
        # Sanitize table name (replace spaces and hyphens with underscores and remove other special characters)
        table_name=$(echo "$raw_table_name" | tr ' -' '_' | tr -cd '[:alnum:]_')

        # If table name doesn't start with a letter or underscore, prepend 't_'
        if [[ ! $table_name =~ ^[a-zA-Z_] ]]; then
            table_name="t_$table_name"
        fi
    fi

    echo "Generating CREATE TABLE SQL command for table: $table_name"

    # Start with USE statement
    local sql="USE $db_name;\n\n"

    # Add DROP TABLE statement if recreate option is enabled
    if [ "$RECREATE" = true ]; then
        sql="${sql}DROP TABLE IF EXISTS $table_name;\n\n"
        echo "Including DROP TABLE IF EXISTS statement"
    fi

    # Add the CREATE TABLE statement
    sql="${sql}CREATE TABLE $table_name (\n"

    # Add columns with their data types and constraints
    for i in "${!CSV_COLUMNS[@]}"; do
        # Clean column name (replace spaces with underscores and remove special characters)
        local column_name=$(echo "${CSV_COLUMNS[$i]}" | tr ' ' '_' | tr -cd '[:alnum:]_')

        # If column name is empty or doesn't start with a letter or underscore, prepend 'c_'
        if [[ -z $column_name || ! $column_name =~ ^[a-zA-Z_] ]]; then
            column_name="c_${i}_$column_name"
        fi

        # Add comma for all but the first column
        if [ $i -gt 0 ]; then
            sql="$sql,\n"
        fi

        # Add column definition with data type and constraints
        if [ "$INTERACTIVE" = true ] && [ ${#COLUMN_TYPES[@]} -gt 0 ]; then
            # Use interactively defined properties
            sql="$sql    $column_name ${COLUMN_TYPES[$i]}"
            if [ -n "${COLUMN_CONSTRAINTS[$i]}" ]; then
                sql="$sql ${COLUMN_CONSTRAINTS[$i]}"
            fi
        else
            # Use default properties
            sql="$sql    $column_name TEXT NULL"
        fi
    done

    # Close the CREATE TABLE statement
    sql="$sql\n);"

    # Print the SQL command
    echo -e "$sql"

    # Get the directory of the CSV file
    local csv_dir=$(dirname "$csv_file")
    # Save to a file in the same directory as the CSV
    echo -e "$sql" > "${csv_dir}/${raw_table_name}_create_table.sql"
    echo "SQL command saved to ${csv_dir}/${raw_table_name}_create_table.sql"
}

# If interactive mode is enabled, define column properties
if [ "$INTERACTIVE" = true ]; then
    define_column_properties "$1"
fi

# Generate the CREATE TABLE SQL command
generate_create_table_sql "$1"

# Function to import data into the database
import_data_to_db() {
    local csv_file="$1"
    local sql_file="$2"
    local table_name="$3"
    local db_service="db"  # Default service name in docker-compose.yml

    echo "Importing data to database..."

    # Check if docker compose is available
    if ! command -v docker &> /dev/null; then
        echo "Error: docker command not found"
        echo "Please install Docker to use the database import feature"
        return 1
    fi

    # Check if the db service is running
    if ! docker compose ps | grep -q "$db_service.*running"; then
        echo "Error: Database service '$db_service' is not running"
        echo "Please start the service with: docker compose up -d $db_service"
        return 1
    fi

    # Create the table using the SQL script
    echo "Creating table using SQL script: $sql_file"
    if ! docker compose exec -T $db_service mysql -u root -p"${MYSQL_ROOT_PASSWORD:-password}" -D db < "$sql_file"; then
        echo "Error: Failed to create table using SQL script"
        return 1
    fi

    # Get the absolute path of the CSV file
    local abs_csv_path=$(realpath "$csv_file")
    local container_csv_path="/tmp/$(basename "$csv_file")"

    # Copy the CSV file to the container
    echo "Copying CSV file to container..."
    docker compose cp "$abs_csv_path" "$db_service:$container_csv_path"

    # Create the LOAD DATA INFILE command with empty string to NULL conversion
    local load_data_cmd="LOAD DATA LOCAL INFILE '$container_csv_path'
INTO TABLE $table_name
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
("

    # Get the number of columns
    local num_columns=${#CSV_COLUMNS[@]}

    # Dynamically generate the column variables
    for i in $(seq 1 $num_columns); do
        # Add comma for all but the first column
        if [ $i -gt 1 ]; then
            load_data_cmd="${load_data_cmd}, "
        fi
        load_data_cmd="${load_data_cmd}@col$i"
    done

    load_data_cmd="${load_data_cmd})"

    # Add SET statements to convert empty strings to NULL
    load_data_cmd="${load_data_cmd}\nSET "

    for i in $(seq 1 $num_columns); do
        local col_name=$(echo "${CSV_COLUMNS[$((i-1))]}" | tr ' ' '_' | tr -cd '[:alnum:]_')

        # If column name is empty or doesn't start with a letter or underscore, prepend 'c_'
        if [[ -z $col_name || ! $col_name =~ ^[a-zA-Z_] ]]; then
            col_name="c_$((i-1))_$col_name"
        fi

        # Add comma for all but the first column
        if [ $i -gt 1 ]; then
            load_data_cmd="${load_data_cmd},"
        fi

        # Convert empty strings to NULL
        load_data_cmd="${load_data_cmd}\n    $col_name = NULLIF(@col$i, '')"
    done

    load_data_cmd="${load_data_cmd};"

    # Import the data
    echo "Importing data from CSV file..."
    if ! echo "$load_data_cmd" | docker compose exec -T $db_service mysql -u root -p"${MYSQL_ROOT_PASSWORD:-password}" -D db --local-infile=1; then
        echo "Error: Failed to import data from CSV file"
        return 1
    fi

    echo "Data import completed successfully!"
    return 0
}

# At the end of the script, after generating the SQL
if [ "$DB_IMPORT" = true ]; then
    # Get the directory of the CSV file and the raw table name
    csv_file="$1"
    raw_table_name=$(basename "$csv_file" .csv)

    # Determine table name - use custom name if provided in interactive mode
    if [ "$INTERACTIVE" = true ] && [ -n "$CUSTOM_TABLE_NAME" ]; then
        table_name="$CUSTOM_TABLE_NAME"
    else
        # Sanitize table name (replace spaces and hyphens with underscores and remove other special characters)
        table_name=$(echo "$raw_table_name" | tr ' -' '_' | tr -cd '[:alnum:]_')

        # If table name doesn't start with a letter or underscore, prepend 't_'
        if [[ ! $table_name =~ ^[a-zA-Z_] ]]; then
            table_name="t_$table_name"
        fi
    fi

    # Get the directory and SQL file path
    csv_dir=$(dirname "$csv_file")
    sql_file="${csv_dir}/${raw_table_name}_create_table.sql"

    # Import the data to the database
    import_data_to_db "$csv_file" "$sql_file" "$table_name"
fi

