-- ***************************************************************************
-- This script will upgrade a database from version <source> of the Xadmin base schema to version
-- <target>.  If upgrading from a schema version earlier than <source>, multiple upgrade scripts may
-- have to be applied in ascending order by <target>.
--
-- This script should only be run against a database previously created and defined by platform-
-- and version-compatible "create" and "define" scripts.
--
-- For certain supported platforms, this script may be run repeatedly against a target compatible
-- database, including an already upgraded one, without error or data loss.  Please consult the
-- Xstore R&D group for a listing of officially supported platforms for which this convenience is
-- provided.
--
-- Source version:  19.0.x
-- Target version:  20.0.0
-- DB platform:     Microsoft SQL Server 2012/2014/2016
-- ***************************************************************************

-- ***************************************************************************
-- ***************************************************************************
-- 19.0.x -> 20.0.0
-- ***************************************************************************
-- ***************************************************************************
-- ***************************************************************************
PRINT '**************************************';
PRINT '* UPGRADE to release 20.0';
PRINT '**************************************';

IF  OBJECT_ID('dbo.SP_DEFAULT_CONSTRAINT_EXISTS') is not null
  DROP FUNCTION dbo.SP_DEFAULT_CONSTRAINT_EXISTS
GO

CREATE FUNCTION dbo.SP_DEFAULT_CONSTRAINT_EXISTS (@tableName nvarchar(max), @columnName varchar(max))
RETURNS nvarchar(255)
AS 
BEGIN
    DECLARE @return nvarchar(255)
    
    SELECT TOP 1 
            @return = default_constraints.name
        FROM 
            sys.all_columns
                INNER JOIN
            sys.tables
                ON all_columns.object_id = tables.object_id
                INNER JOIN 
            sys.schemas
                ON tables.schema_id = schemas.schema_id
                INNER JOIN
            sys.default_constraints
                ON all_columns.default_object_id = default_constraints.object_id
        WHERE 
                schemas.name = 'dbo'
            AND tables.name = @tableName
            AND all_columns.name = @columnName
            
    RETURN @return
END;
GO

--[RXPS-47686] END
  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'staging_progress' AND object_id = OBJECT_ID('dpl_deployment'))
  BEGIN
    EXEC('ALTER TABLE dpl_deployment ADD staging_progress numeric(3, 0) DEFAULT 0');
    PRINT 'dpl_deployment.staging_progress created';
  END
  GO
--[RXPS-47686] END

-- RXPS-48532 - START 
ALTER TABLE [dbo].[cfg_tender_options_change] ALTER COLUMN [fiscal_tndr_id] nvarchar(60) null
GO
-- RXPS-48532 - END

-- [RXPS-47081] 
IF EXISTS (SELECT 1 FROM sys.columns WHERE name = 'table_name' AND object_id = OBJECT_ID('dtx_def'))
BEGIN
    ALTER TABLE dtx_def ALTER COLUMN table_name nvarchar(128);
    PRINT 'Column length of dtx_def.table_name is altered to 128';
END
GO
-- [RXPS-47081] - END

-- [RXPS-44196] 
IF EXISTS (SELECT 1 FROM sys.columns WHERE name = 'blob_data' AND object_id = OBJECT_ID('qrtz_blob_triggers'))
BEGIN
    ALTER TABLE qrtz_blob_triggers ALTER COLUMN blob_data varbinary(max);
    PRINT 'Column type of qrtz_blob_triggers.blob_data is altered to varbinar(max)';
END
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE name = 'job_data' AND object_id = OBJECT_ID('qrtz_job_details'))
BEGIN
    ALTER TABLE qrtz_job_details ALTER COLUMN job_data varbinary(max);
    PRINT 'Column type of qrtz_job_details.job_data is altered to varbinar(max)';
END
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE name = 'calendar' AND object_id = OBJECT_ID('qrtz_calendars'))
BEGIN
    ALTER TABLE qrtz_calendars ALTER COLUMN calendar varbinary(max);
    PRINT 'Column type of qrtz_calendars.calendar is altered to varbinar(max)';
END
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE name = 'job_data' AND object_id = OBJECT_ID('qrtz_triggers'))
BEGIN
    ALTER TABLE qrtz_triggers ALTER COLUMN job_data varbinary(max);
    PRINT 'Column type of qrtz_triggers.job_data is altered to varbinar(max)';
END
GO
-- [RXPS-44196] - END

-- [RXPS-49184] - START
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'path' AND object_id = OBJECT_ID('ocds_subtask_details'))
BEGIN
  ALTER TABLE ocds_subtask_details ADD path nvarchar(120) NULL;
  PRINT 'ocds_subtask_details.path created'
END
GO
-- [RXPS-49184] - END

-- [RXPS-44418] START
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'print_as_inverted' AND object_id = OBJECT_ID('dat_exchange_rate_change'))
BEGIN
  EXEC('ALTER TABLE dat_exchange_rate_change ADD print_as_inverted bit DEFAULT ((0))');
  PRINT 'dat_exchange_rate_change.print_as_inverted created';
END
GO
-- [RXPS-44418] END

-- [RXPS-49182] - START
IF EXISTS (SELECT 1 FROM sys.columns WHERE name = 'active' AND object_id = OBJECT_ID('ocds_subtask_details'))
BEGIN
    DECLARE @v_subtask_id nvarchar(30),@v_organization_id INT, @sql nvarchar(max);
    DECLARE cursor_ocds_subtask_details CURSOR FOR SELECT organization_id, subtask_id FROM OCDS_SUBTASK_DETAILS;
    OPEN cursor_ocds_subtask_details;
    FETCH NEXT FROM cursor_ocds_subtask_details INTO @v_organization_id, @v_subtask_id;
    WHILE @@FETCH_STATUS=0
      BEGIN
        PRINT CONCAT('inserting ENABLE_', @v_subtask_id,'[orgId=', @v_organization_id, ']');
        SET @sql =CONCAT('INSERT INTO cfg_integration_p (organization_id, integration_system, implementation_type, integration_type, property_code, type, decimal_value, create_date, create_user_id, update_date, update_user_id)',' SELECT organization_id, integration_system, implementation_type, integration_type,','''ENABLE_',@v_subtask_id,''' AS property_code,','''BOOLEAN'' AS type,','ISNULL((SELECT active FROM OCDS_SUBTASK_DETAILS s WHERE s.organization_id = c.organization_id AND s.subtask_id = ''',@v_subtask_id,'''), 0) as decimal_value, create_date, create_user_id, update_date, update_user_id FROM cfg_integration c WHERE c.integration_system = ''OCDS'' AND c.organization_id = ',@v_organization_id,' AND (SELECT decimal_value FROM cfg_integration_p p WHERE p.organization_id = ',@v_organization_id,' AND p.integration_system = c.integration_system AND p.implementation_type = c.implementation_type AND p.integration_type = c.integration_type AND p.property_code = ','''ENABLE_',@v_subtask_id,''')','IS NULL')
        EXEC(@sql);
        FETCH NEXT FROM cursor_ocds_subtask_details INTO @v_organization_id, @v_subtask_id;
      END
    CLOSE cursor_ocds_subtask_details;
    DEALLOCATE cursor_ocds_subtask_details
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE name = 'active' AND object_id = OBJECT_ID('ocds_subtask_details'))
BEGIN
DECLARE @sql nvarchar(max);
  SELECT @sql ='Alter Table ocds_subtask_details Drop Constraint [' + ( SELECT d.name
         FROM 
             sys.tables t
             JOIN sys.default_constraints d ON d.parent_object_id = t.object_id
             JOIN sys.columns c ON c.object_id = t.object_id
                               AND c.column_id = d.parent_column_id
         WHERE 
             t.name = 'ocds_subtask_details'
             and c.name = 'active') + ']'
    EXEC (@sql)
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE name = 'active' AND object_id = OBJECT_ID('ocds_subtask_details'))
BEGIN
  ALTER TABLE ocds_subtask_details DROP COLUMN active
  PRINT 'ocds_subtask_details.active dropped';
END
GO
-- [RXPS-49182] - END

-- [RXPS-49862] START
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'legal_form' AND object_id = OBJECT_ID('dat_legal_entity_change'))
BEGIN
  EXEC('ALTER TABLE dat_legal_entity_change ADD legal_form nvarchar(60) NULL');
  PRINT 'dat_legal_entity_change.legal_form created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'social_capital' AND object_id = OBJECT_ID('dat_legal_entity_change'))
BEGIN
  EXEC('ALTER TABLE dat_legal_entity_change ADD social_capital nvarchar(60) NULL');
  PRINT 'dat_legal_entity_change.social_capital created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'companies_register_number' AND object_id = OBJECT_ID('dat_legal_entity_change'))
BEGIN
  EXEC('ALTER TABLE dat_legal_entity_change ADD companies_register_number nvarchar(30) NULL');
  PRINT 'dat_legal_entity_change.companies_register_number created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'fax_number' AND object_id = OBJECT_ID('dat_legal_entity_change'))
BEGIN
  EXEC('ALTER TABLE dat_legal_entity_change ADD fax_number nvarchar(32) NULL');
  PRINT 'dat_legal_entity_change.fax_number created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'phone_number' AND object_id = OBJECT_ID('dat_legal_entity_change'))
BEGIN
  EXEC('ALTER TABLE dat_legal_entity_change ADD phone_number nvarchar(32) NULL');
  PRINT 'dat_legal_entity_change.phone_number created';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'web_site' AND object_id = OBJECT_ID('dat_legal_entity_change'))
BEGIN
  EXEC('ALTER TABLE dat_legal_entity_change ADD web_site nvarchar(254) NULL');
  PRINT 'dat_legal_entity_change.web_site created';
END
GO
-- [RXPS-49862] END

-- [RXPS-53350] START

PRINT '     Step Alter Column: DTX[cfg_menu_config] Field[Field=active_flag] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cfg_menu_config', 'active_flag') ) IS NULL
  PRINT '     Default value Constraint for column [cfg_menu_config].[active_flag] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cfg_menu_config] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cfg_menu_config','active_flag')+'];' 
  EXEC(@sql) 
  PRINT '     cfg_menu_config.active_flag default value dropped';
  END
GO
BEGIN
    EXEC('ALTER TABLE cfg_menu_config ALTER COLUMN [active_flag] BIT NOT NULL');
    EXEC('ALTER TABLE cfg_menu_config ADD DEFAULT 0 FOR [active_flag]');
  PRINT '     Column cfg_menu_config.active_flag modify';
END
GO
PRINT '     Step Alter Column: DTX[ChargeAccountHistory] Field[Field=active_flag] end.';

PRINT '     Step Drop Index: DTX[DAT_ITEM_CHANGE] Index[XST_DAT_ITEM_CHANGE_ID_PARENTID] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'XST_DAT_ITEM_CHANGE_ID_PARENTID' AND object_id = OBJECT_ID(N'DAT_ITEM_CHANGE'))
  BEGIN
    EXEC('DROP INDEX [XST_DAT_ITEM_CHANGE_ID_PARENTID] ON [dbo].[DAT_ITEM_CHANGE]');
    PRINT '     Index XST_DAT_ITEM_CHANGE_ID_PARENTID created';
  END
ELSE
  PRINT '     Index XST_DAT_ITEM_CHANGE_ID_PARENTID does not exist';
GO
PRINT '     Step Drop Index: DTX[DAT_ITEM_CHANGE] Index[XST_DAT_ITEM_CHANGE_ID_PARENTID] end.';

PRINT '     Step Add Index: DTX[DAT_ITEM_CHANGE] Index[XST_DAT_ITEM_CHANGE_ID_PARNTID] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'XST_DAT_ITEM_CHANGE_ID_PARNTID' AND object_id = OBJECT_ID(N'DAT_ITEM_CHANGE'))
  PRINT '     Index XST_DAT_ITEM_CHANGE_ID_PARNTID already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [XST_DAT_ITEM_CHANGE_ID_PARNTID] ON [dbo].[DAT_ITEM_CHANGE](ORGANIZATION_ID, PARENT_ITEM_ID, ITEM_ID)');
    PRINT '     Index XST_DAT_ITEM_CHANGE_ID_PARNTID created';
  END
GO
PRINT '     Step Add Index: DTX[DAT_ITEM_CHANGE] Index[XST_DAT_ITEM_CHANGE_ID_PARNTID] end.';

PRINT '     Step Drop Index: DTX[DAT_ITEM_CHANGE] Index[XST_DAT_ITEM_CHANGE_DESCRIPTION] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'XST_DAT_ITEM_CHANGE_DESCRIPTION' AND object_id = OBJECT_ID(N'DAT_ITEM_CHANGE'))
  BEGIN
    EXEC('DROP INDEX [XST_DAT_ITEM_CHANGE_DESCRIPTION] ON [dbo].[DAT_ITEM_CHANGE]');
    PRINT '     Index XST_DAT_ITEM_CHANGE_DESCRIPTION created';
  END
ELSE
  PRINT '     Index XST_DAT_ITEM_CHANGE_DESCRIPTION does not exist';
GO
PRINT '     Step Drop Index: DTX[DAT_ITEM_CHANGE] Index[XST_DAT_ITEM_CHANGE_DESCRIPTION] end.';

PRINT '     Step Add Index: DTX[DAT_ITEM_CHANGE] Index[XST_DAT_ITEM_CHANGE_DESC] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'XST_DAT_ITEM_CHANGE_DESC' AND object_id = OBJECT_ID(N'DAT_ITEM_CHANGE'))
  PRINT '     Index XST_DAT_ITEM_CHANGE_DESC already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [XST_DAT_ITEM_CHANGE_DESC] ON [dbo].[DAT_ITEM_CHANGE](ORGANIZATION_ID, DESCRIPTION)');
    PRINT '     Index XST_DAT_ITEM_CHANGE_DESC created';
  END
GO
PRINT '     Step Add Index: DTX[DAT_ITEM_CHANGE] Index[XST_DAT_ITEM_CHANGE_DESC] end.';

PRINT '     Alter Column: DTX[QRTZ_FIRED_TRIGGERS] Column[TRIGGER_NAME] starting...';
ALTER TABLE QRTZ_FIRED_TRIGGERS ALTER COLUMN TRIGGER_NAME nvarchar(200) NOT NULL;
GO
PRINT '     Alter Column: DTX[QRTZ_FIRED_TRIGGERS] Column[TRIGGER_NAME] end.';

PRINT '     Alter Column: DTX[QRTZ_FIRED_TRIGGERS] Column[TRIGGER_GROUP] starting...';
ALTER TABLE QRTZ_FIRED_TRIGGERS ALTER COLUMN TRIGGER_GROUP nvarchar(200) NOT NULL;
GO
PRINT '     Alter Column: DTX[QRTZ_FIRED_TRIGGERS] Column[TRIGGER_GROUP] end.';

PRINT '     Alter Column: DTX[DTX_RELATIONSHIP] Column[OTHER_DTX_NAME] starting...';
ALTER TABLE DTX_RELATIONSHIP ALTER COLUMN OTHER_DTX_NAME nvarchar(256);
GO
PRINT '     Alter Column: DTX[DTX_RELATIONSHIP] Column[OTHER_DTX_NAME] end.';

PRINT '     Step Add Column: DTX[DAT_RETAIL_LOCATION_P_CHANGE] Column[[Field=RECORD_STATE]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'DAT_RETAIL_LOCATION_P_CHANGE') AND name in (N'RECORD_STATE'))
  PRINT '      Column DAT_RETAIL_LOCATION_P_CHANGE.RECORD_STATE already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE DAT_RETAIL_LOCATION_P_CHANGE ADD [RECORD_STATE] nvarchar(30)');
    PRINT '     Column DAT_RETAIL_LOCATION_P_CHANGE.RECORD_STATE created';
  END
GO
PRINT '     Step Add Column: DTX[DAT_RETAIL_LOCATION_P_CHANGE] Column[[Field=RECORD_STATE]] end.';

PRINT '     Alter Column: DTX[CFG_CODE_VALUE] Column[DESCRIPTION] starting...';
ALTER TABLE CFG_CODE_VALUE ALTER COLUMN DESCRIPTION nvarchar(256);
GO
PRINT '     Alter Column: DTX[CFG_CODE_VALUE] Column[DESCRIPTION] end.';

PRINT '     Step Add Column: DTX[CFG_REASON_CODE_P_CHANGE] Column[[Field=ENABLED_FLAG]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'CFG_REASON_CODE_P_CHANGE') AND name in (N'ENABLED_FLAG'))
  PRINT '      Column CFG_REASON_CODE_P_CHANGE.ENABLED_FLAG already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE CFG_REASON_CODE_P_CHANGE ADD [ENABLED_FLAG] bit DEFAULT 0 NULL');
    PRINT '     Column CFG_REASON_CODE_P_CHANGE.ENABLED_FLAG created';
  END
GO
PRINT '     Step Add Column: DTX[CFG_REASON_CODE_P_CHANGE] Column[[Field=ENABLED_FLAG]] end.';

PRINT '     Alter Column: DTX[DTX_FIELD] Column[COLUMN_NAME] starting...';
ALTER TABLE DTX_FIELD ALTER COLUMN COLUMN_NAME nvarchar(30);
GO
PRINT '     Alter Column: DTX[DTX_FIELD] Column[COLUMN_NAME] end.';

-- [RXPS-53350] END

-- [RXPS-53422] START
ALTER TABLE [dbo].qrtz_calendars ALTER COLUMN calendar varbinary(max) null
-- [RXPS-53422] END

-- [RXPS-54991] START

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'establishment_code' AND object_id = OBJECT_ID('dat_legal_entity_change'))
BEGIN
  ALTER TABLE dat_legal_entity_change ADD establishment_code nvarchar(30) NULL;
  PRINT 'dat_legal_entity_change.establishment_code added';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE name = 'registration_city' AND object_id = OBJECT_ID('dat_legal_entity_change'))
BEGIN
  ALTER TABLE dat_legal_entity_change ADD registration_city nvarchar(254) NULL;
  PRINT 'dat_legal_entity_change.registration_city added';
END
GO

-- [RXPS-54991] END


-- LEAVE BLANK LINE BELOW
