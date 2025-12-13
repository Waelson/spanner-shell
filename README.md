# Spanner Shell

An interactive and intuitive CLI tool for working with Google Cloud Spanner, offering an experience similar to `psql` (PostgreSQL) or `mysql` (MySQL), but optimized for the Spanner ecosystem.

## 📋 Table of Contents

- [About the Project](#about-the-project)
- [Problems it Solves](#problems-it-solves)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Initial Configuration](#initial-configuration)
- [Available Commands](#available-commands)
- [Update](#update)
- [Uninstallation](#uninstallation)
- [Usage Examples](#usage-examples)

---

## 🎯 About the Project

**Spanner Shell** is an interactive shell developed in Bash that simplifies working with Google Cloud Spanner databases. The tool offers a friendly command-line interface, allowing you to execute SQL queries, manage tables, view data, and much more, both in production environments and the local emulator.

### Key Features

- ✅ **Interactive Interface**: Intuitive prompt similar to traditional SQL tools
- ✅ **Profile Support**: Easily manage multiple environments (dev, stage, prod)
- ✅ **Emulator and Remote**: Works with both Spanner Emulator and remote instances
- ✅ **Isolated History**: Dedicated command history for Spanner Shell
- ✅ **Special Commands**: Shortcuts for common operations (list tables, describe schemas, etc.)
- ✅ **DML Generation**: Automatically generates examples of INSERT, UPDATE, SELECT, and DELETE
- ✅ **Real-time Monitoring**: Track new records in tables with `\f`
- ✅ **AI-Powered Hotspot Analysis**: Detect and prevent write hotspots using LLM (GPT-5.2, GPT-4o, etc.)
- ✅ **Export Data**: Export query results to CSV or JSON files
- ✅ **Record Comparison**: Compare two records and show differences

---

## 💡 Problems it Solves

### 1. **gcloud Command Complexity**

The Google Cloud SDK (`gcloud`) requires verbose and complex commands to execute SQL queries on Spanner. Spanner Shell abstracts this complexity, allowing you to execute SQL queries directly in an interactive environment.

**Before:**
```bash
gcloud spanner databases execute-sql my-database \
  --instance=my-instance \
  --sql="SELECT * FROM users LIMIT 10;"
```

**After:**
```sql
spanner> SELECT * FROM users LIMIT 10;
```

### 2. **Lack of Interactive Interface**

Working with Spanner via `gcloud` is based on single commands, without an interactive environment. Spanner Shell offers a continuous prompt where you can execute multiple queries, explore the database, and maintain context.

### 3. **Multiple Environment Management**

Switching between different projects, instances, and databases requires reconfiguring environment variables or repeatedly executing long commands. Spanner Shell solves this with a profile system that allows quick switching between environments.

### 4. **Schema Exploration**

Discovering the structure of tables, columns, and relationships in Spanner can be laborious. Spanner Shell offers simple commands like `\t` (list tables) and `\d <table>` (describe table) to facilitate exploration.

### 5. **DML Code Generation**

Creating INSERT, UPDATE, SELECT, and DELETE queries manually can be tedious and error-prone. The `\g` command analyzes the table structure and automatically generates DML examples with correct data types.

### 6. **Data Monitoring**

Tracking new records inserted into tables requires repeatedly executing queries. The `\f` command automatically monitors new insertions, updating every 5 seconds.

---

## 📦 Prerequisites

### 1. **Google Cloud SDK (gcloud)**

Spanner Shell uses the `gcloud` CLI to communicate with Spanner. You need to have the Google Cloud SDK installed and configured.

**Installation on macOS:**
```bash
brew install --cask google-cloud-sdk
```

**Verification:**
```bash
gcloud --version
```

### 2. **Authentication (for Remote Spanner)**

If you plan to use Spanner Shell with remote instances (not emulator), you need to authenticate:

```bash
gcloud auth login
```

For local development with the emulator, authentication is not required.

### 3. **Spanner Emulator (Optional)**

For local development, you can use the Spanner Emulator. The emulator must be running on the default port `9020`:

```bash
# Start the emulator (if using Docker)
docker run -d -p 9020:9020 -p 9010:9010 gcr.io/cloud-spanner-emulator/emulator
```

### 4. **Bash 4.0+**

The script requires modern Bash. Most Unix-like systems (macOS, Linux) already have Bash installed.

**Verification:**
```bash
bash --version
```

### 5. **jq (JSON Processor)**

Spanner Shell uses `jq` to process JSON responses from gcloud, especially for the `\df` command that compares records and the `\hotspot-ai` command for AI-powered analysis. `jq` is required for full functionality of the tool.

**Installation on macOS:**
```bash
brew install jq
```

**Installation on Linux (Ubuntu/Debian):**
```bash
sudo apt-get install jq
```

**Installation on Linux (CentOS/RHEL):**
```bash
sudo yum install jq
```

**Verification:**
```bash
jq --version
```

### 6. **curl (HTTP Client)**

Required for AI-powered features like `\hotspot-ai` to communicate with OpenAI API.

**Verification:**
```bash
curl --version
```

Most systems already have `curl` installed. If not:

**Installation on macOS:**
```bash
brew install curl
```

**Installation on Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install curl

# CentOS/RHEL
sudo yum install curl
```

### 7. **OpenAI API Key (Optional - for AI Features)**

To use AI-powered commands like `\hotspot-ai`, you need an OpenAI API key.

**Get your API key:**
1. Visit https://platform.openai.com/api-keys
2. Create a new API key
3. Configure it using `spanner-shell --llm-setup`

**Supported Models:**
- GPT-5.2
- GPT-4o (recommended)
- GPT-4o-mini (cost-effective)
- GPT-4, GPT-4-turbo, GPT-3.5-turbo
- Custom models

### 8. **Write Permissions**

Spanner Shell creates configuration and history files in `~/.spanner-shell/`. Make sure you have write permissions in the home directory.

---

## 🚀 Installation

### Method 1: Automatic Installation (Recommended)

1. **Clone the repository:**
```bash
git clone https://github.com/Waelson/spanner-shell.git
cd spanner-shell
```

2. **Run the installation script:**
```bash
./install.sh
```

The installer will:
- Copy the script to `/opt/homebrew/bin` (macOS with Homebrew) or `/usr/local/bin`
- Make the script executable
- Offer to create a `spanner` alias (optional)

3. **Reload your shell:**
```bash
source ~/.zshrc  # or ~/.bashrc
```

4. **Verify installation:**
```bash
spanner-shell --version
```

### Method 2: Manual Installation

1. **Copy the script to a directory in PATH:**
```bash
sudo cp spanner-shell.sh /usr/local/bin/spanner-shell
sudo chmod +x /usr/local/bin/spanner-shell
```

2. **Create an alias (optional):**
```bash
echo "alias spanner='spanner-shell'" >> ~/.zshrc
source ~/.zshrc
```

---

## ⚙️ Initial Configuration

Before using Spanner Shell, you need to create a configuration profile. A profile stores connection information (Project ID, Instance ID, Database ID) and connection type (emulator or remote).

### Creating a Profile

Run the configuration command:

```bash
spanner-shell --config
```

The assistant will request:
- **Profile name**: An identifier for the profile (e.g., `dev`, `stage`, `prod`)
- **Type**: `emulator` (for local development) or `remote` (for production)
- **Project ID**: Google Cloud project ID
- **Instance ID**: Spanner instance ID
- **Database ID**: Spanner database ID

**Example:**
```
Profile name (ex: dev, stage, prod): dev
Type (emulator | remote): emulator
Project ID: my-project
Instance ID: test-instance
Database ID: my-database
```

### Using a Profile

After creating a profile, you can start Spanner Shell with it in two ways:

#### Method 1: Interactive Selection (Recommended)

Use the `--list-profile` command to see all available profiles and select one interactively:

```bash
spanner-shell --list-profile
```

The script will:
1. List all available profiles numbered
2. Request that you type the number of the desired profile
3. Automatically load the selected profile

**Example output:**
```
📋 Available profiles:

   1) dev (remote) - projeto-dev
   2) stage (remote) - projeto-stage
   3) prod (remote) - projeto-prod

Which profile do you want to use? (enter the number): 2
✅ Profile 'stage' loaded successfully!
```

#### Method 2: Specify Profile Directly

You can also specify the profile name directly:

```bash
spanner-shell --profile dev
```

The profile will be loaded automatically and you'll enter the interactive shell.

---

## 📚 Available Commands

### Configuration Commands

#### `--version` or `-v`
Displays the Spanner Shell version.

```bash
spanner-shell --version
```

#### `--config`
Starts the interactive assistant to create a new configuration profile.

```bash
spanner-shell --config
```

#### `--list-profile`
Lists all available profiles and allows interactive selection. This is the most convenient way to choose a profile when you have multiple profiles configured.

```bash
spanner-shell --list-profile
```

**Features:**
- Displays all profiles numbered with information (type and project ID)
- Requests selection by number
- Validates user input
- Automatically loads the selected profile

**Example:**
```
📋 Available profiles:

   1) dev (remote) - projeto-dev
   2) stage (remote) - projeto-stage
   3) prod (remote) - projeto-prod

Which profile do you want to use? (enter the number): 2
✅ Profile 'stage' loaded successfully!
```

#### `--profile <name>`
Starts Spanner Shell using a specific profile by name.

```bash
spanner-shell --profile dev
```

**Note:** If you don't know the exact profile name, use `--list-profile` to see all available profiles.

#### `--llm-setup`
Configures AI/LLM integration for advanced features like hotspot analysis. This setup is global and works across all profiles.

```bash
spanner-shell --llm-setup
```

**Features:**
- Choose from popular OpenAI models (GPT-5.2, GPT-4o, GPT-4o-mini, GPT-4, GPT-4-turbo, GPT-3.5-turbo)
- Custom model support
- Secure API token storage (chmod 600)
- Configuration stored at `~/.spanner-shell/llm.config`

**Example:**
```
🤖 Spanner Shell LLM Configuration
==================================

LLM Provider:
  1) OpenAI (default)
  2) Exit without saving

Select provider (1-2) [1]: 1

OpenAI Models:
  1) gpt-5.2
  2) gpt-4o
  3) gpt-4o-mini
  4) gpt-4
  5) gpt-4-turbo
  6) gpt-3.5-turbo (default)
  7) Custom model name

Select model (1-7) [6]: 2

API Token (leave empty to keep current): sk-...

✅ LLM configuration saved successfully!
```

**Usage After Setup:**
Once configured, you can use AI-powered commands like `\hotspot-ai` within the shell.

---

### Special Commands (within the shell)

All special commands start with `\` (backslash) and are executed within the interactive shell.

#### `\help` or `\h`
Displays the list of all available commands with their descriptions.

```sql
spanner> \help
```

#### `\c`
Displays the current configuration of the loaded profile (type, project, instance, database).

```sql
spanner> \c
```

#### `\t`
Lists all tables in the current database.

```sql
spanner> \t
```

**Output:**
```
table_name
----------
users
orders
products
```

#### `\d <table>`
Describes the structure of a specific table, showing columns, data types, and whether they are nullable.

```sql
spanner> \d users
```

**Output:**
```
column_name  spanner_type    is_nullable
-----------  --------------  -----------
user_id      INT64           NO
name         STRING(255)     NO
email        STRING(255)     YES
created_at   TIMESTAMP       NO
```

#### `\n <table>`
Counts the total number of records in a table.

```sql
spanner> \n users
```

**Output:**
```
Counting records in table 'users'...
total
-----
1250
```

#### `\s <table> [n]`
Shows a sample of records from a table. By default, displays 10 records. You can specify a different number (maximum 1000).

```sql
spanner> \s users
spanner> \s users 20
```

**Output:**
```
Showing 10 records from table 'users':
----------------------------------------
user_id  name           email
-------  -------------  -------------------
1        João Silva     joao@example.com
2        Maria Santos   maria@example.com
...
```

#### `\l <table> [n] [column]`
Shows the last N records of a table, ordered by a specific column (or by primary key if not specified). By default, shows 10 records.

```sql
spanner> \l users
spanner> \l users 20
spanner> \l users 15 created_at
```

**Parameters:**
- `<table>`: Table name (required)
- `[n]`: Number of records to display (default: 10, maximum: 1000)
- `[column]`: Column for ordering (default: primary key or first column)

#### `\f <table> [n] [column]`
Monitors new records in a table in real-time, updating every 5 seconds. Similar to Unix `tail -f`.

```sql
spanner> \f users
spanner> \f orders 20 order_id
```

**Features:**
- Displays only new records since last check
- Automatically updates every 5 seconds
- Press `Ctrl+C` to stop monitoring
- Orders by primary key or specified column

#### `\g <table>`
Automatically generates examples of DML commands (INSERT, UPDATE, SELECT, DELETE) based on the table structure.

```sql
spanner> \g users
```

**Output:**
```
📝 Example DML for table: users
==========================================
-- INSERT
INSERT INTO users (
  user_id, name, email, created_at
) VALUES (
  123, 'example', 'example', CURRENT_TIMESTAMP()
);

-- SELECT
SELECT * FROM users
WHERE 
  user_id = 123;

-- UPDATE
UPDATE users
SET 
  name = 'example', email = 'example'
WHERE 
  user_id = 123;

-- DELETE
DELETE FROM users
WHERE 
  user_id = 123;
```

#### `\df <table> <id1> <id2>`
Compares two records from a table and displays the differences between them. Useful for identifying changes between versions of the same record or comparing different records.

```sql
spanner> \df members 216172782113783808 468374361246531584
```

**Parameters:**
- `<table>`: Table name (required)
- `<id1>`: ID (primary key) of the first record to compare
- `<id2>`: ID (primary key) of the second record to compare

**Features:**
- Automatically detects primary key type (STRING or INT64)
- Compares all fields of both records
- Displays only fields that are different
- Shows message when records are identical
- Supports all Spanner data types

**Output:**
```
🔍 Comparing records from table: members
   ID1: 216172782113783808
   ID2: 468374361246531584

📊 Differences found:

• user_id:
    216172782113783808 → "meli-123"
    468374361246531584 → "Waelson"
```

**Note:** This command requires `jq` installed on the system. See the [Prerequisites](#prerequisites) section for more information.

**Note:** The command name is `\df` (not `\diff`).

#### `\dd <table>`
Displays the DDL (Data Definition Language) of a specific table, including the CREATE TABLE definition and related indexes.

```sql
spanner> \dd users
```

**Output:**
```
CREATE TABLE users (
  user_id INT64 NOT NULL,
  name STRING(255) NOT NULL,
  email STRING(255),
  created_at TIMESTAMP NOT NULL,
) PRIMARY KEY (user_id);
```

#### `\da`
Displays the complete DDL of the entire database, including all tables and indexes.

```sql
spanner> \da
```

#### `\k <table>`
Displays the Primary Key columns of a specific table.

```sql
spanner> \k users
```

**Output:**
```
🔑 Primary Key of table: users

column_name
-----------
user_id
```

**Features:**
- Shows all columns that form the primary key
- Ordered by ordinal position
- Useful for understanding table structure and relationships

#### `\i <table>`
Lists all indexes of a specific table, showing index name, type, and columns.

```sql
spanner> \i users
```

**Output:**
```
📑 Indexes of table: users

🔹 Index: PRIMARY_KEY (PRIMARY_KEY)
   - user_id

🔹 Index: idx_users_email (INDEX)
   - email
```

**Features:**
- Shows all indexes including primary key
- Displays index type (PRIMARY_KEY, INDEX, etc.)
- Lists columns in each index ordered by position
- Useful for understanding table performance optimization

#### `\llm [show|select]`
Manages LLM (AI) configuration within the interactive shell.

```sql
spanner> \llm show
spanner> \llm select
```

**Subcommands:**
- `show`: Displays current LLM configuration (provider, model, API token preview)
- `select`: Selects global LLM configuration (future: support for multiple LLMs)

**Example Output:**
```
Current LLM Configuration:
----------------------------------------
  Provider: openai
  Model: gpt-4o
  API Token: sk-proj-abc123...
```

**Note:** To configure LLM for the first time, use `spanner-shell --llm-setup` outside the shell.

#### `\hotspot-ai <table>`
**AI-powered hotspot analysis** for Spanner tables. Identifies patterns that may cause write hotspots and provides actionable recommendations.

```sql
spanner> \hotspot-ai users
```

**What is a Hotspot?**
A hotspot occurs when many write operations concentrate on a single partition, causing performance degradation. Sequential keys (timestamps, auto-increment IDs) are the primary cause.

**Features:**
- Analyzes Primary Key patterns (sequences, timestamps, UUID)
- Evaluates Secondary Indexes for inherited hotspots
- Identifies Column Risks (sequential values, low cardinality)
- Provides risk score (0-100) and level (HIGH/MEDIUM/LOW)
- Suggests concrete solutions with code examples

**Requirements:**
- LLM must be configured (`spanner-shell --llm-setup`)
- `curl` and `jq` installed

**Example Output:**
```
════════════════════════════════════════════
🔥 HOTSPOT ANALYSIS — TABLE: permissions
════════════════════════════════════════════

What is a Hotspot?
A hotspot occurs when many write operations concentrate
on a single partition, causing performance degradation.
Sequential keys (timestamps, auto-increment IDs) are
the primary cause. This analysis identifies patterns
that may lead to hotspots in your table.

------------
Primary Key:
------------
- permission_id (INT64)
- Default: GET_NEXT_SEQUENCE_VALUE(SEQUENCE permissions_seq)
❌ Classification: Almost certain hotspot
🧠  Reason: Sequential values concentrate all writes on single partition
💥  Impact: Severe write bottleneck, no horizontal scaling

------------------
Secondary Indexes:
------------------
- permissions_name_unique → Low
🧠  Reason: High cardinality, naturally distributed
⚠️  Avoid: Bulk inserts with sequential names

-------------
Column Risks:
-------------
- created_at → Medium
🧠  Reason: Sequential timestamp values
💥  Impact: Would create hotspot if indexed
⚠️  Avoid: Don't create secondary indexes

- updated_at → Medium
🧠  Reason: Sequential timestamp values
💥  Impact: Hotspot if used in queries
⚠️  Avoid: Avoid in high-volume WHERE clauses

-----------------------
Score Final: 70 / 100
-----------------------
Risk Level: 🔴 HIGH

This table has HIGH risk due to sequential primary key.
All writes concentrate on a single partition, severely
limiting throughput under load.

-------------------
✅ Recommendations:
-------------------
- Use STRING UUID for primary key: permission_id STRING(36) DEFAULT (GENERATE_UUID())
- Or add randomization: (FARM_FINGERPRINT(...) << 20) | GET_NEXT_SEQUENCE_VALUE(...)
```

**Supported Models:**
- GPT-5.2, GPT-4o, GPT-4o-mini, GPT-4, GPT-4-turbo, GPT-3.5-turbo
- Custom models via `--llm-setup`

#### `\im <file.sql>`
Imports and executes a SQL file containing DML instructions (INSERT, UPDATE, DELETE, SELECT).

```sql
spanner> \im /path/to/file.sql
```

**Features:**
- Executes all SQL statements in the file
- Useful for importing data or running migration scripts
- Shows success or error message after execution

**Example file:**
```sql
-- file.sql
INSERT INTO users (user_id, name, email) VALUES (1, 'João', 'joao@example.com');
INSERT INTO users (user_id, name, email) VALUES (2, 'Maria', 'maria@example.com');
```

#### `\id <file.sql>`
Imports and executes a SQL file containing DDL instructions (CREATE TABLE, CREATE INDEX, ALTER TABLE, etc.).

```sql
spanner> \id /path/to/schema.sql
```

**Features:**
- Updates the database schema
- Useful for creating or modifying table structures
- Requires appropriate permissions on Spanner

**Example file:**
```sql
-- schema.sql
CREATE TABLE products (
  product_id INT64 NOT NULL,
  name STRING(255) NOT NULL,
  price FLOAT64 NOT NULL,
) PRIMARY KEY (product_id);

CREATE INDEX idx_products_name ON products(name);
```

#### `\e <query> --format csv|json --output <file>`
Exports query results to CSV or JSON file. Facilitates data analysis and integration with other tools.

```sql
spanner> \e "SELECT * FROM users" --format csv --output users.csv
spanner> \e "SELECT name, email FROM users WHERE active = true" --format json --output active_users.json
```

**Syntax:**
- `<query>`: SQL query to execute (can be in single or double quotes)
- `--format csv|json`: Output format (required)
- `--output <file>`: Output file path (required)

**Features:**
- Executes the query and exports results to the specified format
- Automatically creates output directory if it doesn't exist
- Warns if file already exists (will be overwritten)
- Shows number of exported records
- CSV: First line contains header with column names
- JSON: Array of objects format (uses jq for formatting if available)

**Examples:**

Export to CSV:
```sql
spanner> \e "SELECT user_id, name, email FROM users LIMIT 100" --format csv --output /tmp/users.csv
Executing query...
✅ Exported successfully: /tmp/users.csv (101 line(s))
```

Export to JSON:
```sql
spanner> \e "SELECT * FROM orders WHERE status = 'pending'" --format json --output orders.json
Executing query...
✅ Exported successfully: orders.json (15 record(s))
```

**Notes:**
- The query must be a SELECT (does not support INSERT, UPDATE, DELETE)
- For complex queries, use quotes to avoid parsing issues
- CSV format automatically escapes values containing commas or quotes
- JSON format requires jq for pretty formatting (optional, but recommended)

#### `\p <query> [--page-size <n>]`
Displays SQL query results in a formatted table with borders, alternating colors, column alignment, and automatic pagination. Significantly improves readability of large results.

```sql
spanner> \p "SELECT user_id, name, email FROM users LIMIT 50"
spanner> \p "SELECT * FROM orders WHERE status = 'pending'" --page-size 15
```

**Syntax:**
- `<query>`: SQL query to execute (can be in single or double quotes)
- `--page-size <n>`: Number of lines per page (optional, default: 20, minimum: 1, maximum: 100)

**Features:**
- Visual formatting with borders using box-drawing characters (┌ ┐ └ ┘ │ ─ ├ ┤ ┬ ┴ ┼)
- Highlighted header with colored background
- Alternating row colors for easier reading
- Smart alignment: numeric columns right-aligned, text left-aligned
- Automatic pagination for large results
- Adapts column widths to terminal size
- Automatically truncates very long values

**Example output:**
```
┌──────────┬──────────────────────┬──────────────────────────┬─────────┐
│ user_id  │ name                 │ email                    │ status  │
├──────────┼──────────────────────┼──────────────────────────┼─────────┤
│ 1        │ João Silva           │ joao@example.com         │ active  │
│ 2        │ Maria Santos         │ maria@example.com       │ active  │
│ 3        │ Pedro Oliveira       │ pedro@example.com       │ inactive│
└──────────┴──────────────────────┴──────────────────────────┴─────────┘
[Page 1/3] - Press Enter for next page, 'q' to exit
```

**Examples:**

Simple table:
```sql
spanner> \p "SELECT user_id, name, email FROM users LIMIT 10"
```

Table with custom pagination:
```sql
spanner> \p "SELECT * FROM orders ORDER BY created_at DESC" --page-size 15
```

**Notes:**
- The query must be a SELECT (does not support INSERT, UPDATE, DELETE)
- For many records, consider using LIMIT in the query for better performance
- Press 'q' during pagination to exit
- Command automatically adapts to terminal width
- Very long values are truncated with "..."

#### `\r <n> <command>`
Executes a SQL command N times. Useful for load testing, batch insertions, or repetitive operations.

```sql
spanner> \r 5 SELECT COUNT(*) FROM users;
spanner> \r 10 INSERT INTO logs (message) VALUES ('test');
```

**Parameters:**
- `<n>`: Number of repetitions (minimum: 1, maximum: 100)
- `<command>`: SQL command to execute

**Features:**
- Shows progress of each execution
- Displays results of each iteration
- Stops on error (but doesn't interrupt previous executions)

#### `\hi [n]`
Displays the last N commands executed in history. By default, shows the last 20 commands.

```sql
spanner> \hi
spanner> \hi 50
```

**Features:**
- Isolated history from Spanner Shell (doesn't mix with terminal history)
- Automatically filters invalid commands and comments
- Useful for reviewing previous commands or copying queries

#### `\hc`
Clears all command history from Spanner Shell.

```sql
spanner> \hc
```

---

### System Commands

#### `clear`
Clears the terminal screen, similar to Unix `clear` command.

```sql
spanner> clear
```

#### `exit`
Exits Spanner Shell and returns to terminal.

```sql
spanner> exit
```

---

### Direct SQL Execution

In addition to special commands, you can execute any valid Spanner SQL query directly:

```sql
spanner> SELECT * FROM users WHERE user_id = 1;

spanner> INSERT INTO users (user_id, name, email) 
    ... VALUES (100, 'João', 'joao@example.com');

spanner> UPDATE users SET email = 'novo@example.com' 
    ... WHERE user_id = 100;
```

**Features:**
- Multi-line query support (continue typing after pressing Enter)
- End the query with `;` (semicolon) to execute
- Command history with navigation using keyboard arrows
- Clear and informative error messages

---

## 🔄 Update

To update Spanner Shell to the latest version:

```bash
./update.sh
```

The update script:
1. Detects where Spanner Shell is installed
2. Clones the latest version from the Git repository
3. Replaces the old binary with the new one
4. Displays the updated version

**Note:** The update script requires Git to be installed.

---

## 🗑️ Uninstallation

To remove Spanner Shell from the system:

```bash
./uninstall.sh
```

The uninstall script:
1. Removes the binary from the system
2. Removes the `spanner` alias from the shell configuration file (if it exists)
3. **Does not remove** profiles and history in `~/.spanner-shell/` (you can remove them manually if desired)

---

## 💻 Usage Examples

### Example 1: Initial Database Exploration

```sql
spanner> \t                     # List all tables
spanner> \d users               # Describe users table
spanner> \n users               # Count records
spanner> \s users 5             # Show 5 examples
spanner> \l users 10            # Show last 10 records
```

### Example 2: DML Code Generation

```sql
spanner> \g orders             # Generate INSERT, UPDATE, etc. examples
# Copy and paste the generated examples, adjusting values as needed
```

### Example 3: Record Comparison

```sql
spanner> \df members 216172782113783808 468374361246531584
# Compares two records and shows only the differences
```

### Example 4: Real-time Monitoring

```sql
spanner> \f logs               # Monitor new logs in real-time
# Press Ctrl+C to stop
```

### Example 5: Data Import

```sql
spanner> \im /path/to/data.sql
```

### Example 6: Data Export

```sql
# Export results to CSV
spanner> \e "SELECT * FROM users WHERE created_at > '2024-01-01'" --format csv --output users_2024.csv

# Export results to JSON
spanner> \e "SELECT order_id, total, status FROM orders WHERE status = 'completed'" --format json --output completed_orders.json
```

### Example 7: Formatted Table Visualization

```sql
# Display results in formatted table
spanner> \p "SELECT user_id, name, email, status FROM users LIMIT 20"

# Table with custom pagination
spanner> \p "SELECT * FROM orders ORDER BY created_at DESC" --page-size 15
```

### Example 8: Repeated Execution

```sql
spanner> \r 100 SELECT COUNT(*) FROM users;
```

### Example 9: Working with Multiple Profiles

```bash
# Create profiles for different environments
spanner-shell --config  # Create 'dev' profile
spanner-shell --config  # Create 'prod' profile

# Switch between environments
spanner-shell --profile dev   # Development environment
spanner-shell --profile prod  # Production environment
```

---

## 🐛 Troubleshooting

### Error: "gcloud is not installed"

**Solution:** Install Google Cloud SDK:
```bash
brew install --cask google-cloud-sdk
```

### Error: "No active authentication found"

**Solution:** Authenticate with gcloud:
```bash
gcloud auth login
```

### Error: "Profile not found" or "No profile loaded"

**Solution:** You have a few options:

1. **List available profiles:**
```bash
spanner-shell --list-profile
```

2. **Create a new profile:**
```bash
spanner-shell --config
```

3. **Use a specific profile:**
```bash
spanner-shell --profile <profile-name>
```

### Error connecting to Emulator

**Solution:** Make sure the emulator is running:
```bash
docker ps  # Check if container is active
# If not, start the emulator
docker run -d -p 9020:9020 -p 9010:9010 gcr.io/cloud-spanner-emulator/emulator
```

### Error: "jq: command not found" or errors when using `\df`

**Solution:** Install `jq`:
```bash
# macOS
brew install jq

# Linux (Ubuntu/Debian)
sudo apt-get install jq

# Linux (CentOS/RHEL)
sudo yum install jq
```

Verify installation:
```bash
jq --version
```

**Note:** The `\df` command requires `jq` to process JSON responses from gcloud.

### History is not working

**Solution:** Check directory permissions:
```bash
ls -la ~/.spanner-shell/
chmod -R 755 ~/.spanner-shell/
```

---

## 📝 Additional Notes

- Profiles are stored in `~/.spanner-shell/profiles/`
- History is stored in `~/.spanner-shell/history`
- Spanner Shell works with both remote Spanner and local emulator
- SQL queries are executed through `gcloud spanner databases execute-sql`
- History is isolated and does not interfere with your terminal history

---

## 📄 License

This project is licensed under the license specified in the `LICENSE` file.

---

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or pull requests.

---

## 📧 Support

For questions, suggestions, or issues, open an issue in the project repository.

---

**Version:** 1.0.13
