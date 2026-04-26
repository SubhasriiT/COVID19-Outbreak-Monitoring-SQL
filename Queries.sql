create database mysqlproject1;
use mysqlproject1;

use mysqlproject1;
CREATE TABLE who_daily (
    Date_reported     DATE,
    Country_code      VARCHAR(10),
    Country           VARCHAR(100),
    WHO_region        VARCHAR(50),
    New_cases         INT,
    Cumulative_cases  INT,
    New_deaths        INT,
    Cumulative_deaths INT
);

SET GLOBAL LOCAL_INFILE=ON;
LOAD DATA LOCAL INFILE 'C:/Users/subha/Downloads/WHO-COVID-19-global-daily-data.csv' INTO TABLE who_daily
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

select * from who_daily;

CREATE TABLE country_latest (
    Country_Region          VARCHAR(100),
    Confirmed               INT,
    Deaths                  INT,
    Recovered               INT,
    Active                  INT,
    New_cases               INT,
    New_deaths              INT,
    New_recovered           INT,
    Deaths_per_100_cases    FLOAT,
    Recovered_per_100_cases FLOAT,
    Deaths_per_100_recovered FLOAT,
    Confirmed_last_week     INT,
    One_week_change         INT,
    One_week_pct_increase   FLOAT,
    WHO_Region              VARCHAR(50)
);

SET GLOBAL LOCAL_INFILE=ON;
LOAD DATA LOCAL INFILE 'C:/Users/subha/Downloads/country_wise_latest.csv' INTO TABLE country_latest
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

select * from country_latest;

SELECT COUNT(*) FROM who_daily;
SELECT COUNT(*) FROM country_latest;

-- Check NULL values
SELECT COUNT(*) FROM who_daily WHERE Country IS NULL;
SELECT COUNT(*) FROM who_daily WHERE Date_reported IS NULL;
SELECT COUNT(*) FROM country_latest WHERE Country_Region IS NULL;

SELECT Country, Date_reported, COUNT(*)
FROM who_daily
GROUP BY Country, Date_reported
HAVING COUNT(*) > 1;

CREATE VIEW final_analysis AS
SELECT 
    w.Country,
    w.Date_reported,
    w.New_cases,
    w.New_deaths,
    w.Cumulative_cases,
    c.Active,
    c.Confirmed,
    c.Deaths,
    c.Recovered,
    c.One_week_pct_increase,
    CASE
        WHEN w.New_cases > 50000 OR c.One_week_pct_increase > 30 THEN 'CRITICAL'
        WHEN w.New_cases > 10000 OR c.One_week_pct_increase > 20 THEN 'HIGH'
        WHEN w.New_cases > 1000  OR c.One_week_pct_increase > 10 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Alert_Level
FROM who_daily w
JOIN country_latest c 
ON w.Country = c.Country_Region;

SELECT * FROM final_analysis;

-- Global summary dashboard
SELECT
    SUM(Confirmed)    AS Total_Confirmed,
    SUM(Deaths)       AS Total_Deaths,
    SUM(Recovered)    AS Total_Recovered,
    SUM(Active)       AS Total_Active,
    COUNT(DISTINCT Country_Region) AS Countries_Affected
FROM country_latest;

-- Countries with highest new cases in a single day
SELECT Country, Date_reported, New_cases
FROM who_daily
WHERE New_cases < 1000000
ORDER BY New_cases DESC
LIMIT 10;

-- WHO regions with total new cases this week
SELECT WHO_Region,
       SUM(Active) AS Total_active,
       SUM(New_cases) AS Total_new_cases
FROM country_latest
GROUP BY WHO_Region
ORDER BY Total_active DESC;

-- Daily new case trend for a specific country (India)
SELECT Date_reported, New_cases, Cumulative_cases
FROM who_daily
WHERE Country = 'India'
ORDER BY Date_reported;

-- Month-wise total new cases globally
SELECT DATE_FORMAT(Date_reported, '%Y-%m') AS Month,
       SUM(New_cases) AS Monthly_cases
FROM who_daily
GROUP BY Month
ORDER BY Month;

-- Find peak month
SELECT 
    DATE_FORMAT(Date_reported, '%Y-%m') AS Month,
    SUM(New_cases) AS Monthly_cases
FROM who_daily
GROUP BY Month
ORDER BY Monthly_cases DESC
LIMIT 1;

-- Regions where new cases spiked more than 20% in a week
SELECT Country_Region, One_week_pct_increase, New_cases
FROM country_latest
WHERE One_week_pct_increase > 20 AND New_cases > 1000
ORDER BY One_week_pct_increase DESC;

SELECT Country_Region, One_week_pct_increase, New_cases
FROM country_latest
WHERE One_week_pct_increase > 0
ORDER BY One_week_pct_increase DESC
LIMIT 15;
-- Peak COVID-19 alert levels by country based on highest recorded daily cases
SELECT 
    w.Country,
    w.Date_reported,
    w.New_cases,
    c.One_week_pct_increase,
    CASE
        WHEN w.New_cases > 50000 OR c.One_week_pct_increase > 30 THEN 'CRITICAL'
        WHEN w.New_cases > 10000 OR c.One_week_pct_increase > 20 THEN 'HIGH'
        WHEN w.New_cases > 1000  OR c.One_week_pct_increase > 10 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Alert_Level
FROM who_daily w
JOIN country_latest c
    ON w.Country = c.Country_Region
WHERE w.Date_reported = (SELECT MAX(Date_reported) FROM who_daily)
ORDER BY w.New_cases DESC;

-- copy of Peak COVID-19 alert levels by country based on highest recorded daily cases
SELECT w.Country,
       MAX(w.New_cases) AS Peak_new_cases,
       MAX(w.Date_reported) AS Peak_date,
       MAX(c.One_week_pct_increase) AS Max_weekly_increase,
       CASE
           WHEN MAX(w.New_cases) > 50000 OR MAX(c.One_week_pct_increase) > 30 THEN 'CRITICAL'
           WHEN MAX(w.New_cases) > 10000 OR MAX(c.One_week_pct_increase) > 20 THEN 'HIGH'
           WHEN MAX(w.New_cases) > 1000  OR MAX(c.One_week_pct_increase) > 10 THEN 'MEDIUM'
           ELSE 'LOW'
       END AS Alert_Level
FROM who_daily w
JOIN country_latest c ON w.Country = c.Country_Region
GROUP BY w.Country
ORDER BY Peak_new_cases DESC;

-- Countries needing IMMEDIATE alert
SELECT 
    Country,
    New_cases AS Peak_new_cases,
    Date_reported AS Peak_date,
    CASE
        WHEN New_cases > 50000 THEN 'CRITICAL'
        WHEN New_cases > 10000 THEN 'HIGH'
        WHEN New_cases > 1000  THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Alert_Level
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY Country 
               ORDER BY New_cases DESC
           ) as rn
    FROM who_daily
) t
WHERE rn = 1
ORDER BY Peak_new_cases DESC
LIMIT 20;

-- Top 5 worst weeks (highest global new cases)
SELECT DATE_FORMAT(Date_reported, '%Y-%u') AS Week,
       SUM(New_cases) AS Weekly_cases
FROM who_daily
GROUP BY Week
ORDER BY Weekly_cases DESC
LIMIT 5;

-- Active outbreak countries (high active + rising new cases)
SELECT Country_Region, Active, New_cases, One_week_pct_increase
FROM country_latest
WHERE Active > 10000 AND One_week_pct_increase > 15
ORDER BY Active DESC;

-- Countries with highest death rate (deaths per 100 cases)
SELECT Country_Region, Deaths_per_100_cases, Confirmed, Deaths
FROM country_latest
WHERE Confirmed > 1000
ORDER BY Deaths_per_100_cases DESC
LIMIT 10;

-- Same-Day Death Ratio by Country
SELECT 
    Country_Region,
    Avg_cases_7d,
    Avg_deaths_7d,
    Death_rate_7d,
    CASE
        WHEN Death_rate_7d > 10 THEN 'CRITICAL SIGNAL'
        WHEN Death_rate_7d > 5 THEN 'WARNING'
        ELSE 'NORMAL'
    END AS Risk_Level
FROM (
    SELECT 
        Country_Region,
        AVG(New_cases) AS Avg_cases_7d,
        AVG(New_deaths) AS Avg_deaths_7d,
        ROUND(AVG(New_deaths) * 100.0 / NULLIF(AVG(New_cases),0), 2) AS Death_rate_7d
    FROM country_latest
    GROUP BY Country_Region
    HAVING AVG(New_cases) >= 100
) t
ORDER BY Death_rate_7d DESC
LIMIT 10;

-- Total deaths per WHO region
SELECT WHO_Region, SUM(Deaths) AS Total_deaths,
       SUM(Confirmed) AS Total_confirmed,
       ROUND(SUM(Deaths)/SUM(Confirmed)*100, 2) AS Death_pct
FROM country_latest
GROUP BY WHO_Region
ORDER BY Death_pct DESC;

-- Countries with best recovery rate
SELECT Country_Region, Recovered_per_100_cases, Confirmed, Recovered
FROM country_latest
WHERE Confirmed > 5000
ORDER BY Recovered_per_100_cases DESC
LIMIT 10;

-- Active Case Burden vs Recovery Efficiency Analysis
SELECT Country_Region, Active, Recovered, Confirmed,
       ROUND(Active/Confirmed*100, 2) AS Active_pct
FROM country_latest
WHERE Confirmed > 10000
ORDER BY Active_pct DESC
LIMIT 10;

-- Active vs death vs recovery analysis
SELECT 'Recovered' AS Category, SUM(Recovered) AS Total 
FROM country_latest
UNION ALL
SELECT 'Deaths' AS Category, SUM(Deaths) AS Total 
FROM country_latest
UNION ALL
SELECT 'Active' AS Category, SUM(Active) AS Total 
FROM country_latest;

-- Match WHO daily trend with latest snapshot for SEAR region
SELECT w.Country, w.Date_reported, w.New_cases,
       c.Active, c.One_week_pct_increase
FROM who_daily w
JOIN country_latest c 
    ON w.Country = c.Country_Region
WHERE w.WHO_region = 'SEAR'
ORDER BY w.Date_reported DESC;

-- Top 10 Countries by Confirmed Cases
SELECT Country_Region, Confirmed, Deaths, Recovered
FROM country_latest
ORDER BY Confirmed DESC
LIMIT 10;

-- Countries where cumulative cases in daily data differs from confirmed in latest (data quality check)
SELECT w.Country,
       MAX(w.Cumulative_cases) AS Daily_cumulative,
       c.Confirmed AS Latest_confirmed,
       MAX(w.Cumulative_cases) - c.Confirmed AS Difference
FROM who_daily w
JOIN country_latest c ON w.Country = c.Country_Region
GROUP BY w.Country, c.Confirmed
HAVING ABS(Difference) > 1000
ORDER BY Difference DESC;

-- Countries with zero new cases (possible containment)
SELECT Country_Region, Confirmed, Active, New_cases
FROM country_latest
WHERE New_cases = 0 AND Active > 0
ORDER BY Confirmed DESC;

-- New cases in last recorded date globally
SELECT Date_reported, SUM(New_cases) AS Global_new_cases
FROM who_daily
GROUP BY Date_reported
HAVING SUM(New_cases) > 0
ORDER BY Date_reported DESC
LIMIT 1;

-- Daily records above global average new cases (subquery filter)
SELECT Country, Date_reported, New_cases
FROM who_daily
WHERE New_cases > (
    SELECT AVG(New_cases)
    FROM who_daily
    WHERE New_cases > 0
)
ORDER BY New_cases DESC
LIMIT 15;

-- Running total of global cases over time (window-style)
SELECT Date_reported,
       SUM(New_cases) AS Daily_global,
       SUM(SUM(New_cases)) OVER (ORDER BY Date_reported) AS Running_total
FROM who_daily
GROUP BY Date_reported
ORDER BY Date_reported;


-- Outbreak summary view for district officers
CREATE VIEW outbreak_summary AS
SELECT
    WHO_Region,
    COUNT(Country_Region)        AS Countries_count,
    SUM(Active)                  AS Total_active,
    SUM(New_cases)               AS Total_new_cases,
    AVG(One_week_pct_increase)   AS Avg_weekly_increase,
    MAX(One_week_pct_increase)   AS Max_spike
FROM country_latest
GROUP BY WHO_Region;
SELECT * FROM outbreak_summary;
