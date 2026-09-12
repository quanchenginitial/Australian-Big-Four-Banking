-- Step 5R: audit both ABS Table 18 quarterly detail imports.
-- Requires both raw.abs_cpi_table18_data1_quarterly/data2_quarterly tables,
-- stg.abs_cpi_australia_quarterly (Table 17) and stg.apra_big_four_quarterly.
-- Run each of the five sections as one complete statement. All are read-only.
-- This audit includes ALL 396 series, including NULL cells.
-- Expectations refer to the pinned July 2026 source; review for a new snapshot.

-- 1. Check each source calendar and alignment between the two data sheets.
-- Expected: sixteen issue counts of zero. Both sheets must retain 312 quarters
-- labelled 1948-09-01 through 2026-06-01, on day 1 of March/June/September/December.
-- Row/quarter totals and endpoints also catch a missing first or last quarter.
WITH sheets AS (
    SELECT * FROM (VALUES ('Data1'), ('Data2')) AS s(source_sheet)
), periods AS (
    SELECT 'Data1' AS source_sheet, period_raw FROM raw.abs_cpi_table18_data1_quarterly
    UNION ALL
    SELECT 'Data2' AS source_sheet, period_raw FROM raw.abs_cpi_table18_data2_quarterly
), dates AS (
    SELECT source_sheet,
        CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+')
                 AND TRY_CAST(TRIM(period_raw) AS INTEGER) BETWEEN 0
                     AND DATE_DIFF('day', DATE '1899-12-30', DATE '9999-12-31')
            THEN TRY(DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER))
        END AS source_quarter
    FROM periods
), duplicate_quarters AS (
    SELECT source_sheet, DATE_TRUNC('quarter', source_quarter) AS quarter_start
    FROM dates WHERE source_quarter IS NOT NULL
    GROUP BY source_sheet, quarter_start HAVING COUNT(*) > 1
), counts AS (
    SELECT s.source_sheet,
        ABS(COUNT(d.source_sheet) - 312) AS row_count_difference,
        ABS(COUNT(DISTINCT DATE_TRUNC('quarter', d.source_quarter)) - 312) AS quarter_count_difference,
        COUNT(*) FILTER (WHERE d.source_sheet IS NOT NULL AND d.source_quarter IS NULL) AS invalid_dates,
        COUNT(*) FILTER (WHERE DAY(d.source_quarter) <> 1 OR MONTH(d.source_quarter) NOT IN (3,6,9,12)) AS non_quarter_label_rows,
        COALESCE(DATE_DIFF('quarter', MIN(d.source_quarter), MAX(d.source_quarter)) + 1
            - COUNT(DISTINCT DATE_TRUNC('quarter', d.source_quarter)), 1) AS missing_quarters_in_span,
        CAST(MIN(d.source_quarter) IS DISTINCT FROM DATE '1948-09-01' AS INTEGER)
            + CAST(MAX(d.source_quarter) IS DISTINCT FROM DATE '2026-06-01' AS INTEGER) AS endpoint_mismatches
    FROM sheets s LEFT JOIN dates d USING (source_sheet)
    GROUP BY s.source_sheet
), results AS (
    SELECT c.source_sheet AS scope_name, v.check_order, v.check_name, v.issue_count
    FROM counts c
    CROSS JOIN LATERAL (VALUES
        (1, 'row_count_difference', c.row_count_difference),
        (2, 'quarter_count_difference', c.quarter_count_difference),
        (3, 'invalid_dates', c.invalid_dates),
        (4, 'non_quarter_label_rows', c.non_quarter_label_rows),
        (5, 'duplicate_quarter_groups', (SELECT COUNT(*) FROM duplicate_quarters q WHERE q.source_sheet = c.source_sheet)),
        (6, 'missing_quarters_in_span', c.missing_quarters_in_span),
        (7, 'endpoint_mismatches', c.endpoint_mismatches)
    ) v(check_order, check_name, issue_count)
    UNION ALL
    SELECT 'Cross_sheet', 1, 'dates_only_in_data1', COUNT(*) FROM (
        SELECT source_quarter FROM dates WHERE source_sheet = 'Data1' AND source_quarter IS NOT NULL
        EXCEPT
        SELECT source_quarter FROM dates WHERE source_sheet = 'Data2' AND source_quarter IS NOT NULL
    ) x
    UNION ALL
    SELECT 'Cross_sheet', 2, 'dates_only_in_data2', COUNT(*) FROM (
        SELECT source_quarter FROM dates WHERE source_sheet = 'Data2' AND source_quarter IS NOT NULL
        EXCEPT
        SELECT source_quarter FROM dates WHERE source_sheet = 'Data1' AND source_quarter IS NOT NULL
    ) x
)
SELECT scope_name, check_name, issue_count FROM results ORDER BY scope_name, check_order;

-- 2. Profile all series, keeping NULL cells in the long-form query.
-- Family positions reflect this pinned source layout; section 3 independently
-- verifies the Series IDs, sheet membership and family classification.
-- Each family: 132 series and 41,184 cells checked. All cast failures: zero.
-- index: missing 18,371; negative 0; zero 0.
-- QoQ: missing 18,503; negative 5,537; zero 1,280. Preserve these signs/zeros.
-- contribution: missing 40,788; negative 0; zero 0. Unit is Index Points.
WITH series_columns AS (
    SELECT
        CASE table_name WHEN 'abs_cpi_table18_data1_quarterly' THEN 'Data1'
                        ELSE 'Data2' END AS source_sheet,
        column_name AS series_id,
        CASE
            WHEN table_name = 'abs_cpi_table18_data1_quarterly'
                AND ordinal_position BETWEEN 2 AND 133 THEN 'cpi_index'
            WHEN table_name = 'abs_cpi_table18_data1_quarterly'
                OR ordinal_position BETWEEN 2 AND 15 THEN 'cpi_qoq_pct'
            ELSE 'cpi_contribution_index_points'
        END AS metric
    FROM information_schema.columns
    WHERE table_catalog = CURRENT_DATABASE() AND table_schema = 'raw'
      AND table_name IN ('abs_cpi_table18_data1_quarterly', 'abs_cpi_table18_data2_quarterly')
      AND column_name <> 'period_raw'
),
source_values AS (
    SELECT 'Data1' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data1_quarterly
    UNPIVOT INCLUDE NULLS (raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw))))
    UNION ALL
    SELECT 'Data2' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data2_quarterly
    UNPIVOT INCLUDE NULLS (raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw))))
), typed_values AS (
    SELECT source_sheet, series_id,
        CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+')
                 AND TRY_CAST(TRIM(period_raw) AS INTEGER) BETWEEN 0
                     AND DATE_DIFF('day', DATE '1899-12-30', DATE '9999-12-31')
            THEN TRY(DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER))
        END AS source_quarter,
        NULLIF(TRIM(raw_value), '') AS value_text,
        TRY_CAST(NULLIF(TRIM(raw_value), '') AS DECIMAL(18,6)) AS numeric_value
    FROM source_values
)
SELECT c.metric, COUNT(DISTINCT v.series_id) AS series_count,
    COUNT(*) AS rows_checked,
    COUNT(*) FILTER (WHERE v.value_text IS NULL) AS missing_count,
    COUNT(*) FILTER (WHERE v.value_text IS NOT NULL AND v.numeric_value IS NULL) AS cast_fail_count,
    COUNT(*) FILTER (WHERE v.numeric_value < 0) AS negative_count,
    COUNT(*) FILTER (WHERE v.numeric_value = 0) AS zero_count
FROM typed_values v JOIN series_columns c USING (source_sheet, series_id)
GROUP BY c.metric ORDER BY c.metric;

-- 3. Compare every series against the workbook's recorded coverage metadata.
-- Expected: ten issue counts of zero. The grouped register below contains
-- all 396 source IDs and their declared first date / populated observation count.
-- Common last date: 2026-06-01. Blanks must be before each series' start only.
-- Checking positions catches displaced blanks even when totals remain equal.
-- Nonblank conversion failures remain distinct from missing text (section 2).
-- Index positivity and nonnegative contributions are checks for this snapshot;
-- negative/zero QoQ is retained. No hierarchy is inferred from repeated names.
WITH expected_groups AS (
    SELECT * FROM (VALUES
        ('Data1', 'cpi_index', DATE '1948-09-01', 312, [
            'A2325846C'
        ]),
        ('Data1', 'cpi_index', DATE '1972-09-01', 216, [
            'A2325891R', 'A2326206X', 'A2326251K', 'A2327241X', 'A2327286C', 'A2327376J',
            'A2326161F', 'A2326116V', 'A2326746L', 'A2328861F', 'A2326791X', 'A2328996R',
            'A2325936J', 'A2326386V', 'A2328051C', 'A2325981V', 'A2331876F', 'A2326431V',
            'A2326521X', 'A2326026R', 'A3604403R', 'A3604428K', 'A3604383T', 'A2328276T',
            'A2331021X', 'A2329266F', 'A2326071A', 'A2326656J', 'A2328591T', 'A2328636K',
            'A2326701J', 'A2328816V', 'A2331201J', 'A2326611C'
        ]),
        ('Data1', 'cpi_index', DATE '1980-09-01', 184, [
            'A2327061R', 'A2327106J', 'A2327151V', 'A2327196X', 'A3604358R', 'A2327466L',
            'A2326926W', 'A2326971J', 'A2327016C', 'A2327646W', 'A2327691J', 'A2327781L',
            'A2327736A', 'A2327556T', 'A2327601T', 'A2328951K', 'A2328906X', 'A2327916K',
            'A2327961W', 'A2328006T', 'A2328096J', 'A2328141J', 'A2328186L', 'A3604433C',
            'A2328321T', 'A2328366W', 'A2329221A', 'A2329176A', 'A3604388C', 'A2329041T',
            'A2329131W', 'A2328726R', 'A2328771A', 'A2328681W', 'A2328501A', 'A2328546F',
            'A2329311F', 'A2328456A'
        ]),
        ('Data1', 'cpi_index', DATE '1976-09-01', 200, [
            'A2327511L', 'A2326296R'
        ]),
        ('Data1', 'cpi_index', DATE '1989-09-01', 148, [
            'A2330886T', 'A2330931T', 'A2330976W', 'A3604363J', 'A2329491A', 'A2329536V',
            'A2331741W', 'A3604418F', 'A2331786A', 'A3604368V', 'A2329581F', 'A2329716C',
            'A2329761R', 'A2331921F', 'A2330031K', 'A2331066C', 'A2330076R', 'A2330121R',
            'A2330166V', 'A2331696W', 'A2331111C', 'A2331246L', 'A3604423X', 'A3604443J',
            'A3604408A', 'A2331381C', 'A3602833C', 'A3602878J'
        ]),
        ('Data1', 'cpi_index', DATE '1998-06-01', 113, [
            'A2329806J', 'A2329851V', 'A3604373L', 'A2329941X', 'A3604413V', 'A2329986C',
            'A2329896X', 'A2330211V', 'A3604393W', 'A2330346C', 'A2330391R', 'A2330436J',
            'A2330481V'
        ]),
        ('Data1', 'cpi_index', DATE '1982-03-01', 178, [
            'A2331606F', 'A2326881C', 'A2329356K', 'A2329401K', 'A2331426W', 'A2329446R'
        ]),
        ('Data1', 'cpi_index', DATE '1986-12-01', 159, [
            'A3604438R', 'A2329086W', 'A2328411W'
        ]),
        ('Data1', 'cpi_index', DATE '2000-06-01', 105, [
            'A2331471J', 'A2331516A', 'A2331561L'
        ]),
        ('Data1', 'cpi_index', DATE '2005-06-01', 85, [
            'A2332596F', 'A2332776R'
        ]),
        ('Data1', 'cpi_index', DATE '2011-06-01', 61, [
            'A3604453L', 'A3604448V'
        ]),
        ('Data1', 'cpi_qoq_pct', DATE '1948-12-01', 311, [
            'A2325850V'
        ]),
        ('Data1', 'cpi_qoq_pct', DATE '1972-12-01', 215, [
            'A2325895X', 'A2326210R', 'A2326255V', 'A2327245J', 'A2327290V', 'A2327380X',
            'A2326165R', 'A2326120K', 'A2326750C', 'A2328865R', 'A2326795J', 'A2329000W',
            'A2325940X', 'A2326390K', 'A2328055L', 'A2325985C', 'A2331880W', 'A2326435C',
            'A2326525J', 'A2326030F', 'A3604407X', 'A3604432A', 'A3604387A', 'A2328280J',
            'A2331025J', 'A2329270W', 'A2326075K', 'A2326660X', 'A2328595A', 'A2328640A',
            'A2326705T', 'A2328820K', 'A2331205T', 'A2326615L'
        ]),
        ('Data1', 'cpi_qoq_pct', DATE '1980-12-01', 183, [
            'A2327065X', 'A2327110X', 'A2327155C', 'A2327200C', 'A3604362F', 'A2327470C',
            'A2326930L', 'A2326975T', 'A2327020V', 'A2327650L', 'A2327695T', 'A2327785W',
            'A2327740T', 'A2327560J', 'A2327605A', 'A2328955V', 'A2328910R', 'A2327920A',
            'A2327965F', 'A2328010J', 'A2328100L', 'A2328145T', 'A2328190C', 'A3604437L',
            'A2328325A', 'A2328370L', 'A2329225K', 'A2329180T', 'A3604392V', 'A2329045A',
            'A2329135F', 'A2328730F', 'A2328775K', 'A2328685F', 'A2328505K', 'A2328550W',
            'A2329315R', 'A2328460T'
        ]),
        ('Data1', 'cpi_qoq_pct', DATE '1976-12-01', 199, [
            'A2327515W', 'A2326300V'
        ]),
        ('Data1', 'cpi_qoq_pct', DATE '1989-12-01', 147, [
            'A2330890J', 'A2330935A', 'A2330980L', 'A3604367T', 'A2329495K', 'A2329540K',
            'A2331745F', 'A3604422W', 'A2331790T', 'A3604372K', 'A2329585R', 'A2329720V',
            'A2329765X', 'A2331925R', 'A2330035V', 'A2331070V', 'A2330080F', 'A2330125X',
            'A2330170K', 'A2331700A', 'A2331115L', 'A2331250C', 'A3604427J', 'A3604447T',
            'A3604412T', 'A2331385L'
        ]),
        ('Data1', 'cpi_qoq_pct', DATE '1998-09-01', 112, [
            'A2329810X', 'A2329855C', 'A3604377W', 'A2329945J', 'A3604417C', 'A2329990V',
            'A2329900C', 'A2330215C', 'A3604397F', 'A2330350V', 'A2330395X'
        ]),
        ('Data1', 'cpi_qoq_pct', DATE '1982-06-01', 177, [
            'A2331610W', 'A2326885L', 'A2329360A', 'A2329405V'
        ]),
        ('Data1', 'cpi_qoq_pct', DATE '1987-03-01', 158, [
            'A3604442F', 'A2329090L'
        ]),
        ('Data2', 'cpi_qoq_pct', DATE '1987-03-01', 158, [
            'A2328415F'
        ]),
        ('Data2', 'cpi_qoq_pct', DATE '1998-09-01', 112, [
            'A2330440X', 'A2330485C'
        ]),
        ('Data2', 'cpi_qoq_pct', DATE '1982-06-01', 177, [
            'A2331430L', 'A2329450F'
        ]),
        ('Data2', 'cpi_qoq_pct', DATE '2000-09-01', 104, [
            'A2331475T', 'A2331520T', 'A2331565W'
        ]),
        ('Data2', 'cpi_qoq_pct', DATE '2005-09-01', 84, [
            'A2332600K', 'A2332780F'
        ]),
        ('Data2', 'cpi_qoq_pct', DATE '1989-12-01', 147, [
            'A3602837L', 'A3602882X'
        ]),
        ('Data2', 'cpi_qoq_pct', DATE '2011-09-01', 60, [
            'A3604457W', 'A3604452K'
        ]),
        ('Data2', 'cpi_contribution_index_points', DATE '2025-12-01', 3, [
            'A3597525W', 'A3597570J', 'A3597885A', 'A3598560W', 'A3598605R', 'A3598650A',
            'A3598695F', 'A3597930A', 'A3598740F', 'A3604360A', 'A3598785K', 'A3598830K',
            'A3598875R', 'A3598920R', 'A3597840W', 'A3598425F', 'A3598470T', 'A3598515K',
            'A3601980K', 'A3602025F', 'A3602070T', 'A3604365L', 'A3599055A', 'A3599100A',
            'A3600765A', 'A3600810A', 'A3602655X', 'A3599190T', 'A3604420T', 'A3599145F',
            'A3602700X', 'A3597975F', 'A3598965V', 'A3599010W', 'A3597795W', 'A3598290J',
            'A3600225L', 'A3600180V', 'A3600135J', 'A3598335A', 'A3600270X', 'A3597615A',
            'A3604370F', 'A3600855F', 'A3600900F', 'A3600945K', 'A3598020J', 'A3599235K',
            'A3599280W', 'A3599325R', 'A3600990W', 'A3601035T', 'A3599370A', 'A3597660L',
            'A3602745C', 'A3598065L', 'A3604375T', 'A3601125W', 'A3604415X', 'A3599415V',
            'A3601170J', 'A3598110L', 'A3601080C', 'A3599460F', 'A3602790R', 'A3597705F',
            'A3604405V', 'A3599505X', 'A3604435J', 'A3604430W', 'A3604385W', 'A3601215A',
            'A3599550K', 'A3602115K', 'A3602160W', 'A3599595R', 'A3601260L', 'A3599640R',
            'A3600495L', 'A3601305F', 'A3601350T', 'A3602565V', 'A3600540L', 'A3602610V',
            'A3602205R', 'A3604440A', 'A3600450J', 'A3600360C', 'A3604390R', 'A3600315T',
            'A3600405W', 'A3597750T', 'A3598200T', 'A3599865C', 'A3600000X', 'A3599910C',
            'A3600045C', 'A3599955J', 'A3598245W', 'A3600090R', 'A3602250A', 'A3598155T',
            'A3599775X', 'A3599820X', 'A3602295F', 'A3604425C', 'A3600585T', 'A3604445L',
            'A3604410L', 'A3601395W', 'A3604395A', 'A3598380L', 'A3600630T', 'A3600675W',
            'A3602340F', 'A3601440W', 'A3601485A', 'A3599730V', 'A3599685V', 'A3601530A',
            'A3601575F', 'A3602385K', 'A3600720W', 'A3602430K', 'A3602475R', 'A3602520R',
            'A3603420X', 'A3602835J', 'A3602880V', 'A3604455T', 'A3604450F', 'A3603555J'
        ])
    ) AS g(source_sheet, metric, expected_start, expected_numeric_count, series_ids)
), expected_series AS (
    SELECT source_sheet, metric, expected_start, expected_numeric_count,
           DATE '2026-06-01' AS expected_end, UNNEST(series_ids) AS series_id
    FROM expected_groups
),
series_columns AS (
    SELECT
        CASE table_name WHEN 'abs_cpi_table18_data1_quarterly' THEN 'Data1'
                        ELSE 'Data2' END AS source_sheet,
        column_name AS series_id,
        CASE
            WHEN table_name = 'abs_cpi_table18_data1_quarterly'
                AND ordinal_position BETWEEN 2 AND 133 THEN 'cpi_index'
            WHEN table_name = 'abs_cpi_table18_data1_quarterly'
                OR ordinal_position BETWEEN 2 AND 15 THEN 'cpi_qoq_pct'
            ELSE 'cpi_contribution_index_points'
        END AS metric
    FROM information_schema.columns
    WHERE table_catalog = CURRENT_DATABASE() AND table_schema = 'raw'
      AND table_name IN ('abs_cpi_table18_data1_quarterly', 'abs_cpi_table18_data2_quarterly')
      AND column_name <> 'period_raw'
),
source_values AS (
    SELECT 'Data1' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data1_quarterly
    UNPIVOT INCLUDE NULLS (raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw))))
    UNION ALL
    SELECT 'Data2' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data2_quarterly
    UNPIVOT INCLUDE NULLS (raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw))))
), typed_values AS (
    SELECT source_sheet, series_id,
        CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+')
                 AND TRY_CAST(TRIM(period_raw) AS INTEGER) BETWEEN 0
                     AND DATE_DIFF('day', DATE '1899-12-30', DATE '9999-12-31')
            THEN TRY(DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER))
        END AS source_quarter,
        NULLIF(TRIM(raw_value), '') AS value_text,
        TRY_CAST(NULLIF(TRIM(raw_value), '') AS DECIMAL(18,6)) AS numeric_value
    FROM source_values
), observed AS (
    SELECT source_sheet, series_id, COUNT(*) AS rows_checked,
        COUNT(numeric_value) AS numeric_count,
        MIN(source_quarter) FILTER (WHERE numeric_value IS NOT NULL) AS first_valid,
        MAX(source_quarter) FILTER (WHERE numeric_value IS NOT NULL) AS last_valid
    FROM typed_values GROUP BY source_sheet, series_id
), coverage_checks AS (
    SELECT e.*, o.rows_checked, o.numeric_count, o.first_valid, o.last_valid
    FROM expected_series e LEFT JOIN observed o USING (source_sheet, series_id)
), results AS (
    SELECT 1 AS check_order, 'missing_series_columns' AS check_name, COUNT(*) AS issue_count
    FROM expected_series e LEFT JOIN series_columns c USING (source_sheet, series_id)
    WHERE c.series_id IS NULL
    UNION ALL
    SELECT 2, 'unexpected_series_columns', COUNT(*)
    FROM series_columns c LEFT JOIN expected_series e USING (source_sheet, series_id)
    WHERE e.series_id IS NULL
    UNION ALL
    SELECT 3, 'series_family_mismatches', COUNT(*)
    FROM expected_series e JOIN series_columns c USING (source_sheet, series_id)
    WHERE e.metric IS DISTINCT FROM c.metric
    UNION ALL
    SELECT 4, 'series_row_count_mismatches', COUNT(*) FROM coverage_checks
    WHERE rows_checked IS DISTINCT FROM 312
    UNION ALL
    SELECT 5, 'series_numeric_count_mismatches', COUNT(*) FROM coverage_checks
    WHERE numeric_count IS DISTINCT FROM expected_numeric_count
    UNION ALL
    SELECT 6, 'series_first_date_mismatches', COUNT(*) FROM coverage_checks
    WHERE first_valid IS DISTINCT FROM expected_start
    UNION ALL
    SELECT 7, 'series_last_date_mismatches', COUNT(*) FROM coverage_checks
    WHERE last_valid IS DISTINCT FROM expected_end
    UNION ALL
    SELECT 8, 'unexpected_null_pattern_cells', COUNT(*)
    FROM typed_values v JOIN expected_series e USING (source_sheet, series_id)
    WHERE (v.source_quarter BETWEEN e.expected_start AND e.expected_end AND v.value_text IS NULL)
       OR ((v.source_quarter < e.expected_start OR v.source_quarter > e.expected_end) AND v.value_text IS NOT NULL)
    UNION ALL
    SELECT 9, 'nonpositive_index_cells', COUNT(*)
    FROM typed_values v JOIN expected_series e USING (source_sheet, series_id)
    WHERE e.metric = 'cpi_index' AND v.numeric_value <= 0
    UNION ALL
    SELECT 10, 'negative_contribution_cells', COUNT(*)
    FROM typed_values v JOIN expected_series e USING (source_sheet, series_id)
    WHERE e.metric = 'cpi_contribution_index_points' AND v.numeric_value < 0
)
SELECT check_name, issue_count FROM results ORDER BY check_order;

-- 4. Reconcile All groups CPI against the validated Table 17 staging table.
-- Expected: five PASS rows, matched_quarters 312, all other counts zero.
-- Compare index and published QoQ at DECIMAL(18,6), including the initial NULL.
-- Valid source labels are aligned to quarter ends only for this comparison.
WITH source18 AS (
    SELECT CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+')
                 AND TRY_CAST(TRIM(period_raw) AS INTEGER) BETWEEN 0
                     AND DATE_DIFF('day', DATE '1899-12-30', DATE '9999-12-31')
            THEN TRY(DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER))
        END AS source_quarter,
        TRY_CAST(NULLIF(TRIM("A2325846C"), '') AS DECIMAL(18,6)) AS cpi_index,
        TRY_CAST(NULLIF(TRIM("A2325850V"), '') AS DECIMAL(18,6)) AS cpi_qoq_pct
    FROM raw.abs_cpi_table18_data1_quarterly
), aligned18 AS (
    SELECT 1 AS present18,
        CASE WHEN DAY(source_quarter) = 1 AND MONTH(source_quarter) IN (3,6,9,12)
            THEN LAST_DAY(source_quarter) END AS report_date,
        cpi_index, cpi_qoq_pct FROM source18
), source17 AS (
    SELECT 1 AS present17, report_date, cpi_index, cpi_qoq_pct
    FROM stg.abs_cpi_australia_quarterly
), counts AS (
    SELECT
        COUNT(*) FILTER (WHERE a.present18 IS NOT NULL AND b.present17 IS NOT NULL) AS matched_quarters,
        COUNT(*) FILTER (WHERE a.present18 IS NULL) AS rows_missing_in_table18,
        COUNT(*) FILTER (WHERE b.present17 IS NULL) AS rows_missing_in_table17,
        COUNT(*) FILTER (WHERE a.present18 IS NOT NULL AND b.present17 IS NOT NULL
            AND a.cpi_index IS DISTINCT FROM b.cpi_index) AS index_mismatch_rows,
        COUNT(*) FILTER (WHERE a.present18 IS NOT NULL AND b.present17 IS NOT NULL
            AND a.cpi_qoq_pct IS DISTINCT FROM b.cpi_qoq_pct) AS qoq_mismatch_rows
    FROM aligned18 a FULL OUTER JOIN source17 b USING (report_date)
)
SELECT c.check_name, c.actual_count, c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts CROSS JOIN LATERAL (VALUES
    (1, 'matched_quarters', matched_quarters, 312),
    (2, 'rows_missing_in_table18', rows_missing_in_table18, 0),
    (3, 'rows_missing_in_table17', rows_missing_in_table17, 0),
    (4, 'index_mismatch_rows', index_mismatch_rows, 0),
    (5, 'qoq_mismatch_rows', qoq_mismatch_rows, 0)
) c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;

-- 5. Describe all-series coverage in the 53 distinct ADI quarters (2013Q1-2026Q1).
-- Each family has 132 series, requiring 132 * 53 = 6,996 series-quarter cells.
-- All families: matched_cells 6,996. Index/QoQ: numeric 6,996, unavailable 0.
-- Contribution: numeric 264 (132 * 2 quarters), unavailable 6,732.
-- Only 2025Q4 and 2026Q1 contributions fall within ADI's period; preserve blanks.
-- Matched/numeric counts retain duplicate inflation; unavailable counts use
-- distinct required series/quarter pairs. Read with sections 1-3.
-- Numeric coverage does not establish financial reporting comparability.
WITH series_columns AS (
    SELECT
        CASE table_name WHEN 'abs_cpi_table18_data1_quarterly' THEN 'Data1'
                        ELSE 'Data2' END AS source_sheet,
        column_name AS series_id,
        CASE
            WHEN table_name = 'abs_cpi_table18_data1_quarterly'
                AND ordinal_position BETWEEN 2 AND 133 THEN 'cpi_index'
            WHEN table_name = 'abs_cpi_table18_data1_quarterly'
                OR ordinal_position BETWEEN 2 AND 15 THEN 'cpi_qoq_pct'
            ELSE 'cpi_contribution_index_points'
        END AS metric
    FROM information_schema.columns
    WHERE table_catalog = CURRENT_DATABASE() AND table_schema = 'raw'
      AND table_name IN ('abs_cpi_table18_data1_quarterly', 'abs_cpi_table18_data2_quarterly')
      AND column_name <> 'period_raw'
),
source_values AS (
    SELECT 'Data1' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data1_quarterly
    UNPIVOT INCLUDE NULLS (raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw))))
    UNION ALL
    SELECT 'Data2' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data2_quarterly
    UNPIVOT INCLUDE NULLS (raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw))))
), typed_values AS (
    SELECT source_sheet, series_id,
        CASE WHEN REGEXP_FULL_MATCH(TRIM(period_raw), '[0-9]+')
                 AND TRY_CAST(TRIM(period_raw) AS INTEGER) BETWEEN 0
                     AND DATE_DIFF('day', DATE '1899-12-30', DATE '9999-12-31')
            THEN TRY(DATE '1899-12-30' + TRY_CAST(TRIM(period_raw) AS INTEGER))
        END AS source_quarter,
        NULLIF(TRIM(raw_value), '') AS value_text,
        TRY_CAST(NULLIF(TRIM(raw_value), '') AS DECIMAL(18,6)) AS numeric_value
    FROM source_values
), required_quarters AS (
    SELECT DISTINCT CAST(DATE_TRUNC('quarter', report_date) AS DATE) AS quarter_start
    FROM stg.apra_big_four_quarterly
)
SELECT c.metric, COUNT(DISTINCT c.series_id) AS series_count,
    COUNT(DISTINCT (c.source_sheet, c.series_id, r.quarter_start)) AS required_cells,
    COUNT(v.series_id) AS matched_cells,
    COUNT(v.numeric_value) AS numeric_cells,
    COUNT(DISTINCT (c.source_sheet, c.series_id, r.quarter_start))
        - COUNT(DISTINCT (c.source_sheet, c.series_id, r.quarter_start)) FILTER
            (WHERE v.numeric_value IS NOT NULL) AS unavailable_cells
FROM series_columns c CROSS JOIN required_quarters r
LEFT JOIN typed_values v ON c.source_sheet = v.source_sheet AND c.series_id = v.series_id
    AND CAST(DATE_TRUNC('quarter', v.source_quarter) AS DATE) = r.quarter_start
    AND DAY(v.source_quarter) = 1 AND MONTH(v.source_quarter) IN (3,6,9,12)
GROUP BY c.metric ORDER BY c.metric;
