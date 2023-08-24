-- Note: .csv Dataset is imported into SSMS with each sheet being a separate table within the "Hotel_Revenue_Dataset" database. There are a total of 5 sheets corresponding to 5 tables. The Table names are:
--1) dbo.['2018$']
--2) dbo.['2019$']
--3) dbo.['2020$']
--4) dbo.[market_segment$]
--5) dbo.[meal_cost$]

/*
	EDA with SQL
*/

-- After inspecting each yearly table, we see that each table contains the same column names, but are categorized into each sheet based on the value in 'arrival_date_year'. For example, guests that arrive in either City Hotel or Resort Hotel in the year 2018 will be occupying a row in the 2018 table
SELECT *
FROM Hotel_Revenue_Dataset.dbo.['2018$'] -- Inspecting 2018 table

SELECT *
FROM Hotel_Revenue_Dataset.dbo.['2019$'] -- Inspecting 2019 table

SELECT *
FROM Hotel_Revenue_Dataset.dbo.['2020$'] -- Inspecting 2020 table

SELECT *
FROM Hotel_Revenue_Dataset.dbo.market_segment$ -- Contains the associated discount provided by the hotel group to individuals listed under the 'market_segment' column. For example, 'Corporate' individuals who book the hotel will receive a 15% discount on the total bill

SELECT *
FROM Hotel_Revenue_Dataset.dbo.meal_cost$ -- Contains the total associated cost to provide meals to staying guests, listed in the meal column

/*
	Baseline Query to consolidate data across all tables
*/
-- Given that we'd like to analyze trends, revenue growth across each year, and that the names of columns remain the same across each year. UNION ALL was performed across all years to consolidate data. We'll use CTE and refer to the consolidated table as Hotel. At the same time, the foreign keys market_segment, meal was used to JOIN market_segment$ & meal_cost$ tables together:
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
)
SELECT *
FROM hotels as h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal


/*
	EDA to build upon consolidated query to answer the question: "Is our hotel revenue growing by year"
*/
-- From the "Query to consolidate data across all tables", the following columns were identified to be helpful in revenue calculation:
	-- 'reservation_status', 'stays_in_week_nights', 'stays_in_week_nights', 'adr', 'c.meal', 'c.Cost'
		-- 'reservation_status' can either be "Canceled"/"No-Show/ "Check-Out". For "Canceled", we'll assume no revenue as no booking was made.
		-- 'stays_in_week_nights' & 'stays_in_week_nights' works in conjunction with 'ADR' for revenue calculation. 
		-- ADR is a common metric used in the hospitality industry to calculate the average price that guests pay per room for a specific period. It's given by: ADR = Total Room Revenue / Number of Rooms Sold. 
			-- From the ADR column provided, we can manipulate the equation to obtain the total revenue generated by the hotel by finding the total number of rooms sold, given by :(stays_in_week_nights + stays_in_week_nights) AS Number_of_Rooms_Sold
		-- 'c.meal' & 'c.Cost' represents the total associated cost incurred by the hotel to provide meals to staying guests.
		-- 'm.market_segment' & 'Discount' shows the % of discount offerred to customers within the corresponding market_segment. For example, 'Corporate' individuals who book the hotel will receive a 15% discount on the total bill

-- EDA Query of to single out all important columns for revenue calculation
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
)
SELECT reservation_status, stays_in_week_nights, stays_in_week_nights, 
		(stays_in_week_nights + stays_in_week_nights) AS Number_of_Rooms_Sold,
		adr, c.meal, c.Cost, m.market_segment, Discount
FROM hotels as h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal

/*
	EDA to investigate data discrepancy in ADR [Used to construct CASE WHEN statement in final query]
*/
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
)
SELECT reservation_status,
		(stays_in_week_nights + stays_in_week_nights) AS Number_of_Rooms_Sold,
		adr, c.meal, c.Cost, m.market_segment, Discount
FROM hotels as h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal
WHERE (adr = 0 OR ADR < 0) AND m.market_segment NOT IN ('Complementary') AND (stays_in_week_nights + stays_in_week_nights) > 0 -- Want to single out ADR = 0, -ve ADR values for Number_of_Rooms_Sold >0 , which is unusual in nature for non-100% discounted customers as typically revenue should be made for such customers and adr should be > 0
ORDER BY adr ASC, Number_of_Rooms_Sold DESC

/*
	Conclusion: For ADR < 0 -- Highly likely a calculation error/ data discrepancy has occurred. By definition, ADR is a measure of the hotel's revenue and should represent a positive value.
	  For reservation_status = 'Check-Out' OR 'No-Show' OR adr = 0 -- Highly likely that there's a problem with data collection. For example, if ADR = 0, it'll be either that:
				-- 1) Total Room Revenue is zero: This would mean that no revenue was generated from room sales. This is highly unlikely as it indicates an underlying flaw in the pricing model especially when no 100% discount is given to the customers
				-- 2) Number of Rooms Sold is zero even though the guest has either 'Check-Out','No-Show' or 'Canceled' : This is also highly strange as each row entry in the database would constitute as a hotel room being booked. This would imply that a record was made in the database even though no rooms were booked by the guest. As such, it is highly likely a calculation error/ data discrepancy has occurred
		These data discrepancy in ADR will be considered during construction of CASE WHEN to give an accurate revenue calculation
*/

/*
	Query to generate hotel revenue across years by hotel_type with adr column
*/
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
)
SELECT hotel,arrival_date_year,reservation_status, stays_in_weekend_nights, stays_in_week_nights, 
		(stays_in_week_nights + stays_in_weekend_nights) AS Number_of_Rooms_Sold,
		adr, c.meal, c.Cost, m.market_segment, Discount,
		CASE
                WHEN reservation_status = 'Canceled' THEN 0 -- Validated it's 0
				WHEN ADR < 0 THEN 0 -- Validated it's 0
				WHEN (reservation_status = 'Check-Out' OR reservation_status = 'No-Show') AND (adr = 0 OR adr < 0) THEN 0 -- Validated it's 0. If a customer has checked out or no show, ADR should not be less than or equal to 0 as the customer should be billed for such cases and thus will generate revenue for the company.
                ELSE
				( ((stays_in_week_nights + stays_in_weekend_nights) * (adr) * (1 - Discount)) - c.Cost )
            END AS revenue
FROM hotels AS h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal

/*
	Consolidated query to answer the question: "Is our hotel revenue growing by year", using nested CTEs. Yes, we saw revenue growth from 2018 to 2019, but from 2019 to 2020, we see a decrease in revenue from $11.7M to .$7.2M. This may be due to the influence of COVID-19 pandemic which impacted the hospitality industry [first recorded case of COVID-19 death in Portugal was recorded on 16 MAR 2020]. Alternatively, the dataset is incomplete & does not have complete booking information across the 3 years
*/
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
),
hotel_revenue AS (
SELECT hotel,arrival_date_year,reservation_status,
		(stays_in_week_nights + stays_in_weekend_nights) AS Number_of_Rooms_Sold,
		adr, Discount,
		CASE
                WHEN reservation_status = 'Canceled' THEN 0 -- Validated it's 0. Here we assume that customers who Canceled the reservation did so within the full return window, hence no revenue is generated from such transcations.
				WHEN ADR < 0 THEN 0 -- Validated it's 0. As concluded earlier. For ADR < 0, it's highly likely a calculation error/ data discrepancy has occurred.
				WHEN (reservation_status = 'Check-Out' OR reservation_status = 'No-Show') AND (adr = 0 OR adr < 0) THEN 0 -- Validated it's 0. If a customer has checked out or no show, ADR should not be less than or equal to 0 as the customer should be billed for such cases and thus will generate revenue for the company.
                ELSE
				( ((stays_in_week_nights + stays_in_weekend_nights) * (adr) * (1 - Discount)) - c.Cost )
            END AS revenue
FROM hotels AS h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal
)
SELECT DISTINCT arrival_date_year,
		SUM(revenue) OVER (PARTITION BY arrival_date_year) AS Revenue_by_Year,
		FORMAT(SUM(revenue) OVER (PARTITION BY arrival_date_year),'$0,,.00M') AS Revenue_by_Year_FormattedInMillions
FROM hotel_revenue
ORDER BY arrival_date_year

/*
	Consolidated query to find the total revenue generated from 2018 - 2020:
*/
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
),
hotel_revenue AS (
SELECT hotel,arrival_date_year,reservation_status,
		(stays_in_week_nights + stays_in_weekend_nights) AS Number_of_Rooms_Sold,
		adr, Discount,
		CASE
                WHEN reservation_status = 'Canceled' THEN 0 -- Validated it's 0. Here we assume that customers who Canceled the reservation did so within the full return window, hence no revenue is generated from such transcations.
				WHEN ADR < 0 THEN 0 -- Validated it's 0. As concluded earlier. For ADR < 0, it's highly likely a calculation error/ data discrepancy has occurred.
				WHEN (reservation_status = 'Check-Out' OR reservation_status = 'No-Show') AND (adr = 0 OR adr < 0) THEN 0 -- Validated it's 0. If a customer has checked out or no show, ADR should not be less than or equal to 0 as the customer should be billed for such cases and thus will generate revenue for the company.
                ELSE
				( ((stays_in_week_nights + stays_in_weekend_nights) * (adr) * (1 - Discount)) - c.Cost )
            END AS revenue
FROM hotels AS h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal
)
SELECT SUM(revenue) AS Total_Revenue,
	FORMAT(SUM(revenue),'$0,,.00M') AS Total_Revenue_FormattedInMillions
FROM hotel_revenue

-- $22.01M was the total revenue generated from 2018 - 2020

/*
Based on some of the columns provided, I'd like to create new categorical columns for analysis later in PowerBI. These revenue & categorical columns are iteratively built upon from the baseline query.
I'd also like to compute a revenue column as well.
In this section, I'll create & test for each categorical columns before iteratively building up to the final query to export into PowerBI for data visualization
*/

	/*
		Begin CASE WHEN statements for creation of categorized columns [Creation of guest_type, day_of_week, seasons & revenue columns]
	*/

-- Categorical Query 1): creation of guest_type categorization code, we want to categorize guest_type based on adults, children, babies variable
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
),
hotel_all_columns_with_guest_type AS (
SELECT adults, children, babies,
		CASE
				WHEN adults = 1 AND children = 0 AND babies = 0 THEN 'Single'
				WHEN adults = 2 AND children = 0 AND babies = 0 THEN 'Couple'
				WHEN adults > 2 AND children = 0 AND babies = 0 THEN 'Group'
				ELSE 'Family'
		END AS guest_type
FROM hotels AS h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal
)
SELECT *
FROM hotel_all_columns_with_guest_type

-- Categorical Query 2): Creation of region categorical column based on country code:
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
)
SELECT
    country,
    CASE 
        WHEN country IN ('ISR', 'SYR', 'JOR', 'SAU', 'ARE', 'LBN', 'IRQ', 'KWT', 'QAT', 'OMN', 'BHR', 'PSE', 'YEM', 'TUR','IRN') THEN 'Middle East'
        WHEN country IN ('BOL', 'CHL', 'COL', 'AND', 'ARG', 'PRY', 'URY', 'VEN', 'BRA', 'PER', 'ECU', 'BHS', 'BLZ', 'CRI', 'CUB', 'DOM', 'SLV', 'GRD', 'GTM', 'HTI', 'HND', 'JAM', 'MEX', 'NIC', 'PAN', 'TTO', 'ATG', 'BRB', 'DMA', 'VCT', 'GUY', 'SUR') THEN 'South America'
        WHEN country IN ('USA', 'CAN', 'MEX', 'PRI', 'CRI') THEN 'North America'
        WHEN country IN ('CHN', 'HKG', 'MAC', 'TWN', 'PRK', 'KOR', 'JPN', 'MNG', 'CN', 'TWN', 'PRK', 'KOR', 'JPN', 'MNG') THEN 'East Asia'
        WHEN country IN ('KHM', 'LAO', 'THA', 'VNM', 'IDN', 'PHL', 'BRN', 'MYS', 'SGP', 'LKA', 'VNM', 'THA', 'IDN','MMR','TMP') THEN 'Southeast Asia'
        WHEN country IN ('AUS', 'NZL', 'FJI', 'PNG','ASM') THEN 'Oceania'
        WHEN country IN ('GBR', 'FRA', 'DEU', 'ESP', 'ITA', 'NLD', 'BEL', 'PRT', 'CHE', 'AUT', 'SWE', 'DNK', 'NOR', 'FIN', 'IRL', 'POL', 'CZE', 'HUN', 'SVK', 'SVN', 'GRC', 'ROU', 'BGR', 'EST', 'LVA', 'LTU', 'LUX', 'HRV', 'MLT', 'CYP', 'MKD', 'SMR', 'BIH', 'ALB', 'MNE', 'GIB', 'GGY', 'JEY', 'IMN', 'RUS','ARM') THEN 'Europe'
        WHEN country IN ('DEU', 'POL', 'CZE', 'SVK', 'AUT', 'HUN', 'SVN', 'FIN', 'NLD', 'CHE', 'LIE') THEN 'Central Europe'
        WHEN country IN ('GBR', 'IRL', 'NLD', 'BEL', 'LUX', 'PRT') THEN 'Western Europe'
        WHEN country IN ('POL', 'CZE', 'SVK', 'HUN', 'SVN', 'EST', 'LVA', 'LTU', 'BLR','UKR') THEN 'Eastern Europe'
        WHEN country IN ('FRA', 'ESP', 'AND', 'MCO', 'ITA') THEN 'Southern Europe'
        WHEN country IN ('NOR', 'SWE', 'DNK', 'FIN', 'ISL', 'EST', 'LVA', 'LTU') THEN 'Northern Europe'
        WHEN country IN ('ZAF', 'NGA', 'EGY', 'DZA', 'KEN', 'ETH', 'GHA', 'MAR', 'UGA', 'CMR', 'TUN', 'SEN', 'CIV', 'NER', 'MLI', 'AGO', 'TZA', 'MOZ', 'ZMB', 'MUS', 'SDN', 'RWA', 'BEN', 'TGO', 'SSD', 'BFA', 'NAM', 'GIN', 'MWI', 'COG', 'GAB', 'STP', 'ZWE', 'TCD', 'SOM', 'LBY', 'SWZ', 'LSO', 'GMB', 'GNB', 'CPV', 'CIV', 'TGO', 'SLE', 'TUN', 'MAR', 'DZA', 'LBY', 'EGY','CAF') THEN 'Africa'
        WHEN country IN ('TUN', 'MAR', 'DZA', 'LBY', 'EGY') THEN 'North Africa'
        WHEN country IN ('ZAF', 'NAM', 'BWA', 'LSO', 'SWZ', 'MOZ', 'ZMB') THEN 'Southern Africa'
        WHEN country IN ('KEN', 'UGA', 'TZA', 'RWA', 'BDI', 'SSD', 'DJI', 'SOM', 'ETH', 'ERI', 'COM') THEN 'East Africa'
        WHEN country IN ('NGA', 'GHA', 'CIV', 'BFA', 'SEN', 'GIN', 'MLI', 'TGO', 'BEN', 'NER', 'GMB', 'GNB', 'MLI','MRT') THEN 'West Africa'
		WHEN country IN ('BGD','IND','MDV','NPL','PAK') THEN 'South Asia'
		WHEN country IN ('KAZ', 'AZE','TJK','UZB') THEN 'Central Asia'
        WHEN country IN ('FRO') THEN 'Nordic Countries'
        WHEN country IN ('GEO') THEN 'Caucasus'
		WHEN country IN ('KIR','NCL','PLW','PYF','UMI') THEN 'Oceania' 
        WHEN country IN ('MDG','MYT','SYC') THEN 'East Africa' 
        WHEN country IN ('SRB') THEN 'Balkans'
        WHEN country IN ('ABW', 'CYM', 'GLP', 'KNA', 'LCA', 'PRI', 'BRB', 'VGB', 'BLZ', 'VCT', 'GRD', 'DMA', 'CUW', 'MTQ', 'MSR', 'AIA', 'TCA', 'ATG', 'SXM', 'KNA', 'MAF', 'BRB','VGB') THEN 'Caribbean'
		WHEN country IN ('NULL','ATA','ATF') THEN 'Unknown' -- NULL values, here the field is literally called NULL, so I can't use IS NULL here. ATA is Antarctica and ATF is French Southern and Antartic Islands
		ELSE 'Other'
    END AS region
FROM
    hotels;

-- Categorical Query 3): creation of seasons categorization code:
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
),
hotel_all_columns_with_seasons AS (
SELECT arrival_date_month,
		CASE
				WHEN arrival_date_month IN ('December', 'January', 'February') THEN 'Winter'
				WHEN arrival_date_month IN ('March', 'April', 'May') THEN 'Spring'
				WHEN arrival_date_month IN ('June', 'July', 'August') THEN 'Summer'
				WHEN arrival_date_month IN ('September', 'October', 'November') THEN 'Autumn'
		END AS seasons
FROM hotels AS h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal
)
SELECT *
FROM hotel_all_columns_with_seasons


-- Categorical Query 4): creation of day_of_week categorization code
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
)
SELECT 
    arrival_date_day_of_month,
    arrival_date_month,
    arrival_date_year,
    CONVERT(DATE, CONVERT(VARCHAR, arrival_date_day_of_month) + ' ' + arrival_date_month + ' ' + CONVERT(VARCHAR, arrival_date_year)) AS arrival_date, -- concat and convert year,month, day of month into date format. We name it as arrival_date column.
    CASE DATEPART(dw, CONVERT(DATE, CONVERT(VARCHAR, arrival_date_day_of_month) + ' ' + arrival_date_month + ' ' + CONVERT(VARCHAR, arrival_date_year))) -- DATEPART(dw, ...) extracts day of the week as an integer based on the CASE statement. CASE statement then converts integer to it's corresponding day name (i.e. 'Sunday' is dw value corresponding to 1)
        WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday'
        WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
    END AS day_of_week
FROM hotels;


-- Categorical Query 5): creation of revenue categorization code:
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
),
hotel_all_columns_with_revenue AS (
SELECT reservation_status, adr, discount, c.Cost,
 (stays_in_week_nights + stays_in_weekend_nights) AS Number_of_Rooms_Sold, -- used to calculate revenue
		CASE
                WHEN reservation_status = 'Canceled' THEN 0 -- Validated it's 0. Here we assume that customers who Canceled the reservation did so within the full return window, hence no revenue is generated from such transcations.
				WHEN ADR < 0 THEN 0 -- Validated it's 0. As concluded earlier. For ADR < 0, it's highly likely a calculation error/ data discrepancy has occurred.
				WHEN (reservation_status = 'Check-Out' OR reservation_status = 'No-Show') AND (adr = 0 OR adr < 0) THEN 0 -- Validated it's 0. If a customer has checked out or no show, ADR should not be less than or equal to 0 as the customer should be billed for such cases and thus will generate revenue for the company.
                ELSE
				( ((stays_in_week_nights + stays_in_weekend_nights) * (adr) * (1 - Discount)) - c.Cost )
            END AS revenue
FROM hotels AS h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal
)
SELECT *
FROM hotel_all_columns_with_revenue

/*
	Final SQL Query #1 to import into PowerBI for dashboard creation. Includes all 5 categorical query output and every single column existing within the original dataset, also lumps data from 2018-2020 together via UNION ALL.
*/
-- Final Query lump:
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
),
hotel_all_column_amalgated AS (
SELECT
-- Selecting all original columns
hotel, is_canceled,	lead_time,	arrival_date_year,	arrival_date_month,	arrival_date_week_number,	arrival_date_day_of_month,	stays_in_weekend_nights,	stays_in_week_nights,
adults,	children	,babies	, h.meal	,country,	h.market_segment,	distribution_channel,	is_repeated_guest,	previous_cancellations,	previous_bookings_not_canceled,	reserved_room_type,	assigned_room_type,	booking_changes,	deposit_type,	agent,	company	days_in_waiting_list,	customer_type,	adr,	required_car_parking_spaces,	total_of_special_requests,	reservation_status,	reservation_status_date, Cost, Discount,

-- guest_type column creation
		CASE
				WHEN adults = 1 AND children = 0 AND babies = 0 THEN 'Single'
				WHEN adults = 2 AND children = 0 AND babies = 0 THEN 'Couple'
				WHEN adults > 2 AND children = 0 AND babies = 0 THEN 'Group'
				ELSE 'Family'
		END AS guest_type,
		
-- region column creation
		CASE 
        WHEN country IN ('ISR', 'SYR', 'JOR', 'SAU', 'ARE', 'LBN', 'IRQ', 'KWT', 'QAT', 'OMN', 'BHR', 'PSE', 'YEM', 'TUR','IRN') THEN 'Middle East'
        WHEN country IN ('BOL', 'CHL', 'COL', 'AND', 'ARG', 'PRY', 'URY', 'VEN', 'BRA', 'PER', 'ECU', 'BHS', 'BLZ', 'CRI', 'CUB', 'DOM', 'SLV', 'GRD', 'GTM', 'HTI', 'HND', 'JAM', 'MEX', 'NIC', 'PAN', 'TTO', 'ATG', 'BRB', 'DMA', 'VCT', 'GUY', 'SUR') THEN 'South America'
        WHEN country IN ('USA', 'CAN', 'MEX', 'PRI', 'CRI') THEN 'North America'
        WHEN country IN ('CHN', 'HKG', 'MAC', 'TWN', 'PRK', 'KOR', 'JPN', 'MNG', 'CN', 'TWN', 'PRK', 'KOR', 'JPN', 'MNG') THEN 'East Asia'
        WHEN country IN ('KHM', 'LAO', 'THA', 'VNM', 'IDN', 'PHL', 'BRN', 'MYS', 'SGP', 'LKA', 'VNM', 'THA', 'IDN','MMR','TMP') THEN 'Southeast Asia'
        WHEN country IN ('AUS', 'NZL', 'FJI', 'PNG','ASM') THEN 'Oceania'
        WHEN country IN ('GBR', 'FRA', 'DEU', 'ESP', 'ITA', 'NLD', 'BEL', 'PRT', 'CHE', 'AUT', 'SWE', 'DNK', 'NOR', 'FIN', 'IRL', 'POL', 'CZE', 'HUN', 'SVK', 'SVN', 'GRC', 'ROU', 'BGR', 'EST', 'LVA', 'LTU', 'LUX', 'HRV', 'MLT', 'CYP', 'MKD', 'SMR', 'BIH', 'ALB', 'MNE', 'GIB', 'GGY', 'JEY', 'IMN', 'RUS','ARM') THEN 'Europe'
        WHEN country IN ('DEU', 'POL', 'CZE', 'SVK', 'AUT', 'HUN', 'SVN', 'FIN', 'NLD', 'CHE', 'LIE') THEN 'Central Europe'
        WHEN country IN ('GBR', 'IRL', 'NLD', 'BEL', 'LUX', 'PRT') THEN 'Western Europe'
        WHEN country IN ('POL', 'CZE', 'SVK', 'HUN', 'SVN', 'EST', 'LVA', 'LTU', 'BLR','UKR') THEN 'Eastern Europe'
        WHEN country IN ('FRA', 'ESP', 'AND', 'MCO', 'ITA') THEN 'Southern Europe'
        WHEN country IN ('NOR', 'SWE', 'DNK', 'FIN', 'ISL', 'EST', 'LVA', 'LTU') THEN 'Northern Europe'
        WHEN country IN ('ZAF', 'NGA', 'EGY', 'DZA', 'KEN', 'ETH', 'GHA', 'MAR', 'UGA', 'CMR', 'TUN', 'SEN', 'CIV', 'NER', 'MLI', 'AGO', 'TZA', 'MOZ', 'ZMB', 'MUS', 'SDN', 'RWA', 'BEN', 'TGO', 'SSD', 'BFA', 'NAM', 'GIN', 'MWI', 'COG', 'GAB', 'STP', 'ZWE', 'TCD', 'SOM', 'LBY', 'SWZ', 'LSO', 'GMB', 'GNB', 'CPV', 'CIV', 'TGO', 'SLE', 'TUN', 'MAR', 'DZA', 'LBY', 'EGY','CAF') THEN 'Africa'
        WHEN country IN ('TUN', 'MAR', 'DZA', 'LBY', 'EGY') THEN 'North Africa'
        WHEN country IN ('ZAF', 'NAM', 'BWA', 'LSO', 'SWZ', 'MOZ', 'ZMB') THEN 'Southern Africa'
        WHEN country IN ('KEN', 'UGA', 'TZA', 'RWA', 'BDI', 'SSD', 'DJI', 'SOM', 'ETH', 'ERI', 'COM') THEN 'East Africa'
        WHEN country IN ('NGA', 'GHA', 'CIV', 'BFA', 'SEN', 'GIN', 'MLI', 'TGO', 'BEN', 'NER', 'GMB', 'GNB', 'MLI','MRT') THEN 'West Africa'
		WHEN country IN ('BGD','IND','MDV','NPL','PAK') THEN 'South Asia'
		WHEN country IN ('KAZ', 'AZE','TJK','UZB') THEN 'Central Asia'
        WHEN country IN ('FRO') THEN 'Nordic Countries'
        WHEN country IN ('GEO') THEN 'Caucasus'
		WHEN country IN ('KIR','NCL','PLW','PYF','UMI') THEN 'Oceania' 
        WHEN country IN ('MDG','MYT','SYC') THEN 'East Africa' 
        WHEN country IN ('SRB') THEN 'Balkans'
        WHEN country IN ('ABW', 'CYM', 'GLP', 'KNA', 'LCA', 'PRI', 'BRB', 'VGB', 'BLZ', 'VCT', 'GRD', 'DMA', 'CUW', 'MTQ', 'MSR', 'AIA', 'TCA', 'ATG', 'SXM', 'KNA', 'MAF', 'BRB','VGB') THEN 'Caribbean'
		WHEN country IN ('NULL','ATA','ATF') THEN 'Unknown' -- NULL values, here the field is literally called NULL, so I can't use IS NULL here. ATA is Antarctica and ATF is French Southern and Antartic Islands
		ELSE 'Other'
    END AS region,
	
-- seasons column creation
		CASE
				WHEN arrival_date_month IN ('December', 'January', 'February') THEN 'Winter'
				WHEN arrival_date_month IN ('March', 'April', 'May') THEN 'Spring'
				WHEN arrival_date_month IN ('June', 'July', 'August') THEN 'Summer'
				WHEN arrival_date_month IN ('September', 'October', 'November') THEN 'Autumn'
		END AS seasons,
		
-- arrival_date and day_of_week columns creation
 
		CONVERT(DATE, CONVERT(VARCHAR, arrival_date_day_of_month) + ' ' + arrival_date_month + ' ' + CONVERT(VARCHAR, arrival_date_year)) AS arrival_date, -- concat and convert year,month, day of month into date format
    CASE DATEPART(dw, CONVERT(DATE, CONVERT(VARCHAR, arrival_date_day_of_month) + ' ' + arrival_date_month + ' ' + CONVERT(VARCHAR, arrival_date_year))) -- DATEPART(dw, ...) extracts day of the week as an integer based on the CASE statement. CASE statement then converts integer to it's corresponding day name (i.e. 'Sunday' is dw value corresponding to 1)
        WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday'
        WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
    END AS day_of_week,
	
-- Number_of_Rooms_Sold and revenue columns creation

	(stays_in_week_nights + stays_in_weekend_nights) AS Number_of_Rooms_Sold,
		CASE
                WHEN reservation_status = 'Canceled' THEN 0 -- Validated it's 0. Here we assume that customers who Canceled the reservation did so within the full return window, hence no revenue is generated from such transcations.
				WHEN ADR < 0 THEN 0 -- Validated it's 0. As concluded earlier. For ADR < 0, it's highly likely a calculation error/ data discrepancy has occurred.
				WHEN (reservation_status = 'Check-Out' OR reservation_status = 'No-Show') AND (adr = 0 OR adr < 0) THEN 0 -- Validated it's 0. If a customer has checked out or no show, ADR should not be less than or equal to 0 as the customer should be billed for such cases and thus will generate revenue for the company.
                ELSE
				( ((stays_in_week_nights + stays_in_weekend_nights) * (adr) * (1 - Discount)) - c.Cost )
            END AS revenue
			

FROM hotels AS h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal
)
SELECT *
FROM hotel_all_column_amalgated

/*
	QUERY END
*/

/*
	Final SQL Query #2 imported into PowerBI for dashboard creation. Provides the count of rows of reservation status for Parking Percentage Calculation.
*/
WITH hotels AS (
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2018$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2019$']
    UNION ALL
    SELECT * FROM Hotel_Revenue_Dataset.dbo.['2020$']
),
hotel_all_columns_with_revenue AS (
SELECT hotel, is_canceled,	lead_time,	arrival_date_year,	arrival_date_month,	arrival_date_week_number,	arrival_date_day_of_month,	stays_in_weekend_nights,	stays_in_week_nights,
 (stays_in_week_nights + stays_in_weekend_nights) AS Number_of_Rooms_Sold,
adults,	children	,babies	, h.meal	,country,	h.market_segment,	distribution_channel,	is_repeated_guest,	previous_cancellations,	previous_bookings_not_canceled,	reserved_room_type,	assigned_room_type,	booking_changes,	deposit_type,	agent,	company	days_in_waiting_list,	customer_type,	adr,	required_car_parking_spaces,	total_of_special_requests,	reservation_status,	reservation_status_date, Cost, Discount,
		CASE
                WHEN reservation_status = 'Canceled' THEN 0 -- Validated it's 0. Here we assume that customers who Canceled the reservation did so within the full return window, hence no revenue is generated from such transcations.
				WHEN ADR < 0 THEN 0 -- Validated it's 0. As concluded earlier. For ADR < 0, it's highly likely a calculation error/ data discrepancy has occurred.
				WHEN (reservation_status = 'Check-Out' OR reservation_status = 'No-Show') AND (adr = 0 OR adr < 0) THEN 0 -- Validated it's 0. If a customer has checked out or no show, ADR should not be less than or equal to 0 as the customer should be billed for such cases and thus will generate revenue for the company.
                ELSE
				( ((stays_in_week_nights + stays_in_weekend_nights) * (adr) * (1 - Discount)) - c.Cost )
            END AS revenue
FROM hotels AS h
LEFT JOIN Hotel_Revenue_Dataset.dbo.market_segment$ AS m ON h.market_segment = m.market_segment
LEFT JOIN Hotel_Revenue_Dataset.dbo.meal_cost$ AS c ON h.meal = c.meal
)
SELECT COUNT(*) AS count_of_reservations_made
FROM hotel_all_columns_with_revenue