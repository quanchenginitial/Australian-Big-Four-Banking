let
    Source = Odbc.Query(
        "Driver={DuckDB Driver};"
            & "Database=E:\DuckDB\Australian_Big_Four_Banking\database\australian_big_four_banking.duckdb;"
            & "access_mode=read_only;",
        "SELECT report_date, cash_rate_target_pct, interbank_cash_rate_pct, "
            & "bank_bill_3m_pct, cpi_index, cpi_yoy_pct, cpi_mom_pct "
            & "FROM mart.fact_macro_monthly"
    ),
    #"Changed Type" = Table.TransformColumnTypes(Source, {
        {"report_date", type date},
        {"cash_rate_target_pct", type number},
        {"interbank_cash_rate_pct", type number},
        {"bank_bill_3m_pct", type number},
        {"cpi_index", type number},
        {"cpi_yoy_pct", type number},
        {"cpi_mom_pct", type number}
    })
in
    #"Changed Type"
