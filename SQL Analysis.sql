
--Preprocessing Data
--********************

-- 1- Checking If There Are Any Nulls In All Tables

-- Check Line productivity
SELECT 
    'Line productivity' AS TableName,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$']
            WHERE [Operator] IS NULL OR [Batch] IS NULL OR [TimeSpentInMinutes] IS NULL OR [Batch] IS NULL OR [Operator] IS NULL OR [time] IS NULL
        ) THEN 'Yes' ELSE 'No' 
    END AS Has_Nulls

UNION ALL

-- Check UnpivotedDowntime
SELECT 
    'UnpivotedDowntime',
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime]
            WHERE [Batch] IS NULL OR [DowntimeFactor] IS NULL OR [DowntimeDuration] IS NULL
        ) THEN 'Yes' ELSE 'No' 
    END

UNION ALL

-- Check Downtime factors
SELECT 
    'Downtime factors',
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM [Manufacturing_Line_Productivity].[dbo].['Downtime factors$']
            WHERE [Factor] IS NULL OR [Description] IS NULL OR [Operator Error] IS NULL
        ) THEN 'Yes' ELSE 'No' 
    END

UNION ALL

-- Check if there are any NULLs in 'Product'
SELECT 
    'Product',
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM [Manufacturing_Line_Productivity].[dbo].[Products$]
            WHERE [Product] IS NULL OR [Flavor] IS NULL OR [Min batch time] IS NULL
        ) THEN 'Yes' ELSE 'No' 
    END;
----------------------------------------------------------------------------------------------------------------------------------------------


-- Time 

-- 2-  Add column TimeSpentInMinutes to store spent time

ALTER TABLE [Manufacturing_Line_Productivity].[dbo].['Line productivity$']
ADD TimeSpentInMinutes INT;


-- 3- Convert time to 12Hr
UPDATE [Manufacturing_Line_Productivity].[dbo].['Line productivity$']
SET TimeSpentInMinutes = 
    CASE 
        WHEN CAST([End Time] AS TIME) < CAST([Start Time] AS TIME) 
        THEN DATEDIFF(MINUTE, CAST([Start Time] AS TIME), CAST([End Time] AS TIME)) + 1440  
        ELSE DATEDIFF(MINUTE, CAST([Start Time] AS TIME), CAST([End Time] AS TIME))
    END;

	-----------------------------------------------------------------------------------------------------------------------------------
-- 3- Unpivot Line Downtime Table and insert into the new table

INSERT INTO [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] (Batch, DowntimeFactor, DowntimeDuration)
SELECT 
    Batch, 
    DowntimeFactor, 
    DowntimeValue
FROM 
    (SELECT 
        Batch, 
        [1], [2] , [3], [4], [5], [6], 
        [7], [8], [9], [10], [11], [12]
     FROM [Manufacturing_Line_Productivity].[dbo].[Line downtime]) p
UNPIVOT 
    (DowntimeValue FOR DowntimeFactor IN 
        ( [1], [2] , [3], [4], [5], [6], 
        [7], [8], [9], [10], [11], [12])
    ) AS unpvt;



-----------------------------------------------------------------------------------------------------------
-- 4- set primary key in the tables


ALTER TABLE Products$
ALTER COLUMN Product VARCHAR(50) NOT NULL;


ALTER TABLE [Manufacturing_Line_Productivity].[dbo].[Products$]
ADD CONSTRAINT Product PRIMARY KEY (Product);

-------------------------------------------------------------------------------------------------------

ALTER TABLE [Manufacturing_Line_Productivity].[dbo].['Downtime factors$']
ALTER COLUMN Factor float NOT NULL;

ALTER TABLE [Manufacturing_Line_Productivity].[dbo].['Downtime factors$']
ADD CONSTRAINT Factor PRIMARY KEY (Factor);

-------------------------------------------------------------------------------------------------------
ALTER TABLE [Manufacturing_Line_Productivity].[dbo].['Line productivity$']
ALTER COLUMN Batch float NOT NULL;

ALTER TABLE [Manufacturing_Line_Productivity].[dbo].['Line productivity$']
ADD CONSTRAINT Batch PRIMARY KEY (Batch);

-------------------------------------------------------------------------------------------------------

-- Insights
--*************

--Main KPIs
--*************

-- 5- Display Flavors
Select [Flavor] AS Flavor, [Product] AS Products
from [Manufacturing_Line_Productivity].[dbo].[Products$]

----------------------------------------------------------------------------------------------------
-- 6- Display Operators
Select Distinct [Operator] AS Operator
from [Manufacturing_Line_Productivity].[dbo].['Line productivity$']

------------------------------------------------------------------------------------------------------

-- 7- Display Number of Batches
Select COUNT ([Batch]) AS No_Of_Batches
from [Manufacturing_Line_Productivity].[dbo].['Line productivity$']

-----------------------------------------------------------------------------------------------------

-- 8- Display Flavor + it's No. of baches + Manufacturing time of these batches 

SELECT 
    p.[Flavor], 
    COUNT(lp.[Batch]) AS Number_of_Batches, 
    SUM(lp.TimeSpentInMinutes) AS Manufacturing_Time
FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
JOIN [Manufacturing_Line_Productivity].[dbo].[Products$] p ON lp.Product = p.Product
GROUP BY p.Flavor
ORDER BY Manufacturing_Time DESC;

-----------------------------------------------------------------------------------------------------

-- 9- Diplay Total Productivity Time Vs Total Downtime And Downtime Percentage

WITH TimeData AS (
    SELECT 
        SUM(lp.TimeSpentInMinutes) AS Total_Productivity_Time,
        (SELECT SUM([DowntimeDuration]) FROM [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime]) AS Total_Downtime
    FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
)
SELECT 
    Total_Productivity_Time,
    Total_Downtime,
    CONCAT(CAST((Total_Downtime * 100 / NULLIF(Total_Productivity_Time, 0)) AS DECIMAL(5,2)), ' %') AS Downtime_Percentage
FROM TimeData;

-----------------------------------------------------------------------------------------------------------------------------

-- 10-  Display each day with it's productivity time and downtime and the percentage of downtime

WITH TimeData AS (
    SELECT 
        CAST(lp.[Date] AS DATE) AS Day, 
        SUM(lp.TimeSpentInMinutes) AS Total_Productivity_Time,
        SUM(up.[DowntimeDuration]) AS Total_Downtime
    FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
    LEFT JOIN [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] up
        ON lp.Batch = up.Batch  
    GROUP BY CAST(lp.[Date] AS DATE)
)
SELECT 
    Day,
    Total_Productivity_Time,
    Total_Downtime,
    CONCAT(CAST((Total_Downtime * 100 / NULLIF(Total_Productivity_Time, 0)) AS DECIMAL(5,2)), ' %') AS Downtime_Percentage
FROM TimeData
ORDER BY Day;

------------------------------------------------------------------------------------------------------------------------------

-- 11- The day with the highest manufacturing time

SELECT TOP 1 
    CAST([Date] AS DATE) AS Manufacturing_Date, 
    SUM([TimeSpentInMinutes]) AS TotalManufacturingTime
FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$']
GROUP BY CAST([Date] AS DATE)
ORDER BY TotalManufacturingTime DESC;


--------------------------------------------------------------------------------------------------------------------------------

-- Factor
--**************
-- 12- most factors causing downtime and its number of occcurences and if related to the operator or not (descinding)

SELECT 
    df.Description AS Factor, 
	SUM(d.DowntimeDuration) AS Total_Downtime_Duration,
    COUNT(d.Batch) AS Number_of_Occurrences,     
    df.[Operator Error] AS Related_To_Operator
FROM [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] d
JOIN [Manufacturing_Line_Productivity].[dbo].['Downtime factors$'] df 
    ON d.DowntimeFactor = df.[Factor] 
GROUP BY d.DowntimeFactor, df.Description, df.[Operator Error]
ORDER BY Total_Downtime_Duration DESC;

------------------------------------------------------------------------------------------------------------

-- 13- the downtime factor with the highest total downtime and if related to an operator error or not

	WITH TopDowntimeFactor AS (
    SELECT TOP 1 
        up.DowntimeFactor, 
        SUM(up.DowntimeDuration) AS Total_Downtime
    FROM [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] up
    GROUP BY up.DowntimeFactor
    ORDER BY Total_Downtime DESC
)
SELECT 
    df.Description AS Factor, 
    tdf.Total_Downtime,
    df.[Operator Error] AS Operator_Error
FROM TopDowntimeFactor tdf
JOIN [Manufacturing_Line_Productivity].[dbo].['Downtime factors$'] df 
    ON tdf.DowntimeFactor = df.[Factor]; 

------------------------------------------------------------------------------------------------------------------

-- 14- the most factor causing downtime duration at a timme (max factor) 

SELECT TOP 2
    df.Description AS Factor, 
    MAX(d.DowntimeDuration) AS Max_Downtime_Duration 
FROM [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] d
JOIN [Manufacturing_Line_Productivity].[dbo].['Downtime factors$'] df 
    ON d.DowntimeFactor = df.[Factor] 
GROUP BY d.DowntimeFactor, df.Description 
ORDER BY Max_Downtime_Duration DESC; 

--------------------------------------------------------------------------------------------------------------

-- Operator
--*****************

-- 15- the operator that has the most productivity time and his number of produced batches

WITH OperatorProductivity AS (
    SELECT 
        Operator, 
        SUM([TimeSpentInMinutes]) AS Total_TimeSpent_In_Minutes, 
        COUNT(Batch) AS NumberOfBatches
    FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$']
    GROUP BY Operator
)
SELECT TOP 1 *
FROM OperatorProductivity
ORDER BY Total_TimeSpent_In_Minutes DESC;

-------------------------------------------------------------------------------------------------------------
-- 16- the operator responsible for the most downtime

SELECT TOP 1 
    LP.Operator,  
    SUM(UP.DowntimeDuration) AS TotalDowntime
FROM [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] UP
JOIN [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] LP
    ON UP.Batch = LP.Batch  
GROUP BY LP.Operator
ORDER BY TotalDowntime DESC;

--------------------------------------------------------------------------------------------------------------

-- 17- display each operator and his number of produced batches ,his total productivity time, Downtime Occurences and his total downtime + downtime percentage 

WITH Productivity AS (
    SELECT 
        [Operator],
        COUNT([Batch]) AS Number_of_Batches,
        SUM(TimeSpentInMinutes) AS Total_Productivity_Time
    FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$']
    GROUP BY [Operator]
),
Downtime AS (
    SELECT 
        lp.[Operator],
        SUM(ISNULL(ud.[DowntimeDuration], 0)) AS Total_Downtime,
        COUNT(ud.Batch) AS Downtime_Occurrences
    FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
    JOIN [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] ud 
        ON lp.[Batch] = ud.[Batch]
    GROUP BY lp.[Operator]
)

SELECT 
    p.[Operator], 
    p.Number_of_Batches, 
    p.Total_Productivity_Time,
    ISNULL(d.Total_Downtime, 0) AS Total_Downtime,
    ISNULL(d.Downtime_Occurrences, 0) AS Downtime_Occurrences,
    CASE 
        WHEN p.Total_Productivity_Time = 0 THEN '0%'
        ELSE 
            CONCAT(CAST(CAST(ISNULL(d.Total_Downtime, 0) * 100 / p.Total_Productivity_Time AS DECIMAL(5,2)) AS VARCHAR) , '%') 
    END AS Downtime_Percentage
FROM Productivity p
LEFT JOIN Downtime d ON p.[Operator] = d.[Operator]
ORDER BY p.[Operator];

--------------------------------------------------------------------------------------------------------------------------------

-- 18- Frequency of Downtime by Operator in each Flavor

SELECT 
    lp.[Operator], 
    pr.[Flavor], 
    COUNT(ud.[Batch]) AS Number_of_Downtime_Occurrences
FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
JOIN [Manufacturing_Line_Productivity].[dbo].[Products$]pr 
    ON lp.[Product] = pr.[Product]  
JOIN [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] ud 
    ON lp.[Batch] = ud.[Batch] 
GROUP BY lp.[Operator], pr.[Flavor]  
ORDER BY lp.[Operator], pr.[Flavor];

------------------------------------------------------------------------------------------------------------------------------------------

-- 19- Analyze Operator Performance

SELECT 
    lp.Operator,
    COUNT(lp.Batch) AS Total_Batches,
    SUM(lp.TimeSpentInMinutes) AS Total_TimeSpent,
    MIN(lp.TimeSpentInMinutes) AS Fastest_BatchTime,
    MAX(lp.TimeSpentInMinutes) AS Slowest_BatchTime
FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
GROUP BY lp.Operator
 
-----------------------------------------------------------------------------------------------------------------

--Product and Flavor
--*****************
-- 20- Product that has the highest pructivity time

SELECT TOP 1 
    Product, 
    COUNT(Batch) AS Number_of_Batches, 
    SUM([TimeSpentInMinutes]) AS TotalTimeSpentInMinutes
FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$']
GROUP BY Product
ORDER BY TotalTimeSpentInMinutes DESC;

--------------------------------------------------------------------------------------------------------------

-- 21- flavor taking longer to manufacture

SELECT TOP 1 
        Flavor, 
    SUM([TimeSpentInMinutes]) AS Total_Manufacturing_Time
FROM [Manufacturing_Line_Productivity].[dbo].[Products$] P 
JOIN [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] LP  ON  LP.[Product] = P.[Product]
JOIN [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] UP ON UP.[Batch] = LP.[Batch] 
GROUP BY Flavor
ORDER BY Total_Manufacturing_Time DESC;

---------------------------------------------------------------------------------------------------------------

-- 22- Product that has the highest downtime

SELECT TOP 1 
    P.Product,  
    SUM(UP.[DowntimeDuration]) AS Total_Downtime
FROM [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] UP
JOIN [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] LP 
    ON UP.[Batch] = LP.[Batch] 
JOIN [Manufacturing_Line_Productivity].[dbo].[Products$] P  
    ON LP.[Product] = P.[Product]  
GROUP BY P.[Product]
ORDER BY Total_Downtime DESC;

--------------------------------------------------------------------------------------------------------------

-- 23- display each Product and its number of produced batches , total production time and total downtime

SELECT 
    lp.[Product] AS Product, 
    COUNT(lp.[Batch]) AS Number_of_Batches,
    SUM(lp.TimeSpentInMinutes) AS Total_Productivity_Time,
    SUM(ISNULL(ud.[DowntimeDuration], 0)) AS Total_Downtime,
    CASE 
        WHEN SUM(lp.TimeSpentInMinutes) = 0 THEN '0%'  
        ELSE 
           CONCAT(CAST(CAST(SUM(ISNULL(ud.[DowntimeDuration], 0)) * 100 / SUM(lp.TimeSpentInMinutes) AS DECIMAL(10,2)) AS VARCHAR) , '%')
    END AS Downtime_Percentage
FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
LEFT JOIN [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] ud 
    ON lp.[Batch] = ud.[Batch]
GROUP BY lp.[Product]
ORDER BY lp.[Product];

--------------------------------------------------------------------------------------------------------------------------------

-- 24- display each Flavor and its number of produced batches , total production time and total downtime

SELECT 
    pr.[Flavor],  
    COUNT(lp.[Batch]) AS Number_of_Batches,
    SUM(lp.TimeSpentInMinutes) AS Total_Productivity_Time,
    SUM(ISNULL(ud.[DowntimeDuration], 0)) AS Total_Downtime,
    COUNT(ud.Batch) AS Downtime_Occurrences,
    CASE 
        WHEN SUM(lp.TimeSpentInMinutes) = 0 THEN '0%'
        ELSE 
          CONCAT(
              CAST(
                  CAST(SUM(ISNULL(ud.[DowntimeDuration], 0)) * 100.0 / SUM(lp.TimeSpentInMinutes) AS DECIMAL(10,2)
              ) AS VARCHAR), '%')
    END AS Downtime_Percentage
FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
JOIN [Manufacturing_Line_Productivity].[dbo].[Products$] pr 
    ON lp.[Product] = pr.[Product]  
LEFT JOIN [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] ud 
    ON lp.[Batch] = ud.[Batch]
GROUP BY pr.[Flavor]  
ORDER BY pr.[Flavor];

--------------------------------------------------------------------------------------------------------------

-- 25- Production Efficiency

  WITH BatchComparison AS (
    SELECT 
        lp.Batch,
        lp.Product,
        lp.Operator,
        lp.TimeSpentInMinutes,
        p.[Min batch time] AS ExpectedBatchTime,
        (lp.TimeSpentInMinutes - p.[Min batch time]) AS TimeDifference,
        CASE 
            WHEN lp.TimeSpentInMinutes > p.[Min batch time] THEN 'Delayed'
            WHEN lp.TimeSpentInMinutes < p.[Min batch time] THEN 'Faster'
            ELSE 'On Time'
        END AS Status
    FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
    INNER JOIN [Manufacturing_Line_Productivity].[dbo].[Products$] p
        ON lp.Product = p.Product
)
SELECT * FROM BatchComparison;

------------------------------------------------------------------------------------------------------------

--DownTime 
--*************

-- 26- When does downtime most frequently occur? (By Shift)

SELECT TOP 1  
    CASE  
        WHEN DATEPART(HOUR, LP.[Start Time]) BETWEEN 6 AND 13 THEN 'Morning Shift'  
        WHEN DATEPART(HOUR, LP.[Start Time]) BETWEEN 14 AND 21 THEN 'Afternoon Shift'  
        ELSE 'Night Shift'  
    END AS Shift,  
    SUM(UP.[DowntimeDuration]) AS TotalDowntime  
FROM [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] UP  
JOIN [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] LP  
    ON UP.[Batch] = LP.[Batch] 
GROUP BY  
    CASE  
        WHEN DATEPART(HOUR, LP.[Start Time]) BETWEEN 6 AND 13 THEN 'Morning Shift'  
        WHEN DATEPART(HOUR, LP.[Start Time]) BETWEEN 14 AND 21 THEN 'Afternoon Shift'  
        ELSE 'Night Shift'  
    END  
ORDER BY TotalDowntime DESC;

-----------------------------------------------------------------------------------------------------------------------

-- 27- The longest downtime for a single batch

SELECT TOP 1 
    lp.Batch, 
    lp.[Product], 
    SUM(ld.DowntimeDuration) AS TotalDowntime
FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
JOIN [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] ld ON lp.Batch = ld.Batch
GROUP BY lp.Batch, lp.[Product]
ORDER BY TotalDowntime DESC;

-------------------------------------------------------------------------------------------------------------------------

-- 28- The day with the highest Downtime 

SELECT TOP 1 
    CAST([Date] AS DATE) AS Manufacturing_Date, 
    SUM(ud.DowntimeDuration) AS TotalDowntime
FROM Manufacturing_Line_Productivity.dbo.UnpivotedDowntime ud
JOIN [Manufacturing_Line_Productivity].[dbo].['Line productivity$']lp 
    ON ud.Batch = lp.Batch
GROUP BY CONVERT(DATE, lp.Date)
ORDER BY TotalDowntime DESC;

------------------------------------------------------------------------------------------------------------------------

--- 29-Prediction
--********************

-- Expected Number of Baches to be produced next day

WITH Actual_Production AS (
    SELECT 
        CAST(lp.[Date] AS DATE) AS Production_Date,
        COUNT(DISTINCT lp.Batch) AS Batches_Produced,
        SUM(lp.TimeSpentInMinutes) AS Total_Production_Time,
        SUM(udt.[DowntimeDuration]) AS Total_Downtime
    FROM [Manufacturing_Line_Productivity].[dbo].['Line productivity$'] lp
    LEFT JOIN [Manufacturing_Line_Productivity].[dbo].[UnpivotedDowntime] udt
        ON lp.Batch = udt.Batch
    GROUP BY CAST(lp.[Date] AS DATE)
)
SELECT 
    ROUND(SUM(Batches_Produced) / COUNT(Production_Date), 0) AS AvgDailyBatches, 
    ROUND(SUM(Total_Production_Time) / NULLIF(SUM(Batches_Produced), 0), 0) AS AvgTimePerBatch, 
    ROUND(
        (SUM(Total_Production_Time) / NULLIF(SUM(Total_Production_Time) + SUM(Total_Downtime), 0)) 
        * (SUM(Batches_Produced) / COUNT(Production_Date)), 0) AS PredictedBatchesTomorrow 
FROM Actual_Production;





