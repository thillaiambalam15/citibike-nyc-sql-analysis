# NYC Citi Bike Trip Analysis (April 2026)

A SQL only analysis of one month of NYC Citi Bike ride data. Framed 20 business questions and answered all them using SQL.

## Dataset

- **Source:** [Citi Bike System Data](https://s3.amazonaws.com/tripdata/index.html) — official public dataset, no login required
- **Period used:** April 2026 (`202604-citibike-tripdata.zip`)

| Table | Rows | Description |
|---|---|---|
| `trips` | 3,860,372 | one row per ride — timestamps, start/end staton, bike type, rider type, GPS cordinates |
| `stations` | 2,437 | One row per station, derived from `trips` |

Raw merged CSV: ~753 MB (~165 MB zipped as downloaded).

## Problems Faced & How They Were Solved

### 1. Station IDs get misread as numbers during automatic import

Station IDs look numeric (e.g. `7293.10`), and so import tools that infer types from a sample often type them as floating point whoch is wrong, since some stations use alphanumeric codes (e.g. `SYS016`) . And that crashed with a numeric import outright. **Fix:** manually set both stattion ID columns to `VARCHAR`, whn using the auto import

### 2. Import method comparison — GUI wizard vs. `LOAD DATA INFILE`

Two ways of loading the same trip data into MySQL (via DBeaver) were timed:

| Method | Time |
|---|---|
| DBeaver "Import Data" wizard | 5m 04s |
| `LOAD DATA INFILE` (raw SQL) | 1m 27s |

`LOAD DATA INFILE` has the mysql server read the file directly off its own disk in one direct pass, wheras the GUI import  wizard instead sends rows as batched `INSERT`s over the network, which costs more per row. And thats why MySQL Workbench's own import wizard is slowers, 32 minutes for the same data. This is what first pushed this towards using `LOAD DATA INFILE`, and later toward DBeaver.

### 3. MySQL Workbench kept dropping the connection on long-running queries

Queries running past ~30s in Workbench failed with `Error Code: 2013 — Lost connection to MySQL server during query`. Tried raising `net_read_timeout`/`net_write_timeout` to 600s and `innodb_buffer_pool_size` to 2GB didn't help. And the real cause was **Workbench's own client-side connection timeout**, independent of any server setting. Switching to DBeaver fixed it immediately, no server-side changes required. So use mysql as the database and DBeaver as the database client for this project.

## SQL Techniques Used

- Common Table Expressions (CTEs)
- Window functions — `RANK()`, `LAG()`, `PARTITION BY`, custom frame specs (`ROWS BETWEEN ... PRECEDING AND CURRENT ROW`)
- Conditional aggregation (`SUM(condition) OVER()` patterns)
- `NULLIF`-based data cleaning applied during load
- Geospatial distance calculation via the Haversine formula (trigonometric functions)
- Query plan analysis and index-driven optimization using `EXPLAIN`
- Created schema and derived dimension table directly from the CSV file

## Tools Used

- MySQL 8.0
- DBeaver — primary SQL client used for the bulk of the analysis
- MySQL Workbench — used initially;

## Project Structure

```
citibike-nyc-sql-analysis/
├── README.md
└── sql/
    ├── data_loader.sql         
    └── business_questions.sql
```

Raw data files are intentionally not included in this repo, as it is well over GitHub's file size limits. Download and load it yourself following the steps below.

## How to Run This Yourself

1. Download the dataset: [Citi Bike System Data — April 2026](https://s3.amazonaws.com/tripdata/202604-citibike-tripdata.zip)
2. Unzip it and merge them all into a single file, or run the load statement (see `sql/data_loader.sql` for help) once per part.
3. Either load the data using the import data/table wizard or follow the `sql/data_loader.sql` for a faster loading of data
5. Run `sql/business_questions.sql` to work through all 20 business questions.

If you have comments or suggestions, feel free to reach out.