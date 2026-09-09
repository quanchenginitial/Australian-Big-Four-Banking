-- Check the active DuckDB database and file path.
SELECT
    version() AS duckdb_version,
    database_name,
    path
FROM duckdb_databases()
WHERE database_name = current_database();

-- List existing tables and views.
SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_catalog = current_database()
ORDER BY table_schema, table_name;
