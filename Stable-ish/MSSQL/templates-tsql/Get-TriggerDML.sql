-- Script: Get-TriggerDML.sql 
-- Return list of DML triggers at the database level for the current database. 

-- Return list of triggers at the database level for the current database.
select	@@SERVERNAME as server_name,
		DB_NAME() as database_name,
		OBJECT_NAME(parent_id) as parent_name,
		OBJECT_NAME(object_id) as trigger_name,
		OBJECT_DEFINITION(object_id) as trigger_definition,
		OBJECT_ID,
		CASE OBJECTPROPERTY(object_id, 'ExecIsTriggerDisabled')
          WHEN 1 THEN 'Disabled'
          ELSE 'Enabled'
        END AS status,
		OBJECTPROPERTY(object_id, 'ExecIsUpdateTrigger') AS isupdate ,
        OBJECTPROPERTY(object_id, 'ExecIsDeleteTrigger') AS isdelete ,
        OBJECTPROPERTY(object_id, 'ExecIsInsertTrigger') AS isinsert ,
        OBJECTPROPERTY(object_id, 'ExecIsAfterTrigger') AS isafter ,
        OBJECTPROPERTY(object_id, 'ExecIsInsteadOfTrigger') AS isinsteadof ,
		create_date,
		modify_date,
		is_ms_shipped,
		is_not_for_replication
FROM sys.triggers

