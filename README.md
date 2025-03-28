# Temp Database

Need a database to import CSV files into for analysis?

## Setup

```bash
docker compose up -d
```

## Import CSV

The `import-new-table.bash` script allows you to easily convert CSV files to MySQL tables and import the data.

```bash
./import-new-table.bash [options] <csv_file>
```

### Options

- `-i` Interactive mode: Allows customizing column data types and constraints
- `-d` Database import: Import the data into the database after creating the table
- `-r` Recreate table: Drop the table first if it exists

### Examples

1. Generate a CREATE TABLE SQL script from a CSV file:

```bash
./import-new-table.bash data.csv
```

2. Use interactive mode to customize column types and constraints:

```bash
./import-new-table.bash -i data.csv
```

3. Import the data directly into the database:

```bash
./import-new-table.bash -d data.csv
```

4. Drop and recreate the table if it already exists:

```bash
./import-new-table.bash -r data.csv
```

5. Combine options:

```bash
./import-new-table.bash -i -d -r data.csv
```

### Interactive Mode

In interactive mode, you can:

- Customize the table name
- Define data types for each column (TEXT, VARCHAR, INT, FLOAT, DATE, etc.)
- Add constraints (NOT NULL, UNIQUE, PRIMARY KEY)
- Use 'd' at any prompt to accept defaults for all remaining questions

### Generated SQL

The script generates SQL files with the naming pattern `<csv_filename>_create_table.sql` in the same directory as the CSV file. By default, all columns use the TEXT data type with NULL allowed.

### Empty Values

Empty values in the CSV file are automatically converted to NULL in the database.
