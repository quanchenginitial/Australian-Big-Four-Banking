-- Step 5B: audit the 212 quarterly records for the four mapped banks.
-- Prerequisites: raw.apra_adi_quarterly and core.dim_bank.
-- All three statements are read-only and can be run separately in DBeaver.
-- Publication and entity dates remain separate; amounts are AUD million.
-- Ratios are decimal fractions, and liquidity ratios can validly exceed 1.

-- 1. Check dates and the normalized bank/publication-period key.
WITH bank_dates AS (
    SELECT
        b.bank_code,
        DATE '1899-12-30'
            + TRY_CAST(TRIM(r."Period") AS INTEGER) AS period_date,
        DATE '1899-12-30'
            + TRY_CAST(TRIM(r."Entity quarter end") AS INTEGER) AS entity_date
    FROM raw.apra_adi_quarterly AS r
    JOIN core.dim_bank AS b
        ON TRIM(r."ABN") = TRIM(b.bank_abn)
), duplicate_keys AS (
    SELECT bank_code, period_date
    FROM bank_dates
    GROUP BY bank_code, period_date
    HAVING COUNT(*) > 1
), checks AS (
    SELECT
        COUNT(*) FILTER (WHERE period_date IS NULL) AS invalid_period_dates,
        COUNT(*) FILTER (WHERE entity_date IS NULL) AS invalid_entity_dates,
        COUNT(*) FILTER (
            WHERE period_date <> LAST_DAY(period_date)
               OR MONTH(period_date) NOT IN (3, 6, 9, 12)
        ) AS period_not_quarter_end,
        COUNT(*) FILTER (
            WHERE entity_date <> LAST_DAY(entity_date)
               OR MONTH(entity_date) NOT IN (3, 6, 9, 12)
        ) AS entity_not_quarter_end,
        COUNT(*) FILTER (
            WHERE period_date <> entity_date
        ) AS period_entity_mismatch,
        (SELECT COUNT(*) FROM duplicate_keys) AS duplicate_bank_period_groups
    FROM bank_dates
)
SELECT v.check_name, v.issue_count
FROM checks AS c
CROSS JOIN LATERAL (
    VALUES
        ('invalid_period_dates', c.invalid_period_dates),
        ('invalid_entity_dates', c.invalid_entity_dates),
        ('period_not_quarter_end', c.period_not_quarter_end),
        ('entity_not_quarter_end', c.entity_not_quarter_end),
        ('period_entity_mismatch', c.period_entity_mismatch),
        ('duplicate_bank_period_groups', c.duplicate_bank_period_groups)
) AS v(check_name, issue_count)
ORDER BY check_name;

-- 2. Check four capital amounts and six capital/liquidity ratios.
-- Missing values are counted separately from nonblank conversion failures.
-- Negative/zero counts are diagnostic; no values are changed or filled.
WITH values_long AS (
    SELECT
        m.metric,
        NULLIF(TRIM(m.raw_value), '') AS value_text
    FROM raw.apra_adi_quarterly AS r
    JOIN core.dim_bank AS b
        ON TRIM(r."ABN") = TRIM(b.bank_abn)
    CROSS JOIN LATERAL (
        VALUES
            ('cet1_capital_million', r."Total Common Equity Tier 1 capital"),
            ('tier1_capital_million', r."Total Tier 1 capital"),
            ('total_capital_million', r."Total capital base"),
            ('rwa_million', r."Total risk-weighted assets"),
            ('cet1_ratio', r."Common Equity Tier 1 capital ratio"),
            ('tier1_ratio', r."Tier 1 capital ratio"),
            ('total_capital_ratio', r."Total capital ratio"),
            ('lcr_ratio', r."Mean Liquidity coverage ratio (LCR)"),
            ('nsfr_ratio', r."Net stable funding ratio (NSFR)"),
            ('mlh_ratio', r."Average Minimum liquidity holdings ratio (MLH)")
    ) AS m(metric, raw_value)
), typed AS (
    SELECT
        metric,
        value_text,
        TRY_CAST(value_text AS DECIMAL(20, 6)) AS value_num
    FROM values_long
)
SELECT
    metric,
    COUNT(*) AS rows_checked,
    COUNT(*) FILTER (WHERE value_text IS NULL) AS missing_count,
    COUNT(*) FILTER (
        WHERE value_text IS NOT NULL AND value_num IS NULL
    ) AS cast_fail_count,
    COUNT(*) FILTER (WHERE value_num < 0) AS negative_count,
    COUNT(*) FILTER (WHERE value_num = 0) AS zero_count
FROM typed
GROUP BY metric
ORDER BY metric;

-- 3. Locate the observed coverage of each liquidity metric for each bank.
-- gaps counts absent/non-numeric values within the observed valid date span.
-- A completely missing series has NULL first_date, last_date and gaps.
-- Compare endpoints with the source's collection history as well as gaps.
WITH liquidity AS (
    SELECT
        b.bank_code,
        m.metric,
        DATE '1899-12-30'
            + TRY_CAST(TRIM(r."Period") AS INTEGER) AS period_date,
        TRY_CAST(NULLIF(TRIM(m.raw_value), '') AS DECIMAL(20, 6)) AS ratio_value
    FROM raw.apra_adi_quarterly AS r
    JOIN core.dim_bank AS b
        ON TRIM(r."ABN") = TRIM(b.bank_abn)
    CROSS JOIN LATERAL (
        VALUES
            ('LCR', r."Mean Liquidity coverage ratio (LCR)"),
            ('NSFR', r."Net stable funding ratio (NSFR)"),
            ('MLH', r."Average Minimum liquidity holdings ratio (MLH)")
    ) AS m(metric, raw_value)
), coverage AS (
    SELECT
        bank_code,
        metric,
        COUNT(DISTINCT period_date) FILTER (
            WHERE ratio_value IS NOT NULL
        ) AS valid_quarters,
        MIN(period_date) FILTER (WHERE ratio_value IS NOT NULL) AS first_date,
        MAX(period_date) FILTER (WHERE ratio_value IS NOT NULL) AS last_date
    FROM liquidity
    GROUP BY bank_code, metric
)
SELECT
    bank_code,
    metric,
    valid_quarters,
    first_date,
    last_date,
    DATE_DIFF('quarter', first_date, last_date) + 1 - valid_quarters AS gaps
FROM coverage
ORDER BY bank_code, metric;
