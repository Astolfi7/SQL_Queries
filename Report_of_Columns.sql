USE AdventureWorksv2;

IF OBJECT_ID('tempdb..#Columnsreport') IS NOT NULL DROP TABLE #Columnsreport;

CREATE TABLE #Columnsreport (
    TableName NVARCHAR(128),
    ColumnName NVARCHAR(128),
    NullCount INT
);

DECLARE @TableName NVARCHAR(128);
DECLARE @ColumnName NVARCHAR(128);
DECLARE @SchemaName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);

DECLARE table_cursor CURSOR FOR
SELECT 
    t.name AS TableName,
    c.name AS ColumnName,
    s.name AS SchemaName
FROM sys.tables t
JOIN sys.columns c ON t.object_id = c.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id;

OPEN table_cursor;

FETCH NEXT FROM table_cursor INTO @TableName, @ColumnName, @SchemaName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'DECLARE @NullCount INT; ' +
               'SET @NullCount = (SELECT COUNT(*) FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) +
               ' WHERE ' + QUOTENAME(@ColumnName) + ' IS NULL); ' +
               'INSERT INTO #Columnsreport (TableName, ColumnName, NullCount) ' +
               'VALUES (''' + @SchemaName + '.' + @TableName + ''', ''' + @ColumnName + ''', @NullCount);';

    EXEC sp_executesql @SQL;

    FETCH NEXT FROM table_cursor INTO @TableName, @ColumnName, @SchemaName;
END;

CLOSE table_cursor;
DEALLOCATE table_cursor;

SELECT DISTINCT
    t.name AS [table],
    c.name AS field,
	CASE WHEN pkc.object_id IS NOT NULL THEN 'Yes' ELSE 'No' END AS IsPrimary,
    CASE WHEN uc.object_id IS NOT NULL THEN 'Yes' ELSE 'No' END AS IsUnique,
    TYPE_NAME(c.system_type_id) AS [type],
    p.rows AS n_records,
    x.NullCount
    
FROM sys.tables t
INNER JOIN sys.columns c ON t.object_id = c.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
INNER JOIN sys.partitions p ON t.object_id = p.object_id
INNER JOIN (
    SELECT TableName, ColumnName, NullCount, TableName + '.' + ColumnName AS id
    FROM #Columnsreport
) x ON x.id = s.name + '.' + t.name + '.' + c.name
LEFT JOIN sys.key_constraints pkc ON pkc.parent_object_id = t.object_id AND pkc.type = 'PK' AND c.column_id IN (
    SELECT ic.column_id
    FROM sys.index_columns ic
    WHERE ic.object_id = pkc.parent_object_id AND ic.index_id = pkc.unique_index_id
)
LEFT JOIN sys.key_constraints uc ON uc.parent_object_id = t.object_id AND uc.type = 'UQ' AND EXISTS (
    SELECT 1
    FROM sys.indexes ui
    INNER JOIN sys.index_columns uic ON uic.object_id = ui.object_id AND uic.index_id = ui.index_id
    WHERE ui.is_unique = 1
        AND uic.column_id = c.column_id
        AND ui.object_id = uc.unique_index_id
)
WHERE p.index_id IN (0, 1)
    AND OBJECTPROPERTY(t.object_id, 'IsMSShipped') = 0 -- Exclude system tables
    AND t.type_desc <> 'VIEW'; -- Exclude views

