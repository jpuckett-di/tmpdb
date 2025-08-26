# Temp Database

Need a database to import CSV files into for analysis?

## Setup

```bash
docker compose up -d
```

## Import CSV

The [`import.bash`](./import.bash) script allows you to easily import CSV files into MySQL tables and will create the table if needed.

```bash
./import.bash [options] <csv_file>
```

### Options

- `-t` Truncate table: Clear all data from the table before importing
- `-c` Create table: Create a new table for the data (otherwise imports into an existing table)
- `-i` Interactive mode: Allows customizing column data types and constraints (implies `-c`)
- `-a` Add auto-increment ID: Adds an `id` column as an auto-incrementing unsigned integer primary key (implies `-c`)
- `-T` Use `TEXT`: Use `TEXT` as the default column type instead of `VARCHAR(255)` (implies `-c`)
- `-n` Dry run: Only generate SQL, don't import data

### Examples

Import a CSV file to an existing table:

```bash
./import.bash data.csv
```

Truncate table before importing:

```bash
./import.bash -t data.csv
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

### Requirements

The script requires [`jq`](https://jqlang.org) to be installed:
