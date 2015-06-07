-- Script: Get-DatabasePriv.sql
-- Description: This script will return all of the database user
--	privileges for the current database.
-- Reference: http://msdn.microsoft.com/en-us/library/ms188367.aspx
-- Note: This line below will also show full privs for sysadmin users
--       SELECT * FROM fn_my_permissions(NULL, 'DATABASE'); 

SELECT  distinct class_desc as [CLASS_DESC],
	c.name AS [GRANTOR],
	b.name AS [GRANTEE],
	b.type_desc AS [PRINCIPAL_TYPE],
	ISNULL(SCH.name + N'.' + OBJ.name,DB_NAME()) AS [OBJECT_NAME],
	a.permission_name AS [PERMISSION_NAME],
	a.state_desc AS [PERMISSION_STATE]
FROM [sys].[database_permissions] a
INNER JOIN [sys].[database_principals] b
	ON a.grantee_principal_id = b.principal_id
INNER JOIN [sys].[database_principals] c
	ON a.grantor_principal_id = c.principal_id
LEFT JOIN [sys].[objects] AS OBJ
    ON a.major_id = OBJ.object_id
LEFT JOIN [sys].[schemas] AS SCH
    ON OBJ.schema_id = SCH.schema_id
LEFT JOIN [sys].[columns] AS COL
    ON a.major_id = COL.object_id
    AND a.minor_id = COL.column_id
ORDER BY CLASS_DESC,GRANTEE