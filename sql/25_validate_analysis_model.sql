-- Step 6G: integrated acceptance of the six analysis-model tables.
-- DuckDB; three repeatable, read-only statements on the project connection.
-- Prerequisites: the existing core.dim_bank and completed scripts 20-24.
-- These checks supplement the individual schema, period and value audits.
-- Pinned snapshot expectations must be reviewed when source windows change.

-- 1. Inventory the six tables and validate their logical keys.
-- Expected: six PASS rows; row_count = unique_keys = expected_rows;
-- null_key_rows = 0. A bank fact key is (bank_code, report_date).
WITH inventory AS (
    SELECT 1 AS table_order, 'core.dim_bank' AS table_name,
        COUNT(*) AS row_count, 4 AS expected_rows,
        COUNT(DISTINCT bank_code) AS unique_keys,
        COUNT(*) FILTER (WHERE bank_code IS NULL) AS null_key_rows
    FROM core.dim_bank
    UNION ALL
    SELECT 2, 'core.dim_date', COUNT(*), 5113,
        COUNT(DISTINCT calendar_date), COUNT(*) FILTER (WHERE calendar_date IS NULL)
    FROM core.dim_date
    UNION ALL
    SELECT 3, 'mart.fact_bank_monthly', COUNT(*), 356,
        COUNT(DISTINCT (bank_code, report_date)),
        COUNT(*) FILTER (WHERE bank_code IS NULL OR report_date IS NULL)
    FROM mart.fact_bank_monthly
    UNION ALL
    SELECT 4, 'mart.fact_bank_quarterly', COUNT(*), 212,
        COUNT(DISTINCT (bank_code, report_date)),
        COUNT(*) FILTER (WHERE bank_code IS NULL OR report_date IS NULL)
    FROM mart.fact_bank_quarterly
    UNION ALL
    SELECT 5, 'mart.fact_macro_monthly', COUNT(*), 89,
        COUNT(DISTINCT report_date), COUNT(*) FILTER (WHERE report_date IS NULL)
    FROM mart.fact_macro_monthly
    UNION ALL
    SELECT 6, 'mart.fact_macro_quarterly', COUNT(*), 53,
        COUNT(DISTINCT report_date), COUNT(*) FILTER (WHERE report_date IS NULL)
    FROM mart.fact_macro_quarterly
)
SELECT table_name, row_count, expected_rows, unique_keys, null_key_rows,
    CASE WHEN row_count = expected_rows AND unique_keys = row_count
        AND null_key_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM inventory
ORDER BY table_order;

-- 2. Check all six intended dimension-to-fact relationships.
-- Names use bank/date for core.dim_bank/core.dim_date and the fact suffix.
-- Each child key must match exactly one parent key; all parent keys must
-- be unique and non-NULL, including keys not referenced by a current fact.
-- bad_parent_keys counts groups with duplicate rows or a NULL parent key.
-- Expected: six PASS rows; fact_rows = joined_rows = 356/212/356/212/89/53;
-- unmatched_rows and bad_parent_keys are all zero.
WITH bank_keys AS (
    SELECT bank_code, COUNT(*) AS key_rows
    FROM core.dim_bank GROUP BY bank_code
), date_keys AS (
    SELECT calendar_date, COUNT(*) AS key_rows
    FROM core.dim_date GROUP BY calendar_date
), parent_issues AS (
    SELECT
        (SELECT COUNT(*) FROM bank_keys
         WHERE bank_code IS NULL OR key_rows <> 1) AS bad_bank_keys,
        (SELECT COUNT(*) FROM date_keys
         WHERE calendar_date IS NULL OR key_rows <> 1) AS bad_date_keys
), relationships AS (
    SELECT 1 AS relation_order, 'bank -> bank_monthly' AS relationship_name,
        'bank' AS parent_kind, 356 AS expected_rows,
        (SELECT COUNT(*) FROM mart.fact_bank_monthly) AS fact_rows,
        COUNT(*) AS joined_rows,
        COUNT(*) FILTER (WHERE d.bank_code IS NULL) AS unmatched_rows
    FROM mart.fact_bank_monthly AS f
    LEFT JOIN core.dim_bank AS d ON f.bank_code = d.bank_code
    UNION ALL
    SELECT 2, 'bank -> bank_quarterly', 'bank', 212,
        (SELECT COUNT(*) FROM mart.fact_bank_quarterly), COUNT(*),
        COUNT(*) FILTER (WHERE d.bank_code IS NULL)
    FROM mart.fact_bank_quarterly AS f
    LEFT JOIN core.dim_bank AS d ON f.bank_code = d.bank_code
    UNION ALL
    SELECT 3, 'date -> bank_monthly', 'date', 356,
        (SELECT COUNT(*) FROM mart.fact_bank_monthly), COUNT(*),
        COUNT(*) FILTER (WHERE d.calendar_date IS NULL)
    FROM mart.fact_bank_monthly AS f
    LEFT JOIN core.dim_date AS d ON f.report_date = d.calendar_date
    UNION ALL
    SELECT 4, 'date -> bank_quarterly', 'date', 212,
        (SELECT COUNT(*) FROM mart.fact_bank_quarterly), COUNT(*),
        COUNT(*) FILTER (WHERE d.calendar_date IS NULL)
    FROM mart.fact_bank_quarterly AS f
    LEFT JOIN core.dim_date AS d ON f.report_date = d.calendar_date
    UNION ALL
    SELECT 5, 'date -> macro_monthly', 'date', 89,
        (SELECT COUNT(*) FROM mart.fact_macro_monthly), COUNT(*),
        COUNT(*) FILTER (WHERE d.calendar_date IS NULL)
    FROM mart.fact_macro_monthly AS f
    LEFT JOIN core.dim_date AS d ON f.report_date = d.calendar_date
    UNION ALL
    SELECT 6, 'date -> macro_quarterly', 'date', 53,
        (SELECT COUNT(*) FROM mart.fact_macro_quarterly), COUNT(*),
        COUNT(*) FILTER (WHERE d.calendar_date IS NULL)
    FROM mart.fact_macro_quarterly AS f
    LEFT JOIN core.dim_date AS d ON f.report_date = d.calendar_date
), evaluated AS (
    SELECT r.*, CASE WHEN parent_kind = 'bank' THEN p.bad_bank_keys
        ELSE p.bad_date_keys END AS bad_parent_keys
    FROM relationships AS r CROSS JOIN parent_issues AS p
)
SELECT relationship_name, fact_rows, joined_rows, unmatched_rows, bad_parent_keys,
    CASE WHEN fact_rows = expected_rows AND joined_rows = fact_rows
        AND unmatched_rows = 0 AND bad_parent_keys = 0
        THEN 'PASS' ELSE 'FAIL' END AS status
FROM evaluated
ORDER BY relation_order;

-- 3. Trial-join each bank fact to BOTH dimensions and its macro fact.
-- This is a SQL diagnostic, not a proposed fact-to-fact Power BI link.
-- In Power BI, the date dimension will filter all four facts independently;
-- the bank dimension will filter only the two bank facts.
-- unmatched_rows counts joined rows missing ANY bank/date/macro match.
-- A matched macro row with a NULL CPI measure is still a valid match.
-- duplicate_joined_keys counts bank-period groups with more than one row.
-- Expected: two PASS rows; bank_rows = joined_rows = 356 monthly / 212 quarterly;
-- unmatched_rows = duplicate_joined_keys = 0. Do not sum repeated macro values.
WITH joined AS (
    SELECT 'monthly' AS scope_name, b.bank_code, b.report_date,
        d.bank_code IS NULL OR c.calendar_date IS NULL OR m.report_date IS NULL
            AS missing_match
    FROM mart.fact_bank_monthly AS b
    LEFT JOIN core.dim_bank AS d ON b.bank_code = d.bank_code
    LEFT JOIN core.dim_date AS c ON b.report_date = c.calendar_date
    LEFT JOIN mart.fact_macro_monthly AS m ON b.report_date = m.report_date
    UNION ALL
    SELECT 'quarterly', b.bank_code, b.report_date,
        d.bank_code IS NULL OR c.calendar_date IS NULL OR m.report_date IS NULL
    FROM mart.fact_bank_quarterly AS b
    LEFT JOIN core.dim_bank AS d ON b.bank_code = d.bank_code
    LEFT JOIN core.dim_date AS c ON b.report_date = c.calendar_date
    LEFT JOIN mart.fact_macro_quarterly AS m ON b.report_date = m.report_date
), duplicate_keys AS (
    SELECT scope_name, bank_code, report_date
    FROM joined
    GROUP BY scope_name, bank_code, report_date
    HAVING COUNT(*) > 1
), scopes AS (
    SELECT 1 AS scope_order, 'monthly' AS scope_name, 356 AS expected_rows,
        COUNT(*) AS bank_rows FROM mart.fact_bank_monthly
    UNION ALL
    SELECT 2, 'quarterly', 212, COUNT(*) FROM mart.fact_bank_quarterly
), join_counts AS (
    SELECT scope_name, COUNT(*) AS joined_rows,
        COUNT(*) FILTER (WHERE missing_match) AS unmatched_rows
    FROM joined GROUP BY scope_name
), duplicate_counts AS (
    SELECT scope_name, COUNT(*) AS duplicate_joined_keys
    FROM duplicate_keys GROUP BY scope_name
), evaluated AS (
    SELECT s.*, COALESCE(j.joined_rows, 0) AS joined_rows,
        COALESCE(j.unmatched_rows, 0) AS unmatched_rows,
        COALESCE(d.duplicate_joined_keys, 0) AS duplicate_joined_keys
    FROM scopes AS s
    LEFT JOIN join_counts AS j USING (scope_name)
    LEFT JOIN duplicate_counts AS d USING (scope_name)
)
SELECT scope_name, bank_rows, joined_rows, unmatched_rows, duplicate_joined_keys,
    CASE WHEN bank_rows = expected_rows AND joined_rows = bank_rows
        AND unmatched_rows = 0 AND duplicate_joined_keys = 0
        THEN 'PASS' ELSE 'FAIL' END AS status
FROM evaluated
ORDER BY scope_order;
