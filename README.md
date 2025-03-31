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
- `-r` Recreate table: Drop the table first if it exists
- `-a` Add auto-increment ID: Adds an 'id' column as an unsigned int primary key
- `-n` Dry run: Only generate SQL, don't import data

### Examples

1. Import a CSV file with default settings:

```bash
./import-new-table.bash data.csv
```

2. Use interactive mode to customize column types and constraints:

```bash
./import-new-table.bash -i data.csv
```

3. Generate SQL without importing (dry run):

```bash
./import-new-table.bash -n data.csv
```

4. Drop and recreate the table if it already exists:

```bash
./import-new-table.bash -r data.csv
```

5. Add an auto-increment ID column:

```bash
./import-new-table.bash -a data.csv
```

6. Combine options:

```bash
./import-new-table.bash -i -r -a -n data.csv
```

### Interactive Mode

In interactive mode, you can:

- Customize the table name
- Define data types for each column (TEXT, VARCHAR, INT, FLOAT, DATE, etc.)
- Add constraints (NOT NULL, UNIQUE, PRIMARY KEY)
- Use 'd' at any prompt to accept defaults for all remaining questions

### Generated SQL

The script generates and displays the CREATE TABLE SQL statement. By default, all columns use the TEXT data type with NULL allowed.

### Empty Values

Empty values in the CSV file are automatically converted to NULL in the database.
