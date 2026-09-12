-- Step 5S: create the typed Australia quarterly CPI detail table.
-- Requires both Table 18 raw tables and a successful complete 17 audit.
-- Pinned source: 06_ABS_CPI_Table18_Quarterly_Detail_Jul2026.xlsx.
-- Keep all 396 series x 312 quarters, including every unavailable observation.
-- Section 2 creates the table once; sections 3-6 are repeatable checks.

-- 1. Ensure the staging schema exists.
CREATE SCHEMA IF NOT EXISTS stg;

-- 2. Preserve each series-quarter cell and attach its source metadata.
-- Run the whole CREATE TABLE statement, including all 396 VALUES rows.
-- The fixed register comes from workbook descriptions, units and Series IDs.
-- Match by source sheet and exact ID, not column position or category name.
-- category_name is the trimmed middle part of "measure ; category ; Australia ;".
-- Repeated names belong to distinct IDs; no hierarchy or pairing is invented.
-- INCLUDE NULLS retains unavailable history. UNION ALL retains both sheets.
-- LEFT JOIN keeps an unknown raw series visible for the metadata checks.
-- Strict CAST rejects invalid nonblank numeric text; no filling or filtering.
-- Source labels are day 1 of the quarter's LAST month (3/6/9/12).
-- LAST_DAY maps these audited labels to quarter ends, not publication dates.
-- Index reference: September MONTH 2025 = 100; September QUARTER stays 99.73.
-- QoQ is in per-cent units (0.6 means 0.6%). Contributions are Index Points.
-- Values from different metrics or overlapping category levels are not additive.
-- CREATE TABLE fails if the table exists, without replacing it.
CREATE TABLE stg.abs_cpi_australia_quarterly_detail AS
WITH series_register(source_sheet, series_id, category_name, metric, unit) AS (
    VALUES
        ('Data1', 'A2325846C', 'All groups CPI', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2325891R', 'Food and non-alcoholic beverages', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326206X', 'Bread and cereal products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327061R', 'Bread', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327106J', 'Cakes and biscuits', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327151V', 'Breakfast cereals', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327196X', 'Other cereal products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326251K', 'Meat and seafoods', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327241X', 'Beef and veal', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604358R', 'Pork', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327286C', 'Lamb and goat', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327376J', 'Poultry', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327466L', 'Other meats', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327511L', 'Fish and other seafood', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326161F', 'Dairy and related products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326926W', 'Milk', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326971J', 'Cheese', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327016C', 'Ice cream and other dairy products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330886T', 'Fruit and vegetables', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330931T', 'Fruit', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330976W', 'Vegetables', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604363J', 'Food products n.e.c.', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327646W', 'Eggs', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327691J', 'Jams, honey and spreads', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329491A', 'Food additives and condiments', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329536V', 'Oils and fats', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331741W', 'Snacks and confectionery', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327781L', 'Other food products n.e.c.', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604418F', 'Non-alcoholic beverages', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327736A', 'Coffee, tea and cocoa', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331786A', 'Waters, soft drinks and juices', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326296R', 'Meals out and take away foods', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327556T', 'Restaurant meals', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327601T', 'Take away and fast foods', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326116V', 'Alcohol and tobacco', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326746L', 'Alcoholic beverages', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328951K', 'Spirits', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328906X', 'Wine', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328861F', 'Beer', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326791X', 'Tobacco', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328996R', 'Tobacco', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2325936J', 'Clothing and footwear', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604368V', 'Garments', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329581F', 'Garments for men', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329716C', 'Garments for women', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329761R', 'Garments for infants and children', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326386V', 'Footwear', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327916K', 'Footwear for men', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2327961W', 'Footwear for women', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328006T', 'Footwear for infants and children', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329806J', 'Accessories and clothing services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329851V', 'Accessories', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328051C', 'Cleaning, repair and hire of clothing and footwear', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2325981V', 'Housing', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331876F', 'Rents', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326431V', 'Rents', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604373L', 'New dwelling purchase by owner-occupiers', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329941X', 'New dwelling purchase by owner-occupiers', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604413V', 'Other housing', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328096J', 'Maintenance and repair of the dwelling', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329986C', 'Property rates and charges', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326521X', 'Utilities', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329896X', 'Water and sewerage', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328141J', 'Electricity', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331921F', 'Gas and other household fuels', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326026R', 'Furnishings, household equipment and services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604403R', 'Furniture and furnishings', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328186L', 'Furniture', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604433C', 'Carpets and other floor coverings', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604428K', 'Household textiles', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604383T', 'Household textiles', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330031K', 'Household appliances, utensils and tools', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328276T', 'Major household appliances', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331021X', 'Small electric household appliances', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331066C', 'Glassware, tableware and household utensils', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328321T', 'Tools and equipment for house and garden', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330076R', 'Non-durable household products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328366W', 'Cleaning and maintenance products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329221A', 'Personal care products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330121R', 'Other non-durable household products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330166V', 'Domestic and household services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331606F', 'Child care', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329266F', 'Hairdressing and personal grooming services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331696W', 'Other household services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331111C', 'Health', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604438R', 'Medical products, appliances and equipment', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329176A', 'Pharmaceutical products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329086W', 'Therapeutic appliances and equipment', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604388C', 'Medical, dental and hospital services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329041T', 'Medical and hospital services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329131W', 'Dental services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326071A', 'Transport', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326656J', 'Private motoring', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328591T', 'Motor vehicles', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328726R', 'Spare parts and accessories for motor vehicles', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328636K', 'Automotive fuel', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328771A', 'Maintenance and repair of motor vehicles', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328681W', 'Other services in respect of motor vehicles', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326701J', 'Urban transport fares', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328816V', 'Urban transport fares', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331201J', 'Communication', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326611C', 'Communication', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328501A', 'Postal services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328546F', 'Telecommunication equipment and services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331246L', 'Recreation and culture', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604423X', 'Audio, visual and computing equipment and services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329311F', 'Audio, visual and computing equipment', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604443J', 'Audio, visual and computing media and services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604408A', 'Newspapers, books and stationery', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330211V', 'Books', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604393W', 'Newspapers, magazines and stationery', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2326881C', 'Holiday travel and accommodation', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329356K', 'Domestic holiday travel and accommodation', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329401K', 'International holiday travel and accommodation', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331381C', 'Other recreation, sport and culture', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330346C', 'Equipment for sports, camping and open-air recreation', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330391R', 'Games, toys and hobbies', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328456A', 'Pets and related products', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2328411W', 'Veterinary and other services for pets', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330436J', 'Sports participation', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2330481V', 'Other recreational, sporting and cultural services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331426W', 'Education', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2329446R', 'Education', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331471J', 'Preschool and primary education', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331516A', 'Secondary education', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2331561L', 'Tertiary education', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2332596F', 'Insurance and financial services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3602833C', 'Insurance', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3602878J', 'Insurance', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604453L', 'Financial services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A3604448V', 'Deposit and loan facilities (direct charges)', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2332776R', 'Other financial services', 'cpi_index', 'Index Numbers'),
        ('Data1', 'A2325850V', 'All groups CPI', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2325895X', 'Food and non-alcoholic beverages', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326210R', 'Bread and cereal products', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327065X', 'Bread', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327110X', 'Cakes and biscuits', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327155C', 'Breakfast cereals', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327200C', 'Other cereal products', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326255V', 'Meat and seafoods', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327245J', 'Beef and veal', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604362F', 'Pork', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327290V', 'Lamb and goat', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327380X', 'Poultry', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327470C', 'Other meats', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327515W', 'Fish and other seafood', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326165R', 'Dairy and related products', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326930L', 'Milk', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326975T', 'Cheese', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327020V', 'Ice cream and other dairy products', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330890J', 'Fruit and vegetables', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330935A', 'Fruit', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330980L', 'Vegetables', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604367T', 'Food products n.e.c.', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327650L', 'Eggs', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327695T', 'Jams, honey and spreads', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329495K', 'Food additives and condiments', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329540K', 'Oils and fats', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331745F', 'Snacks and confectionery', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327785W', 'Other food products n.e.c.', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604422W', 'Non-alcoholic beverages', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327740T', 'Coffee, tea and cocoa', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331790T', 'Waters, soft drinks and juices', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326300V', 'Meals out and take away foods', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327560J', 'Restaurant meals', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327605A', 'Take away and fast foods', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326120K', 'Alcohol and tobacco', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326750C', 'Alcoholic beverages', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328955V', 'Spirits', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328910R', 'Wine', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328865R', 'Beer', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326795J', 'Tobacco', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329000W', 'Tobacco', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2325940X', 'Clothing and footwear', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604372K', 'Garments', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329585R', 'Garments for men', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329720V', 'Garments for women', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329765X', 'Garments for infants and children', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326390K', 'Footwear', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327920A', 'Footwear for men', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2327965F', 'Footwear for women', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328010J', 'Footwear for infants and children', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329810X', 'Accessories and clothing services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329855C', 'Accessories', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328055L', 'Cleaning, repair and hire of clothing and footwear', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2325985C', 'Housing', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331880W', 'Rents', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326435C', 'Rents', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604377W', 'New dwelling purchase by owner-occupiers', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329945J', 'New dwelling purchase by owner-occupiers', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604417C', 'Other housing', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328100L', 'Maintenance and repair of the dwelling', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329990V', 'Property rates and charges', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326525J', 'Utilities', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329900C', 'Water and sewerage', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328145T', 'Electricity', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331925R', 'Gas and other household fuels', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326030F', 'Furnishings, household equipment and services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604407X', 'Furniture and furnishings', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328190C', 'Furniture', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604437L', 'Carpets and other floor coverings', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604432A', 'Household textiles', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604387A', 'Household textiles', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330035V', 'Household appliances, utensils and tools', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328280J', 'Major household appliances', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331025J', 'Small electric household appliances', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331070V', 'Glassware, tableware and household utensils', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328325A', 'Tools and equipment for house and garden', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330080F', 'Non-durable household products', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328370L', 'Cleaning and maintenance products', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329225K', 'Personal care products', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330125X', 'Other non-durable household products', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330170K', 'Domestic and household services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331610W', 'Child care', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329270W', 'Hairdressing and personal grooming services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331700A', 'Other household services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331115L', 'Health', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604442F', 'Medical products, appliances and equipment', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329180T', 'Pharmaceutical products', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329090L', 'Therapeutic appliances and equipment', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604392V', 'Medical, dental and hospital services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329045A', 'Medical and hospital services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329135F', 'Dental services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326075K', 'Transport', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326660X', 'Private motoring', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328595A', 'Motor vehicles', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328730F', 'Spare parts and accessories for motor vehicles', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328640A', 'Automotive fuel', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328775K', 'Maintenance and repair of motor vehicles', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328685F', 'Other services in respect of motor vehicles', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326705T', 'Urban transport fares', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328820K', 'Urban transport fares', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331205T', 'Communication', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326615L', 'Communication', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328505K', 'Postal services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328550W', 'Telecommunication equipment and services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331250C', 'Recreation and culture', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604427J', 'Audio, visual and computing equipment and services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329315R', 'Audio, visual and computing equipment', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604447T', 'Audio, visual and computing media and services', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604412T', 'Newspapers, books and stationery', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330215C', 'Books', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A3604397F', 'Newspapers, magazines and stationery', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2326885L', 'Holiday travel and accommodation', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329360A', 'Domestic holiday travel and accommodation', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2329405V', 'International holiday travel and accommodation', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2331385L', 'Other recreation, sport and culture', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330350V', 'Equipment for sports, camping and open-air recreation', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2330395X', 'Games, toys and hobbies', 'cpi_qoq_pct', 'Percent'),
        ('Data1', 'A2328460T', 'Pets and related products', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2328415F', 'Veterinary and other services for pets', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2330440X', 'Sports participation', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2330485C', 'Other recreational, sporting and cultural services', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2331430L', 'Education', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2329450F', 'Education', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2331475T', 'Preschool and primary education', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2331520T', 'Secondary education', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2331565W', 'Tertiary education', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2332600K', 'Insurance and financial services', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A3602837L', 'Insurance', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A3602882X', 'Insurance', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A3604457W', 'Financial services', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A3604452K', 'Deposit and loan facilities (direct charges)', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A2332780F', 'Other financial services', 'cpi_qoq_pct', 'Percent'),
        ('Data2', 'A3597525W', 'All groups CPI', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597570J', 'Food and non-alcoholic beverages', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597885A', 'Bread and cereal products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598560W', 'Bread', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598605R', 'Cakes and biscuits', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598650A', 'Breakfast cereals', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598695F', 'Other cereal products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597930A', 'Meat and seafoods', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598740F', 'Beef and veal', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604360A', 'Pork', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598785K', 'Lamb and goat', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598830K', 'Poultry', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598875R', 'Other meats', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598920R', 'Fish and other seafood', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597840W', 'Dairy and related products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598425F', 'Milk', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598470T', 'Cheese', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598515K', 'Ice cream and other dairy products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601980K', 'Fruit and vegetables', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602025F', 'Fruit', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602070T', 'Vegetables', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604365L', 'Food products n.e.c.', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599055A', 'Eggs', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599100A', 'Jams, honey and spreads', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600765A', 'Food additives and condiments', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600810A', 'Oils and fats', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602655X', 'Snacks and confectionery', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599190T', 'Other food products n.e.c.', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604420T', 'Non-alcoholic beverages', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599145F', 'Coffee, tea and cocoa', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602700X', 'Waters, soft drinks and juices', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597975F', 'Meals out and take away foods', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598965V', 'Restaurant meals', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599010W', 'Take away and fast foods', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597795W', 'Alcohol and tobacco', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598290J', 'Alcoholic beverages', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600225L', 'Spirits', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600180V', 'Wine', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600135J', 'Beer', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598335A', 'Tobacco', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600270X', 'Tobacco', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597615A', 'Clothing and footwear', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604370F', 'Garments', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600855F', 'Garments for men', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600900F', 'Garments for women', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600945K', 'Garments for infants and children', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598020J', 'Footwear', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599235K', 'Footwear for men', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599280W', 'Footwear for women', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599325R', 'Footwear for infants and children', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600990W', 'Accessories and clothing services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601035T', 'Accessories', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599370A', 'Cleaning, repair and hire of clothing and footwear', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597660L', 'Housing', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602745C', 'Rents', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598065L', 'Rents', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604375T', 'New dwelling purchase by owner-occupiers', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601125W', 'New dwelling purchase by owner-occupiers', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604415X', 'Other housing', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599415V', 'Maintenance and repair of the dwelling', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601170J', 'Property rates and charges', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598110L', 'Utilities', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601080C', 'Water and sewerage', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599460F', 'Electricity', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602790R', 'Gas and other household fuels', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597705F', 'Furnishings, household equipment and services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604405V', 'Furniture and furnishings', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599505X', 'Furniture', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604435J', 'Carpets and other floor coverings', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604430W', 'Household textiles', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604385W', 'Household textiles', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601215A', 'Household appliances, utensils and tools', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599550K', 'Major household appliances', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602115K', 'Small electric household appliances', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602160W', 'Glassware, tableware and household utensils', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599595R', 'Tools and equipment for house and garden', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601260L', 'Non-durable household products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599640R', 'Cleaning and maintenance products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600495L', 'Personal care products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601305F', 'Other non-durable household products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601350T', 'Domestic and household services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602565V', 'Child care', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600540L', 'Hairdressing and personal grooming services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602610V', 'Other household services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602205R', 'Health', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604440A', 'Medical products, appliances and equipment', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600450J', 'Pharmaceutical products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600360C', 'Therapeutic appliances and equipment', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604390R', 'Medical, dental and hospital services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600315T', 'Medical and hospital services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600405W', 'Dental services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3597750T', 'Transport', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598200T', 'Private motoring', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599865C', 'Motor vehicles', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600000X', 'Spare parts and accessories for motor vehicles', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599910C', 'Automotive fuel', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600045C', 'Maintenance and repair of motor vehicles', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599955J', 'Other services in respect of motor vehicles', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598245W', 'Urban transport fares', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600090R', 'Urban transport fares', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602250A', 'Communication', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598155T', 'Communication', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599775X', 'Postal services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599820X', 'Telecommunication equipment and services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602295F', 'Recreation and culture', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604425C', 'Audio, visual and computing equipment and services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600585T', 'Audio, visual and computing equipment', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604445L', 'Audio, visual and computing media and services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604410L', 'Newspapers, books and stationery', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601395W', 'Books', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604395A', 'Newspapers, magazines and stationery', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3598380L', 'Holiday travel and accommodation', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600630T', 'Domestic holiday travel and accommodation', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600675W', 'International holiday travel and accommodation', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602340F', 'Other recreation, sport and culture', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601440W', 'Equipment for sports, camping and open-air recreation', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601485A', 'Games, toys and hobbies', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599730V', 'Pets and related products', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3599685V', 'Veterinary and other services for pets', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601530A', 'Sports participation', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3601575F', 'Other recreational, sporting and cultural services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602385K', 'Education', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3600720W', 'Education', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602430K', 'Preschool and primary education', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602475R', 'Secondary education', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602520R', 'Tertiary education', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3603420X', 'Insurance and financial services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602835J', 'Insurance', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3602880V', 'Insurance', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604455T', 'Financial services', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3604450F', 'Deposit and loan facilities (direct charges)', 'cpi_contribution_index_points', 'Index Points'),
        ('Data2', 'A3603555J', 'Other financial services', 'cpi_contribution_index_points', 'Index Points')
), raw_values AS (
    SELECT 'Data1' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data1_quarterly
    UNPIVOT INCLUDE NULLS (
        raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw)))
    )
    UNION ALL
    SELECT 'Data2' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data2_quarterly
    UNPIVOT INCLUDE NULLS (
        raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw)))
    )
)
SELECT
    LAST_DAY(DATE '1899-12-30' + CAST(TRIM(r.period_raw) AS INTEGER)) AS report_date,
    r.series_id,
    m.category_name,
    m.metric,
    m.unit,
    r.source_sheet,
    CAST(NULLIF(TRIM(r.raw_value), '') AS DECIMAL(18, 6)) AS metric_value
FROM raw_values AS r
LEFT JOIN series_register AS m
    ON r.source_sheet = m.source_sheet AND r.series_id = m.series_id;

-- 3. Inspect the seven columns and their types.
-- report_date DATE; series_id/category_name/metric/unit/source_sheet VARCHAR;
-- metric_value DECIMAL(18,6).
DESCRIBE stg.abs_cpi_australia_quarterly_detail;

-- 4. Check the retained series and calendar.
-- Expected: 123552 rows, 396 series, 312 quarters, 1948-09-30 to 2026-06-30.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT series_id) AS series_count,
    COUNT(DISTINCT DATE_TRUNC('quarter', report_date)) AS quarter_count,
    MIN(report_date) AS first_date,
    MAX(report_date) AS last_date
FROM stg.abs_cpi_australia_quarterly_detail;

-- 5. Validate keys, metadata, complete per-series calendars and source patterns.
-- Expected: fifteen PASS rows. Nonzero expected counts preserve source data.
-- Snapshot counts must be reviewed when the source workbook changes.
-- No uniqueness or NOT NULL constraints are added by this CREATE AS SELECT.
WITH duplicate_keys AS (
    SELECT series_id, DATE_TRUNC('quarter', report_date) AS report_quarter
    FROM stg.abs_cpi_australia_quarterly_detail
    GROUP BY series_id, report_quarter
    HAVING COUNT(*) > 1
), series_calendars AS (
    SELECT series_id
    FROM stg.abs_cpi_australia_quarterly_detail
    GROUP BY series_id
    HAVING COUNT(*) <> 312
        OR COUNT(DISTINCT DATE_TRUNC('quarter', report_date)) <> 312
        OR MIN(report_date) IS DISTINCT FROM DATE '1948-09-30'
        OR MAX(report_date) IS DISTINCT FROM DATE '2026-06-30'
), counts AS (
    SELECT
        ABS(COUNT(*) - 123552) AS row_count_difference,
        ABS(COUNT(DISTINCT series_id) - 396) AS series_count_difference,
        (SELECT COUNT(*) FROM duplicate_keys) AS duplicate_series_quarter_keys,
        COUNT(*) FILTER (
            WHERE report_date IS NULL OR NULLIF(TRIM(series_id), '') IS NULL
        ) AS missing_key_rows,
        COUNT(*) FILTER (
            WHERE NULLIF(TRIM(category_name), '') IS NULL
               OR NULLIF(TRIM(metric), '') IS NULL
               OR NULLIF(TRIM(unit), '') IS NULL
               OR NULLIF(TRIM(source_sheet), '') IS NULL
        ) AS missing_metadata_rows,
        COUNT(*) FILTER (
            WHERE NOT COALESCE(
                (metric = 'cpi_index' AND unit = 'Index Numbers' AND source_sheet = 'Data1')
                OR (metric = 'cpi_qoq_pct' AND unit = 'Percent' AND source_sheet IN ('Data1', 'Data2'))
                OR (metric = 'cpi_contribution_index_points' AND unit = 'Index Points' AND source_sheet = 'Data2'),
                FALSE
            )
        ) AS invalid_metric_unit_rows,
        COUNT(*) FILTER (
            WHERE report_date <> LAST_DAY(report_date)
               OR MONTH(report_date) NOT IN (3, 6, 9, 12)
        ) AS non_quarter_end_rows,
        (SELECT COUNT(*) FROM series_calendars) AS series_calendar_mismatches,
        COUNT(*) FILTER (WHERE metric = 'cpi_index' AND metric_value IS NULL) AS cpi_index_missing,
        COUNT(*) FILTER (WHERE metric = 'cpi_qoq_pct' AND metric_value IS NULL) AS cpi_qoq_missing,
        COUNT(*) FILTER (WHERE metric = 'cpi_contribution_index_points' AND metric_value IS NULL) AS cpi_contribution_missing,
        COUNT(*) FILTER (WHERE metric = 'cpi_index' AND metric_value <= 0) AS nonpositive_index_values,
        COUNT(*) FILTER (WHERE metric = 'cpi_contribution_index_points' AND metric_value < 0) AS negative_contribution_values,
        COUNT(*) FILTER (WHERE metric = 'cpi_qoq_pct' AND metric_value < 0) AS cpi_qoq_negative,
        COUNT(*) FILTER (WHERE metric = 'cpi_qoq_pct' AND metric_value = 0) AS cpi_qoq_zero
    FROM stg.abs_cpi_australia_quarterly_detail
)
SELECT
    c.check_name,
    c.actual_count,
    c.expected_count,
    CASE WHEN c.actual_count = c.expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
CROSS JOIN LATERAL (
    VALUES
        (1, 'row_count_difference', row_count_difference, 0),
        (2, 'series_count_difference', series_count_difference, 0),
        (3, 'duplicate_series_quarter_keys', duplicate_series_quarter_keys, 0),
        (4, 'missing_key_rows', missing_key_rows, 0),
        (5, 'missing_metadata_rows', missing_metadata_rows, 0),
        (6, 'invalid_metric_unit_rows', invalid_metric_unit_rows, 0),
        (7, 'non_quarter_end_rows', non_quarter_end_rows, 0),
        (8, 'series_calendar_mismatches', series_calendar_mismatches, 0),
        (9, 'cpi_index_missing', cpi_index_missing, 18371),
        (10, 'cpi_qoq_missing', cpi_qoq_missing, 18503),
        (11, 'cpi_contribution_missing', cpi_contribution_missing, 40788),
        (12, 'nonpositive_index_values', nonpositive_index_values, 0),
        (13, 'negative_contribution_values', negative_contribution_values, 0),
        (14, 'cpi_qoq_negative', cpi_qoq_negative, 5537),
        (15, 'cpi_qoq_zero', cpi_qoq_zero, 1280)
) AS c(check_order, check_name, actual_count, expected_count)
ORDER BY c.check_order;

-- 6. Reconcile every typed date, ID, sheet and value against both raw tables.
-- Expected: two PASS rows, both differences 0.
-- EXCEPT ALL retains duplicate multiplicity and treats corresponding NULLs as equal.
-- This checks transformation fidelity, not the independent accuracy of ABS data.
-- Metadata mappings are fixed in section 2 and independently checked to the workbook.
WITH raw_values AS (
    SELECT 'Data1' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data1_quarterly
    UNPIVOT INCLUDE NULLS (
        raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw)))
    )
    UNION ALL
    SELECT 'Data2' AS source_sheet, period_raw, series_id, raw_value
    FROM raw.abs_cpi_table18_data2_quarterly
    UNPIVOT INCLUDE NULLS (
        raw_value FOR series_id IN (COLUMNS(* EXCLUDE (period_raw)))
    )
), expected_values AS (
    SELECT
        LAST_DAY(DATE '1899-12-30' + CAST(TRIM(period_raw) AS INTEGER)) AS report_date,
        series_id,
        source_sheet,
        CAST(NULLIF(TRIM(raw_value), '') AS DECIMAL(18, 6)) AS metric_value
    FROM raw_values
), raw_minus_staging AS (
    SELECT report_date, series_id, source_sheet, metric_value FROM expected_values
    EXCEPT ALL
    SELECT report_date, series_id, source_sheet, metric_value
    FROM stg.abs_cpi_australia_quarterly_detail
), staging_minus_raw AS (
    SELECT report_date, series_id, source_sheet, metric_value
    FROM stg.abs_cpi_australia_quarterly_detail
    EXCEPT ALL
    SELECT report_date, series_id, source_sheet, metric_value FROM expected_values
), counts AS (
    SELECT 1 AS check_order, 'raw_minus_staging_rows' AS check_name,
        COUNT(*) AS actual_count FROM raw_minus_staging
    UNION ALL
    SELECT 2, 'staging_minus_raw_rows', COUNT(*) FROM staging_minus_raw
)
SELECT check_name, actual_count, 0 AS expected_count,
    CASE WHEN actual_count = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts
ORDER BY check_order;
