use AdventureWorksv2;

IF OBJECT_ID('tempdb..#Columnsreport') IS NOT NULL DROP TABLE #Columnsreport

CREATE TABLE #Columnsreport (
    TableName NVARCHAR(128),
    ColumnName NVARCHAR(128),
    NullCount INT
)

DECLARE @TableName NVARCHAR(128)
DECLARE @ColumnName NVARCHAR(128)
DECLARE @SchemaName NVARCHAR(128)
DECLARE @SQL NVARCHAR(MAX)

DECLARE table_cursor CURSOR FOR
SELECT 
    t.name AS TableName,
    c.name AS ColumnName,
    s.name AS SchemaName
FROM sys.tables t
JOIN sys.columns c ON t.object_id = c.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id

OPEN table_cursor

FETCH NEXT FROM table_cursor INTO @TableName, @ColumnName, @SchemaName

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'DECLARE @NullCount INT; ' +
               'SET @NullCount = (SELECT COUNT(*) FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) +
               ' WHERE ' + QUOTENAME(@ColumnName) + ' IS NULL); ' +
               'INSERT INTO #Columnsreport (TableName, ColumnName, NullCount) ' +
               'VALUES (''' + @SchemaName + '.' + @TableName + ''', ''' + @ColumnName + ''', @NullCount);'

    EXEC sp_executesql @SQL

    FETCH NEXT FROM table_cursor INTO @TableName, @ColumnName, @SchemaName
END

CLOSE table_cursor
DEALLOCATE table_cursor

--SELECT TableName, ColumnName, NullCount
--FROM #NumberofNulls

SELECT
    t.name AS [table],
    c.name AS field,
	
    TYPE_NAME(c.system_type_id) AS [type],
    p.rows AS n_records,
    x.NullCount as n_null

FROM sys.tables t
INNER JOIN sys.columns c ON t.object_id = c.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
INNER JOIN sys.partitions p ON t.object_id = p.object_id
INNER JOIN (
    SELECT TableName, ColumnName, NullCount, TableName + '.' + ColumnName AS id
    FROM #Columnsreport
) x ON x.id = s.name + '.' + t.name + '.' + c.name
WHERE p.index_id IN (0, 1)