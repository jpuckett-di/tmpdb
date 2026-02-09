# Temp Database

Need a database to import CSV files into for analysis?

## Setup

```bash
docker compose up -d
```

## Import CSV

The [`import.bash`](./import.bash) script allows you to easily import CSV and TSV files into MySQL tables and will create the table if needed.

```bash
./import.bash [options] [--table TABLE_NAME] <csv_file|tsv_file>
```

**Note**: The script can be run from any directory - it will automatically find the `docker-compose.yml` file in the project directory.

### Supported File Formats

- **CSV files**: Comma-separated values (`.csv` extension)
- **TSV files**: Tab-separated values (`.tsv` extension)

The script automatically detects the file format based on the extension and uses the appropriate field separator.

### Options

- `-t` Truncate table: Clear all data from the table before importing
- `-c` Create table: Create a new table for the data (otherwise imports into an existing table)
- `-i` Interactive mode: Allows customizing column data types and constraints (implies `-c`)
- `-a` Add auto-increment ID: Adds an `id` column as an auto-incrementing unsigned integer primary key (implies `-c`)
- `-T` Use `TEXT`: Use `TEXT` as the default column type instead of `VARCHAR(255)` (implies `-c`)
- `-n` Dry run: Only generate SQL, don't import data
- `--table TABLE_NAME` Specify table name for import (skips table name prompt)

### Examples

Import a CSV file to an existing table (will prompt for table name):

```bash
./import.bash data.csv
```

Import a TSV file to an existing table:

```bash
./import.bash data.tsv
```

Import a CSV file to a specific table (no prompt):

```bash
./import.bash --table my_table data.csv
```

Import a TSV file to a specific table:

```bash
./import.bash --table my_table data.tsv
```

Truncate table before importing:

```bash
./import.bash -t data.csv
```

Truncate a specific table before importing:

```bash
./import.bash -t --table existing_table data.csv
```

Create a new table and import data:

```bash
./import.bash -c data.csv
```

Use interactive mode (automatically creates a table):

```bash
./import.bash -i data.csv
```

Add an auto-increment ID column (automatically creates a table):

```bash
./import.bash -a data.csv
```

If you're dealing with too much data and you get an error like this:

> ERROR 1118 (42000) at line 5: Row size too large. The maximum row size for the used table type, not counting BLOBs, is 65535. This includes storage overhead, check the manual. You have to change some columns to TEXT or BLOBs

then create a table with `TEXT` columns instead of the default `VARCHAR(255)`:

```bash
./import.bash -T data.csv
```

Generate SQL without importing (dry run):

```bash
./import.bash -cn data.csv
```

Combine options:

```bash
./import.bash -ian data.csv
```

Dry run with specific table:

```bash
./import.bash -n --table test_table data.csv
```

Run from any directory using absolute path:

```bash
/path/to/tmpdb/import.bash -c data.csv
```

### Interactive Mode

In interactive mode, you can:

- Customize the table name
- Define data types for each column (`VARCHAR(255)`, `TEXT`, `INT`, `FLOAT`, `DATE`, `DATETIME`, etc.)
- Add constraints (`NOT NULL`, `UNIQUE`, `PRIMARY KEY`)
- Use `d` at any prompt to accept defaults for all remaining questions

### Generated SQL

When creating a table (`-c` option), the script generates and displays the `CREATE TABLE` SQL statement. By default, all columns use the `VARCHAR(255)` data type with `NULL` allowed. The script always includes a `DROP TABLE IF EXISTS` statement to ensure a clean table creation.

### Empty Values

Empty values in the CSV file are automatically converted to `NULL` in the database.

### MySQL Reserved Keywords

The script automatically detects MySQL reserved keywords in column names (like `SELECT`, `FROM`, `WHERE`, `GROUP`, etc.) and handles them appropriately:

- In non-interactive mode, reserved keywords are automatically prefixed with `col_` (e.g., `select` becomes `col_select`)
- In interactive mode, you'll be warned about reserved keywords and given the opportunity to provide a custom column name

This prevents SQL syntax errors that would occur when using reserved words as column names.

## Execute SQL Files

The [`execute.bash`](./execute.bash) script allows you to execute SQL files directly against the database.

```bash
./execute.bash [options] <sql_file>
```

### Options

- `-n` Dry run: Show the SQL content without executing
- `-h, --help` Show help message

### Examples

Execute a SQL file:

```bash
./execute.bash queries/my_query.sql
```

Preview SQL without executing (dry run):

```bash
./execute.bash -n schema.sql
```

Run from any directory using absolute path:

```bash
/path/to/tmpdb/execute.bash /path/to/script.sql
```

**Note**: The script can be run from any directory - it will automatically find the `docker-compose.yml` file in the project directory.

## Convert JSON to CSV

The [`convert-json-to-csv.bash`](./convert-json-to-csv.bash) script allows you to convert JSON files to CSV format for easy importing into databases.

```bash
./convert-json-to-csv.bash [OPTIONS] input.json [output.csv]
```

### Options

- `-p, --path PATH` - JSON path to extract before conversion (jq syntax)
- `-h, --help` - Show help message

### Examples

Convert entire JSON file to CSV (output to stdout):

```bash
./convert-json-to-csv.bash data.json
```

Convert JSON file and save to CSV file:

```bash
./convert-json-to-csv.bash data.json output.csv
```

Extract specific data using JSON path:

```bash
./convert-json-to-csv.bash -p '.data.users' nested.json users.csv
./convert-json-to-csv.bash --path '.results[]' api-response.json
```

This is useful when you have nested JSON and want to convert only a specific array or object within it.

### JSON Path Examples

- `.data.users` - Extract users array from data object
- `.results[]` - Extract each item from results array
- `.response.items` - Extract items from response object

### Supported JSON Structures

- **Array of objects**: Each object becomes a CSV row
- **Single object**: Converted to single-row CSV
- **Nested structures**: Use JSON paths to extract specific parts

#### Handling Objects with Varying Properties

The script intelligently handles JSON arrays where objects have different properties or properties in different orders:

**Different Property Orders:**
```json
[
    {"name": "John", "age": 30, "city": "NYC"},
    {"city": "LA", "name": "Jane", "age": 25},
    {"age": 35, "city": "Chicago", "name": "Bob"}
]
```

**Missing Properties:**
```json
[
    {"name": "Alice", "age": 28, "department": "HR"},
    {"name": "Bob", "city": "Boston"},
    {"age": 30, "city": "Denver", "name": "Carol", "country": "USA"}
]
```

**Completely Different Property Sets:**
```json
[
    {"id": 1, "product": "Laptop", "price": 999},
    {"name": "John", "role": "Manager"},
    {"category": "Electronics", "stock": 50, "supplier": "TechCorp"}
]
```

The script automatically:
1. **Discovers all unique properties** across all objects in the array
2. **Sorts property names alphabetically** for consistent column ordering
3. **Fills missing properties** with empty strings to maintain CSV structure
4. **Preserves data types** (numbers, booleans, strings) while handling null values appropriately
5. **Strips control characters** (tabs, newlines, carriage returns) from all string values to ensure MySQL compatibility

This ensures that the resulting CSV has consistent columns and properly aligned data, regardless of the input JSON structure variations. Control character stripping happens early in the pipeline -- before any CSV conversion -- so both simple string columns and embedded JSON columns are clean. This prevents MySQL `"Invalid encoding in string"` errors when importing CSV data that contains JSON columns.

### Testing

The script includes comprehensive unit tests covering various scenarios including objects with varying properties:

```bash
./tests/test-convert-json-to-csv.bash
```

Test coverage includes:
- Objects with properties in different orders
- Objects with missing properties  
- Objects with completely different property sets
- Nested objects and arrays
- Various data types (strings, numbers, booleans, null)
- Unicode and special characters
- Control character stripping (tabs, newlines, carriage returns)
- Embedded JSON validity after stripping
- Error handling and edge cases

### Requirements

The script requires [`jq`](https://jqlang.org) to be installed:
