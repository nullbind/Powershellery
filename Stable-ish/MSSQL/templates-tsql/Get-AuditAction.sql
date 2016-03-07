-- Script: Get-AuditAction.sql
-- Requirements: Sysadmin or required SELECT privileges.
-- Description: Returns audit actions. 
-- Reference: https://msdn.microsoft.com/en-us/library/cc280725.aspx

Select DISTINCT action_id,name,class_desc,parent_class_desc,containing_group_name from sys.dm_audit_actions order by parent_class_desc,containing_group_name,name
