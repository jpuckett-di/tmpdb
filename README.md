# Temp Database

Need a database to import CSV files into for analysis?

## Setup

```bash
docker compose up -d
```

## Import CSV

The `import.bash` script allows you to easily convert CSV files to MySQL tables and import the data.

```bash
./import.bash [options] <csv_file>
```

### Options

- `-t` Truncate table: Clear all data from the table before importing
- `-c` Create table: Create a new table for the data (otherwise imports into an existing table)
- `-i` Interactive mode: Allows customizing column data types and constraints (implies -c)
- `-a` Add auto-increment ID: Adds an 'id' column as an unsigned int primary key (implies -c)
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
- Define data types for each column (VARCHAR(255), TEXT, INT, FLOAT, DATE, DATETIME, etc.)
- Add constraints (NOT NULL, UNIQUE, PRIMARY KEY)
- Use 'd' at any prompt to accept defaults for all remaining questions

### Generated SQL

When creating a table (-c option), the script generates and displays the CREATE TABLE SQL statement. By default, all columns use the VARCHAR(255) data type with NULL allowed. The script always includes a DROP TABLE IF EXISTS statement to ensure a clean table creation.

### Empty Values

Empty values in the CSV file are automatically converted to NULL in the database.
