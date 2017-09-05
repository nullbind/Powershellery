-- Create temp table
CREATE TABLE #file (content nvarchar(4000));

-- Read file into temp table
BULK INSERT #file FROM 'c:\temp\file.txt';

-- Select contents of file
SELECT content FROM #file
