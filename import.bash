#!/bin/bash

set -e

# Move MYSQL_RESERVED_KEYWORDS to the top level of the script, before any functions
# Define common MySQL reserved keywords at the top of the script, before any functions
MYSQL_RESERVED_KEYWORDS=("ADD" "ALL" "ALTER" "ANALYZE" "AND" "AS" "ASC" "ASENSITIVE"
"BEFORE" "BETWEEN" "BIGINT" "BINARY" "BLOB" "BOTH" "BY" "CALL" "CASCADE" "CASE" "CHANGE"
"CHAR" "CHARACTER" "CHECK" "COLLATE" "COLUMN" "CONDITION" "CONSTRAINT" "CONTINUE"
"CONVERT" "CREATE" "CROSS" "CURRENT_DATE" "CURRENT_TIME" "CURRENT_TIMESTAMP" "CURRENT_USER"
"CURSOR" "DATABASE" "DATABASES" "DAY_HOUR" "DAY_MICROSECOND" "DAY_MINUTE" "DAY_SECOND"
"DEC" "DECIMAL" "DECLARE" "DEFAULT" "DELAYED" "DELETE" "DESC" "DESCRIBE" "DETERMINISTIC"
"DISTINCT" "DISTINCTROW" "DIV" "DOUBLE" "DROP" "DUAL" "EACH" "ELSE" "ELSEIF" "ENCLOSED"
"ESCAPED" "EXISTS" "EXIT" "EXPLAIN" "FALSE" "FETCH" "FLOAT" "FLOAT4" "FLOAT8" "FOR"
"FORCE" "FOREIGN" "FROM" "FULLTEXT" "GRANT" "GROUP" "HAVING" "HIGH_PRIORITY" "HOUR_MICROSECOND"
"HOUR_MINUTE" "HOUR_SECOND" "IF" "IGNORE" "IN" "INDEX" "INFILE" "INNER" "INOUT" "INSENSITIVE"
"INSERT" "INT" "INT1" "INT2" "INT3" "INT4" "INT8" "INTEGER" "INTERVAL" "INTO" "IS" "ITERATE"
"JOIN" "KEY" "KEYS" "KILL" "LEADING" "LEAVE" "LEFT" "LIKE" "LIMIT" "LINES" "LOAD" "LOCALTIME"
"LOCALTIMESTAMP" "LOCK" "LONG" "LONGBLOB" "LONGTEXT" "LOOP" "LOW_PRIORITY" "MATCH" "MEDIUMBLOB"
"MEDIUMINT" "MEDIUMTEXT" "MIDDLEINT" "MINUTE_MICROSECOND" "MINUTE_SECOND" "MOD" "MODIFIES"
"NATURAL" "NOT" "NO_WRITE_TO_BINLOG" "NULL" "NUMERIC" "ON" "OPTIMIZE" "OPTION" "OPTIONALLY"
"OR" "ORDER" "OUT" "OUTER" "OUTFILE" "PRECISION" "PRIMARY" "PROCEDURE" "PURGE" "RANGE" "READ"
"READS" "READ_ONLY" "READ_WRITE" "REAL" "REFERENCES" "REGEXP" "RELEASE" "RENAME" "REPEAT"
"REPLACE" "REQUIRE" "RESTRICT" "RETURN" "REVOKE" "RIGHT" "RLIKE" "SCHEMA" "SCHEMAS" "SECOND_MICROSECOND"
"SELECT" "SENSITIVE" "SEPARATOR" "SET" "SHOW" "SMALLINT" "SONAME" "SPATIAL" "SPECIFIC" "SQL"
"SQLEXCEPTION" "SQLSTATE" "SQLWARNING" "SQL_BIG_RESULT" "SQL_CALC_FOUND_ROWS" "SQL_SMALL_RESULT"
"SSL" "STARTING" "STRAIGHT_JOIN" "TABLE" "TERMINATED" "THEN" "TINYBLOB" "TINYINT" "TINYTEXT"
"TO" "TRAILING" "TRIGGER" "TRUE" "UNDO" "UNION" "UNIQUE" "UNLOCK" "UNSIGNED" "UPDATE" "USAGE"
"USE" "USING" "UTC_DATE" "UTC_TIME" "UTC_TIMESTAMP" "VALUES" "VARBINARY" "VARCHAR" "VARCHARACTER"
"VARYING" "WHEN" "WHERE" "WHILE" "WITH" "WRITE" "X509" "XOR" "YEAR_MONTH" "ZEROFILL")

# Function to check if a string is a MySQL reserved keyword
is_mysql_reserved_keyword() {
    local word_to_check=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    for keyword in "${MYSQL_RESERVED_KEYWORDS[@]}"; do
        if [ "$word_to_check" = "$keyword" ]; then
            return 0  # True, it is a reserved keyword
        fi
    done
    return 1  # False, not a reserved keyword
}

# Function to display usage information
show_usage() {
    echo "Usage: $0 [-t] [-c] [-i] [-a] [-T] [-n] <csv_file>"
    echo "Options:"
    echo "  -t    Truncate table: Clear all data from the table before importing"
    echo "  -c    Create table: Create a new table for the data (otherwise imports to existing table)"
    echo "  -i    Interactive mode: Allows customizing column data types and constraints (implies -c)"
    echo "  -a    Add auto-increment ID: Adds an 'id' column as an unsigned int primary key (implies -c)"
    echo "  -T    Use TEXT: Use TEXT as the default column type instead of VARCHAR(255) (implies -c)"
    echo "  -n    Dry run: Only generate SQL, don't import data"
    exit 1
}

# Parse command line options
INTERACTIVE=false
ADD_AUTO_ID=false
DRY_RUN=false
CREATE_TABLE=false
TRUNCATE_TABLE=false
USE_TEXT=false
while getopts "tciaTn" opt; do
    case $opt in
        t) TRUNCATE_TABLE=true ;;
        c) CREATE_TABLE=true ;;
        i)
            INTERACTIVE=true
            CREATE_TABLE=true
            ;;
        a)
            ADD_AUTO_ID=true
            CREATE_TABLE=true
            ;;
        T)
            USE_TEXT=true
            CREATE_TABLE=true
            ;;
        n) DRY_RUN=true ;;
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
    COLUMN_NAMES=()  # Add this array to store custom column names

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

    # Default data type based on USE_TEXT option
    local default_type
    if [ "$USE_TEXT" = true ]; then
        default_type="TEXT"
    else
        default_type="VARCHAR(255)"
    fi

    for i in "${!CSV_COLUMNS[@]}"; do
        # Clean column name
        local column_name=$(echo "${CSV_COLUMNS[$i]}" | tr ' ' '_' | tr -cd '[:alnum:]_')

        # If column name is empty or doesn't start with a letter or underscore, prepend 'c_'
        if [[ -z $column_name || ! $column_name =~ ^[a-zA-Z_] ]]; then
            column_name="c_${i}_$column_name"
        fi

        # Check if column name is a reserved keyword using our function
        if is_mysql_reserved_keyword "$column_name"; then
            if [ "$INTERACTIVE" = true ]; then
                echo "  Warning: '$column_name' is a MySQL reserved keyword"
                read -p "  New column name [col_$column_name]: " reserved_column_name
                if [ -n "$reserved_column_name" ]; then
                    column_name="$reserved_column_name"
                else
                    column_name="col_$column_name"
                fi
            else
                # Automatically prefix reserved keywords
                column_name="col_$column_name"
                echo "  Renamed reserved keyword column: $column_name"
            fi
        fi

        # Store the column name
        COLUMN_NAMES[$i]="$column_name"

        echo "Column $i: $column_name"

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

        # Pre-populate remaining columns with defaults if user chose to use defaults
        if [ "$USE_DEFAULTS" = true ] && [ $i -lt $((${#CSV_COLUMNS[@]} - 1)) ]; then
            echo "Pre-populating remaining columns with defaults"
            for j in $(seq $((i + 1)) $((${#CSV_COLUMNS[@]} - 1))); do
                # Clean column name
                local next_col_name=$(echo "${CSV_COLUMNS[$j]}" | tr ' ' '_' | tr -cd '[:alnum:]_')

                # If column name is empty or doesn't start with a letter or underscore, prepend 'c_'
                if [[ -z $next_col_name || ! $next_col_name =~ ^[a-zA-Z_] ]]; then
                    next_col_name="c_${j}_$next_col_name"
                fi

                # Check if column name is a reserved keyword
                if is_mysql_reserved_keyword "$next_col_name"; then
                    next_col_name="col_$next_col_name"
                    echo "  Renamed reserved keyword column: $next_col_name"
                fi

                # Store the column name
                COLUMN_NAMES[$j]="$next_col_name"

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

    # Always add DROP TABLE statement
    sql="${sql}DROP TABLE IF EXISTS $table_name;\n\n"

    # Add the CREATE TABLE statement
    sql="${sql}CREATE TABLE $table_name (\n"

    # Add auto-increment ID column if option is enabled
    local first_column=true
    if [ "$ADD_AUTO_ID" = true ]; then
        sql="${sql}    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY"
        echo "Adding auto-increment ID column"
        first_column=false
    fi

    # Add columns with their data types and constraints
    for i in "${!CSV_COLUMNS[@]}"; do
        # Use the stored column name if available from interactive mode
        local column_name
        if [ "$INTERACTIVE" = true ] && [ ${#COLUMN_NAMES[@]} -gt 0 ]; then
            column_name="${COLUMN_NAMES[$i]}"
        else
            # Clean column name (replace spaces with underscores and remove special characters)
            column_name=$(echo "${CSV_COLUMNS[$i]}" | tr ' ' '_' | tr -cd '[:alnum:]_')

            # If column name is empty or doesn't start with a letter or underscore, prepend 'c_'
            if [[ -z $column_name || ! $column_name =~ ^[a-zA-Z_] ]]; then
                column_name="c_${i}_$column_name"
            fi

            # Check if column name is a reserved keyword using our function
            if is_mysql_reserved_keyword "$column_name"; then
                echo "  WARNING: '$column_name' is a MySQL reserved keyword, renaming to 'col_$column_name'"
                column_name="col_$column_name"
            fi
        fi

        # Add comma if this is not the first column
        if [ "$first_column" = false ]; then
            sql="$sql,\n"
        else
            first_column=false
        fi

        # Add column definition with data type and constraints
        if [ "$INTERACTIVE" = true ] && [ ${#COLUMN_TYPES[@]} -gt 0 ]; then
            # Use interactively defined properties
            sql="$sql    $column_name ${COLUMN_TYPES[$i]}"
            if [ -n "${COLUMN_CONSTRAINTS[$i]}" ]; then
                sql="$sql ${COLUMN_CONSTRAINTS[$i]}"
            fi
        else
            # Use default properties based on USE_TEXT option
            if [ "$USE_TEXT" = true ]; then
                sql="$sql    $column_name TEXT NULL"
            else
                sql="$sql    $column_name VARCHAR(255) NULL"
            fi
        fi
    done

    # Close the CREATE TABLE statement
    sql="$sql\n);"

    # Print the SQL command
    echo -e "$sql"

    # Store the SQL for later use if needed for database import
    CREATE_TABLE_SQL="$sql"
    TABLE_NAME="$table_name"
}

# Function to import data to an existing table
import_to_existing_table() {
    local csv_file="$1"
    local raw_table_name=$(basename "$csv_file" .csv)
    local db_name="db"  # Hardcoded database name

    # Determine default table name
    local default_table_name=$(echo "$raw_table_name" | tr ' -' '_' | tr -cd '[:alnum:]_')
    if [[ ! $default_table_name =~ ^[a-zA-Z_] ]]; then
        default_table_name="t_$default_table_name"
    fi

    # Prompt for table name
    read -p "Table name to import data into [$default_table_name]: " table_name
    table_name=${table_name:-$default_table_name}

    # Import the data
    if [ "$DRY_RUN" = false ]; then
        import_data_to_existing_table "$csv_file" "$table_name"
    else
        echo "Dry run specified - would import to table: $table_name"
    fi
}

# Function to import data into an existing table
import_data_to_existing_table() {
    local csv_file="$1"
    local table_name="$2"
    local db_service="db"  # Default service name in docker-compose.yml

    echo "Importing data to existing table: $table_name"

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

    # Check if the table exists
    echo "Checking if table exists..."
    if ! docker compose exec -T $db_service mysql -u root -p"${MYSQL_ROOT_PASSWORD:-password}" -D db -e "SHOW TABLES LIKE '$table_name'" | grep -q "$table_name"; then
        echo "Error: Table '$table_name' does not exist"
        echo "Use the -c option to create a new table"
        return 1
    fi

    # Truncate the table if requested
    if [ "$TRUNCATE_TABLE" = true ]; then
        echo "Truncating table before import..."
        if ! docker compose exec -T $db_service mysql -u root -p"${MYSQL_ROOT_PASSWORD:-password}" -D db -e "TRUNCATE TABLE $table_name"; then
            echo "Error: Failed to truncate table"
            return 1
        fi
        echo "Table truncated successfully"
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
        local col_name

        # Use the stored column name if available from interactive mode
        if [ "$INTERACTIVE" = true ] && [ ${#COLUMN_NAMES[@]} -gt 0 ] && [ -n "${COLUMN_NAMES[$((i-1))]}" ]; then
            col_name="${COLUMN_NAMES[$((i-1))]}"
        else
            # Clean column name
            col_name=$(echo "${CSV_COLUMNS[$((i-1))]}" | tr ' ' '_' | tr -cd '[:alnum:]_')

            # If column name is empty or doesn't start with a letter or underscore, prepend 'c_'
            if [[ -z $col_name || ! $col_name =~ ^[a-zA-Z_] ]]; then
                col_name="c_$((i-1))_$col_name"
            fi

            # Check if column name is a reserved keyword
            if is_mysql_reserved_keyword "$col_name"; then
                col_name="col_$col_name"
            fi
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

# Function to import data into the database with a new table
import_data_to_db() {
    local csv_file="$1"
    local table_name="$2"
    local sql="$3"
    local db_service="db"  # Default service name in docker-compose.yml

    echo "Creating table and importing data..."

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

    # Create the table using the SQL
    echo "Creating table using SQL command"
    if ! echo -e "$sql" | docker compose exec -T $db_service mysql -u root -p"${MYSQL_ROOT_PASSWORD:-password}" -D db; then
        echo "Error: Failed to create table using SQL command"
        return 1
    fi

    # Now that the table is created, import the data
    import_data_to_existing_table "$csv_file" "$table_name"
}

# Main flow at the end of the script
if [ "$CREATE_TABLE" = true ]; then
    # If interactive mode is enabled, define column properties
    if [ "$INTERACTIVE" = true ]; then
        define_column_properties "$1"
    fi

    # Generate the CREATE TABLE SQL command
    generate_create_table_sql "$1"

    # Import the data if not a dry run
    if [ "$DRY_RUN" = false ]; then
        import_data_to_db "$1" "$TABLE_NAME" "$CREATE_TABLE_SQL"
    else
        echo "Dry run specified - no data imported"
    fi
else
    # Just import to an existing table
    import_to_existing_table "$1"
fi
