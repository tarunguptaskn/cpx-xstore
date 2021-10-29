-- ***************************************************************************
-- This script will upgrade a database from version <source> of the Xstore base schema to version
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


PRINT '***** Prefix scripts start *****';


IF  OBJECT_ID('Create_Property_Table') is not null
       DROP PROCEDURE Create_Property_Table
GO

CREATE PROCEDURE Create_Property_Table
  -- Add the parameters for the stored procedure here
  @tableName nvarchar(30)
AS
BEGIN
  declare @sql nvarchar(max),
      @column nvarchar(30),
      @pk nvarchar(max),
      @datatype nvarchar(10),
      @maxlen nvarchar(4),
      @prec nvarchar(3),
      @scale nvarchar(3),
      @deflt nvarchar(50);
  SET NOCOUNT ON;

  IF OBJECT_ID(@tableName + '_p') IS NOT NULL or OBJECT_ID(@tableName) IS NULL or RIGHT(@tableName,2)='_p' or NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS C JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS K
  ON C.TABLE_NAME = K.TABLE_NAME AND C.CONSTRAINT_CATALOG = K.CONSTRAINT_CATALOG AND C.CONSTRAINT_SCHEMA = K.CONSTRAINT_SCHEMA AND C.CONSTRAINT_NAME = K.CONSTRAINT_NAME
  WHERE C.CONSTRAINT_TYPE = 'PRIMARY KEY' and K.TABLE_NAME = @tableName and K.COLUMN_NAME = 'organization_id')
    return;

  set @pk = '';
  set @sql='CREATE TABLE dbo.' + @tableName + '_p (
  '
    declare mycur CURSOR Fast_Forward FOR
  SELECT COL.COLUMN_NAME,DATA_TYPE,CHARACTER_MAXIMUM_LENGTH,NUMERIC_PRECISION,NUMERIC_SCALE,replace(replace(COLUMN_DEFAULT,'(',''),')','') FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS C JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS K
  ON C.TABLE_NAME = K.TABLE_NAME AND C.CONSTRAINT_CATALOG = K.CONSTRAINT_CATALOG AND C.CONSTRAINT_SCHEMA = K.CONSTRAINT_SCHEMA AND C.CONSTRAINT_NAME = K.CONSTRAINT_NAME
  join INFORMATION_SCHEMA.COLUMNS col ON C.TABLE_NAME=col.TABLE_NAME and K.COLUMN_NAME=COL.COLUMN_NAME
  WHERE C.CONSTRAINT_TYPE = 'PRIMARY KEY' and K.TABLE_NAME = @tableName
  order by K.ORDINAL_POSITION

  open mycur;

  while 1=1
  BEGIN
    FETCH NEXT FROM mycur INTO @column,@datatype,@maxlen,@prec,@scale,@deflt;
    IF @@FETCH_STATUS <> 0
      BREAK;

      set @pk=@pk + @column + ','

    set @sql=@sql + @column + ' ' + @datatype

    if @datatype='varchar' or @datatype='nvarchar' or @datatype='char' or @datatype='nchar'
      set @sql=@sql + '(' + @maxlen + ')'
    else if @datatype='numeric' or @datatype='decimal'
      set @sql=@sql + '(' + @prec + ',' + @scale + ')'

    if LEN(@deflt)>0
      set @sql=@sql + ' DEFAULT ' + @deflt

    set @sql=@sql + ' NOT NULL,
  '
  END
  close mycur
  deallocate mycur

  set @sql=@sql + 'property_code nvarchar(30) NOT NULL,
    type nvarchar(30) NULL,
    string_value nvarchar(4000) NULL,
    date_value datetime NULL,
    decimal_value decimal(17,6) NULL,
    create_date datetime NULL,
    create_user_id nvarchar(256) NULL,
    update_date datetime NULL,
    update_user_id nvarchar(256) NULL,
    record_state nvarchar(30) NULL,
  '

  if LEN('pk_'+ @tableName + '_p')>30
    set @sql=@sql + 'CONSTRAINT ' + REPLACE('pk_'+ @tableName + '_p','_','') + ' PRIMARY KEY CLUSTERED (' + @pk + 'property_code) WITH (FILLFACTOR = 80))'
  else
    set @sql=@sql + 'CONSTRAINT pk_'+ @tableName + '_p PRIMARY KEY CLUSTERED (' + @pk + 'property_code) WITH (FILLFACTOR = 80))'

  print '--- CREATING TABLE ' + @tableName + '_p ---'
  exec(@sql);
END
GO


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

IF  OBJECT_ID('dbo.SP_PK_CONSTRAINT_EXISTS') is not null
  DROP FUNCTION dbo.SP_PK_CONSTRAINT_EXISTS
GO

CREATE FUNCTION dbo.SP_PK_CONSTRAINT_EXISTS (@tableName nvarchar(max))
RETURNS nvarchar(255)
AS 
BEGIN
    DECLARE @return nvarchar(255)
    
    SELECT TOP 1 
            @return = Tab.Constraint_Name 
       FROM 
            INFORMATION_SCHEMA.TABLE_CONSTRAINTS Tab, 
            INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE Col 
       WHERE 
            Col.Constraint_Name = Tab.Constraint_Name
            AND Col.Table_Name = Tab.Table_Name
            AND Constraint_Type = 'PRIMARY KEY'
            AND Col.Table_Name = @tableName
            
    RETURN @return
END;
GO

PRINT '***** Prefix scripts end *****';


PRINT '***** Body scripts start *****';

PRINT '     Step Add Table: DTX[OfflinePOSTransaction] starting...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('CTL_OFFLINE_POS_TRANSACTION'))
  PRINT '      Table ctl_offline_pos_transaction already exists';
ELSE
  BEGIN
    EXEC('CREATE TABLE [dbo].[ctl_offline_pos_transaction](
[organization_id] INT NOT NULL,
[uuid] nvarchar(36) NOT NULL,
[rtl_loc_id] INT,
[wkstn_id] BIGINT,
[timestamp_end] DATETIME,
[cust_email] nvarchar(254),
[sale_items_count] INT,
[trans_total] DECIMAL(17, 6),
[serialized_data] VARBINARY(MAX) NOT NULL,
[processed_flag] BIT DEFAULT (0) NOT NULL,
[create_user_id] nvarchar(256),
[create_date] DATETIME,
[update_user_id] nvarchar(256),
[update_date] DATETIME,
[record_state] nvarchar(30), 
CONSTRAINT [pk_ctl_offline_pos_transaction] PRIMARY KEY CLUSTERED (organization_id, uuid))
');
  PRINT '      Table ctl_offline_pos_transaction created';
  END
GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('CTL_OFFLINE_POS_TRANSACTION_P'))
  PRINT '      Table ctl_offline_pos_transaction_P already exists';
ELSE
  BEGIN
    EXEC('CREATE_PROPERTY_TABLE ctl_offline_pos_transaction;');
  PRINT '     Table ctl_offline_pos_transaction_P created';
  END
GO


PRINT '     Step Add Table: DTX[OfflinePOSTransaction] end.';



PRINT '     Step Alter Column: DTX[OfflinePOSTransaction] Field[[Field=uuid, Field=workstationId]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction') ) IS NULL
  PRINT '     PK ctl_offline_pos_transaction is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_offline_pos_transaction] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('ctl_offline_pos_transaction')+'];' 
  EXEC(@sql) 
    PRINT '     PK ctl_offline_pos_transaction dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction_P') ) IS NULL
  PRINT '     PK ctl_offline_pos_transaction_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_offline_pos_transaction_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('ctl_offline_pos_transaction_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK ctl_offline_pos_transaction_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction', 'uuid') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_offline_pos_transaction].[uuid] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_offline_pos_transaction] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_offline_pos_transaction','uuid')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_offline_pos_transaction.uuid default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_offline_pos_transaction ALTER COLUMN [uuid] nvarchar(36) NOT NULL');
  PRINT '     Column ctl_offline_pos_transaction.uuid modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction_P', 'uuid') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_offline_pos_transaction_P].[uuid] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_offline_pos_transaction_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_offline_pos_transaction_P','uuid')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_offline_pos_transaction_P.uuid default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_offline_pos_transaction_P ALTER COLUMN [uuid] nvarchar(36) NOT NULL');
  PRINT '     Column ctl_offline_pos_transaction_P.uuid modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction') ) IS NOT NULL
  PRINT '     PK ctl_offline_pos_transaction already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE ctl_offline_pos_transaction ADD CONSTRAINT [pk_ctl_offline_pos_transaction] PRIMARY KEY CLUSTERED (organization_id, uuid)');
    PRINT '     PK ctl_offline_pos_transaction created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction_P') ) IS NOT NULL
  PRINT '     PK ctl_offline_pos_transaction_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE ctl_offline_pos_transaction_P ADD CONSTRAINT [pk_ctl_offline_pos_transaction_P] PRIMARY KEY CLUSTERED (organization_id, uuid, property_code)');
    PRINT '     PK ctl_offline_pos_transaction_P created';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction', 'wkstn_id') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_offline_pos_transaction].[wkstn_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_offline_pos_transaction] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_offline_pos_transaction','wkstn_id')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_offline_pos_transaction.wkstn_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_offline_pos_transaction ALTER COLUMN [wkstn_id] BIGINT');
  PRINT '     Column ctl_offline_pos_transaction.wkstn_id modify';
END
GO
PRINT '     Step Alter Column: DTX[OfflinePOSTransaction] Field[[Field=uuid, Field=workstationId]] end.';



PRINT '     Step Add Column: DTX[DeTseDeviceRegister] Column[[Field=voidFlag]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'cger_tse_device_register') AND name in (N'void_flag'))
  PRINT '      Column cger_tse_device_register.void_flag already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE cger_tse_device_register ADD [void_flag] BIT DEFAULT (0)');
    PRINT '     Column cger_tse_device_register.void_flag created';
  END
GO


PRINT '     Step Add Column: DTX[DeTseDeviceRegister] Column[[Field=voidFlag]] end.';



PRINT '     Step Add Table: DTX[TransactionAttachment] starting...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('TRN_TRANS_ATTACHMENT'))
  PRINT '      Table trn_trans_attachment already exists';
ELSE
  BEGIN
    EXEC('CREATE TABLE [dbo].[trn_trans_attachment](
[organization_id] INT NOT NULL,
[rtl_loc_id] INT NOT NULL,
[business_date] DATETIME NOT NULL,
[wkstn_id] BIGINT NOT NULL,
[trans_seq] BIGINT NOT NULL,
[attachment_type] nvarchar(60) NOT NULL,
[attachment_data] VARBINARY(MAX),
[create_user_id] nvarchar(256),
[create_date] DATETIME,
[update_user_id] nvarchar(256),
[update_date] DATETIME,
[record_state] nvarchar(30), 
CONSTRAINT [pk_trn_trans_attachment] PRIMARY KEY CLUSTERED (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, attachment_type))
');
  PRINT '      Table trn_trans_attachment created';
  END
GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('TRN_TRANS_ATTACHMENT_P'))
  PRINT '      Table trn_trans_attachment_P already exists';
ELSE
  BEGIN
    EXEC('CREATE_PROPERTY_TABLE trn_trans_attachment;');
  PRINT '     Table trn_trans_attachment_P created';
  END
GO


PRINT '     Step Add Table: DTX[TransactionAttachment] end.';



PRINT '     Step Alter Column: DTX[TenderOptions] Field[[Field=fiscalTenderId]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('tnd_tndr_options', 'fiscal_tndr_id') ) IS NULL
  PRINT '     Default value Constraint for column [tnd_tndr_options].[fiscal_tndr_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [tnd_tndr_options] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('tnd_tndr_options','fiscal_tndr_id')+'];' 
  EXEC(@sql) 
  PRINT '     tnd_tndr_options.fiscal_tndr_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE tnd_tndr_options ALTER COLUMN [fiscal_tndr_id] nvarchar(60)');
  PRINT '     Column tnd_tndr_options.fiscal_tndr_id modify';
END
GO
PRINT '     Step Alter Column: DTX[TenderOptions] Field[[Field=fiscalTenderId]] end.';



PRINT '     Step Move the old data in to the new column starting...';
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'trn_trans_attachment') AND type in (N'U'))
  PRINT 'Moving CFDI_XML to the trn_trans_attachment table not executed'
ELSE
  BEGIN
    INSERT INTO trn_trans_attachment (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, attachment_type, attachment_data, create_date, create_user_id)
    SELECT t1.organization_id, t1.rtl_loc_id, t1.business_date, t1.wkstn_id, t1.trans_seq, 'MX_INVOICE', t1.receipt_data, t1.create_date, 'SYSTEM'
    FROM trn_receipt_data t1
    LEFT JOIN trn_trans_attachment t2
    ON t2.organization_id = t1.organization_id
    AND t2.rtl_loc_id = t1.rtl_loc_id
    AND t2.business_date = t1.business_date
    AND t2.wkstn_id = t1.wkstn_id
    AND t2.trans_seq = t1.trans_seq
    AND t2.attachment_type = 'MX_INVOICE'
    WHERE t1.receipt_id = 'CFDI_XML' AND t1.receipt_data IS NOT NULL 
    AND t2.organization_id IS NULL;
    PRINT 'Moved CFDI_XML to the trn_trans_attachment table executed'
  END
GO
PRINT '     Step Move the old data in to the new column end.';



PRINT '     Step Add Column: DTX[TenderExchangeRate] Column[[Field=printAsInverted]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'tnd_exchange_rate') AND name in (N'print_as_inverted'))
  PRINT '      Column tnd_exchange_rate.print_as_inverted already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE tnd_exchange_rate ADD [print_as_inverted] BIT DEFAULT (0)');
    PRINT '     Column tnd_exchange_rate.print_as_inverted created';
  END
GO


PRINT '     Step Add Column: DTX[TenderExchangeRate] Column[[Field=printAsInverted]] end.';



PRINT '     Step Add Table: DTX[DealLoc] starting...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('PRC_DEAL_LOC'))
  PRINT '      Table prc_deal_loc already exists';
ELSE
  BEGIN
    EXEC('CREATE TABLE [dbo].[prc_deal_loc](
[organization_id] INT NOT NULL,
[deal_id] nvarchar(60) NOT NULL,
[rtl_loc_id] INT NOT NULL,
[create_user_id] nvarchar(256),
[create_date] DATETIME,
[update_user_id] nvarchar(256),
[update_date] DATETIME,
[record_state] nvarchar(30), 
CONSTRAINT [pk_prc_deal_loc] PRIMARY KEY CLUSTERED (organization_id, deal_id, rtl_loc_id))
');
  PRINT '      Table prc_deal_loc created';
  END
GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('PRC_DEAL_LOC_P'))
  PRINT '      Table prc_deal_loc_P already exists';
ELSE
  BEGIN
    EXEC('CREATE_PROPERTY_TABLE prc_deal_loc;');
  PRINT '     Table prc_deal_loc_P created';
  END
GO


PRINT '     Step Add Table: DTX[DealLoc] end.';



PRINT '     Step Population of PRC_DEAL_LOC starting...';
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('prc_deal_loc')) or (0=$(StoreID))
  PRINT 'Population of prc_deal_loc not executed'
ELSE
BEGIN
  MERGE INTO prc_deal_loc l
  USING (SELECT organization_id, deal_id, create_date, create_user_id, update_date, update_user_id FROM prc_deal) d 
    ON (l.organization_id = d.organization_id AND l.deal_id = d.deal_id)
  WHEN NOT MATCHED THEN
    INSERT (organization_id, deal_id, rtl_loc_id, create_date, create_user_id, update_date, update_user_id)
    VALUES (d.organization_id, d.deal_id, $(StoreID), d.create_date, d.create_user_id, d.update_date, d.update_user_id);

  PRINT 'Population of prc_deal_loc completed'
END
GO
PRINT '     Step Population of PRC_DEAL_LOC end.';



PRINT '     Step Add Table: DTX[TemporaryStoreRequest] starting...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('LOC_TEMP_STORE_REQUEST'))
  PRINT '      Table loc_temp_store_request already exists';
ELSE
  BEGIN
    EXEC('CREATE TABLE [dbo].[loc_temp_store_request](
[organization_id] INT NOT NULL,
[rtl_loc_id] INT NOT NULL,
[request_id] BIGINT NOT NULL,
[request_type] nvarchar(30),
[store_created_flag] BIT,
[description] nvarchar(254),
[start_date_str] nvarchar(8) NOT NULL,
[end_date_str] nvarchar(8),
[active_date_str] nvarchar(8),
[assigned_server_host] nvarchar(254),
[assigned_server_port] INT,
[status] nvarchar(30) NOT NULL,
[approve_reject_notes] nvarchar(254),
[use_store_tax_loc_flag] BIT DEFAULT (1) NOT NULL,
[create_user_id] nvarchar(256),
[create_date] DATETIME,
[update_user_id] nvarchar(256),
[update_date] DATETIME,
[record_state] nvarchar(30), 
CONSTRAINT [pk_loc_temp_store_request] PRIMARY KEY CLUSTERED (organization_id, rtl_loc_id, request_id))
');
  PRINT '      Table loc_temp_store_request created';
  END
GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('LOC_TEMP_STORE_REQUEST_P'))
  PRINT '      Table loc_temp_store_request_P already exists';
ELSE
  BEGIN
    EXEC('CREATE_PROPERTY_TABLE loc_temp_store_request;');
  PRINT '     Table loc_temp_store_request_P created';
  END
GO


PRINT '     Step Add Table: DTX[TemporaryStoreRequest] end.';



PRINT '     Step Add Column: DTX[TemporaryStoreRequest] Column[[Field=startDateStr, Field=endDateStr, Field=activeDateStr]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_temp_store_request') AND name in (N'start_date_str'))
  PRINT '      Column loc_temp_store_request.start_date_str already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_temp_store_request ADD [start_date_str] nvarchar(8) DEFAULT (''changeit'') NOT NULL');
    PRINT '     Column loc_temp_store_request.start_date_str created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_temp_store_request') AND name in (N'end_date_str'))
  PRINT '      Column loc_temp_store_request.end_date_str already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_temp_store_request ADD [end_date_str] nvarchar(8)');
    PRINT '     Column loc_temp_store_request.end_date_str created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_temp_store_request') AND name in (N'active_date_str'))
  PRINT '      Column loc_temp_store_request.active_date_str already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_temp_store_request ADD [active_date_str] nvarchar(8)');
    PRINT '     Column loc_temp_store_request.active_date_str created';
  END
GO


PRINT '     Step Add Column: DTX[TemporaryStoreRequest] Column[[Field=startDateStr, Field=endDateStr, Field=activeDateStr]] end.';



PRINT '     Step Converting data from old to new columns in LOC_TEMP_STORE_REQUEST starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'LOC_TEMP_STORE_REQUEST') AND name in (N'start_date_str'))
   AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'LOC_TEMP_STORE_REQUEST') AND name in (N'start_date'))
BEGIN
    EXEC('    UPDATE loc_temp_store_request SET start_date_str = CONVERT(VARCHAR(8), start_date, 112) WHERE start_date IS NOT NULL');
    PRINT '        LOC_TEMP_STORE_REQUEST.start_date_str populated';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'LOC_TEMP_STORE_REQUEST') AND name in (N'end_date_str'))
   AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'LOC_TEMP_STORE_REQUEST') AND name in (N'end_date'))
BEGIN
  EXEC('    UPDATE loc_temp_store_request SET end_date_str = CONVERT(VARCHAR(8), end_date, 112) WHERE end_date IS NOT NULL');
  PRINT '        LOC_TEMP_STORE_REQUEST.end_date_str populated';
END
GO
PRINT '     Step Converting data from old to new columns in LOC_TEMP_STORE_REQUEST end.';



PRINT '     Step Alter Column: DTX[TemporaryStoreRequest] Field[[Field=startDateStr]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_temp_store_request', 'start_date_str') ) IS NULL
  PRINT '     Default value Constraint for column [loc_temp_store_request].[start_date_str] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_temp_store_request] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_temp_store_request','start_date_str')+'];' 
  EXEC(@sql) 
  PRINT '     loc_temp_store_request.start_date_str default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_temp_store_request ALTER COLUMN [start_date_str] nvarchar(8) NOT NULL');
  PRINT '     Column loc_temp_store_request.start_date_str modify';
END
GO
PRINT '     Step Alter Column: DTX[TemporaryStoreRequest] Field[[Field=startDateStr]] end.';



PRINT '     Step Drop Column: DTX[TemporaryStoreRequest] Column[[Column=start_date, Column=end_date]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_temp_store_request', 'start_date') ) IS NULL
  PRINT '     Default value Constraint for column [loc_temp_store_request].[start_date] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_temp_store_request] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_temp_store_request','start_date')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_temp_store_request') AND name in (N'start_date'))
  PRINT '      Column loc_temp_store_request.start_date is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [loc_temp_store_request] DROP COLUMN [start_date];');
    PRINT 'Table loc_temp_store_request.start_date dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_temp_store_request', 'end_date') ) IS NULL
  PRINT '     Default value Constraint for column [loc_temp_store_request].[end_date] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_temp_store_request] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_temp_store_request','end_date')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_temp_store_request') AND name in (N'end_date'))
  PRINT '      Column loc_temp_store_request.end_date is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [loc_temp_store_request] DROP COLUMN [end_date];');
    PRINT 'Table loc_temp_store_request.end_date dropped';
  END
GO


PRINT '     Step Drop Column: DTX[TemporaryStoreRequest] Column[[Column=start_date, Column=end_date]] end.';



PRINT '     Step Alter Column: DTX[PartyIdCrossReference] Field[[Field=organizationId, Field=partyId]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref') ) IS NULL
  PRINT '     PK crm_party_id_xref is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_id_xref')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_id_xref dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref_P') ) IS NULL
  PRINT '     PK crm_party_id_xref_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_id_xref_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_id_xref_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_id_xref', 'organization_id') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_id_xref].[organization_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party_id_xref','organization_id')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party_id_xref.organization_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party_id_xref ALTER COLUMN [organization_id] INT NOT NULL');
  PRINT '     Column crm_party_id_xref.organization_id modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_id_xref_P', 'organization_id') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_id_xref_P].[organization_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party_id_xref_P','organization_id')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party_id_xref_P.organization_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party_id_xref_P ALTER COLUMN [organization_id] INT NOT NULL');
  PRINT '     Column crm_party_id_xref_P.organization_id modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref') ) IS NOT NULL
  PRINT '     PK crm_party_id_xref already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE crm_party_id_xref ADD CONSTRAINT [pk_crm_party_id_xref] PRIMARY KEY CLUSTERED (organization_id, party_id, alternate_id_owner)');
    PRINT '     PK crm_party_id_xref created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref_P') ) IS NOT NULL
  PRINT '     PK crm_party_id_xref_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE crm_party_id_xref_P ADD CONSTRAINT [pk_crm_party_id_xref_P] PRIMARY KEY CLUSTERED (organization_id, party_id, alternate_id_owner, property_code)');
    PRINT '     PK crm_party_id_xref_P created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref') ) IS NULL
  PRINT '     PK crm_party_id_xref is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_id_xref')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_id_xref dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref_P') ) IS NULL
  PRINT '     PK crm_party_id_xref_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_id_xref_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_id_xref_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_id_xref', 'party_id') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_id_xref].[party_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party_id_xref','party_id')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party_id_xref.party_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party_id_xref ALTER COLUMN [party_id] BIGINT NOT NULL');
  PRINT '     Column crm_party_id_xref.party_id modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_id_xref_P', 'party_id') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_id_xref_P].[party_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party_id_xref_P','party_id')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party_id_xref_P.party_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party_id_xref_P ALTER COLUMN [party_id] BIGINT NOT NULL');
  PRINT '     Column crm_party_id_xref_P.party_id modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref') ) IS NOT NULL
  PRINT '     PK crm_party_id_xref already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE crm_party_id_xref ADD CONSTRAINT [pk_crm_party_id_xref] PRIMARY KEY CLUSTERED (organization_id, party_id, alternate_id_owner)');
    PRINT '     PK crm_party_id_xref created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref_P') ) IS NOT NULL
  PRINT '     PK crm_party_id_xref_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE crm_party_id_xref_P ADD CONSTRAINT [pk_crm_party_id_xref_P] PRIMARY KEY CLUSTERED (organization_id, party_id, alternate_id_owner, property_code)');
    PRINT '     PK crm_party_id_xref_P created';
  END
GO


PRINT '     Step Alter Column: DTX[PartyIdCrossReference] Field[[Field=organizationId, Field=partyId]] end.';



PRINT '     Step Alter Column: DTX[TransactionReportData] Field[[Field=reportId]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data') ) IS NULL
  PRINT '     PK trn_report_data is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('trn_report_data')+'];' 
  EXEC(@sql) 
    PRINT '     PK trn_report_data dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data_P') ) IS NULL
  PRINT '     PK trn_report_data_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('trn_report_data_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK trn_report_data_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_report_data', 'report_id') ) IS NULL
  PRINT '     Default value Constraint for column [trn_report_data].[report_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trn_report_data','report_id')+'];' 
  EXEC(@sql) 
  PRINT '     trn_report_data.report_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE trn_report_data ALTER COLUMN [report_id] nvarchar(60) NOT NULL');
  PRINT '     Column trn_report_data.report_id modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_report_data_P', 'report_id') ) IS NULL
  PRINT '     Default value Constraint for column [trn_report_data_P].[report_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trn_report_data_P','report_id')+'];' 
  EXEC(@sql) 
  PRINT '     trn_report_data_P.report_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE trn_report_data_P ALTER COLUMN [report_id] nvarchar(60) NOT NULL');
  PRINT '     Column trn_report_data_P.report_id modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data') ) IS NOT NULL
  PRINT '     PK trn_report_data already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE trn_report_data ADD CONSTRAINT [pk_trn_report_data] PRIMARY KEY CLUSTERED (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, report_id)');
    PRINT '     PK trn_report_data created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data_P') ) IS NOT NULL
  PRINT '     PK trn_report_data_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE trn_report_data_P ADD CONSTRAINT [pk_trn_report_data_P] PRIMARY KEY CLUSTERED (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, report_id, property_code)');
    PRINT '     PK trn_report_data_P created';
  END
GO


PRINT '     Step Alter Column: DTX[TransactionReportData] Field[[Field=reportId]] end.';



PRINT '     Step Alter Column: DTX[WorkstationConfigData] Field[[Field=fieldName, Field=fieldValue]] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_LOC_WKSTN_CONFIG_DATA01' AND object_id = OBJECT_ID(N'loc_wkstn_config_data'))
  PRINT '     Index IDX_LOC_WKSTN_CONFIG_DATA01 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [loc_wkstn_config_data].[IDX_LOC_WKSTN_CONFIG_DATA01];');
    PRINT '     Index IDX_LOC_WKSTN_CONFIG_DATA01 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_wkstn_config_data', 'field_name') ) IS NULL
  PRINT '     Default value Constraint for column [loc_wkstn_config_data].[field_name] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_wkstn_config_data] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_wkstn_config_data','field_name')+'];' 
  EXEC(@sql) 
  PRINT '     loc_wkstn_config_data.field_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_wkstn_config_data ALTER COLUMN [field_name] nvarchar(100) NOT NULL');
  PRINT '     Column loc_wkstn_config_data.field_name modify';
END
GO
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_LOC_WKSTN_CONFIG_DATA01' AND object_id = OBJECT_ID(N'loc_wkstn_config_data'))
  PRINT '     Index IDX_LOC_WKSTN_CONFIG_DATA01 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_LOC_WKSTN_CONFIG_DATA01] ON [dbo].[loc_wkstn_config_data]([organization_id], [rtl_loc_id], [wkstn_id], [field_name], [create_timestamp])');
    PRINT '     Index IDX_LOC_WKSTN_CONFIG_DATA01 created';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_wkstn_config_data', 'field_value') ) IS NULL
  PRINT '     Default value Constraint for column [loc_wkstn_config_data].[field_value] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_wkstn_config_data] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_wkstn_config_data','field_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_wkstn_config_data.field_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_wkstn_config_data ALTER COLUMN [field_value] nvarchar(1024)');
  PRINT '     Column loc_wkstn_config_data.field_value modify';
END
GO
PRINT '     Step Alter Column: DTX[WorkstationConfigData] Field[[Field=fieldName, Field=fieldValue]] end.';



PRINT '     Step Update columns from Strings types(VARCHAR and NCLOB) to CLOB starting...';
PRINT '     Step Update columns from Strings types(VARCHAR and NCLOB) to CLOB end.';



PRINT '     Step Alter Column: DTX[OrgHierarchy] Field[[Field=levelCode, Field=levelValue]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy') ) IS NULL
  PRINT '     PK loc_org_hierarchy is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_org_hierarchy')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_org_hierarchy dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy_P') ) IS NULL
  PRINT '     PK loc_org_hierarchy_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_org_hierarchy_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_org_hierarchy_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_org_hierarchy', 'org_code') ) IS NULL
  PRINT '     Default value Constraint for column [loc_org_hierarchy].[org_code] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_org_hierarchy','org_code')+'];' 
  EXEC(@sql) 
  PRINT '     loc_org_hierarchy.org_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy ALTER COLUMN [org_code] nvarchar(30) NOT NULL');
  PRINT '     Column loc_org_hierarchy.org_code modify';
END
GO
BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy ADD DEFAULT (''*'') FOR org_code;');
  PRINT '     Column loc_org_hierarchy.org_code default value modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_org_hierarchy_P', 'org_code') ) IS NULL
  PRINT '     Default value Constraint for column [loc_org_hierarchy_P].[org_code] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_org_hierarchy_P','org_code')+'];' 
  EXEC(@sql) 
  PRINT '     loc_org_hierarchy_P.org_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy_P ALTER COLUMN [org_code] nvarchar(30) NOT NULL');
  PRINT '     Column loc_org_hierarchy_P.org_code modify';
END
GO
BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy_P ADD DEFAULT (''*'') FOR org_code;');
  PRINT '     Column loc_org_hierarchy_P.org_code default value modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy') ) IS NOT NULL
  PRINT '     PK loc_org_hierarchy already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_org_hierarchy ADD CONSTRAINT [pk_loc_org_hierarchy] PRIMARY KEY CLUSTERED (organization_id, org_code, org_value)');
    PRINT '     PK loc_org_hierarchy created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy_P') ) IS NOT NULL
  PRINT '     PK loc_org_hierarchy_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_org_hierarchy_P ADD CONSTRAINT [pk_loc_org_hierarchy_P] PRIMARY KEY CLUSTERED (organization_id, org_code, org_value, property_code)');
    PRINT '     PK loc_org_hierarchy_P created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy') ) IS NULL
  PRINT '     PK loc_org_hierarchy is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_org_hierarchy')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_org_hierarchy dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy_P') ) IS NULL
  PRINT '     PK loc_org_hierarchy_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_org_hierarchy_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_org_hierarchy_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_org_hierarchy', 'org_value') ) IS NULL
  PRINT '     Default value Constraint for column [loc_org_hierarchy].[org_value] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_org_hierarchy','org_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_org_hierarchy.org_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy ALTER COLUMN [org_value] nvarchar(60) NOT NULL');
  PRINT '     Column loc_org_hierarchy.org_value modify';
END
GO
BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy ADD DEFAULT (''*'') FOR org_value;');
  PRINT '     Column loc_org_hierarchy.org_value default value modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_org_hierarchy_P', 'org_value') ) IS NULL
  PRINT '     Default value Constraint for column [loc_org_hierarchy_P].[org_value] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_org_hierarchy_P','org_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_org_hierarchy_P.org_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy_P ALTER COLUMN [org_value] nvarchar(60) NOT NULL');
  PRINT '     Column loc_org_hierarchy_P.org_value modify';
END
GO
BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy_P ADD DEFAULT (''*'') FOR org_value;');
  PRINT '     Column loc_org_hierarchy_P.org_value default value modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy') ) IS NOT NULL
  PRINT '     PK loc_org_hierarchy already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_org_hierarchy ADD CONSTRAINT [pk_loc_org_hierarchy] PRIMARY KEY CLUSTERED (organization_id, org_code, org_value)');
    PRINT '     PK loc_org_hierarchy created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy_P') ) IS NOT NULL
  PRINT '     PK loc_org_hierarchy_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_org_hierarchy_P ADD CONSTRAINT [pk_loc_org_hierarchy_P] PRIMARY KEY CLUSTERED (organization_id, org_code, org_value, property_code)');
    PRINT '     PK loc_org_hierarchy_P created';
  END
GO


PRINT '     Step Alter Column: DTX[OrgHierarchy] Field[[Field=levelCode, Field=levelValue]] end.';



PRINT '     Step Alter Column: DTX[PricingHierarchy] Field[[Field=levelCode, Field=levelValue]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy') ) IS NULL
  PRINT '     PK loc_pricing_hierarchy is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_pricing_hierarchy')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_pricing_hierarchy dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy_P') ) IS NULL
  PRINT '     PK loc_pricing_hierarchy_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_pricing_hierarchy_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_pricing_hierarchy_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_pricing_hierarchy', 'level_code') ) IS NULL
  PRINT '     Default value Constraint for column [loc_pricing_hierarchy].[level_code] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_pricing_hierarchy','level_code')+'];' 
  EXEC(@sql) 
  PRINT '     loc_pricing_hierarchy.level_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy ALTER COLUMN [level_code] nvarchar(30) NOT NULL');
  PRINT '     Column loc_pricing_hierarchy.level_code modify';
END
GO
BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy ADD DEFAULT (''*'') FOR level_code;');
  PRINT '     Column loc_pricing_hierarchy.level_code default value modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_pricing_hierarchy_P', 'level_code') ) IS NULL
  PRINT '     Default value Constraint for column [loc_pricing_hierarchy_P].[level_code] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_pricing_hierarchy_P','level_code')+'];' 
  EXEC(@sql) 
  PRINT '     loc_pricing_hierarchy_P.level_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy_P ALTER COLUMN [level_code] nvarchar(30) NOT NULL');
  PRINT '     Column loc_pricing_hierarchy_P.level_code modify';
END
GO
BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy_P ADD DEFAULT (''*'') FOR level_code;');
  PRINT '     Column loc_pricing_hierarchy_P.level_code default value modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy') ) IS NOT NULL
  PRINT '     PK loc_pricing_hierarchy already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_pricing_hierarchy ADD CONSTRAINT [pk_loc_pricing_hierarchy] PRIMARY KEY CLUSTERED (organization_id, level_code, level_value)');
    PRINT '     PK loc_pricing_hierarchy created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy_P') ) IS NOT NULL
  PRINT '     PK loc_pricing_hierarchy_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_pricing_hierarchy_P ADD CONSTRAINT [pk_loc_pricing_hierarchy_P] PRIMARY KEY CLUSTERED (organization_id, level_code, level_value, property_code)');
    PRINT '     PK loc_pricing_hierarchy_P created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy') ) IS NULL
  PRINT '     PK loc_pricing_hierarchy is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_pricing_hierarchy')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_pricing_hierarchy dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy_P') ) IS NULL
  PRINT '     PK loc_pricing_hierarchy_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_pricing_hierarchy_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_pricing_hierarchy_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_pricing_hierarchy', 'level_value') ) IS NULL
  PRINT '     Default value Constraint for column [loc_pricing_hierarchy].[level_value] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_pricing_hierarchy','level_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_pricing_hierarchy.level_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy ALTER COLUMN [level_value] nvarchar(60) NOT NULL');
  PRINT '     Column loc_pricing_hierarchy.level_value modify';
END
GO
BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy ADD DEFAULT (''*'') FOR level_value;');
  PRINT '     Column loc_pricing_hierarchy.level_value default value modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_pricing_hierarchy_P', 'level_value') ) IS NULL
  PRINT '     Default value Constraint for column [loc_pricing_hierarchy_P].[level_value] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_pricing_hierarchy_P','level_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_pricing_hierarchy_P.level_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy_P ALTER COLUMN [level_value] nvarchar(60) NOT NULL');
  PRINT '     Column loc_pricing_hierarchy_P.level_value modify';
END
GO
BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy_P ADD DEFAULT (''*'') FOR level_value;');
  PRINT '     Column loc_pricing_hierarchy_P.level_value default value modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy') ) IS NOT NULL
  PRINT '     PK loc_pricing_hierarchy already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_pricing_hierarchy ADD CONSTRAINT [pk_loc_pricing_hierarchy] PRIMARY KEY CLUSTERED (organization_id, level_code, level_value)');
    PRINT '     PK loc_pricing_hierarchy created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy_P') ) IS NOT NULL
  PRINT '     PK loc_pricing_hierarchy_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_pricing_hierarchy_P ADD CONSTRAINT [pk_loc_pricing_hierarchy_P] PRIMARY KEY CLUSTERED (organization_id, level_code, level_value, property_code)');
    PRINT '     PK loc_pricing_hierarchy_P created';
  END
GO


PRINT '     Step Alter Column: DTX[PricingHierarchy] Field[[Field=levelCode, Field=levelValue]] end.';



PRINT '     Step Alter Column: DTX[ItemRestrictGS1] Field[[Field=orgCode, Field=orgValue]] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_ITM_RESTRICT_GS1' AND object_id = OBJECT_ID(N'itm_restrict_gs1'))
  PRINT '     Index IDX_ITM_RESTRICT_GS1 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [itm_restrict_gs1].[IDX_ITM_RESTRICT_GS1];');
    PRINT '     Index IDX_ITM_RESTRICT_GS1 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('itm_restrict_gs1', 'org_code') ) IS NULL
  PRINT '     Default value Constraint for column [itm_restrict_gs1].[org_code] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [itm_restrict_gs1] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('itm_restrict_gs1','org_code')+'];' 
  EXEC(@sql) 
  PRINT '     itm_restrict_gs1.org_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE itm_restrict_gs1 ALTER COLUMN [org_code] nvarchar(30) NOT NULL');
  PRINT '     Column itm_restrict_gs1.org_code modify';
END
GO
BEGIN
    EXEC('ALTER TABLE itm_restrict_gs1 ADD DEFAULT (''*'') FOR org_code;');
  PRINT '     Column itm_restrict_gs1.org_code default value modify';
END
GO
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_ITM_RESTRICT_GS1' AND object_id = OBJECT_ID(N'itm_restrict_gs1'))
  PRINT '     Index IDX_ITM_RESTRICT_GS1 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_ITM_RESTRICT_GS1] ON [dbo].[itm_restrict_gs1]([org_code], [org_value])');
    PRINT '     Index IDX_ITM_RESTRICT_GS1 created';
  END
GO


IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_ITM_RESTRICT_GS1' AND object_id = OBJECT_ID(N'itm_restrict_gs1'))
  PRINT '     Index IDX_ITM_RESTRICT_GS1 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [itm_restrict_gs1].[IDX_ITM_RESTRICT_GS1];');
    PRINT '     Index IDX_ITM_RESTRICT_GS1 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('itm_restrict_gs1', 'org_value') ) IS NULL
  PRINT '     Default value Constraint for column [itm_restrict_gs1].[org_value] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [itm_restrict_gs1] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('itm_restrict_gs1','org_value')+'];' 
  EXEC(@sql) 
  PRINT '     itm_restrict_gs1.org_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE itm_restrict_gs1 ALTER COLUMN [org_value] nvarchar(60) NOT NULL');
  PRINT '     Column itm_restrict_gs1.org_value modify';
END
GO
BEGIN
    EXEC('ALTER TABLE itm_restrict_gs1 ADD DEFAULT (''*'') FOR org_value;');
  PRINT '     Column itm_restrict_gs1.org_value default value modify';
END
GO
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_ITM_RESTRICT_GS1' AND object_id = OBJECT_ID(N'itm_restrict_gs1'))
  PRINT '     Index IDX_ITM_RESTRICT_GS1 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_ITM_RESTRICT_GS1] ON [dbo].[itm_restrict_gs1]([org_code], [org_value])');
    PRINT '     Index IDX_ITM_RESTRICT_GS1 created';
  END
GO


PRINT '     Step Alter Column: DTX[ItemRestrictGS1] Field[[Field=orgCode, Field=orgValue]] end.';



PRINT '     Step Alter Column: DTX[KitComponent] Field[[Field=quantityPerKit]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('itm_kit_component', 'quantity_per_kit') ) IS NULL
  PRINT '     Default value Constraint for column [itm_kit_component].[quantity_per_kit] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [itm_kit_component] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('itm_kit_component','quantity_per_kit')+'];' 
  EXEC(@sql) 
  PRINT '     itm_kit_component.quantity_per_kit default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE itm_kit_component ALTER COLUMN [quantity_per_kit] INT');
  PRINT '     Column itm_kit_component.quantity_per_kit modify';
END
GO
BEGIN
    EXEC('ALTER TABLE itm_kit_component ADD DEFAULT (1) FOR quantity_per_kit;');
  PRINT '     Column itm_kit_component.quantity_per_kit default value modify';
END
GO
PRINT '     Step Alter Column: DTX[KitComponent] Field[[Field=quantityPerKit]] end.';



PRINT '     Step Alter Column: DTX[PartyLocaleInformation] Field[[Field=sequence]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_locale_information') ) IS NULL
  PRINT '     PK crm_party_locale_information is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_locale_information] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_locale_information')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_locale_information dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_locale_information_P') ) IS NULL
  PRINT '     PK crm_party_locale_information_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_locale_information_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_locale_information_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_locale_information_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_locale_information', 'party_locale_seq') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_locale_information].[party_locale_seq] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_locale_information] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party_locale_information','party_locale_seq')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party_locale_information.party_locale_seq default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party_locale_information ALTER COLUMN [party_locale_seq] INT NOT NULL');
  PRINT '     Column crm_party_locale_information.party_locale_seq modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_locale_information_P', 'party_locale_seq') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_locale_information_P].[party_locale_seq] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_locale_information_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party_locale_information_P','party_locale_seq')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party_locale_information_P.party_locale_seq default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party_locale_information_P ALTER COLUMN [party_locale_seq] INT NOT NULL');
  PRINT '     Column crm_party_locale_information_P.party_locale_seq modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_locale_information') ) IS NOT NULL
  PRINT '     PK crm_party_locale_information already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE crm_party_locale_information ADD CONSTRAINT [pk_crm_party_locale_information] PRIMARY KEY CLUSTERED (organization_id, party_id, party_locale_seq)');
    PRINT '     PK crm_party_locale_information created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_locale_information_P') ) IS NOT NULL
  PRINT '     PK crm_party_locale_information_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE crm_party_locale_information_P ADD CONSTRAINT [pk_crm_party_locale_information_P] PRIMARY KEY CLUSTERED (organization_id, party_id, party_locale_seq, property_code)');
    PRINT '     PK crm_party_locale_information_P created';
  END
GO


PRINT '     Step Alter Column: DTX[PartyLocaleInformation] Field[[Field=sequence]] end.';



PRINT '     Step Alter Column: DTX[PartyEmail] Field[[Field=sequence]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_email') ) IS NULL
  PRINT '     PK crm_party_email is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_email] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_email')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_email dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_email_P') ) IS NULL
  PRINT '     PK crm_party_email_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_email_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_email_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_email_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_email', 'email_sequence') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_email].[email_sequence] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_email] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party_email','email_sequence')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party_email.email_sequence default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party_email ALTER COLUMN [email_sequence] INT NOT NULL');
  PRINT '     Column crm_party_email.email_sequence modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_email_P', 'email_sequence') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_email_P].[email_sequence] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_email_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party_email_P','email_sequence')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party_email_P.email_sequence default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party_email_P ALTER COLUMN [email_sequence] INT NOT NULL');
  PRINT '     Column crm_party_email_P.email_sequence modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_email') ) IS NOT NULL
  PRINT '     PK crm_party_email already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE crm_party_email ADD CONSTRAINT [pk_crm_party_email] PRIMARY KEY CLUSTERED (organization_id, party_id, email_sequence)');
    PRINT '     PK crm_party_email created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_email_P') ) IS NOT NULL
  PRINT '     PK crm_party_email_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE crm_party_email_P ADD CONSTRAINT [pk_crm_party_email_P] PRIMARY KEY CLUSTERED (organization_id, party_id, email_sequence, property_code)');
    PRINT '     PK crm_party_email_P created';
  END
GO


PRINT '     Step Alter Column: DTX[PartyEmail] Field[[Field=sequence]] end.';



PRINT '     Step Alter Column: DTX[EmployeePassword] Field[[Field=effectiveDate]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('hrs_employee_password', 'effective_date') ) IS NULL
  PRINT '     Default value Constraint for column [hrs_employee_password].[effective_date] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [hrs_employee_password] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('hrs_employee_password','effective_date')+'];' 
  EXEC(@sql) 
  PRINT '     hrs_employee_password.effective_date default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE hrs_employee_password ALTER COLUMN [effective_date] DATETIME NOT NULL');
  PRINT '     Column hrs_employee_password.effective_date modify';
END
GO
PRINT '     Step Alter Column: DTX[EmployeePassword] Field[[Field=effectiveDate]] end.';



PRINT '     Step Drop Column: DTX[SaleReturnLineItem] Column[[Column=RETURNED_QUANTITY]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_sale_lineitm', 'RETURNED_QUANTITY') ) IS NULL
  PRINT '     Default value Constraint for column [trl_sale_lineitm].[RETURNED_QUANTITY] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_sale_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_sale_lineitm','RETURNED_QUANTITY')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_sale_lineitm') AND name in (N'RETURNED_QUANTITY'))
  PRINT '      Column trl_sale_lineitm.RETURNED_QUANTITY is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_sale_lineitm] DROP COLUMN [RETURNED_QUANTITY];');
    PRINT 'Table trl_sale_lineitm.RETURNED_QUANTITY dropped';
  END
GO


PRINT '     Step Drop Column: DTX[SaleReturnLineItem] Column[[Column=RETURNED_QUANTITY]] end.';



PRINT '     Step Drop Column: DTX[DeviceRegistration] Column[[Column=ENV_INSTALL_DATE]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_device_registration', 'ENV_INSTALL_DATE') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_device_registration].[ENV_INSTALL_DATE] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_device_registration] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_device_registration','ENV_INSTALL_DATE')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ctl_device_registration') AND name in (N'ENV_INSTALL_DATE'))
  PRINT '      Column ctl_device_registration.ENV_INSTALL_DATE is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ctl_device_registration] DROP COLUMN [ENV_INSTALL_DATE];');
    PRINT 'Table ctl_device_registration.ENV_INSTALL_DATE dropped';
  END
GO


PRINT '     Step Drop Column: DTX[DeviceRegistration] Column[[Column=ENV_INSTALL_DATE]] end.';



PRINT '     Step Drop Column: DTX[TenderSerializedCount] Column[[Column=DIFFERENCE_AMT]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('tsn_serialized_tndr_count', 'DIFFERENCE_AMT') ) IS NULL
  PRINT '     Default value Constraint for column [tsn_serialized_tndr_count].[DIFFERENCE_AMT] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [tsn_serialized_tndr_count] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('tsn_serialized_tndr_count','DIFFERENCE_AMT')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'tsn_serialized_tndr_count') AND name in (N'DIFFERENCE_AMT'))
  PRINT '      Column tsn_serialized_tndr_count.DIFFERENCE_AMT is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [tsn_serialized_tndr_count] DROP COLUMN [DIFFERENCE_AMT];');
    PRINT 'Table tsn_serialized_tndr_count.DIFFERENCE_AMT dropped';
  END
GO


PRINT '     Step Drop Column: DTX[TenderSerializedCount] Column[[Column=DIFFERENCE_AMT]] end.';



PRINT '     Step Drop Column: DTX[VoucherTenderLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ttr_voucher_tndr_lineitm', 'TRACK1') ) IS NULL
  PRINT '     Default value Constraint for column [ttr_voucher_tndr_lineitm].[TRACK1] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ttr_voucher_tndr_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ttr_voucher_tndr_lineitm','TRACK1')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ttr_voucher_tndr_lineitm') AND name in (N'TRACK1'))
  PRINT '      Column ttr_voucher_tndr_lineitm.TRACK1 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ttr_voucher_tndr_lineitm] DROP COLUMN [TRACK1];');
    PRINT 'Table ttr_voucher_tndr_lineitm.TRACK1 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ttr_voucher_tndr_lineitm', 'TRACK2') ) IS NULL
  PRINT '     Default value Constraint for column [ttr_voucher_tndr_lineitm].[TRACK2] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ttr_voucher_tndr_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ttr_voucher_tndr_lineitm','TRACK2')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ttr_voucher_tndr_lineitm') AND name in (N'TRACK2'))
  PRINT '      Column ttr_voucher_tndr_lineitm.TRACK2 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ttr_voucher_tndr_lineitm] DROP COLUMN [TRACK2];');
    PRINT 'Table ttr_voucher_tndr_lineitm.TRACK2 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ttr_voucher_tndr_lineitm', 'TRACK3') ) IS NULL
  PRINT '     Default value Constraint for column [ttr_voucher_tndr_lineitm].[TRACK3] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ttr_voucher_tndr_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ttr_voucher_tndr_lineitm','TRACK3')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ttr_voucher_tndr_lineitm') AND name in (N'TRACK3'))
  PRINT '      Column ttr_voucher_tndr_lineitm.TRACK3 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ttr_voucher_tndr_lineitm] DROP COLUMN [TRACK3];');
    PRINT 'Table ttr_voucher_tndr_lineitm.TRACK3 dropped';
  END
GO


PRINT '     Step Drop Column: DTX[VoucherTenderLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3]] end.';



PRINT '     Step Drop Column: DTX[CreditDebitTenderLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ttr_credit_debit_tndr_lineitm', 'TRACK1') ) IS NULL
  PRINT '     Default value Constraint for column [ttr_credit_debit_tndr_lineitm].[TRACK1] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ttr_credit_debit_tndr_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ttr_credit_debit_tndr_lineitm','TRACK1')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ttr_credit_debit_tndr_lineitm') AND name in (N'TRACK1'))
  PRINT '      Column ttr_credit_debit_tndr_lineitm.TRACK1 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ttr_credit_debit_tndr_lineitm] DROP COLUMN [TRACK1];');
    PRINT 'Table ttr_credit_debit_tndr_lineitm.TRACK1 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ttr_credit_debit_tndr_lineitm', 'TRACK2') ) IS NULL
  PRINT '     Default value Constraint for column [ttr_credit_debit_tndr_lineitm].[TRACK2] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ttr_credit_debit_tndr_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ttr_credit_debit_tndr_lineitm','TRACK2')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ttr_credit_debit_tndr_lineitm') AND name in (N'TRACK2'))
  PRINT '      Column ttr_credit_debit_tndr_lineitm.TRACK2 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ttr_credit_debit_tndr_lineitm] DROP COLUMN [TRACK2];');
    PRINT 'Table ttr_credit_debit_tndr_lineitm.TRACK2 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ttr_credit_debit_tndr_lineitm', 'TRACK3') ) IS NULL
  PRINT '     Default value Constraint for column [ttr_credit_debit_tndr_lineitm].[TRACK3] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ttr_credit_debit_tndr_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ttr_credit_debit_tndr_lineitm','TRACK3')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ttr_credit_debit_tndr_lineitm') AND name in (N'TRACK3'))
  PRINT '      Column ttr_credit_debit_tndr_lineitm.TRACK3 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ttr_credit_debit_tndr_lineitm] DROP COLUMN [TRACK3];');
    PRINT 'Table ttr_credit_debit_tndr_lineitm.TRACK3 dropped';
  END
GO


PRINT '     Step Drop Column: DTX[CreditDebitTenderLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3]] end.';



PRINT '     Step Drop Column: DTX[VoucherSaleLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3, Column=serial_nbr]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_voucher_sale_lineitm', 'TRACK1') ) IS NULL
  PRINT '     Default value Constraint for column [trl_voucher_sale_lineitm].[TRACK1] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_voucher_sale_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_voucher_sale_lineitm','TRACK1')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_voucher_sale_lineitm') AND name in (N'TRACK1'))
  PRINT '      Column trl_voucher_sale_lineitm.TRACK1 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_voucher_sale_lineitm] DROP COLUMN [TRACK1];');
    PRINT 'Table trl_voucher_sale_lineitm.TRACK1 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_voucher_sale_lineitm', 'TRACK2') ) IS NULL
  PRINT '     Default value Constraint for column [trl_voucher_sale_lineitm].[TRACK2] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_voucher_sale_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_voucher_sale_lineitm','TRACK2')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_voucher_sale_lineitm') AND name in (N'TRACK2'))
  PRINT '      Column trl_voucher_sale_lineitm.TRACK2 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_voucher_sale_lineitm] DROP COLUMN [TRACK2];');
    PRINT 'Table trl_voucher_sale_lineitm.TRACK2 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_voucher_sale_lineitm', 'TRACK3') ) IS NULL
  PRINT '     Default value Constraint for column [trl_voucher_sale_lineitm].[TRACK3] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_voucher_sale_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_voucher_sale_lineitm','TRACK3')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_voucher_sale_lineitm') AND name in (N'TRACK3'))
  PRINT '      Column trl_voucher_sale_lineitm.TRACK3 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_voucher_sale_lineitm] DROP COLUMN [TRACK3];');
    PRINT 'Table trl_voucher_sale_lineitm.TRACK3 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_voucher_sale_lineitm', 'serial_nbr') ) IS NULL
  PRINT '     Default value Constraint for column [trl_voucher_sale_lineitm].[serial_nbr] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_voucher_sale_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_voucher_sale_lineitm','serial_nbr')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_voucher_sale_lineitm') AND name in (N'serial_nbr'))
  PRINT '      Column trl_voucher_sale_lineitm.serial_nbr is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_voucher_sale_lineitm] DROP COLUMN [serial_nbr];');
    PRINT 'Table trl_voucher_sale_lineitm.serial_nbr dropped';
  END
GO


PRINT '     Step Drop Column: DTX[VoucherSaleLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3, Column=serial_nbr]] end.';



PRINT '     Step Drop Column: DTX[VoucherDiscountLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3, Column=serial_nbr]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_voucher_discount_lineitm', 'TRACK1') ) IS NULL
  PRINT '     Default value Constraint for column [trl_voucher_discount_lineitm].[TRACK1] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_voucher_discount_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_voucher_discount_lineitm','TRACK1')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_voucher_discount_lineitm') AND name in (N'TRACK1'))
  PRINT '      Column trl_voucher_discount_lineitm.TRACK1 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_voucher_discount_lineitm] DROP COLUMN [TRACK1];');
    PRINT 'Table trl_voucher_discount_lineitm.TRACK1 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_voucher_discount_lineitm', 'TRACK2') ) IS NULL
  PRINT '     Default value Constraint for column [trl_voucher_discount_lineitm].[TRACK2] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_voucher_discount_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_voucher_discount_lineitm','TRACK2')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_voucher_discount_lineitm') AND name in (N'TRACK2'))
  PRINT '      Column trl_voucher_discount_lineitm.TRACK2 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_voucher_discount_lineitm] DROP COLUMN [TRACK2];');
    PRINT 'Table trl_voucher_discount_lineitm.TRACK2 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_voucher_discount_lineitm', 'TRACK3') ) IS NULL
  PRINT '     Default value Constraint for column [trl_voucher_discount_lineitm].[TRACK3] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_voucher_discount_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_voucher_discount_lineitm','TRACK3')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_voucher_discount_lineitm') AND name in (N'TRACK3'))
  PRINT '      Column trl_voucher_discount_lineitm.TRACK3 is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_voucher_discount_lineitm] DROP COLUMN [TRACK3];');
    PRINT 'Table trl_voucher_discount_lineitm.TRACK3 dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_voucher_discount_lineitm', 'serial_nbr') ) IS NULL
  PRINT '     Default value Constraint for column [trl_voucher_discount_lineitm].[serial_nbr] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_voucher_discount_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_voucher_discount_lineitm','serial_nbr')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_voucher_discount_lineitm') AND name in (N'serial_nbr'))
  PRINT '      Column trl_voucher_discount_lineitm.serial_nbr is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_voucher_discount_lineitm] DROP COLUMN [serial_nbr];');
    PRINT 'Table trl_voucher_discount_lineitm.serial_nbr dropped';
  END
GO


PRINT '     Step Drop Column: DTX[VoucherDiscountLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3, Column=serial_nbr]] end.';



PRINT '     Step Drop Column: DTX[RetailTransaction] Column[[Column=TOTAL, Column=SUBTOTAL, Column=TAXTOTAL]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_rtrans', 'TOTAL') ) IS NULL
  PRINT '     Default value Constraint for column [trl_rtrans].[TOTAL] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_rtrans] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_rtrans','TOTAL')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_rtrans') AND name in (N'TOTAL'))
  PRINT '      Column trl_rtrans.TOTAL is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_rtrans] DROP COLUMN [TOTAL];');
    PRINT 'Table trl_rtrans.TOTAL dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_rtrans', 'SUBTOTAL') ) IS NULL
  PRINT '     Default value Constraint for column [trl_rtrans].[SUBTOTAL] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_rtrans] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_rtrans','SUBTOTAL')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_rtrans') AND name in (N'SUBTOTAL'))
  PRINT '      Column trl_rtrans.SUBTOTAL is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_rtrans] DROP COLUMN [SUBTOTAL];');
    PRINT 'Table trl_rtrans.SUBTOTAL dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_rtrans', 'TAXTOTAL') ) IS NULL
  PRINT '     Default value Constraint for column [trl_rtrans].[TAXTOTAL] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_rtrans] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_rtrans','TAXTOTAL')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_rtrans') AND name in (N'TAXTOTAL'))
  PRINT '      Column trl_rtrans.TAXTOTAL is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_rtrans] DROP COLUMN [TAXTOTAL];');
    PRINT 'Table trl_rtrans.TAXTOTAL dropped';
  END
GO


PRINT '     Step Drop Column: DTX[RetailTransaction] Column[[Column=TOTAL, Column=SUBTOTAL, Column=TAXTOTAL]] end.';



PRINT '     Step Drop Column: DTX[TenderLineItem] Column[[Column=APPROVAL_CODE, Column=ACCT_USER_NAME, Column=PARTY_ID]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ttr_tndr_lineitm', 'APPROVAL_CODE') ) IS NULL
  PRINT '     Default value Constraint for column [ttr_tndr_lineitm].[APPROVAL_CODE] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ttr_tndr_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ttr_tndr_lineitm','APPROVAL_CODE')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ttr_tndr_lineitm') AND name in (N'APPROVAL_CODE'))
  PRINT '      Column ttr_tndr_lineitm.APPROVAL_CODE is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ttr_tndr_lineitm] DROP COLUMN [APPROVAL_CODE];');
    PRINT 'Table ttr_tndr_lineitm.APPROVAL_CODE dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ttr_tndr_lineitm', 'ACCT_USER_NAME') ) IS NULL
  PRINT '     Default value Constraint for column [ttr_tndr_lineitm].[ACCT_USER_NAME] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ttr_tndr_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ttr_tndr_lineitm','ACCT_USER_NAME')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ttr_tndr_lineitm') AND name in (N'ACCT_USER_NAME'))
  PRINT '      Column ttr_tndr_lineitm.ACCT_USER_NAME is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ttr_tndr_lineitm] DROP COLUMN [ACCT_USER_NAME];');
    PRINT 'Table ttr_tndr_lineitm.ACCT_USER_NAME dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ttr_tndr_lineitm', 'PARTY_ID') ) IS NULL
  PRINT '     Default value Constraint for column [ttr_tndr_lineitm].[PARTY_ID] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ttr_tndr_lineitm] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ttr_tndr_lineitm','PARTY_ID')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ttr_tndr_lineitm') AND name in (N'PARTY_ID'))
  PRINT '      Column ttr_tndr_lineitm.PARTY_ID is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [ttr_tndr_lineitm] DROP COLUMN [PARTY_ID];');
    PRINT 'Table ttr_tndr_lineitm.PARTY_ID dropped';
  END
GO


PRINT '     Step Drop Column: DTX[TenderLineItem] Column[[Column=APPROVAL_CODE, Column=ACCT_USER_NAME, Column=PARTY_ID]] end.';



PRINT '     Step Drop Column: DTX[InventoryMovementPending] Column[[Column=DEST_BUCKET_ID, Column=DEST_LOCATION_ID]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('inv_movement_pending', 'DEST_BUCKET_ID') ) IS NULL
  PRINT '     Default value Constraint for column [inv_movement_pending].[DEST_BUCKET_ID] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [inv_movement_pending] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('inv_movement_pending','DEST_BUCKET_ID')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'inv_movement_pending') AND name in (N'DEST_BUCKET_ID'))
  PRINT '      Column inv_movement_pending.DEST_BUCKET_ID is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [inv_movement_pending] DROP COLUMN [DEST_BUCKET_ID];');
    PRINT 'Table inv_movement_pending.DEST_BUCKET_ID dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('inv_movement_pending', 'DEST_LOCATION_ID') ) IS NULL
  PRINT '     Default value Constraint for column [inv_movement_pending].[DEST_LOCATION_ID] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [inv_movement_pending] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('inv_movement_pending','DEST_LOCATION_ID')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'inv_movement_pending') AND name in (N'DEST_LOCATION_ID'))
  PRINT '      Column inv_movement_pending.DEST_LOCATION_ID is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [inv_movement_pending] DROP COLUMN [DEST_LOCATION_ID];');
    PRINT 'Table inv_movement_pending.DEST_LOCATION_ID dropped';
  END
GO


PRINT '     Step Drop Column: DTX[InventoryMovementPending] Column[[Column=DEST_BUCKET_ID, Column=DEST_LOCATION_ID]] end.';



PRINT '     Step Drop Column: DTX[PosTransaction] Column[[Column=SESSION_RTL_LOC_ID]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_trans', 'SESSION_RTL_LOC_ID') ) IS NULL
  PRINT '     Default value Constraint for column [trn_trans].[SESSION_RTL_LOC_ID] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_trans] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trn_trans','SESSION_RTL_LOC_ID')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trn_trans') AND name in (N'SESSION_RTL_LOC_ID'))
  PRINT '      Column trn_trans.SESSION_RTL_LOC_ID is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trn_trans] DROP COLUMN [SESSION_RTL_LOC_ID];');
    PRINT 'Table trn_trans.SESSION_RTL_LOC_ID dropped';
  END
GO


PRINT '     Step Drop Column: DTX[PosTransaction] Column[[Column=SESSION_RTL_LOC_ID]] end.';



PRINT '     Step Drop Column: DTX[TransactionVersion] Column[[Column=CUSTOMER_APP_DATE]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_trans_version', 'CUSTOMER_APP_DATE') ) IS NULL
  PRINT '     Default value Constraint for column [trn_trans_version].[CUSTOMER_APP_DATE] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_trans_version] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trn_trans_version','CUSTOMER_APP_DATE')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trn_trans_version') AND name in (N'CUSTOMER_APP_DATE'))
  PRINT '      Column trn_trans_version.CUSTOMER_APP_DATE is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trn_trans_version] DROP COLUMN [CUSTOMER_APP_DATE];');
    PRINT 'Table trn_trans_version.CUSTOMER_APP_DATE dropped';
  END
GO


PRINT '     Step Drop Column: DTX[TransactionVersion] Column[[Column=CUSTOMER_APP_DATE]] end.';



PRINT '     Step Drop Column: DTX[DocumentInventoryLocationModifier] Column[[Column=VOID_FLAG]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('inv_inventory_loc_mod', 'VOID_FLAG') ) IS NULL
  PRINT '     Default value Constraint for column [inv_inventory_loc_mod].[VOID_FLAG] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [inv_inventory_loc_mod] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('inv_inventory_loc_mod','VOID_FLAG')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'inv_inventory_loc_mod') AND name in (N'VOID_FLAG'))
  PRINT '      Column inv_inventory_loc_mod.VOID_FLAG is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [inv_inventory_loc_mod] DROP COLUMN [VOID_FLAG];');
    PRINT 'Table inv_inventory_loc_mod.VOID_FLAG dropped';
  END
GO


PRINT '     Step Drop Column: DTX[DocumentInventoryLocationModifier] Column[[Column=VOID_FLAG]] end.';



PRINT '     Step Drop Column: DTX[CustomerItemAccount] Column[[Column=LAST_ACTIVITY_DATE, Column=ACCT_SETUP_DATE, Column=CUST_ACCT_STATCODE]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cat_cust_item_acct', 'LAST_ACTIVITY_DATE') ) IS NULL
  PRINT '     Default value Constraint for column [cat_cust_item_acct].[LAST_ACTIVITY_DATE] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cat_cust_item_acct] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cat_cust_item_acct','LAST_ACTIVITY_DATE')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'cat_cust_item_acct') AND name in (N'LAST_ACTIVITY_DATE'))
  PRINT '      Column cat_cust_item_acct.LAST_ACTIVITY_DATE is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [cat_cust_item_acct] DROP COLUMN [LAST_ACTIVITY_DATE];');
    PRINT 'Table cat_cust_item_acct.LAST_ACTIVITY_DATE dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cat_cust_item_acct', 'ACCT_SETUP_DATE') ) IS NULL
  PRINT '     Default value Constraint for column [cat_cust_item_acct].[ACCT_SETUP_DATE] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cat_cust_item_acct] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cat_cust_item_acct','ACCT_SETUP_DATE')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'cat_cust_item_acct') AND name in (N'ACCT_SETUP_DATE'))
  PRINT '      Column cat_cust_item_acct.ACCT_SETUP_DATE is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [cat_cust_item_acct] DROP COLUMN [ACCT_SETUP_DATE];');
    PRINT 'Table cat_cust_item_acct.ACCT_SETUP_DATE dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cat_cust_item_acct', 'CUST_ACCT_STATCODE') ) IS NULL
  PRINT '     Default value Constraint for column [cat_cust_item_acct].[CUST_ACCT_STATCODE] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cat_cust_item_acct] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cat_cust_item_acct','CUST_ACCT_STATCODE')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'cat_cust_item_acct') AND name in (N'CUST_ACCT_STATCODE'))
  PRINT '      Column cat_cust_item_acct.CUST_ACCT_STATCODE is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [cat_cust_item_acct] DROP COLUMN [CUST_ACCT_STATCODE];');
    PRINT 'Table cat_cust_item_acct.CUST_ACCT_STATCODE dropped';
  END
GO


PRINT '     Step Drop Column: DTX[CustomerItemAccount] Column[[Column=LAST_ACTIVITY_DATE, Column=ACCT_SETUP_DATE, Column=CUST_ACCT_STATCODE]] end.';



PRINT '     Step Drop Column: DTX[Schedule] Column[[Column=POSTED_DATE, Column=POSTED_FLAG]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('sch_schedule', 'POSTED_DATE') ) IS NULL
  PRINT '     Default value Constraint for column [sch_schedule].[POSTED_DATE] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [sch_schedule] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('sch_schedule','POSTED_DATE')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'sch_schedule') AND name in (N'POSTED_DATE'))
  PRINT '      Column sch_schedule.POSTED_DATE is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [sch_schedule] DROP COLUMN [POSTED_DATE];');
    PRINT 'Table sch_schedule.POSTED_DATE dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('sch_schedule', 'POSTED_FLAG') ) IS NULL
  PRINT '     Default value Constraint for column [sch_schedule].[POSTED_FLAG] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [sch_schedule] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('sch_schedule','POSTED_FLAG')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'sch_schedule') AND name in (N'POSTED_FLAG'))
  PRINT '      Column sch_schedule.POSTED_FLAG is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [sch_schedule] DROP COLUMN [POSTED_FLAG];');
    PRINT 'Table sch_schedule.POSTED_FLAG dropped';
  END
GO


PRINT '     Step Drop Column: DTX[Schedule] Column[[Column=POSTED_DATE, Column=POSTED_FLAG]] end.';



PRINT '     Step Drop Column: DTX[InventoryDocumentModifier] Column[[Column=INVCTL_DOCUMENT_RTL_LOC_ID]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_invctl_document_mod', 'INVCTL_DOCUMENT_RTL_LOC_ID') ) IS NULL
  PRINT '     Default value Constraint for column [trl_invctl_document_mod].[INVCTL_DOCUMENT_RTL_LOC_ID] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trl_invctl_document_mod] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trl_invctl_document_mod','INVCTL_DOCUMENT_RTL_LOC_ID')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trl_invctl_document_mod') AND name in (N'INVCTL_DOCUMENT_RTL_LOC_ID'))
  PRINT '      Column trl_invctl_document_mod.INVCTL_DOCUMENT_RTL_LOC_ID is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trl_invctl_document_mod] DROP COLUMN [INVCTL_DOCUMENT_RTL_LOC_ID];');
    PRINT 'Table trl_invctl_document_mod.INVCTL_DOCUMENT_RTL_LOC_ID dropped';
  END
GO


PRINT '     Step Drop Column: DTX[InventoryDocumentModifier] Column[[Column=INVCTL_DOCUMENT_RTL_LOC_ID]] end.';



PRINT '     Step Drop Column: DTX[LineItemGenericStorage] Column[[Column=FORM_KEY]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_generic_lineitm_storage', 'FORM_KEY') ) IS NULL
  PRINT '     Default value Constraint for column [trn_generic_lineitm_storage].[FORM_KEY] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_generic_lineitm_storage] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trn_generic_lineitm_storage','FORM_KEY')+'];' 
  EXEC(@sql) 
  END
GO


IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'trn_generic_lineitm_storage') AND name in (N'FORM_KEY'))
  PRINT '      Column trn_generic_lineitm_storage.FORM_KEY is missing';
ELSE
  BEGIN
    EXEC('    ALTER TABLE [trn_generic_lineitm_storage] DROP COLUMN [FORM_KEY];');
    PRINT 'Table trn_generic_lineitm_storage.FORM_KEY dropped';
  END
GO


PRINT '     Step Drop Column: DTX[LineItemGenericStorage] Column[[Column=FORM_KEY]] end.';



PRINT '     Step Drop Primary Key: DTX[WorkOrderAccount] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('cwo_work_order_acct') ) IS NULL
  PRINT '     PK cwo_work_order_acct is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cwo_work_order_acct] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('cwo_work_order_acct')+'];' 
  EXEC(@sql) 
    PRINT '     PK cwo_work_order_acct dropped';
  END
GO


PRINT '     Step Drop Primary Key: DTX[WorkOrderAccount] end.';



PRINT '     Step Add Primary Key: DTX[WorkOrderAccount] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('cwo_work_order_acct') ) IS NOT NULL
  PRINT '     PK cwo_work_order_acct already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE cwo_work_order_acct ADD CONSTRAINT [pk_cwo_work_order_acct] PRIMARY KEY CLUSTERED (organization_id, cust_acct_code, cust_acct_id)');
    PRINT '     PK cwo_work_order_acct created';
  END
GO


PRINT '     Step Add Primary Key: DTX[WorkOrderAccount] end.';



PRINT '     Step Alter Column: DTX[PafNfeTransType] Field[[Field=notes, Field=ruleType]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_nfe_trans_type', 'notes') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_nfe_trans_type].[notes] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_trans_type] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_nfe_trans_type','notes')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_nfe_trans_type.notes default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_nfe_trans_type ALTER COLUMN [notes] nvarchar(2000)');
  PRINT '     Column cpaf_nfe_trans_type.notes modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_nfe_trans_type', 'rule_type') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_nfe_trans_type].[rule_type] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_trans_type] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_nfe_trans_type','rule_type')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_nfe_trans_type.rule_type default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_nfe_trans_type ALTER COLUMN [rule_type] nvarchar(30)');
  PRINT '     Column cpaf_nfe_trans_type.rule_type modify';
END
GO
PRINT '     Step Alter Column: DTX[PafNfeTransType] Field[[Field=notes, Field=ruleType]] end.';



PRINT '     Step Alter Column: DTX[TransactionReportData] Field[[Field=workstationId]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data') ) IS NULL
  PRINT '     PK trn_report_data is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('trn_report_data')+'];' 
  EXEC(@sql) 
    PRINT '     PK trn_report_data dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data_P') ) IS NULL
  PRINT '     PK trn_report_data_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('trn_report_data_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK trn_report_data_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_report_data', 'wkstn_id') ) IS NULL
  PRINT '     Default value Constraint for column [trn_report_data].[wkstn_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trn_report_data','wkstn_id')+'];' 
  EXEC(@sql) 
  PRINT '     trn_report_data.wkstn_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE trn_report_data ALTER COLUMN [wkstn_id] INT NOT NULL');
  PRINT '     Column trn_report_data.wkstn_id modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_report_data_P', 'wkstn_id') ) IS NULL
  PRINT '     Default value Constraint for column [trn_report_data_P].[wkstn_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trn_report_data_P','wkstn_id')+'];' 
  EXEC(@sql) 
  PRINT '     trn_report_data_P.wkstn_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE trn_report_data_P ALTER COLUMN [wkstn_id] INT NOT NULL');
  PRINT '     Column trn_report_data_P.wkstn_id modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data') ) IS NOT NULL
  PRINT '     PK trn_report_data already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE trn_report_data ADD CONSTRAINT [pk_trn_report_data] PRIMARY KEY CLUSTERED (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, report_id)');
    PRINT '     PK trn_report_data created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data_P') ) IS NOT NULL
  PRINT '     PK trn_report_data_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE trn_report_data_P ADD CONSTRAINT [pk_trn_report_data_P] PRIMARY KEY CLUSTERED (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, report_id, property_code)');
    PRINT '     PK trn_report_data_P created';
  END
GO


PRINT '     Step Alter Column: DTX[TransactionReportData] Field[[Field=workstationId]] end.';



PRINT '     Step Set the correct length for RelatedItemHead starting...';
PRINT '     Step Set the correct length for RelatedItemHead end.';



PRINT '     Step Alter Column: DTX[RelatedItemHead] Field[[Field=relationshipId]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('rms_related_item_head') ) IS NULL
  PRINT '     PK rms_related_item_head is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [rms_related_item_head] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('rms_related_item_head')+'];' 
  EXEC(@sql) 
    PRINT '     PK rms_related_item_head dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('rms_related_item_head', 'relationship_id') ) IS NULL
  PRINT '     Default value Constraint for column [rms_related_item_head].[relationship_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [rms_related_item_head] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('rms_related_item_head','relationship_id')+'];' 
  EXEC(@sql) 
  PRINT '     rms_related_item_head.relationship_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE rms_related_item_head ALTER COLUMN [relationship_id] BIGINT NOT NULL');
  PRINT '     Column rms_related_item_head.relationship_id modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('rms_related_item_head') ) IS NOT NULL
  PRINT '     PK rms_related_item_head already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_related_item_head ADD CONSTRAINT [pk_rms_related_item_head] PRIMARY KEY CLUSTERED (organization_id, relationship_id, location)');
    PRINT '     PK rms_related_item_head created';
  END
GO


PRINT '     Step Alter Column: DTX[RelatedItemHead] Field[[Field=relationshipId]] end.';



PRINT '     Step Alter Column: DTX[PafNfeTaxCst] Field[[Field=taxLocationId]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('cpaf_nfe_tax_cst') ) IS NULL
  PRINT '     PK cpaf_nfe_tax_cst is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_tax_cst] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('cpaf_nfe_tax_cst')+'];' 
  EXEC(@sql) 
    PRINT '     PK cpaf_nfe_tax_cst dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('cpaf_nfe_tax_cst_P') ) IS NULL
  PRINT '     PK cpaf_nfe_tax_cst_P is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_tax_cst_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('cpaf_nfe_tax_cst_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK cpaf_nfe_tax_cst_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_nfe_tax_cst', 'tax_loc_id') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_nfe_tax_cst].[tax_loc_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_tax_cst] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_nfe_tax_cst','tax_loc_id')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_nfe_tax_cst.tax_loc_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_nfe_tax_cst ALTER COLUMN [tax_loc_id] nvarchar(60) NOT NULL');
  PRINT '     Column cpaf_nfe_tax_cst.tax_loc_id modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_nfe_tax_cst_P', 'tax_loc_id') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_nfe_tax_cst_P].[tax_loc_id] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_tax_cst_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_nfe_tax_cst_P','tax_loc_id')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_nfe_tax_cst_P.tax_loc_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_nfe_tax_cst_P ALTER COLUMN [tax_loc_id] nvarchar(60) NOT NULL');
  PRINT '     Column cpaf_nfe_tax_cst_P.tax_loc_id modify';
END
GO
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('cpaf_nfe_tax_cst') ) IS NOT NULL
  PRINT '     PK cpaf_nfe_tax_cst already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE cpaf_nfe_tax_cst ADD CONSTRAINT [pk_cpaf_nfe_tax_cst] PRIMARY KEY CLUSTERED (organization_id, trans_typcode, tax_loc_id, tax_group_id, tax_authority_id)');
    PRINT '     PK cpaf_nfe_tax_cst created';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('cpaf_nfe_tax_cst_P') ) IS NOT NULL
  PRINT '     PK cpaf_nfe_tax_cst_P already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE cpaf_nfe_tax_cst_P ADD CONSTRAINT [pk_cpaf_nfe_tax_cst_P] PRIMARY KEY CLUSTERED (organization_id, trans_typcode, tax_loc_id, tax_group_id, tax_authority_id, property_code)');
    PRINT '     PK cpaf_nfe_tax_cst_P created';
  END
GO


PRINT '     Step Alter Column: DTX[PafNfeTaxCst] Field[[Field=taxLocationId]] end.';



PRINT '     Step Alter Column: DTX[DiffGroupDetail] Field[[Field=displaySeq]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('rms_diff_group_detail', 'display_seq') ) IS NULL
  PRINT '     Default value Constraint for column [rms_diff_group_detail].[display_seq] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [rms_diff_group_detail] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('rms_diff_group_detail','display_seq')+'];' 
  EXEC(@sql) 
  PRINT '     rms_diff_group_detail.display_seq default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE rms_diff_group_detail ALTER COLUMN [display_seq] INT');
  PRINT '     Column rms_diff_group_detail.display_seq modify';
END
GO
PRINT '     Step Alter Column: DTX[DiffGroupDetail] Field[[Field=displaySeq]] end.';



PRINT '     Step Alter Column: DTX[Measurement] Field[[Field=symbol, Field=name]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('com_measurement', 'symbol') ) IS NULL
  PRINT '     Default value Constraint for column [com_measurement].[symbol] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [com_measurement] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('com_measurement','symbol')+'];' 
  EXEC(@sql) 
  PRINT '     com_measurement.symbol default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE com_measurement ALTER COLUMN [symbol] nvarchar(254) NOT NULL');
  PRINT '     Column com_measurement.symbol modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('com_measurement', 'name') ) IS NULL
  PRINT '     Default value Constraint for column [com_measurement].[name] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [com_measurement] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('com_measurement','name')+'];' 
  EXEC(@sql) 
  PRINT '     com_measurement.name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE com_measurement ALTER COLUMN [name] nvarchar(254) NOT NULL');
  PRINT '     Column com_measurement.name modify';
END
GO
PRINT '     Step Alter Column: DTX[Measurement] Field[[Field=symbol, Field=name]] end.';



PRINT '     Step Alter Column: DTX[PafSatResponse] Field[[Field=signatureQRCODE]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_sat_response', 'signature_QR_code') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_sat_response].[signature_QR_code] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_sat_response] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_sat_response','signature_QR_code')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_sat_response.signature_QR_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_sat_response ALTER COLUMN [signature_qr_code] nvarchar(2000)');
  PRINT '     Column cpaf_sat_response.signature_QR_code modify';
END
GO
PRINT '     Step Alter Column: DTX[PafSatResponse] Field[[Field=signatureQRCODE]] end.';



PRINT '     Step Alter Column: DTX[PafNfeQueueTrans] Field[[Field=inactive]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_nfe_queue_trans', 'inactive_flag') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_nfe_queue_trans].[inactive_flag] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_queue_trans] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_nfe_queue_trans','inactive_flag')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_nfe_queue_trans.inactive_flag default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_nfe_queue_trans ALTER COLUMN [inactive_flag] BIT NOT NULL');
  PRINT '     Column cpaf_nfe_queue_trans.inactive_flag modify';
END
GO
BEGIN
    EXEC('ALTER TABLE cpaf_nfe_queue_trans ADD DEFAULT (0) FOR inactive_flag;');
  PRINT '     Column cpaf_nfe_queue_trans.inactive_flag default value modify';
END
GO
PRINT '     Step Alter Column: DTX[PafNfeQueueTrans] Field[[Field=inactive]] end.';



PRINT '     Step Alter Column: DTX[InventoryDocumentCrossReference] Field[[Field=createDate, Field=updateDate]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('inv_invctl_document_xref', 'create_date') ) IS NULL
  PRINT '     Default value Constraint for column [inv_invctl_document_xref].[create_date] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [inv_invctl_document_xref] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('inv_invctl_document_xref','create_date')+'];' 
  EXEC(@sql) 
  PRINT '     inv_invctl_document_xref.create_date default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE inv_invctl_document_xref ALTER COLUMN [create_date] DATETIME');
  PRINT '     Column inv_invctl_document_xref.create_date modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('inv_invctl_document_xref', 'update_date') ) IS NULL
  PRINT '     Default value Constraint for column [inv_invctl_document_xref].[update_date] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [inv_invctl_document_xref] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('inv_invctl_document_xref','update_date')+'];' 
  EXEC(@sql) 
  PRINT '     inv_invctl_document_xref.update_date default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE inv_invctl_document_xref ALTER COLUMN [update_date] DATETIME');
  PRINT '     Column inv_invctl_document_xref.update_date modify';
END
GO
PRINT '     Step Alter Column: DTX[InventoryDocumentCrossReference] Field[[Field=createDate, Field=updateDate]] end.';



PRINT '     Step Update version table to use identity type starting...';
PRINT '     Step Update version table to use identity type end.';



PRINT '     Step Alter Column: DTX[StateJournal] Field[[Field=timeStamp]] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'XST_LOC_STATEJOURNAL_TIME' AND object_id = OBJECT_ID(N'loc_state_journal'))
  PRINT '     Index XST_LOC_STATEJOURNAL_TIME is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [loc_state_journal].[XST_LOC_STATEJOURNAL_TIME];');
    PRINT '     Index XST_LOC_STATEJOURNAL_TIME dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_state_journal', 'time_stamp') ) IS NULL
  PRINT '     Default value Constraint for column [loc_state_journal].[time_stamp] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [loc_state_journal] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_state_journal','time_stamp')+'];' 
  EXEC(@sql) 
  PRINT '     loc_state_journal.time_stamp default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_state_journal ALTER COLUMN [time_stamp] DATETIME NOT NULL');
  PRINT '     Column loc_state_journal.time_stamp modify';
END
GO
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'XST_LOC_STATEJOURNAL_TIME' AND object_id = OBJECT_ID(N'loc_state_journal'))
  PRINT '     Index XST_LOC_STATEJOURNAL_TIME already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [XST_LOC_STATEJOURNAL_TIME] ON [dbo].[loc_state_journal]([time_stamp])');
    PRINT '     Index XST_LOC_STATEJOURNAL_TIME created';
  END
GO


PRINT '     Step Alter Column: DTX[StateJournal] Field[[Field=timeStamp]] end.';



PRINT '     Step Alter Column: DTX[DeviceInformation] Field[[Field=deviceName, Field=deviceType, Field=model, Field=serialNumber]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_device_information', 'device_name') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_device_information].[device_name] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_device_information] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_device_information','device_name')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_device_information.device_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_device_information ALTER COLUMN [device_name] nvarchar(255)');
  PRINT '     Column ctl_device_information.device_name modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_device_information', 'device_type') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_device_information].[device_type] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_device_information] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_device_information','device_type')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_device_information.device_type default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_device_information ALTER COLUMN [device_type] nvarchar(255)');
  PRINT '     Column ctl_device_information.device_type modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_device_information', 'model') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_device_information].[model] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_device_information] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_device_information','model')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_device_information.model default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_device_information ALTER COLUMN [model] nvarchar(255)');
  PRINT '     Column ctl_device_information.model modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_device_information', 'serial_number') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_device_information].[serial_number] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_device_information] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_device_information','serial_number')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_device_information.serial_number default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_device_information ALTER COLUMN [serial_number] nvarchar(255)');
  PRINT '     Column ctl_device_information.serial_number modify';
END
GO
PRINT '     Step Alter Column: DTX[DeviceInformation] Field[[Field=deviceName, Field=deviceType, Field=model, Field=serialNumber]] end.';



PRINT '     Step Alter Column: DTX[SaleInvoice] Field[[Field=confirmSentFlag, Field=returnFlag, Field=confirmFlag, Field=voidPendingFlag]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('civc_invoice', 'confirm_sent_flag') ) IS NULL
  PRINT '     Default value Constraint for column [civc_invoice].[confirm_sent_flag] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [civc_invoice] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('civc_invoice','confirm_sent_flag')+'];' 
  EXEC(@sql) 
  PRINT '     civc_invoice.confirm_sent_flag default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE civc_invoice ALTER COLUMN [confirm_sent_flag] BIT');
  PRINT '     Column civc_invoice.confirm_sent_flag modify';
END
GO
BEGIN
    EXEC('ALTER TABLE civc_invoice ADD DEFAULT (0) FOR confirm_sent_flag;');
  PRINT '     Column civc_invoice.confirm_sent_flag default value modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('civc_invoice', 'return_flag') ) IS NULL
  PRINT '     Default value Constraint for column [civc_invoice].[return_flag] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [civc_invoice] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('civc_invoice','return_flag')+'];' 
  EXEC(@sql) 
  PRINT '     civc_invoice.return_flag default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE civc_invoice ALTER COLUMN [return_flag] BIT');
  PRINT '     Column civc_invoice.return_flag modify';
END
GO
BEGIN
    EXEC('ALTER TABLE civc_invoice ADD DEFAULT (0) FOR return_flag;');
  PRINT '     Column civc_invoice.return_flag default value modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('civc_invoice', 'confirm_flag') ) IS NULL
  PRINT '     Default value Constraint for column [civc_invoice].[confirm_flag] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [civc_invoice] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('civc_invoice','confirm_flag')+'];' 
  EXEC(@sql) 
  PRINT '     civc_invoice.confirm_flag default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE civc_invoice ALTER COLUMN [confirm_flag] BIT');
  PRINT '     Column civc_invoice.confirm_flag modify';
END
GO
BEGIN
    EXEC('ALTER TABLE civc_invoice ADD DEFAULT (0) FOR confirm_flag;');
  PRINT '     Column civc_invoice.confirm_flag default value modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('civc_invoice', 'void_pending_flag') ) IS NULL
  PRINT '     Default value Constraint for column [civc_invoice].[void_pending_flag] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [civc_invoice] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('civc_invoice','void_pending_flag')+'];' 
  EXEC(@sql) 
  PRINT '     civc_invoice.void_pending_flag default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE civc_invoice ALTER COLUMN [void_pending_flag] BIT');
  PRINT '     Column civc_invoice.void_pending_flag modify';
END
GO
BEGIN
    EXEC('ALTER TABLE civc_invoice ADD DEFAULT (0) FOR void_pending_flag;');
  PRINT '     Column civc_invoice.void_pending_flag default value modify';
END
GO
PRINT '     Step Alter Column: DTX[SaleInvoice] Field[[Field=confirmSentFlag, Field=returnFlag, Field=confirmFlag, Field=voidPendingFlag]] end.';



PRINT '     Step Alter Column: DTX[TaxBracket] Field[[Field=orgCode, Field=orgValue]] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TAX_TAX_BRACKET_ORGNODE' AND object_id = OBJECT_ID(N'tax_tax_bracket'))
  PRINT '     Index IDX_TAX_TAX_BRACKET_ORGNODE is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [tax_tax_bracket].[IDX_TAX_TAX_BRACKET_ORGNODE];');
    PRINT '     Index IDX_TAX_TAX_BRACKET_ORGNODE dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('tax_tax_bracket', 'org_code') ) IS NULL
  PRINT '     Default value Constraint for column [tax_tax_bracket].[org_code] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [tax_tax_bracket] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('tax_tax_bracket','org_code')+'];' 
  EXEC(@sql) 
  PRINT '     tax_tax_bracket.org_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE tax_tax_bracket ALTER COLUMN [org_code] nvarchar(30)');
  PRINT '     Column tax_tax_bracket.org_code modify';
END
GO
BEGIN
    EXEC('ALTER TABLE tax_tax_bracket ADD DEFAULT (''*'') FOR org_code;');
  PRINT '     Column tax_tax_bracket.org_code default value modify';
END
GO
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TAX_TAX_BRACKET_ORGNODE' AND object_id = OBJECT_ID(N'tax_tax_bracket'))
  PRINT '     Index IDX_TAX_TAX_BRACKET_ORGNODE already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TAX_TAX_BRACKET_ORGNODE] ON [dbo].[tax_tax_bracket]([org_code], [org_value])');
    PRINT '     Index IDX_TAX_TAX_BRACKET_ORGNODE created';
  END
GO


IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TAX_TAX_BRACKET_ORGNODE' AND object_id = OBJECT_ID(N'tax_tax_bracket'))
  PRINT '     Index IDX_TAX_TAX_BRACKET_ORGNODE is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [tax_tax_bracket].[IDX_TAX_TAX_BRACKET_ORGNODE];');
    PRINT '     Index IDX_TAX_TAX_BRACKET_ORGNODE dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('tax_tax_bracket', 'org_value') ) IS NULL
  PRINT '     Default value Constraint for column [tax_tax_bracket].[org_value] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [tax_tax_bracket] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('tax_tax_bracket','org_value')+'];' 
  EXEC(@sql) 
  PRINT '     tax_tax_bracket.org_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE tax_tax_bracket ALTER COLUMN [org_value] nvarchar(60)');
  PRINT '     Column tax_tax_bracket.org_value modify';
END
GO
BEGIN
    EXEC('ALTER TABLE tax_tax_bracket ADD DEFAULT (''*'') FOR org_value;');
  PRINT '     Column tax_tax_bracket.org_value default value modify';
END
GO
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TAX_TAX_BRACKET_ORGNODE' AND object_id = OBJECT_ID(N'tax_tax_bracket'))
  PRINT '     Index IDX_TAX_TAX_BRACKET_ORGNODE already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TAX_TAX_BRACKET_ORGNODE] ON [dbo].[tax_tax_bracket]([org_code], [org_value])');
    PRINT '     Index IDX_TAX_TAX_BRACKET_ORGNODE created';
  END
GO


PRINT '     Step Alter Column: DTX[TaxBracket] Field[[Field=orgCode, Field=orgValue]] end.';



PRINT '     Step Align ctl_event_log to the Oracle definition starting...';
PRINT '     Step Alter Column: DTX[EventLogEntry] Field[[Field=logMessage]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_event_log', 'log_message') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_event_log].[log_message] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_event_log] DROP CONSTRAINT [''+dbo.SP_DEFAULT_CONSTRAINT_EXISTS(''ctl_event_log'',''log_message'')+''];' 
  EXEC(@sql) 
  PRINT '     ctl_event_log.log_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_event_log ALTER COLUMN [log_message] nvarchar(MAX) NOT NULL');
  PRINT '     Column ctl_event_log.log_message modify';
END
GO
PRINT '     Step Alter Column: DTX[EventLogEntry] Field[[Field=logMessage]] end.';
PRINT '     Step Align ctl_event_log to the Oracle definition end.';



PRINT '     Step Add record state column to the missing tables starting...';
PRINT '     Adding missing record state column...';

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RMS_RELATED_ITEM_HEAD') AND name in (N'record_state'))
  PRINT '      RMS_RELATED_ITEM_HEAD.record_state already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE RMS_RELATED_ITEM_HEAD ADD [record_state] nvarchar(30)');
    PRINT '     RMS_RELATED_ITEM_HEAD.record_state created';
  END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RMS_DIFF_GROUP_DETAIL') AND name in (N'record_state'))
  PRINT '      RMS_DIFF_GROUP_DETAIL.record_state already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE RMS_DIFF_GROUP_DETAIL ADD [record_state] nvarchar(30)');
    PRINT '     RMS_DIFF_GROUP_DETAIL.record_state created';
  END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'LOG_SP_REPORT') AND name in (N'record_state'))
  PRINT '      LOG_SP_REPORT.record_state already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE LOG_SP_REPORT ADD [record_state] nvarchar(30)');
    PRINT '     LOG_SP_REPORT.record_state created';
  END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RMS_DIFF_GROUP_HEAD') AND name in (N'record_state'))
  PRINT '      RMS_DIFF_GROUP_HEAD.record_state already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE RMS_DIFF_GROUP_HEAD ADD [record_state] nvarchar(30)');
    PRINT '     RMS_DIFF_GROUP_HEAD.record_state created';
  END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RMS_DIFF_IDS') AND name in (N'record_state'))
  PRINT '      RMS_DIFF_IDS.record_state already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE RMS_DIFF_IDS ADD [record_state] nvarchar(30)');
    PRINT '     RMS_DIFF_IDS.record_state created';
  END
GO

BEGIN
    EXEC('ALTER TABLE trn_report_data ALTER COLUMN [record_state] nvarchar(30)');
  PRINT '     trn_report_data.record_state modify';
END
GO

BEGIN
    EXEC('ALTER TABLE loc_wkstn_config_data ALTER COLUMN [record_state] nvarchar(30)');
  PRINT '     loc_wkstn_config_data.record_state modify';
END
GO
PRINT '     Step Add record state column to the missing tables end.';



PRINT '     Step Add Column: DTX[SpReport] Column[[Field=createDate, Field=createUserId, Field=updateDate, Field=updateUserId]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'log_sp_report') AND name in (N'create_date'))
  PRINT '      Column log_sp_report.create_date already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE log_sp_report ADD [create_date] DATETIME');
    PRINT '     Column log_sp_report.create_date created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'log_sp_report') AND name in (N'create_user_id'))
  PRINT '      Column log_sp_report.create_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE log_sp_report ADD [create_user_id] nvarchar(256)');
    PRINT '     Column log_sp_report.create_user_id created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'log_sp_report') AND name in (N'update_date'))
  PRINT '      Column log_sp_report.update_date already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE log_sp_report ADD [update_date] DATETIME');
    PRINT '     Column log_sp_report.update_date created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'log_sp_report') AND name in (N'update_user_id'))
  PRINT '      Column log_sp_report.update_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE log_sp_report ADD [update_user_id] nvarchar(256)');
    PRINT '     Column log_sp_report.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[SpReport] Column[[Field=createDate, Field=createUserId, Field=updateDate, Field=updateUserId]] end.';



PRINT '     Step Add Column: DTX[RelatedItemHead] Column[[Field=createUserId, Field=updateUserId]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_related_item_head') AND name in (N'create_user_id'))
  PRINT '      Column rms_related_item_head.create_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_related_item_head ADD [create_user_id] nvarchar(256)');
    PRINT '     Column rms_related_item_head.create_user_id created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_related_item_head') AND name in (N'update_user_id'))
  PRINT '      Column rms_related_item_head.update_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_related_item_head ADD [update_user_id] nvarchar(256)');
    PRINT '     Column rms_related_item_head.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[RelatedItemHead] Column[[Field=createUserId, Field=updateUserId]] end.';



PRINT '     Step Add Column: DTX[DiffGroupDetail] Column[[Field=createUserId, Field=updateUserId]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_group_detail') AND name in (N'create_user_id'))
  PRINT '      Column rms_diff_group_detail.create_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_group_detail ADD [create_user_id] nvarchar(256)');
    PRINT '     Column rms_diff_group_detail.create_user_id created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_group_detail') AND name in (N'update_user_id'))
  PRINT '      Column rms_diff_group_detail.update_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_group_detail ADD [update_user_id] nvarchar(256)');
    PRINT '     Column rms_diff_group_detail.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[DiffGroupDetail] Column[[Field=createUserId, Field=updateUserId]] end.';



PRINT '     Step Add Column: DTX[DiffGroupHead] Column[[Field=createUserId, Field=updateUserId]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_group_head') AND name in (N'create_user_id'))
  PRINT '      Column rms_diff_group_head.create_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_group_head ADD [create_user_id] nvarchar(256)');
    PRINT '     Column rms_diff_group_head.create_user_id created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_group_head') AND name in (N'update_user_id'))
  PRINT '      Column rms_diff_group_head.update_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_group_head ADD [update_user_id] nvarchar(256)');
    PRINT '     Column rms_diff_group_head.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[DiffGroupHead] Column[[Field=createUserId, Field=updateUserId]] end.';



PRINT '     Step Add Column: DTX[DiffIds] Column[[Field=createUserId, Field=updateUserId]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_ids') AND name in (N'create_user_id'))
  PRINT '      Column rms_diff_ids.create_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_ids ADD [create_user_id] nvarchar(256)');
    PRINT '     Column rms_diff_ids.create_user_id created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_ids') AND name in (N'update_user_id'))
  PRINT '      Column rms_diff_ids.update_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_ids ADD [update_user_id] nvarchar(256)');
    PRINT '     Column rms_diff_ids.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[DiffIds] Column[[Field=createUserId, Field=updateUserId]] end.';



PRINT '     Step Drop Index: DTX[ExternalSystemMap] Index[IDX_COM_EXTERNAL_SYSTEM_MAP02] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_COM_EXTERNAL_SYSTEM_MAP02' AND object_id = OBJECT_ID(N'com_external_system_map'))
  PRINT '     Index IDX_COM_EXTERNAL_SYSTEM_MAP02 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [com_external_system_map].[IDX_COM_EXTERNAL_SYSTEM_MAP02];');
    PRINT '     Index IDX_COM_EXTERNAL_SYSTEM_MAP02 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[ExternalSystemMap] Index[IDX_COM_EXTERNAL_SYSTEM_MAP02] end.';



PRINT '     Step Drop Index: DTX[ExternalSystemMap] Index[IDX_COM_EXTERNAL_SYSTEM_MAP01] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_COM_EXTERNAL_SYSTEM_MAP01' AND object_id = OBJECT_ID(N'com_external_system_map'))
  PRINT '     Index IDX_COM_EXTERNAL_SYSTEM_MAP01 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [com_external_system_map].[IDX_COM_EXTERNAL_SYSTEM_MAP01];');
    PRINT '     Index IDX_COM_EXTERNAL_SYSTEM_MAP01 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[ExternalSystemMap] Index[IDX_COM_EXTERNAL_SYSTEM_MAP01] end.';



PRINT '     Step Drop Index: DTX[CustomerAccount] Index[IDX_CAT_CUST_ACCT01] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_CAT_CUST_ACCT01' AND object_id = OBJECT_ID(N'cat_cust_acct'))
  PRINT '     Index IDX_CAT_CUST_ACCT01 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [cat_cust_acct].[IDX_CAT_CUST_ACCT01];');
    PRINT '     Index IDX_CAT_CUST_ACCT01 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[CustomerAccount] Index[IDX_CAT_CUST_ACCT01] end.';



PRINT '     Step Drop Index: DTX[OrderModifier] Index[IDX_XOM_ORDER_MOD01] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_XOM_ORDER_MOD01' AND object_id = OBJECT_ID(N'xom_order_mod'))
  PRINT '     Index IDX_XOM_ORDER_MOD01 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [xom_order_mod].[IDX_XOM_ORDER_MOD01];');
    PRINT '     Index IDX_XOM_ORDER_MOD01 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[OrderModifier] Index[IDX_XOM_ORDER_MOD01] end.';



PRINT '     Step Drop Index: DTX[ItemOptions] Index[XST_ITM_ITEM_OPTIONS_JOIN] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'XST_ITM_ITEM_OPTIONS_JOIN' AND object_id = OBJECT_ID(N'itm_item_options'))
  PRINT '     Index XST_ITM_ITEM_OPTIONS_JOIN is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [itm_item_options].[XST_ITM_ITEM_OPTIONS_JOIN];');
    PRINT '     Index XST_ITM_ITEM_OPTIONS_JOIN dropped';
  END
GO


PRINT '     Step Drop Index: DTX[ItemOptions] Index[XST_ITM_ITEM_OPTIONS_JOIN] end.';



PRINT '     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITEM02] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_SALE_LINEITEM02' AND object_id = OBJECT_ID(N'trl_sale_lineitm'))
  PRINT '     Index IDX_TRL_SALE_LINEITEM02 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_SALE_LINEITEM02] ON [dbo].[trl_sale_lineitm]([organization_id], [business_date], [sale_lineitm_typcode])');
    PRINT '     Index IDX_TRL_SALE_LINEITEM02 created';
  END
GO


PRINT '     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITEM02] end.';



PRINT '     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE03] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_RPT_SALE_LINE03' AND object_id = OBJECT_ID(N'rpt_sale_line'))
  PRINT '     Index IDX_RPT_SALE_LINE03 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_RPT_SALE_LINE03] ON [dbo].[rpt_sale_line]([organization_id], [trans_statcode], [business_date], [rtl_loc_id], [wkstn_id], [trans_seq], [rtrans_lineitm_seq], [quantity], [net_amt])');
    PRINT '     Index IDX_RPT_SALE_LINE03 created';
  END
GO


PRINT '     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE03] end.';



PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS_LINEITM01' AND object_id = OBJECT_ID(N'trl_rtrans_lineitm'))
  PRINT '     Index IDX_TRL_RTRANS_LINEITM01 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_RTRANS_LINEITM01] ON [dbo].[trl_rtrans_lineitm]([trans_seq], [business_date], [rtl_loc_id], [wkstn_id], [organization_id], [rtrans_lineitm_seq])');
    PRINT '     Index IDX_TRL_RTRANS_LINEITM01 created';
  END
GO


PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] end.';



PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS_LINEITM02' AND object_id = OBJECT_ID(N'trl_rtrans_lineitm'))
  PRINT '     Index IDX_TRL_RTRANS_LINEITM02 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_RTRANS_LINEITM02] ON [dbo].[trl_rtrans_lineitm]([organization_id], [void_flag], [business_date])');
    PRINT '     Index IDX_TRL_RTRANS_LINEITM02 created';
  END
GO


PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] end.';



PRINT '     Step Add Index: DTX[PartyEmail] Index[XST_CRM_PARTY_EMAIL01] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'XST_CRM_PARTY_EMAIL01' AND object_id = OBJECT_ID(N'crm_party_email'))
  PRINT '     Index XST_CRM_PARTY_EMAIL01 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [XST_CRM_PARTY_EMAIL01] ON [dbo].[crm_party_email]([email_address])');
    PRINT '     Index XST_CRM_PARTY_EMAIL01 created';
  END
GO


PRINT '     Step Add Index: DTX[PartyEmail] Index[XST_CRM_PARTY_EMAIL01] end.';



PRINT '     Step Add Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS02] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS02' AND object_id = OBJECT_ID(N'trl_rtrans'))
  PRINT '     Index IDX_TRL_RTRANS02 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_RTRANS02] ON [dbo].[trl_rtrans]([cust_party_id])');
    PRINT '     Index IDX_TRL_RTRANS02 created';
  END
GO


PRINT '     Step Add Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS02] end.';



PRINT '     Step Add Index: DTX[TenderLineItem] Index[IDX_TTR_TNDR_LINEITM01] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TTR_TNDR_LINEITM01' AND object_id = OBJECT_ID(N'ttr_tndr_lineitm'))
  PRINT '     Index IDX_TTR_TNDR_LINEITM01 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TTR_TNDR_LINEITM01] ON [dbo].[ttr_tndr_lineitm]([trans_seq], [business_date], [rtl_loc_id], [wkstn_id], [organization_id], [rtrans_lineitm_seq])');
    PRINT '     Index IDX_TTR_TNDR_LINEITM01 created';
  END
GO


PRINT '     Step Add Index: DTX[TenderLineItem] Index[IDX_TTR_TNDR_LINEITM01] end.';



PRINT '     Step Add Index: DTX[ItemOptions] Index[IDX_ITM_ITEM_OPTIONS] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_ITM_ITEM_OPTIONS' AND object_id = OBJECT_ID(N'itm_item_options'))
  PRINT '     Index IDX_ITM_ITEM_OPTIONS already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_ITM_ITEM_OPTIONS] ON [dbo].[itm_item_options]([organization_id], [item_id])');
    PRINT '     Index IDX_ITM_ITEM_OPTIONS created';
  END
GO


PRINT '     Step Add Index: DTX[ItemOptions] Index[IDX_ITM_ITEM_OPTIONS] end.';



PRINT '     Step Add Index: DTX[RetailPriceModifier] Index[IDX_TRL_RTL_PRICE_MOD01] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTL_PRICE_MOD01' AND object_id = OBJECT_ID(N'trl_rtl_price_mod'))
  PRINT '     Index IDX_TRL_RTL_PRICE_MOD01 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_RTL_PRICE_MOD01] ON [dbo].[trl_rtl_price_mod]([trans_seq], [business_date], [rtl_loc_id], [wkstn_id], [organization_id], [rtrans_lineitm_seq], [rtl_price_mod_seq_nbr])');
    PRINT '     Index IDX_TRL_RTL_PRICE_MOD01 created';
  END
GO


PRINT '     Step Add Index: DTX[RetailPriceModifier] Index[IDX_TRL_RTL_PRICE_MOD01] end.';



PRINT '     Step Drop Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITM01] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_SALE_LINEITM01' AND object_id = OBJECT_ID(N'trl_sale_lineitm'))
  PRINT '     Index IDX_TRL_SALE_LINEITM01 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [trl_sale_lineitm].[IDX_TRL_SALE_LINEITM01];');
    PRINT '     Index IDX_TRL_SALE_LINEITM01 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITM01] end.';



PRINT '     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITM01] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_SALE_LINEITM01' AND object_id = OBJECT_ID(N'trl_sale_lineitm'))
  PRINT '     Index IDX_TRL_SALE_LINEITM01 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_SALE_LINEITM01] ON [dbo].[trl_sale_lineitm]([trans_seq], [business_date], [rtl_loc_id], [wkstn_id], [organization_id], [rtrans_lineitm_seq])');
    PRINT '     Index IDX_TRL_SALE_LINEITM01 created';
  END
GO


PRINT '     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITM01] end.';



PRINT '     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE01] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_RPT_SALE_LINE01' AND object_id = OBJECT_ID(N'rpt_sale_line'))
  PRINT '     Index IDX_RPT_SALE_LINE01 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [rpt_sale_line].[IDX_RPT_SALE_LINE01];');
    PRINT '     Index IDX_RPT_SALE_LINE01 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE01] end.';



PRINT '     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE01] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_RPT_SALE_LINE01' AND object_id = OBJECT_ID(N'rpt_sale_line'))
  PRINT '     Index IDX_RPT_SALE_LINE01 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_RPT_SALE_LINE01] ON [dbo].[rpt_sale_line]([trans_seq], [business_date], [rtl_loc_id], [wkstn_id], [organization_id], [rtrans_lineitm_seq])');
    PRINT '     Index IDX_RPT_SALE_LINE01 created';
  END
GO


PRINT '     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE01] end.';



PRINT '     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE02] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_RPT_SALE_LINE02' AND object_id = OBJECT_ID(N'rpt_sale_line'))
  PRINT '     Index IDX_RPT_SALE_LINE02 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [rpt_sale_line].[IDX_RPT_SALE_LINE02];');
    PRINT '     Index IDX_RPT_SALE_LINE02 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE02] end.';



PRINT '     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE02] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_RPT_SALE_LINE02' AND object_id = OBJECT_ID(N'rpt_sale_line'))
  PRINT '     Index IDX_RPT_SALE_LINE02 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_RPT_SALE_LINE02] ON [dbo].[rpt_sale_line]([cust_party_id])');
    PRINT '     Index IDX_RPT_SALE_LINE02 created';
  END
GO


PRINT '     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE02] end.';



PRINT '     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS_LINEITM01' AND object_id = OBJECT_ID(N'trl_rtrans_lineitm'))
  PRINT '     Index IDX_TRL_RTRANS_LINEITM01 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [trl_rtrans_lineitm].[IDX_TRL_RTRANS_LINEITM01];');
    PRINT '     Index IDX_TRL_RTRANS_LINEITM01 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] end.';



PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS_LINEITM01' AND object_id = OBJECT_ID(N'trl_rtrans_lineitm'))
  PRINT '     Index IDX_TRL_RTRANS_LINEITM01 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_RTRANS_LINEITM01] ON [dbo].[trl_rtrans_lineitm]([trans_seq], [business_date], [rtl_loc_id], [wkstn_id], [organization_id], [rtrans_lineitm_seq])');
    PRINT '     Index IDX_TRL_RTRANS_LINEITM01 created';
  END
GO


PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] end.';



PRINT '     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS_LINEITM02' AND object_id = OBJECT_ID(N'trl_rtrans_lineitm'))
  PRINT '     Index IDX_TRL_RTRANS_LINEITM02 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [trl_rtrans_lineitm].[IDX_TRL_RTRANS_LINEITM02];');
    PRINT '     Index IDX_TRL_RTRANS_LINEITM02 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] end.';



PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS_LINEITM02' AND object_id = OBJECT_ID(N'trl_rtrans_lineitm'))
  PRINT '     Index IDX_TRL_RTRANS_LINEITM02 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_RTRANS_LINEITM02] ON [dbo].[trl_rtrans_lineitm]([organization_id], [void_flag], [business_date])');
    PRINT '     Index IDX_TRL_RTRANS_LINEITM02 created';
  END
GO


PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] end.';



PRINT '     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM03] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS_LINEITM03' AND object_id = OBJECT_ID(N'trl_rtrans_lineitm'))
  PRINT '     Index IDX_TRL_RTRANS_LINEITM03 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [trl_rtrans_lineitm].[IDX_TRL_RTRANS_LINEITM03];');
    PRINT '     Index IDX_TRL_RTRANS_LINEITM03 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM03] end.';



PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM03] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS_LINEITM03' AND object_id = OBJECT_ID(N'trl_rtrans_lineitm'))
  PRINT '     Index IDX_TRL_RTRANS_LINEITM03 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_RTRANS_LINEITM03] ON [dbo].[trl_rtrans_lineitm]([organization_id], [rtl_loc_id], [wkstn_id], [trans_seq], [void_flag])');
    PRINT '     Index IDX_TRL_RTRANS_LINEITM03 created';
  END
GO


PRINT '     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM03] end.';



PRINT '     Step Drop Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS01] starting...';
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS01' AND object_id = OBJECT_ID(N'trl_rtrans'))
  PRINT '     Index IDX_TRL_RTRANS01 is missing';
ELSE
  BEGIN
    EXEC('    DROP INDEX [trl_rtrans].[IDX_TRL_RTRANS01];');
    PRINT '     Index IDX_TRL_RTRANS01 dropped';
  END
GO


PRINT '     Step Drop Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS01] end.';



PRINT '     Step Add Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS01] starting...';
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_TRL_RTRANS01' AND object_id = OBJECT_ID(N'trl_rtrans'))
  PRINT '     Index IDX_TRL_RTRANS01 already exists';
ELSE
  BEGIN
    EXEC('CREATE INDEX [IDX_TRL_RTRANS01] ON [dbo].[trl_rtrans]([trans_seq], [business_date], [rtl_loc_id], [wkstn_id], [organization_id])');
    PRINT '     Index IDX_TRL_RTRANS01 created';
  END
GO


PRINT '     Step Add Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS01] end.';



PRINT '     Step Upgrade some indexes to use the column with UPPER() starting...';
PRINT '     Step Upgrade some indexes to use the column with UPPER() end.';



PRINT '     Step Add Column: DTX[LegalEntity] Column[[Field=legalForm, Field=socialCapital, Field=companiesRegisterNumber, Field=faxNumber, Field=phoneNumber, Field=webSite]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'legal_form'))
  PRINT '      Column loc_legal_entity.legal_form already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [legal_form] nvarchar(60)');
    PRINT '     Column loc_legal_entity.legal_form created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'social_capital'))
  PRINT '      Column loc_legal_entity.social_capital already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [social_capital] nvarchar(60)');
    PRINT '     Column loc_legal_entity.social_capital created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'companies_register_number'))
  PRINT '      Column loc_legal_entity.companies_register_number already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [companies_register_number] nvarchar(30)');
    PRINT '     Column loc_legal_entity.companies_register_number created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'fax_number'))
  PRINT '      Column loc_legal_entity.fax_number already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [fax_number] nvarchar(32)');
    PRINT '     Column loc_legal_entity.fax_number created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'phone_number'))
  PRINT '      Column loc_legal_entity.phone_number already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [phone_number] nvarchar(32)');
    PRINT '     Column loc_legal_entity.phone_number created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'web_site'))
  PRINT '      Column loc_legal_entity.web_site already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [web_site] nvarchar(254)');
    PRINT '     Column loc_legal_entity.web_site created';
  END
GO


PRINT '     Step Add Column: DTX[LegalEntity] Column[[Field=legalForm, Field=socialCapital, Field=companiesRegisterNumber, Field=faxNumber, Field=phoneNumber, Field=webSite]] end.';



PRINT '     Step Add Column: DTX[MobileServer] Column[[Field=wkstnRangeStart, Field=wkstnRangeEnd]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ctl_mobile_server') AND name in (N'wkstn_range_start'))
  PRINT '      Column ctl_mobile_server.wkstn_range_start already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE ctl_mobile_server ADD [wkstn_range_start] INT');
    PRINT '     Column ctl_mobile_server.wkstn_range_start created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'ctl_mobile_server') AND name in (N'wkstn_range_end'))
  PRINT '      Column ctl_mobile_server.wkstn_range_end already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE ctl_mobile_server ADD [wkstn_range_end] INT');
    PRINT '     Column ctl_mobile_server.wkstn_range_end created';
  END
GO


PRINT '     Step Add Column: DTX[MobileServer] Column[[Field=wkstnRangeStart, Field=wkstnRangeEnd]] end.';



PRINT '     Step Add Column: DTX[Party] Column[[Field=saveCardPayments]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'crm_party') AND name in (N'save_card_payments_flag'))
  PRINT '      Column crm_party.save_card_payments_flag already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE crm_party ADD [save_card_payments_flag] BIT DEFAULT (0) NOT NULL');
    PRINT '     Column crm_party.save_card_payments_flag created';
  END
GO


PRINT '     Step Add Column: DTX[Party] Column[[Field=saveCardPayments]] end.';



PRINT '     Step Add Table: DTX[CustomerPaymentCard] starting...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('CRM_CUSTOMER_PAYMENT_CARD'))
  PRINT '      Table crm_customer_payment_card already exists';
ELSE
  BEGIN
    EXEC('CREATE TABLE [dbo].[crm_customer_payment_card](
[organization_id] INT NOT NULL,
[party_id] BIGINT NOT NULL,
[card_token] nvarchar(254) NOT NULL,
[card_alias] nvarchar(254),
[card_type] nvarchar(60),
[card_last_four] nvarchar(4),
[expr_date] nvarchar(64),
[shopper_ref] nvarchar(254),
[create_user_id] nvarchar(256),
[create_date] DATETIME,
[update_user_id] nvarchar(256),
[update_date] DATETIME,
[record_state] nvarchar(30), 
CONSTRAINT [pk_crm_customer_payment_card] PRIMARY KEY CLUSTERED (organization_id, party_id, card_token))
');
  PRINT '      Table crm_customer_payment_card created';
  END
GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('CRM_CUSTOMER_PAYMENT_CARD_P'))
  PRINT '      Table crm_customer_payment_card_P already exists';
ELSE
  BEGIN
    EXEC('CREATE_PROPERTY_TABLE crm_customer_payment_card;');
  PRINT '     Table crm_customer_payment_card_P created';
  END
GO


PRINT '     Step Add Table: DTX[CustomerPaymentCard] end.';



PRINT '     Step Add Column: DTX[TemporaryStoreRequest] Column[[Field=useStoreTaxLocation]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_temp_store_request') AND name in (N'use_store_tax_loc_flag'))
  PRINT '      Column loc_temp_store_request.use_store_tax_loc_flag already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_temp_store_request ADD [use_store_tax_loc_flag] BIT DEFAULT (1) NOT NULL');
    PRINT '     Column loc_temp_store_request.use_store_tax_loc_flag created';
  END
GO


PRINT '     Step Add Column: DTX[TemporaryStoreRequest] Column[[Field=useStoreTaxLocation]] end.';



PRINT '     Step Add Column: DTX[FrRcptDuplicate] Column[[Field=signatureVersion]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'cfra_rcpt_dup') AND name in (N'signature_version'))
  PRINT '      Column cfra_rcpt_dup.signature_version already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE cfra_rcpt_dup ADD [signature_version] INT');
    PRINT '     Column cfra_rcpt_dup.signature_version created';
  END
GO


PRINT '     Step Add Column: DTX[FrRcptDuplicate] Column[[Field=signatureVersion]] end.';



PRINT '     Step Add Column: DTX[FrRcptDuplicate] Column[[Field=documentType]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'cfra_rcpt_dup') AND name in (N'document_type'))
  PRINT '      Column cfra_rcpt_dup.document_type already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE cfra_rcpt_dup ADD [document_type] nvarchar(30)');
    PRINT '     Column cfra_rcpt_dup.document_type created';
  END
GO


PRINT '     Step Add Column: DTX[FrRcptDuplicate] Column[[Field=documentType]] end.';



PRINT '     Step Add Column: DTX[FrTechnicalEventLog] Column[[Field=signatureVersion]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'cfra_technical_event_log') AND name in (N'signature_version'))
  PRINT '      Column cfra_technical_event_log.signature_version already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE cfra_technical_event_log ADD [signature_version] INT');
    PRINT '     Column cfra_technical_event_log.signature_version created';
  END
GO


PRINT '     Step Add Column: DTX[FrTechnicalEventLog] Column[[Field=signatureVersion]] end.';



PRINT '     Step Alter Column: DTX[FrTechnicalEventLog] Field[[Field=signatureSource]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cfra_technical_event_log', 'signature_source') ) IS NULL
  PRINT '     Default value Constraint for column [cfra_technical_event_log].[signature_source] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cfra_technical_event_log] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cfra_technical_event_log','signature_source')+'];' 
  EXEC(@sql) 
  PRINT '     cfra_technical_event_log.signature_source default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cfra_technical_event_log ALTER COLUMN [signature_source] nvarchar(4000)');
  PRINT '     Column cfra_technical_event_log.signature_source modify';
END
GO
PRINT '     Step Alter Column: DTX[FrTechnicalEventLog] Field[[Field=signatureSource]] end.';



PRINT '     Step Add Table: DTX[FrInvoiceDuplicate] starting...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('CFRA_INVOICE_DUP'))
  PRINT '      Table cfra_invoice_dup already exists';
ELSE
  BEGIN
    EXEC('CREATE TABLE [dbo].[cfra_invoice_dup](
[organization_id] INT NOT NULL,
[rtl_loc_id] INT NOT NULL,
[wkstn_id] INT NOT NULL,
[reprint_id] nvarchar(30) NOT NULL,
[doc_number] nvarchar(30) NOT NULL,
[reprint_number] INT,
[operator_code] nvarchar(30),
[business_date] DATETIME,
[reprint_date] DATETIME,
[document_type] nvarchar(32) NOT NULL,
[inv_rtl_loc_id] INT,
[inv_wkstn_id] BIGINT,
[inv_business_year] INT,
[inv_sequence_id] nvarchar(255),
[inv_sequence_nbr] BIGINT,
[postponement_flag] BIT DEFAULT (0),
[signature] nvarchar(1024),
[signature_source] nvarchar(1024),
[signature_version] INT,
[create_user_id] nvarchar(256),
[create_date] DATETIME,
[update_user_id] nvarchar(256),
[update_date] DATETIME,
[record_state] nvarchar(30), 
CONSTRAINT [pk_cfra_invoice_dup] PRIMARY KEY CLUSTERED (organization_id, rtl_loc_id, wkstn_id, reprint_id, doc_number))
');
  PRINT '      Table cfra_invoice_dup created';
  END
GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('CFRA_INVOICE_DUP_P'))
  PRINT '      Table cfra_invoice_dup_P already exists';
ELSE
  BEGIN
    EXEC('CREATE_PROPERTY_TABLE cfra_invoice_dup;');
  PRINT '     Table cfra_invoice_dup_P created';
  END
GO


PRINT '     Step Add Table: DTX[FrInvoiceDuplicate] end.';



PRINT '     Step Consolidating legal entity extended properties starting...';
BEGIN

  UPDATE loc_legal_entity
  SET social_capital = b.string_value
  FROM loc_legal_entity a
  INNER JOIN loc_legal_entity_p b ON a.organization_id = b.organization_id AND a.legal_entity_id = b.legal_entity_id
  WHERE b.property_code = 'SHARE_CAPITAL'
  AND a.social_capital IS NULL
  PRINT '        ' + CAST(@@rowcount AS NVARCHAR(10)) + ' Social capital converted';

  UPDATE loc_legal_entity
  SET companies_register_number = b.string_value
  FROM loc_legal_entity a
  INNER JOIN loc_legal_entity_p b ON a.organization_id = b.organization_id AND a.legal_entity_id = b.legal_entity_id
  WHERE b.property_code = 'COMPANIES_REGISTER_NUMBER'
  AND a.companies_register_number IS NULL
  PRINT '        ' + CAST(@@rowcount AS NVARCHAR(10)) + ' Companies_register_number capital converted';

END
GO
PRINT '     Step Consolidating legal entity extended properties end.';



PRINT '     Step Removing legal entity extended properties starting...';
BEGIN
  DELETE FROM loc_legal_entity_p WHERE property_code IN ('SHARE_CAPITAL', 'COMPANIES_REGISTER_NUMBER')
  PRINT '        ' + CAST(@@rowcount AS NVARCHAR(10)) + ' Shared capital and Companies register number removed';
END
GO
PRINT '     Step Removing legal entity extended properties end.';



PRINT '     Step Mexican pending invoice conversion in V20 format starting...';
BEGIN
  UPDATE civc_invoice SET sequence_id = 'PENDING_' + sequence_id, invoice_type = 'PENDING_GLOBAL_' + invoice_type 
  FROM civc_invoice 
  INNER JOIN loc_rtl_loc ON civc_invoice.organization_id = loc_rtl_loc.organization_id AND civc_invoice.rtl_loc_id = loc_rtl_loc.rtl_loc_id 
  WHERE ext_invoice_id IS NULL AND sequence_id NOT LIKE 'PENDING%'
  AND loc_rtl_loc.country = 'MX';
  
  PRINT '        ' + CAST(@@rowcount AS NVARCHAR(10)) + ' Mexican pending invoices converted';
END
GO

BEGIN
  UPDATE civc_invoice_xref SET civc_invoice_xref.sequence_id = 'PENDING_' + civc_invoice_xref.sequence_id 
  FROM civc_invoice_xref 
  INNER JOIN civc_invoice 
    ON civc_invoice.organization_id = civc_invoice_xref.organization_id 
          AND civc_invoice.rtl_loc_id = civc_invoice_xref.rtl_loc_id 
          AND civc_invoice.wkstn_id = civc_invoice_xref.wkstn_id
          AND civc_invoice.business_year = civc_invoice_xref.business_year
          AND civc_invoice.sequence_id = 'PENDING_' + civc_invoice_xref.sequence_id
          AND civc_invoice.sequence_nbr = civc_invoice_xref.sequence_nbr
          AND civc_invoice.sequence_id LIKE 'PENDING%'
  WHERE civc_invoice_xref.sequence_id NOT LIKE 'PENDING%';

  PRINT '        ' + CAST(@@rowcount AS NVARCHAR(10)) + ' Mexican pending invoices reference converted';
END
GO
PRINT '     Step Mexican pending invoice conversion in V20 format end.';



PRINT '     Step Alter Column: DTX[Party] Field[[Field=organizationName]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party', 'organization_name') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party].[organization_name] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_party] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party','organization_name')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party.organization_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party ALTER COLUMN [organization_name] nvarchar(254)');
  PRINT '     Column crm_party.organization_name modify';
END
GO
PRINT '     Step Alter Column: DTX[Party] Field[[Field=organizationName]] end.';



PRINT '     Step Alter Column: DTX[FulfillmentModifier] Field[[Field=organizationName]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_fulfillment_mod', 'organization_name') ) IS NULL
  PRINT '     Default value Constraint for column [xom_fulfillment_mod].[organization_name] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [xom_fulfillment_mod] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_fulfillment_mod','organization_name')+'];' 
  EXEC(@sql) 
  PRINT '     xom_fulfillment_mod.organization_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_fulfillment_mod ALTER COLUMN [organization_name] nvarchar(254)');
  PRINT '     Column xom_fulfillment_mod.organization_name modify';
END
GO
PRINT '     Step Alter Column: DTX[FulfillmentModifier] Field[[Field=organizationName]] end.';



PRINT '     Step Alter Column: DTX[CustomerModifier] Field[[Field=organizationName]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_customer_mod', 'organization_name') ) IS NULL
  PRINT '     Default value Constraint for column [xom_customer_mod].[organization_name] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [xom_customer_mod] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_customer_mod','organization_name')+'];' 
  EXEC(@sql) 
  PRINT '     xom_customer_mod.organization_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_customer_mod ALTER COLUMN [organization_name] nvarchar(254)');
  PRINT '     Column xom_customer_mod.organization_name modify';
END
GO
PRINT '     Step Alter Column: DTX[CustomerModifier] Field[[Field=organizationName]] end.';



PRINT '     Step Alter Column: DTX[DeTseDeviceConfig] Field[[Field=tseCertificate, Field=tseConfig]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cger_tse_device', 'tse_certificate') ) IS NULL
  PRINT '     Default value Constraint for column [cger_tse_device].[tse_certificate] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cger_tse_device] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cger_tse_device','tse_certificate')+'];' 
  EXEC(@sql) 
  PRINT '     cger_tse_device.tse_certificate default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cger_tse_device ALTER COLUMN [tse_certificate] nvarchar(4000)');
  PRINT '     Column cger_tse_device.tse_certificate modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cger_tse_device', 'tse_config') ) IS NULL
  PRINT '     Default value Constraint for column [cger_tse_device].[tse_config] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [cger_tse_device] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cger_tse_device','tse_config')+'];' 
  EXEC(@sql) 
  PRINT '     cger_tse_device.tse_config default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cger_tse_device ALTER COLUMN [tse_config] nvarchar(4000)');
  PRINT '     Column cger_tse_device.tse_config modify';
END
GO
PRINT '     Step Alter Column: DTX[DeTseDeviceConfig] Field[[Field=tseCertificate, Field=tseConfig]] end.';



PRINT '     Step Alter Column: DTX[ReceiptText] Field[[Field=receiptText]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('com_receipt_text', 'receipt_text') ) IS NULL
  PRINT '     Default value Constraint for column [com_receipt_text].[receipt_text] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [com_receipt_text] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('com_receipt_text','receipt_text')+'];' 
  EXEC(@sql) 
  PRINT '     com_receipt_text.receipt_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE com_receipt_text ALTER COLUMN [receipt_text] nvarchar(4000) NOT NULL');
  PRINT '     Column com_receipt_text.receipt_text modify';
END
GO
PRINT '     Step Alter Column: DTX[ReceiptText] Field[[Field=receiptText]] end.';



PRINT '     Step Alter Column: DTX[DatabaseTranslation] Field[[Field=translation]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('com_translations', 'translation') ) IS NULL
  PRINT '     Default value Constraint for column [com_translations].[translation] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [com_translations] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('com_translations','translation')+'];' 
  EXEC(@sql) 
  PRINT '     com_translations.translation default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE com_translations ALTER COLUMN [translation] nvarchar(4000)');
  PRINT '     Column com_translations.translation modify';
END
GO
PRINT '     Step Alter Column: DTX[DatabaseTranslation] Field[[Field=translation]] end.';



PRINT '     Step Alter Column: DTX[CustomerConsentInfo] Field[[Field=consent1Text, Field=consent2Text, Field=consent3Text, Field=consent4Text, Field=consent5Text, Field=termsAndConditions]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent1_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent1_text] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent1_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent1_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent1_text] nvarchar(4000)');
  PRINT '     Column crm_consent_info.consent1_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent2_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent2_text] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent2_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent2_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent2_text] nvarchar(4000)');
  PRINT '     Column crm_consent_info.consent2_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent3_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent3_text] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent3_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent3_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent3_text] nvarchar(4000)');
  PRINT '     Column crm_consent_info.consent3_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent4_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent4_text] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent4_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent4_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent4_text] nvarchar(4000)');
  PRINT '     Column crm_consent_info.consent4_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent5_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent5_text] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent5_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent5_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent5_text] nvarchar(4000)');
  PRINT '     Column crm_consent_info.consent5_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'terms_and_conditions') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[terms_and_conditions] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','terms_and_conditions')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.terms_and_conditions default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [terms_and_conditions] nvarchar(4000)');
  PRINT '     Column crm_consent_info.terms_and_conditions modify';
END
GO
PRINT '     Step Alter Column: DTX[CustomerConsentInfo] Field[[Field=consent1Text, Field=consent2Text, Field=consent3Text, Field=consent4Text, Field=consent5Text, Field=termsAndConditions]] end.';



PRINT '     Step Alter Column: DTX[DataLoaderFailure] Field[[Field=failedData, Field=failureMessage]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_dataloader_failure', 'failed_data') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_dataloader_failure].[failed_data] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_dataloader_failure] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_dataloader_failure','failed_data')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_dataloader_failure.failed_data default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_dataloader_failure ALTER COLUMN [failed_data] nvarchar(4000)');
  PRINT '     Column ctl_dataloader_failure.failed_data modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_dataloader_failure', 'failure_message') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_dataloader_failure].[failure_message] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [ctl_dataloader_failure] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_dataloader_failure','failure_message')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_dataloader_failure.failure_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_dataloader_failure ALTER COLUMN [failure_message] nvarchar(4000) NOT NULL');
  PRINT '     Column ctl_dataloader_failure.failure_message modify';
END
GO
PRINT '     Step Alter Column: DTX[DataLoaderFailure] Field[[Field=failedData, Field=failureMessage]] end.';



PRINT '     Step Alter Column: DTX[EmployeeAnswers] Field[[Field=challengeAnswer]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('hrs_employee_answers', 'challenge_answer') ) IS NULL
  PRINT '     Default value Constraint for column [hrs_employee_answers].[challenge_answer] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [hrs_employee_answers] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('hrs_employee_answers','challenge_answer')+'];' 
  EXEC(@sql) 
  PRINT '     hrs_employee_answers.challenge_answer default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE hrs_employee_answers ALTER COLUMN [challenge_answer] nvarchar(4000)');
  PRINT '     Column hrs_employee_answers.challenge_answer modify';
END
GO
PRINT '     Step Alter Column: DTX[EmployeeAnswers] Field[[Field=challengeAnswer]] end.';



PRINT '     Step Alter Column: DTX[Shipment] Field[[Field=shippingLabel]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('inv_shipment', 'shipping_label') ) IS NULL
  PRINT '     Default value Constraint for column [inv_shipment].[shipping_label] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [inv_shipment] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('inv_shipment','shipping_label')+'];' 
  EXEC(@sql) 
  PRINT '     inv_shipment.shipping_label default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE inv_shipment ALTER COLUMN [shipping_label] nvarchar(4000)');
  PRINT '     Column inv_shipment.shipping_label modify';
END
GO
PRINT '     Step Alter Column: DTX[Shipment] Field[[Field=shippingLabel]] end.';



PRINT '     Step Alter Column: DTX[CustomizationModifier] Field[[Field=customizationMessage]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_customization_mod', 'customization_message') ) IS NULL
  PRINT '     Default value Constraint for column [xom_customization_mod].[customization_message] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [xom_customization_mod] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_customization_mod','customization_message')+'];' 
  EXEC(@sql) 
  PRINT '     xom_customization_mod.customization_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_customization_mod ALTER COLUMN [customization_message] nvarchar(4000)');
  PRINT '     Column xom_customization_mod.customization_message modify';
END
GO
PRINT '     Step Alter Column: DTX[CustomizationModifier] Field[[Field=customizationMessage]] end.';



PRINT '     Step Alter Column: DTX[Order] Field[[Field=giftMessage, Field=orderMessage, Field=statusCodeReasonNote]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order', 'gift_message') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order].[gift_message] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [xom_order] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order','gift_message')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order.gift_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order ALTER COLUMN [gift_message] nvarchar(4000)');
  PRINT '     Column xom_order.gift_message modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order', 'order_message') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order].[order_message] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [xom_order] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order','order_message')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order.order_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order ALTER COLUMN [order_message] nvarchar(4000)');
  PRINT '     Column xom_order.order_message modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order', 'status_code_reason_note') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order].[status_code_reason_note] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [xom_order] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order','status_code_reason_note')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order.status_code_reason_note default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order ALTER COLUMN [status_code_reason_note] nvarchar(4000)');
  PRINT '     Column xom_order.status_code_reason_note modify';
END
GO
PRINT '     Step Alter Column: DTX[Order] Field[[Field=giftMessage, Field=orderMessage, Field=statusCodeReasonNote]] end.';



PRINT '     Step Alter Column: DTX[OrderLineDetail] Field[[Field=lineMessage, Field=statusCodeReasonNote]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order_line_detail', 'line_message') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order_line_detail].[line_message] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [xom_order_line_detail] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order_line_detail','line_message')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order_line_detail.line_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order_line_detail ALTER COLUMN [line_message] nvarchar(4000)');
  PRINT '     Column xom_order_line_detail.line_message modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order_line_detail', 'status_code_reason_note') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order_line_detail].[status_code_reason_note] is missing';
ELSE
  BEGIN
  DECLARE @sql nvarchar(max) 
  SET @sql = '    ALTER TABLE [xom_order_line_detail] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order_line_detail','status_code_reason_note')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order_line_detail.status_code_reason_note default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order_line_detail ALTER COLUMN [status_code_reason_note] nvarchar(4000)');
  PRINT '     Column xom_order_line_detail.status_code_reason_note modify';
END
GO
PRINT '     Step Alter Column: DTX[OrderLineDetail] Field[[Field=lineMessage, Field=statusCodeReasonNote]] end.';



PRINT '     Step Update sp_flash stored procedure starting...';
PRINT '     Step Update sp_flash stored procedure end.';



PRINT '     Step Upgrade row modification information to the new size starting...';
DECLARE @TableName AS NVARCHAR(1000)
DECLARE @SQL AS NVARCHAR(1000)
DECLARE @ColumnName AS NVARCHAR(1000)
DECLARE @DEFAULT AS NVARCHAR(1000)
DECLARE Table_Cursor CURSOR FOR SELECT TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME IN ('CREATE_USER_ID', 'UPDATE_USER_ID') AND CHARACTER_MAXIMUM_LENGTH <> 256 ORDER BY TABLE_NAME
OPEN Table_Cursor
FETCH NEXT FROM Table_Cursor INTO @TableName, @ColumnName
WHILE @@FETCH_STATUS = 0
BEGIN
   PRINT '     Step Alter Column: DTX[' + @TableName + '] Field[Field=' + @ColumnName + '] starting...';
   SET @DEFAULT = (SELECT dbo.SP_DEFAULT_CONSTRAINT_EXISTS ('' + @TableName + '', '' + @ColumnName + ''))
   IF (@DEFAULT) IS NULL
      PRINT '     Default value Constraint for column [' + @TableName + '].[' + @ColumnName + '] is missing';
   ELSE
      BEGIN
         EXEC('ALTER TABLE [' + @TableName + '] DROP CONSTRAINT ['+ @DEFAULT +'];')
         PRINT '     ' + @TableName + '.' + @ColumnName + ' default value dropped';
      END
   BEGIN
      EXEC('ALTER TABLE ' + @TableName + ' ALTER COLUMN [' + @ColumnName + '] nvarchar(256)');
      PRINT '     Column ' + @TableName + '.' + @ColumnName + ' modify';
   END
   FETCH NEXT FROM Table_Cursor INTO @TableName, @ColumnName
END
GO
CLOSE Table_Cursor
DEALLOCATE Table_Cursor
PRINT '     Step Upgrade row modification information to the new size end.';



PRINT '     Step Update string_value from nvarchar(MAX) to VARCHAR(4000) - Only for MS SQL Server starting...';
DECLARE @TableName AS NVARCHAR(1000)
DECLARE @SQL AS NVARCHAR(1000)
DECLARE Table_Cursor CURSOR FOR SELECT TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME LIKE '%[_]P' AND COLUMN_NAME = 'STRING_VALUE' AND CHARACTER_MAXIMUM_LENGTH <> 4000 ORDER BY TABLE_NAME
OPEN Table_Cursor
FETCH NEXT FROM Table_Cursor INTO @TableName
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'PRINT ''     Step Alter Column: DTX[' + @TableName + '] Field[Field=string_value] starting...'';
BEGIN
   EXEC(''ALTER TABLE ' + @TableName + ' ALTER COLUMN [string_value] nvarchar(4000)'');
   PRINT ''     Column ' + @TableName + '.string_value modify'';
END
PRINT ''     Step Alter Column: DTX[' + @TableName + '] Field[Field=string_value] end...'';'
    EXEC (@SQL)
    FETCH NEXT FROM Table_Cursor INTO @TableName
END
GO
CLOSE Table_Cursor
DEALLOCATE Table_Cursor
PRINT '     Step Update string_value from nvarchar(MAX) to VARCHAR(4000) - Only for MS SQL Server end.';



PRINT '     Step Add Table: DTX[PtAts] starting...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('CPOR_ATS'))
  PRINT '      Table cpor_ats already exists';
ELSE
  BEGIN
    EXEC('CREATE TABLE [dbo].[cpor_ats](
[organization_id] INT NOT NULL,
[rtl_loc_id] INT NOT NULL,
[wkstn_id] BIGINT NOT NULL,
[sequence_id] nvarchar(255) NOT NULL,
[series] nvarchar(1) NOT NULL,
[year] BIGINT NOT NULL,
[ats] nvarchar(70),
[create_user_id] nvarchar(256),
[create_date] DATETIME,
[update_user_id] nvarchar(256),
[update_date] DATETIME,
[record_state] nvarchar(30), 
CONSTRAINT [pk_cpor_ats] PRIMARY KEY CLUSTERED (organization_id, rtl_loc_id, wkstn_id, sequence_id, series, year))
');
  PRINT '      Table cpor_ats created';
  END
GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('CPOR_ATS_P'))
  PRINT '      Table cpor_ats_P already exists';
ELSE
  BEGIN
    EXEC('CREATE_PROPERTY_TABLE cpor_ats;');
  PRINT '     Table cpor_ats_P created';
  END
GO


PRINT '     Step Add Table: DTX[PtAts] end.';



PRINT '     Step Fixing a missing DBMS_OUTPUT.ENABLE starting...';
PRINT '     Step Fixing a missing DBMS_OUTPUT.ENABLE end.';



PRINT '     Step Add Column: DTX[WorkstationConfigData] Column[[Field=linkColumn]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_wkstn_config_data') AND name in (N'link_column'))
  PRINT '      Column loc_wkstn_config_data.link_column already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_wkstn_config_data ADD [link_column] nvarchar(30)');
    PRINT '     Column loc_wkstn_config_data.link_column created';
  END
GO


PRINT '     Step Add Column: DTX[WorkstationConfigData] Column[[Field=linkColumn]] end.';



PRINT '     Step Add Column: DTX[LegalEntity] Column[[Field=establishmentCode, Field=registrationCity]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'establishment_code'))
  PRINT '      Column loc_legal_entity.establishment_code already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [establishment_code] nvarchar(30)');
    PRINT '     Column loc_legal_entity.establishment_code created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'registration_city'))
  PRINT '      Column loc_legal_entity.registration_city already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [registration_city] nvarchar(254)');
    PRINT '     Column loc_legal_entity.registration_city created';
  END
GO


PRINT '     Step Add Column: DTX[LegalEntity] Column[[Field=establishmentCode, Field=registrationCity]] end.';




PRINT '***** Body scripts end *****';


PRINT '**************************************';
PRINT 'Finalizing UPGRADE release 20.0';
PRINT '**************************************';
GO

-- LEAVE BLANK LINE BELOW
/* 
 * VIEW: Dual 
 */
 
IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'Dual'))
    DROP VIEW Dual
GO

CREATE VIEW Dual(dummy)
AS
SELECT 'X'
GO

/* 
 * VIEW: Test_Connection 
 */
 
IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'Test_Connection'))
    DROP VIEW Test_Connection
GO

CREATE VIEW Test_Connection(result)
AS
SELECT 1
GO

/* 
 * VIEW: [dbo].[rpt_trl_sale_lineitm_view] 
 */

IF EXISTS (Select * From information_schema.views Where table_name = 'rpt_trl_sale_lineitm_view')
  DROP VIEW rpt_trl_sale_lineitm_view;
GO

CREATE VIEW rpt_trl_sale_lineitm_view
AS
  SELECT trn.organization_id,
         trn.rtl_loc_id ,
         trn.wkstn_id ,
         trn.trans_seq ,
         tsl.rtrans_lineitm_seq ,
         trn.business_date,
         trn.begin_datetime,
         trn.end_datetime,
         trn.trans_statcode,
         trn.trans_typcode,
         trn.session_id,
         trn.operator_party_id,
         trt.cust_party_id,
         tsl.item_id,
         tsl.merch_level_1,
         tsl.quantity,
         tsl.unit_price,
         tsl.extended_amt,
         tsl.vat_amt,
         tsl.return_flag,
         tsl.net_amt,
         tsl.gross_amt,
         tsl.serial_nbr,
         tsl.sale_lineitm_typcode,
         tsl.tax_group_id,
         tsl.original_rtl_loc_id,
         tsl.original_wkstn_id,
         tsl.original_business_date,
         tsl.original_trans_seq,
         tsl.original_rtrans_lineitm_seq,
         tsl.return_reascode,
         tsl.return_comment,
         tsl.return_typcode,
         trl.void_flag,
         trl.void_lineitm_reascode,
         tsl.base_extended_price,
         tsl.rpt_base_unit_price,
         tsl.exclude_from_net_sales_flag
    FROM  
         trn_trans AS trn, 
         trl_sale_lineitm AS tsl, 
         trl_rtrans_lineitm AS trl, 
         trl_rtrans AS trt     
    WHERE 
          trn.organization_id = tsl.organization_id 
      AND trn.rtl_loc_id = tsl.rtl_loc_id
      AND trn.wkstn_id = tsl.wkstn_id 
      AND trn.business_date = tsl.business_date
      AND trn.trans_seq = tsl.trans_seq
      AND tsl.organization_id = trl.organization_id
      AND tsl.rtl_loc_id = trl.rtl_loc_id
      AND tsl.wkstn_id = trl.wkstn_id
      AND tsl.business_date = trl.business_date
      AND tsl.trans_seq = trl.trans_seq
      AND tsl.rtrans_lineitm_seq = trl.rtrans_lineitm_seq
      AND tsl.organization_id = trt.organization_id
      AND tsl.rtl_loc_id = trt.rtl_loc_id
      AND tsl.wkstn_id = trt.wkstn_id
      AND tsl.business_date = trt.business_date
      AND tsl.trans_seq = trt.trans_seq
      AND trn.trans_statcode = 'COMPLETE';
GO
/* 
 * VIEW: [dbo].[rpt_trl_stock_movement_view] 
 */

IF EXISTS (Select * From information_schema.views Where table_name = 'rpt_trl_stock_movement_view')
  DROP VIEW rpt_trl_stock_movement_view;
GO

CREATE VIEW rpt_trl_stock_movement_view
AS
SELECT itm_mov.organization_id, itm_mov.rtl_loc_id, itm_mov.business_date, itm_mov.item_id, 
      itm_mov.quantity, itm_mov.adjustment_flag
FROM

((SELECT tsl.organization_id as organization_id, tsl.rtl_loc_id as rtl_loc_id, tsl.business_date as business_date, tsl.item_id as item_id,
	quantity, case when return_flag = 0 then 1 else 0 end as adjustment_flag
	FROM rpt_trl_sale_lineitm_view tsl
	WHERE trans_seq NOT IN
          (SELECT voided_trans_id FROM trn_post_void_trans pvt
           WHERE pvt.organization_id = tsl.organization_id
           AND pvt.rtl_loc_id = tsl.rtl_loc_id
           AND pvt.wkstn_id = tsl.wkstn_id)
	AND sale_lineitm_typcode = 'SALE'
	AND tsl.void_flag = 0) 
				
UNION ALL

(SELECT inv_journal.organization_id, inv_journal.rtl_loc_id, inv_journal.business_date, inv_journal.inventory_item_id,
     quantity, case when action_code IN ('RECEIVING', 'INVENTORY_ADJUSTMENT', 'CYCLE_COUNT_ADJUSTMENT') then 0 else 1 end as adjustment_flag
FROM inv_inventory_journal inv_journal
WHERE action_code IN ('RECEIVING', 'SHIPPING', 'INVENTORY_ADJUSTMENT', 'CYCLE_COUNT_ADJUSTMENT')
      AND (source_bucket_id='ON_HAND' OR dest_bucket_id='ON_HAND'))) itm_mov 

GO

/* 
 * FUNCTION: [dbo].[fn_integerListToTable] 
 */

PRINT 'dbo.fn_integerListToTable';

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_integerListToTable]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
	DROP FUNCTION [dbo].[fn_integerListToTable]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [dbo].[fn_integerListToTable] (@list nvarchar(MAX))
   RETURNS @tbl TABLE (number int NOT NULL) AS
BEGIN
   DECLARE @pos        int,
           @nextpos    int,
           @valuelen   int

   SELECT @pos = 0, @nextpos = 1

   WHILE @nextpos > 0
   BEGIN
      SELECT @nextpos = charindex(',', @list, @pos + 1)
      SELECT @valuelen = CASE WHEN @nextpos > 0
                              THEN @nextpos
                              ELSE len(@list) + 1
                         END - @pos - 1
      INSERT @tbl (number)
         VALUES (convert(int, substring(@list, @pos + 1, @valuelen)))
      SELECT @pos = @nextpos
   END
   RETURN
END


GO


IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_nodesInHierarchy')
DROP FUNCTION dbo.fn_nodesInHierarchy
GO

Create FUNCTION fn_nodesInHierarchy (@vorgId INT, @vorgCode NVARCHAR(30), @vorgValue NVARCHAR(60))
RETURNS TABLE
AS
RETURN (
  WITH Nodes AS (
    SELECT organization_id, org_code, org_value, parent_code, parent_value
    FROM loc_org_hierarchy chain
    WHERE organization_id = @vorgId
      AND org_code = @vorgCode
      AND org_value = @vorgValue
    UNION ALL
    SELECT node.organization_id, node.org_code, node.org_value, node.parent_code, node.parent_value
    FROM loc_org_hierarchy node
    INNER JOIN Nodes s
      ON node.organization_id = s.organization_id
      AND node.org_code = s.parent_code
      AND node.org_value = s.parent_value
    WHERE node.organization_id = @vorgId
  )
  SELECT org_code + ':' + org_value as node
  FROM Nodes
  union
  select @vorgCode + ':' + @vorgValue as node
)
GO
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_storesInHierarchy')
DROP FUNCTION dbo.fn_storesInHierarchy
GO

CREATE FUNCTION dbo.fn_storesInHierarchy (@vorgId INT, @vorgCode NVARCHAR(30), @vorgValue NVARCHAR(60))
RETURNS TABLE
AS
RETURN (
  WITH Stores AS (
    SELECT organization_id, org_code, org_value
    FROM loc_org_hierarchy chain
    WHERE organization_id = @vorgId
      AND org_code = @vorgCode
      AND org_value = @vorgValue
    UNION ALL
    SELECT node.organization_id, node.org_code, node.org_value
    FROM loc_org_hierarchy node
    INNER JOIN Stores s
      ON node.organization_id = s.organization_id
      AND node.parent_code = s.org_code
      AND node.parent_value = s.org_value
    WHERE node.organization_id = @vorgId
  )
  SELECT org_value
  FROM Stores
  WHERE org_code = 'STORE'
)
GO
/* 
 * PROCEDURE: [dbo].[sp_conv_to_unicode] 
 */

IF EXISTS (Select * From sysobjects Where name = 'sp_conv_to_unicode' and type = 'P')
  DROP PROCEDURE sp_conv_to_unicode;
GO

-- =============================================
-- Author:		Brett C. White
-- Create date: 2/14/12
-- Description:	Converts all char, nvarchar, and text fields into nchar, nvarchar, and ntext.
-- =============================================
CREATE PROCEDURE sp_conv_to_unicode 
AS
BEGIN
	begin try
	create table indexlist(
		tablename	     nvarchar(max),
		indexname	     nvarchar(max),
		sql			nvarchar(max),
		is_pk		bit,
		mult			float
	)
	end try
	begin catch
	   declare @rsql0 nvarchar(max)

	   declare icur0 CURSOR FAST_FORWARD for
	   select sql from indexlist order by is_pk desc,tablename asc

	   OPEN icur0

	   WHILE 1=1
	   BEGIN
	    FETCH NEXT FROM icur0 INTO @rsql0
	    if @@FETCH_STATUS <> 0
		    break;
	    begin try
		   print @rsql0
		   exec(@rsql0)
		   delete from indexlist where sql=@rsql0
	    end try
	    begin catch
	    end catch
	   END
	   close icur0;
	   deallocate icur0;
	end catch

	declare @ctable nvarchar(max),@csql nvarchar(max),@oldtable nvarchar(max),@isql nvarchar(max),@default nvarchar(max),@ccolumn nvarchar(max),@mult float,@error nvarchar(max);

	declare column_list CURSOR FAST_FORWARD for
	select COL.table_name,name,COLUMN_NAME,'ALTER TABLE [' + COL.table_name + '] ALTER COLUMN [' + column_name + '] n' + data_type
	+ '(' + case when(character_maximum_length=-1 or character_maximum_length>=4000) then 'max' else cast(character_maximum_length as nvarchar(5)) end + ') '
	+ case when(is_nullable='no') then ' NOT NULL' else ' NULL' end
	+ case when(name is not null) then '; ALTER TABLE [' + COL.table_name + '] ADD ' + case when(isnull(is_system_named,1)=0) then 'CONSTRAINT [' + name + ']' else '' end + ' DEFAULT ' + definition + ' FOR [' + COLUMN_NAME + ']' else '' end
	from INFORMATION_SCHEMA.columns COL
	inner join INFORMATION_SCHEMA.TABLES t on t.TABLE_NAME=COL.TABLE_NAME
	left join sys.default_constraints on parent_object_id = OBJECT_ID(COL.table_name) and COL_NAME(parent_object_id, parent_column_id) = column_name
	where data_type in ('varchar','char') and TABLE_TYPE like '%table%'
	order by COL.table_name,ORDINAL_POSITION

	open column_list;

	while 1=1
	BEGIN
		FETCH NEXT FROM column_list INTO @ctable,@default,@ccolumn,@csql
		if @@FETCH_STATUS <> 0
		BEGIN
			break;
		END
		declare @iname nvarchar(max),@icolumn nvarchar(max),@itype tinyint,@PK bit,@old nvarchar(max),@oldPK bit,@unique bit,@is_included bit,@ref nvarchar(max),@fktable nvarchar(max),@fill_factor nvarchar(10)

		SET @old=null
		-- Find all Foreign Keys from this table or references this table
		if exists(SELECT 1 from sysobjects f
			 inner join sysobjects c on  f.parent_obj = c.id
			 inner join sysforeignkeys r on f.id =  r.constid
			 inner join sysobjects p on r.rkeyid = p.id
			 inner  join syscolumns rc on r.rkeyid = rc.id and r.rkey = rc.colid
			 INNER JOIN INFORMATION_SCHEMA.COLUMNS col ON rc.name=col.COLUMN_NAME and c.name=col.TABLE_NAME
			 where f.type = 'F' and (p.name=@ctable or c.name=@ctable) and DATA_TYPE in ('varchar','char'))
		BEGIN
			    declare index_list CURSOR FAST_FORWARD for
				    select c.name,f.name,'alter table [' + c.name + '] WITH CHECK ADD CONSTRAINT [' + f.name
					+ '] FOREIGN KEY (' + fc.name + ISNULL(',' + fc2.name,'') + ISNULL(',' + fc3.name,'') + ISNULL(',' + fc4.name,'')
					+ ISNULL(',' + fc5.name,'') + ISNULL(',' + fc6.name,'') + ISNULL(',' + fc7.name,'') + ISNULL(',' + fc8.name,'')
					+ ISNULL(',' + fc9.name,'') + ISNULL(',' + fc10.name,'') + ISNULL(',' + fc11.name,'') + ISNULL(',' + fc12.name,'')
					+ ISNULL(',' + fc13.name,'') + ISNULL(',' + fc14.name,'') + ISNULL(',' + fc15.name,'') + ISNULL(',' + fc16.name,'') + ')'
					+ ' REFERENCES [' + p.name + '] (' + rc.name + ISNULL(',' + rc2.name,'') + ISNULL(',' + rc3.name,'') + ISNULL(',' + rc4.name,'')
				    + ISNULL(',' + rc5.name,'') + ISNULL(',' + rc6.name,'') + ISNULL(',' + rc7.name,'') + ISNULL(',' + rc8.name,'')
				    + ISNULL(',' + rc9.name,'') + ISNULL(',' + rc10.name,'') + ISNULL(',' + rc11.name,'') + ISNULL(',' + rc12.name,'') 
				    + ISNULL(',' + rc13.name,'') + ISNULL(',' + rc14.name,'') + ISNULL(',' + rc15.name,'') + ISNULL(',' + rc16.name,'') + ')'
				    + CASE WHEN(UPDATE_RULE<>'NO ACTION') then ' ON UPDATE ' + UPDATE_RULE else '' end
				    + CASE WHEN(DELETE_RULE<>'NO ACTION') then ' ON DELETE ' + DELETE_RULE else '' end
				    from sysobjects f
				    inner join sysobjects c on  f.parent_obj = c.id
				    inner join INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS IC on f.name=IC.CONSTRAINT_NAME
				    inner join sysreferences r on f.id =  r.constid
				    inner join sysobjects p on r.rkeyid = p.id
				    inner join syscolumns rc on r.rkeyid = rc.id and r.rkey1 = rc.colid
				    inner join syscolumns fc on r.fkeyid = fc.id and r.fkey1 = fc.colid
				    left join syscolumns rc2 on r.rkeyid = rc2.id and r.rkey2 = rc2.colid
				    left join syscolumns rc3 on r.rkeyid = rc3.id and r.rkey3 = rc3.colid
				    left join syscolumns rc4 on r.rkeyid = rc4.id and r.rkey4 = rc4.colid
				    left join syscolumns rc5 on r.rkeyid = rc5.id and r.rkey5 = rc5.colid
				    left join syscolumns rc6 on r.rkeyid = rc6.id and r.rkey6 = rc6.colid
				    left join syscolumns rc7 on r.rkeyid = rc7.id and r.rkey7 = rc7.colid
				    left join syscolumns rc8 on r.rkeyid = rc8.id and r.rkey8 = rc8.colid
				    left join syscolumns rc9 on r.rkeyid = rc9.id and r.rkey9 = rc9.colid
				    left join syscolumns rc10 on r.rkeyid = rc10.id and r.rkey10 = rc10.colid
				    left join syscolumns rc11 on r.rkeyid = rc11.id and r.rkey11 = rc11.colid
				    left join syscolumns rc12 on r.rkeyid = rc12.id and r.rkey12 = rc12.colid
				    left join syscolumns rc13 on r.rkeyid = rc13.id and r.rkey13 = rc13.colid
				    left join syscolumns rc14 on r.rkeyid = rc14.id and r.rkey14 = rc14.colid
				    left join syscolumns rc15 on r.rkeyid = rc15.id and r.rkey15 = rc15.colid
				    left join syscolumns rc16 on r.rkeyid = rc16.id and r.rkey16 = rc16.colid
				    left join syscolumns fc2 on r.fkeyid = fc2.id and r.fkey2 = fc2.colid
				    left join syscolumns fc3 on r.fkeyid = fc3.id and r.fkey3 = fc3.colid
				    left join syscolumns fc4 on r.fkeyid = fc4.id and r.fkey4 = fc4.colid
				    left join syscolumns fc5 on r.fkeyid = fc5.id and r.fkey5 = fc5.colid
				    left join syscolumns fc6 on r.fkeyid = fc6.id and r.fkey6 = fc6.colid
				    left join syscolumns fc7 on r.fkeyid = fc7.id and r.fkey7 = fc7.colid
				    left join syscolumns fc8 on r.fkeyid = fc8.id and r.fkey8 = fc8.colid
				    left join syscolumns fc9 on r.fkeyid = fc9.id and r.fkey9 = fc9.colid
				    left join syscolumns fc10 on r.fkeyid = fc10.id and r.fkey10 = fc10.colid
				    left join syscolumns fc11 on r.fkeyid = fc11.id and r.fkey11 = fc11.colid
				    left join syscolumns fc12 on r.fkeyid = fc12.id and r.fkey12 = fc12.colid
				    left join syscolumns fc13 on r.fkeyid = fc13.id and r.fkey13 = fc13.colid
				    left join syscolumns fc14 on r.fkeyid = fc14.id and r.fkey14 = fc14.colid
				    left join syscolumns fc15 on r.fkeyid = fc15.id and r.fkey15 = fc15.colid
				    left join syscolumns fc16 on r.fkeyid = fc16.id and r.fkey16 = fc16.colid
				 where f.type =  'F' and p.name=@ctable or c.name=@ctable
				 ORDER BY f.name
 
		    open index_list;
		    while 1=1
		    BEGIN
			    FETCH NEXT FROM index_list INTO @fktable,@iname,@isql
			    if @@FETCH_STATUS <> 0 break;
				    
			    insert into indexlist (tablename,indexname,sql) values(@fktable,@iname,@isql)

			    print 'ALTER TABLE [' + @fktable + '] DROP CONSTRAINT [' + @iname + ']'
			    exec('ALTER TABLE [' + @fktable + '] DROP CONSTRAINT [' + @iname + ']');
		    END
		    close index_list
		    deallocate index_list
		END
		  -- Find all check constraints.
		  declare index_list CURSOR FAST_FORWARD for
		  SELECT  cc.CONSTRAINT_NAME,CHECK_CLAUSE 
		  FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc 
		  INNER JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE c ON cc.CONSTRAINT_NAME = c.CONSTRAINT_NAME 
		  INNER JOIN INFORMATION_SCHEMA.COLUMNS col ON c.COLUMN_NAME=col.COLUMN_NAME and c.TABLE_NAME=col.TABLE_NAME
		  where DATA_TYPE in ('varchar','char') and c.TABLE_NAME=@ctable

		  open index_list;
		  while 1=1
		  BEGIN
			  FETCH NEXT FROM index_list INTO @iname,@icolumn
			  if @@FETCH_STATUS <> 0
			  break;
			  insert into indexlist (tablename,indexname,sql) values(@ctable,@iname,'ALTER TABLE [' + @ctable + ']  WITH CHECK ADD  CONSTRAINT [' + @iname + '] CHECK  (' + @icolumn + ')')
		    
			  print 'ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @iname + ']' 
			  exec('ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @iname + ']');
		  END
		  close index_list
		  deallocate index_list
		  
		set @old = null;
		-- Find all primary keys and indexes that have char and/or nvarchar columns.
		if not exists (select 1 from indexlist where tablename=@ctable and is_pk is not null) and exists(SELECT 1 FROM sys.indexes ind 
			INNER JOIN sys.index_columns ic ON ind.object_id = ic.object_id and ind.index_id = ic.index_id  
			INNER JOIN sys.columns col ON ic.object_id = col.object_id and ic.column_id = col.column_id  
			INNER JOIN sys.tables t ON ind.object_id = t.object_id  
			INNER JOIN INFORMATION_SCHEMA.COLUMNS cl on t.name=cl.TABLE_NAME and col.name=cl.COLUMN_NAME  
			WHERE ind.type in (1, 2) and is_disabled=0 and t.name=@ctable and data_type in ('varchar','char'))
		BEGIN
			declare char_index CURSOR FAST_FORWARD for
			SELECT distinct ind.name FROM sys.indexes ind 
			INNER JOIN sys.index_columns ic ON ind.object_id = ic.object_id and ind.index_id = ic.index_id  
			INNER JOIN sys.columns col ON ic.object_id = col.object_id and ic.column_id = col.column_id  
			INNER JOIN sys.tables t ON ind.object_id = t.object_id  
			INNER JOIN INFORMATION_SCHEMA.COLUMNS cl on t.name=cl.TABLE_NAME and col.name=cl.COLUMN_NAME  
			WHERE ind.type in (1, 2) and is_disabled=0 and t.name=@ctable and data_type in ('varchar','char')

			open char_index
			WHILE 1=1
			BEGIN
			    FETCH NEXT FROM char_index INTO @iname
			    if @@FETCH_STATUS<>0
				    break;
			    declare index_list CURSOR FAST_FORWARD for
			    SELECT col.name,ind.type,ind.is_primary_key,ind.is_unique,is_included_column,fill_factor  
			    FROM sys.indexes ind 
			    INNER JOIN sys.index_columns ic ON ind.object_id = ic.object_id and ind.index_id = ic.index_id  
			    INNER JOIN sys.columns col ON ic.object_id = col.object_id and ic.column_id = col.column_id  
			    INNER JOIN sys.tables t ON ind.object_id = t.object_id  
			    WHERE ind.name=@iname and t.name=@ctable
			    ORDER BY ic.key_ordinal
    			
			    open index_list;
			    while 1=1
			    BEGIN
				    FETCH NEXT FROM index_list INTO @icolumn,@itype,@PK,@unique,@is_included,@fill_factor
				    if @@FETCH_STATUS <> 0
				    BEGIN
					    if not exists(select 1 from indexlist where indexname=@old and tablename=@ctable and is_pk is not null)
					    begin
						   SET @isql=@isql + ') WITH (FILLFACTOR = ' + @fill_factor + ')'
						   SELECT @mult=1-((SUM(max_length)-450.0)/450.0) --Shrink column length to keep key size under 900
						   FROM sys.indexes ind 
						   INNER JOIN sys.index_columns ic ON ind.object_id = ic.object_id and ind.index_id = ic.index_id  
						   INNER JOIN sys.columns col ON ic.object_id = col.object_id and ic.column_id = col.column_id  
						   INNER JOIN sys.tables t ON ind.object_id = t.object_id  
						   WHERE ind.type in (1, 2) and is_disabled=0 and is_included_column=0 and ind.name=@old
						   group BY ind.name
						   if (@mult>1)
	   						   insert into indexlist (tablename,indexname,sql,is_pk) values(@ctable,@old,@isql,@oldPK)
	   					   else
	   					   begin
	   						   if(@mult<.10) SET @mult=.10
	   						   insert into indexlist (tablename,indexname,sql,is_pk,mult) values(@ctable,@old,@isql,@oldPK,@mult)
	   					   end
	   					   
	   					   if @oldPK=1
							 BEGIN TRY
								 exec('ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + ']');
								 print 'ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + ']'
							 END TRY
							 BEGIN CATCH
								 print 'ERROR: ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + '] failed: ' + error_message()
							 END CATCH
							 else
							 BEGIN TRY
								 exec('DROP INDEX [' + @ctable + '].[' + @old + ']');
								 print 'DROP INDEX [' + @ctable + '].[' + @old + ']'
							 END TRY
							 BEGIN CATCH
								 BEGIN TRY
									SET @error=error_message()
									exec('ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + ']');
									print 'ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + ']'
								 END TRY
								 BEGIN CATCH
	   								print 'ERROR: DROP INDEX [' + @ctable + '].[' + @old + ']' + ' failed: ' + @error
	   								delete from indexlist where sql=@isql
								 END CATCH
							 END CATCH
	   				    end
					    set @mult = null;
					    break;
				    END
				    if @old is not null and @old<>@iname
				    BEGIN
					    if not exists(select 1 from indexlist where indexname=@old and tablename=@ctable and is_pk is not null)
					    begin
						   SET @isql=@isql + ') WITH (FILLFACTOR = ' + @fill_factor + ')'
						   SELECT @mult=1-((SUM(max_length)-450.0)/450.0) --Shrink column length to keep key size under 900
						   FROM sys.indexes ind 
						   INNER JOIN sys.index_columns ic ON ind.object_id = ic.object_id and ind.index_id = ic.index_id  
						   INNER JOIN sys.columns col ON ic.object_id = col.object_id and ic.column_id = col.column_id  
						   INNER JOIN sys.tables t ON ind.object_id = t.object_id  
						   WHERE ind.type in (1, 2) and is_disabled=0 and is_included_column=0 and ind.name=@old
						   group BY ind.name
    					    
						   if (@mult>1)
	   						   insert into indexlist (tablename,indexname,sql,is_pk) values(@ctable,@old,@isql,@oldPK)
	   					   else
	   					   begin
	   						   if(@mult<.10) SET @mult=.10
	   						   insert into indexlist (tablename,indexname,sql,is_pk,mult) values(@ctable,@old,@isql,@oldPK,@mult)
	   					   end

	   					   if @oldPK=1
							 BEGIN TRY
								 exec('ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + ']');
								 print 'ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + ']'
							 END TRY
							 BEGIN CATCH
								 print 'ERROR: ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + '] failed: ' + error_message()
							 END CATCH
							 else
							 BEGIN TRY
								 exec('DROP INDEX [' + @ctable + '].[' + @old + ']');
								 print 'DROP INDEX [' + @ctable + '].[' + @old + ']'
							 END TRY
							 BEGIN CATCH
								 BEGIN TRY
									SET @error=error_message()
									exec('ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + ']');
									print 'ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @old + ']'
								 END TRY
								 BEGIN CATCH
	   								print 'ERROR: DROP INDEX [' + @ctable + '].[' + @old + ']' + ' failed: ' + @error
	   								delete from indexlist where sql=@isql
								 END CATCH
							 END CATCH
	   				    end
					    set @mult = null;

					    if @PK=1
					    begin
						    SET @isql='ALTER TABLE [' + @ctable + '] ADD CONSTRAINT [' + @iname + '] PRIMARY KEY '
						    if @itype=1
							    SET @isql=@isql + ' CLUSTERED '
						    SET @isql=@isql + '('
					    end
					    else
					    BEGIN
						    SET @isql='CREATE '
						    if @unique=1
							    SET @isql=@isql + ' UNIQUE '
						    SET @isql=@isql + 'INDEX [' + @iname + '] ON [' + @ctable + '] ('
					    END
					    SET @oldPK=@PK
					    SET @old=@iname
				    END
				    ELSE IF @old is null
				    BEGIN
					    SET @old=@iname
					    SET @oldPK=@PK
    					
					    if @PK=1
					    begin
						    SET @isql='ALTER TABLE [' + @ctable + '] ADD CONSTRAINT [' + @iname + '] PRIMARY KEY '
						    if @itype=1
							    SET @isql=@isql + ' CLUSTERED '
						    SET @isql=@isql + '('
					    end
					    else
					    BEGIN
						    SET @isql='CREATE '
						    if @unique=1
							    SET @isql=@isql + ' UNIQUE '
						    SET @isql=@isql + 'INDEX [' + @iname + '] ON [' + @ctable + '] ('
					    END
				    END
				    ELSE IF @is_included=1 AND CHARINDEX(') INCLUDE (',@isql)=0
					    SET @isql=@isql + ') INCLUDE (';
				    ELSE
					    SET @isql=@isql + ','
    				
				    SET @isql=@isql + '[' + @icolumn + ']'
			    END
			    close index_list
			    deallocate index_list
			END
		     close char_index
		     deallocate char_index
		END
		-- Find statistics
		  declare stat_list CURSOR FAST_FORWARD for
		  select name, user_created, stats_id from sys.stats where object_id=OBJECT_ID(@ctable)
		  declare @user_created bit,@stats_id int;
		  open stat_list;
		  while 1=1
		  BEGIN
			  FETCH NEXT FROM stat_list INTO @iname,@user_created,@stats_id
			  if @@FETCH_STATUS <> 0
				break;
			  if @user_created=0
				continue;
			declare @columns nvarchar(max);
			set @columns='';
			declare scolumns cursor fast_forward for
			select col.name from sys.stats_columns sc
			INNER JOIN sys.columns col ON sc.object_id = col.object_id and sc.column_id = col.column_id  
			where sc.object_id=OBJECT_ID(@ctable) and stats_id=@stats_id order by stats_column_id

			open scolumns;
			while 1=1
			BEGIN
			    FETCH NEXT FROM scolumns INTO @icolumn
			    if @@FETCH_STATUS <> 0
				   break;
			    set @columns = @columns + @icolumn + ','
			END
			close scolumns
			deallocate scolumns
			insert into indexlist (tablename,indexname,sql) values(@ctable,@iname,'CREATE STATISTICS [' + @iname + '] ON [' + @ctable + '] (' + left(@columns,len(@columns)-1) + ')')
		    
			print 'DROP STATISTICS [' + @ctable + '].[' + @iname + ']' 
			exec('DROP STATISTICS [' + @ctable + '].[' + @iname + ']');
		  END
		  close stat_list
		  deallocate stat_list
		-- Calculate new char lengths for key columns that index key is over 900 not including include columns
		if exists(select 1 from indexlist where tablename=@ctable AND CHARINDEX(@ccolumn,sql,1)>0 and mult is not null and (CHARINDEX('INCLUDE (',sql,1)=0 or CHARINDEX(@ccolumn,sql,1)<CHARINDEX('INCLUDE (',sql,1)))
		begin
		  select top 1 @mult=ABS(mult) from indexlist where tablename=@ctable AND CHARINDEX(@ccolumn,sql)>0 and mult is not null;
		  SELECT @csql=REPLACE(@csql,cast(max_length as nvarchar(5)),cast(round(max_length*@mult,0) as varchar(5))) FROM sys.columns where object_id=object_id(@ctable) and name=@ccolumn and max_length>50
		end
		-- Drop default constraints.
		if @default is not null
		BEGIN
			print 'ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @default + ']'
			exec('ALTER TABLE [' + @ctable + '] DROP CONSTRAINT [' + @default + ']')
		END
		-- Convert the columns to unicode and add back the default constraints.
		begin try
		    exec(@csql)
		    print @csql
		end try
		begin catch
	   		print 'ERROR: ' + @csql + ' failed: ' + error_message()
		end catch
	END 
	
	-- Re-create the indexes, keys, and constraints
	declare @rsql nvarchar(max)

	declare icur CURSOR FAST_FORWARD for
	select sql from indexlist order by is_pk desc,tablename asc

	OPEN icur

	WHILE 1=1
	BEGIN
		FETCH NEXT FROM icur INTO @rsql
		if @@FETCH_STATUS <> 0
			break;
		begin try
		    exec(@rsql)
		    print @rsql
		    delete from indexlist where sql=@rsql
		end try
		begin catch
		    print 'ERROR: ' + @rsql + ' failed: ' + error_message()
		end catch
	END
	close icur
	deallocate icur
	
	if not exists(select 1 from indexlist)
	   drop table indexlist
	close column_list
	deallocate column_list
	
	-- Convert to Text columns to NText
	declare @ttable nvarchar(max),@tcolumn nvarchar(max);

	declare text_list CURSOR FAST_FORWARD for
	select COL.table_name,col.COLUMN_NAME
	from INFORMATION_SCHEMA.columns COL
	inner join INFORMATION_SCHEMA.TABLES t on t.TABLE_NAME=COL.TABLE_NAME
	left join sys.default_constraints on parent_object_id = OBJECT_ID(COL.table_name) and COL_NAME(parent_object_id, parent_column_id) = column_name
	where data_type in ('text') and TABLE_TYPE like '%table%'
	order by COL.table_name,ORDINAL_POSITION

	open text_list

	while 1=1
	begin
		FETCH NEXT FROM text_list INTO @ttable,@tcolumn
		if @@FETCH_STATUS <> 0
			break;
		
		SET @old=@tcolumn + '_old'
		SET @oldtable=@ttable + '.' + @tcolumn

		print 'sp_rename ' + @oldtable + ',' + @old + ', ''COLUMN''';
		EXEC sp_rename @oldtable, @old, 'COLUMN';
		
		print 'ALTER TABLE ' + @ttable + ' ADD ' + @tcolumn + ' NTEXT NULL'
		EXEC('ALTER TABLE ' + @ttable + ' ADD ' + @tcolumn + ' NTEXT NULL')
		
		print 'UPDATE ' + @ttable + ' SET ' + @tcolumn + ' = ' + @old
		EXEC('UPDATE ' + @ttable + ' SET ' + @tcolumn + ' = ' + @old)

		print 'ALTER TABLE ' + @ttable + ' DROP COLUMN ' + @old
		exec('ALTER TABLE ' + @ttable + ' DROP COLUMN ' + @old)
	end
	close text_list
	deallocate text_list
	
	PRINT 'PLEASE UPDATE THE STORED PROCEDURES, FUNCTIONS, AND TRIGGERS MANUALLY!!!'
END
GO
PRINT 'dbo.sp_defrag_indexes';
GO

IF OBJECT_ID('dbo.sp_defrag_indexes') IS NOT NULL
	DROP PROCEDURE dbo.sp_defrag_indexes;
GO
	
CREATE PROCEDURE dbo.sp_defrag_indexes (@minfrag int = 10,
					  					@minindexpages int = 1)
AS
BEGIN
-------------------------------------------------------------------------------------------------------------------
--                                                                                                               --
-- Procedure         : sp_defrag_indexes (@minfrag int, @minindexpage int)										 --
-- Parameters		 : minfrag - The minum about a fragmentation allowed in the database.  Tables with less than
--                               the amont specified will not be reorganized.
--                   : minindexpages - The minum number of pages in the indexes for a reorganized to be performed --
-- Description       : Reorganizes the tables that are fragmented with the respective minimume fragmentation 
-- Version           : 19.0                                                                                       --
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-- ST  01/30/07  Initially created
-- PGH 11/07/09  Rewriten for 2005 / 2008
-- BCW 12/02/11  Added fill factor to rebuild
-------------------------------------------------------------------------------------------------------------------
-- Declare variables

	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER ON

	DECLARE @ls_version		 nvarchar(128),
			@li_version			integer,
			@li_pos				integer,
			@table_nm		 nvarchar (128),
			@index_nm		 nvarchar(128),
			@objectid			INT,
			@indexid			INT,
			@part_nbr			int,
			@index_typ		 nvarchar(60),
			@index_depth		int,
			@page_cnt			int,
			@frag				DECIMAL,
			@dbname				sysname,
			@ls_sqlcmd			nvarchar(128)

	--check to verify the version, this procedure is using the DMV views introduced in 2005
	--check this is being run in a user database
	SET @ls_version = CONVERT(varchar(128), SERVERPROPERTY ('ProductVersion'))
	SET @li_pos = CHARINDEX('.', @ls_version) - 1
	SET @li_version = CONVERT(int, SUBSTRING(@ls_version, 1, @li_pos))
	IF @li_version < 9
	BEGIN
		PRINT 'Wrong Version, this procedure requires SQL SERVER 2005 or greater'
		RETURN
	END

	SELECT @dbname = db_name()
	IF @dbname IN ('master', 'msdb', 'model', 'tempdb')
	BEGIN
		PRINT 'This procedure should not be run in system databases.'
		RETURN
	END

	--begin Stage 1: Find the indexes with fragmentation
	-- Declare cursor 
	DECLARE FindIDXFrag CURSOR FOR
	SELECT object_name(i.object_id) as 'Table Name', 
			i.name as 'Index Name',
			i.object_id,
			i.index_id,
			partition_number,
			index_type_desc,
			index_depth,
			avg_fragmentation_in_percent,
			page_count
		FROM sys.dm_db_index_physical_stats(db_id(), NULL, NULL, NULL , NULL) ips
		JOIN sys.indexes i on i.object_id = ips.object_id and i.index_id = ips.index_id
		where index_type_desc in ('CLUSTERED INDEX', 'NONCLUSTERED INDEX')
		  --and avg_fragmentation_in_percent > @minfrag
		  and page_count > @minindexpages

	---- Report the ouput of showcontig for results checking
	-- SELECT * FROM #fraglist order by 1

	-- Write to output start time for information purposes
	PRINT 'Started defragmenting indexes at ' + CONVERT(VARCHAR,GETDATE())
	PRINT 'REORGANIZING:'

	-- Open the cursor
	OPEN FindIDXFrag

	-- Loop through the indexes
	FETCH NEXT
	FROM FindIDXFrag
	INTO @table_nm,
		@index_nm,
		@objectid,
		@indexid,
		@part_nbr,
		@index_typ,
		@index_depth,
		@frag,
		@page_cnt

	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @frag > @minfrag
		BEGIN 
			IF @frag > 50
				BEGIN
					PRINT 'Index ' + @index_nm + ' on ' + @table_nm + ' Rebuilt';
--					SET @ls_sqlcmd = 'ALTER INDEX [' + @index_nm + '] on [' + @table_nm + '] REBUILD WITH ONLINE=ON';  -- Online only works with Enterprise Edition
					SET @ls_sqlcmd = 'ALTER INDEX [' + @index_nm + '] on [' + @table_nm + '] REBUILD WITH (FILLFACTOR = 80)';
					print @ls_sqlcmd;
					exec (@ls_sqlcmd);
				END;
			ELSE
				BEGIN
					PRINT 'Index ' + @index_nm + ' on ' + @table_nm + ' Reorganized';
					SET @ls_sqlcmd = 'ALTER INDEX [' + @index_nm + '] on [' + @table_nm + '] REORGANIZE';
					--print @ls_sqlcmd;
					exec (@ls_sqlcmd);
					SET @ls_sqlcmd = 'UPDATE STATISTICS [' + @table_nm + '] [' + @index_nm + ']';
					--print @ls_sqlcmd;
					exec (@ls_sqlcmd);
				END;
		END;
		ELSE
			BEGIN
				PRINT 'Index ' + @index_nm + ' on ' + @table_nm + ' Statistics Updated';
				SET @ls_sqlcmd = 'UPDATE STATISTICS [' + @table_nm + '] [' + @index_nm + ']';
				--print @ls_sqlcmd;
				exec (@ls_sqlcmd);
			END;
		
		FETCH NEXT
		FROM FindIDXFrag
			INTO  @table_nm,
				@index_nm,
				@objectid,
				@indexid,
				@part_nbr,
				@index_typ,
				@index_depth,
				@frag,
				@page_cnt;
		
	END;

	-- Close and deallocate the cursor
	CLOSE FindIDXFrag;
	DEALLOCATE FindIDXFrag;

	-- move back to full mode 
	-- alter database xstore set recovery full

	-- Report on finish time for information purposes
	PRINT 'Finished defragmenting indexes at ' + CONVERT(VARCHAR,GETDATE());
END
GO
/* 
 * PROCEDURE: [dbo].[sp_fifo_detail] 
 */

PRINT 'dbo.sp_fifo_detail';

IF EXISTS (Select * From sysobjects Where name = 'sp_fifo_detail' and type = 'P')
  DROP PROCEDURE sp_fifo_detail;
GO

CREATE PROCEDURE [dbo].[sp_fifo_detail] 
    @merch_level_1_param nvarchar(60), 
    @merch_level_2_param nvarchar(60), 
    @merch_level_3_param nvarchar(60), 
    @merch_level_4_param nvarchar(60),
    @item_id_param          nvarchar(60),
    @style_id_param         nvarchar(60),
    @rtl_loc_id_param	 nvarchar(MAX), 
    @organization_id_param	int,
    @user_name_param	 nvarchar(30),
    @stock_val_date_param   DATETIME
 
 AS
BEGIN

  --TRUNCATE TABLE rpt_fifo_detail;
  DELETE FROM rpt_fifo_detail WHERE user_name = @user_name_param

  DECLARE 
            @organization_id		 int,
            @organization_id_a		 int,
            @item_id				 nvarchar(60),
            @item_id_a				 nvarchar(60),
            @description			 nvarchar(254),
            @description_a			 nvarchar(254),
            @style_id				 nvarchar(60),
            @style_id_a				 nvarchar(60),
            @style_desc			     nvarchar(254),
            @style_desc_a			 nvarchar(254),
            @rtl_loc_id				 int,
            @rtl_loc_id_a			 int,
            @store_name				 nvarchar(254),
            @store_name_a			 nvarchar(254),
            @invctl_document_id		 nvarchar(30),
            @invctl_document_id_a	 nvarchar(30),
            @invctl_document_nbr	 int,
            @invctl_document_nbr_a	 int,
            @create_date_timestamp	 DATETIME,
            @create_date_timestamp_a DATETIME,
            @unit_count				 DECIMAL(14,4),
            @unit_count_a			 DECIMAL(14,4),
            @current_unit_count		 DECIMAL(14,4),
            @unit_cost				 DECIMAL(17,6),
            @unit_cost_a			 DECIMAL(17,6),
            @unitCount				 DECIMAL(14,4),
            @unitCount_a			 DECIMAL(14,4),

            @comment				 nvarchar(254),

            @current_item_id		 nvarchar(60),
            @pending_unitCount		 DEC(14,4),
            
            @insert					 smallint;
  
  DECLARE tableCur CURSOR READ_ONLY FOR 
      SELECT MAX(sla.organization_id), MAX(COALESCE(sla.unitcount,0)) + MAX(COALESCE(ts.quantity, 0)) AS quantity, 
                  sla.item_id, MAX(i.description), MAX(style.item_id), MAX(style.description), 
		          l.rtl_loc_id, MAX(l.store_name), doc.invctl_document_id, doc.invctl_document_line_nbr,
                  doc.create_date, MAX(COALESCE(doc.unit_count,0)), MAX(COALESCE(doc.unit_cost,0))
      FROM loc_rtl_loc l, fn_integerListToTable(@rtl_loc_id_param) fn, 
			(SELECT organization_id, item_id, COALESCE(SUM(unitcount),0) AS unitcount 
				FROM inv_stock_ledger_acct, fn_integerListToTable(@rtl_loc_id_param) fn
				WHERE fn.number = rtl_loc_id 
                    AND bucket_id = 'ON_HAND'
				GROUP BY organization_id, item_id) sla
		    LEFT OUTER JOIN
            (SELECT itm_mov.organization_id, itm_mov.rtl_loc_id, itm_mov.item_id, 
	                SUM(COALESCE(quantity,0) * CASE WHEN adjustment_flag = 1 THEN 1 ELSE -1 END) AS quantity
	         FROM rpt_trl_stock_movement_view itm_mov
	         WHERE CONVERT(char(10),business_date,120) > CONVERT(char(10),@stock_val_date_param,120)
	         GROUP BY itm_mov.organization_id, itm_mov.rtl_loc_id, itm_mov.item_id) ts
	         ON sla.organization_id = ts.organization_id
	            AND sla.item_id = ts.item_id
            LEFT OUTER JOIN (
                  SELECT id.organization_id, idl.inventory_item_id, idl.rtl_loc_id , id.invctl_document_id, 
                        idl.invctl_document_line_nbr, idl.create_date, COALESCE(idl.unit_count,0) AS unit_count, COALESCE(idl.unit_cost,0) AS unit_cost
                  FROM inv_invctl_document_lineitm idl, fn_integerListToTable(@rtl_loc_id_param) fn, inv_invctl_document id
                  WHERE idl.organization_id = id.organization_id AND idl.rtl_loc_id = id.rtl_loc_id AND 
                        idl.document_typcode = id.document_typcode AND idl.invctl_document_id = id.invctl_document_id AND 
                        idl.unit_count IS NOT NULL AND idl.unit_cost IS NOT NULL AND idl.create_date IS NOT NULL AND
                        id.document_subtypcode = 'ASN'
                        AND id.status_code IN ('CLOSED', 'OPEN', 'IN_PROCESS')
                        AND CAST(FLOOR(CAST(idl.create_date AS FLOAT)) AS DATETIME) <= @stock_val_date_param
                        AND fn.number = idl.rtl_loc_id 
                        AND @organization_id_param = idl.organization_id
            ) doc
            on sla.organization_id = doc.organization_id AND 
               sla.item_id = doc.inventory_item_id
            INNER JOIN itm_item i
            ON sla.item_id = i.item_id AND
               sla.organization_id = i.organization_id
            LEFT OUTER JOIN itm_item style
            ON i.parent_item_id = style.item_id AND
               i.organization_id = style.organization_id
      WHERE @merch_level_1_param in (i.merch_level_1,'%') AND @merch_level_2_param in (i.merch_level_2,'%') AND 
            @merch_level_3_param IN (i.merch_level_3,'%') AND @merch_level_4_param IN (i.merch_level_4,'%') AND
            @item_id_param IN (i.item_id,'%') AND @style_id_param IN (i.parent_item_id,'%') AND
            sla.organization_id = l.organization_id AND 
            fn.number = l.rtl_loc_id AND 
            doc.rtl_loc_id = l.rtl_loc_id AND 
            COALESCE(sla.unitcount,0) + COALESCE(ts.quantity, 0) <> 0
      GROUP BY style.item_id, sla.item_id, doc.invctl_document_id, l.rtl_loc_id, doc.invctl_document_line_nbr, doc.create_date
      ORDER BY sla.item_id,doc.create_date DESC;
      
  BEGIN
    SET @comment = '';
    SET @current_item_id = '';
    SET @pending_unitCount = 0;
    SET @insert = 0;
    OPEN tableCur;
    FETCH tableCur INTO @organization_id, @unitcount, @item_id, @description, @style_id, @style_desc, @rtl_loc_id, @store_name, @invctl_document_id, @invctl_document_nbr,@create_date_timestamp, @unit_count, @unit_cost;
    WHILE @@FETCH_STATUS = 0 
    BEGIN
      IF @current_item_id <> @item_id
      BEGIN
        SET @current_item_id = @item_id;
        SET @pending_unitCount = @unitcount;
      END
		IF @pending_unitCount > 0
		BEGIN
		  IF @pending_unitCount < @unit_count
		  BEGIN
			SET @current_unit_count = @pending_unitCount;
			SET @pending_unitCount = 0;
		  END 
		  ELSE
		  BEGIN
			SET @current_unit_count = @unit_count ;
			SET @pending_unitCount = @pending_unitCount - @unit_count;
		  END
		  SET @insert = 1;
		END
		ELSE IF @pending_unitCount < 0
		   SET @insert = 1;
		ELSE
		   SET @insert = 0;
	      
		SET @organization_id_a = @organization_id
		SET @unitcount_a = @unitcount;
		SET @item_id_a = @item_id;
		SET @description_a = @description;
		SET @style_id_a = @style_id;
		SET @style_desc_a = @style_desc;
		SET @rtl_loc_id_a = @rtl_loc_id;
		SET @store_name_a = @store_name;
		SET @invctl_document_id_a = @invctl_document_id;
		SET @invctl_document_nbr_a = @invctl_document_nbr;
		SET @create_date_timestamp_a = @create_date_timestamp;
		SET @unit_count_a = @unit_count;
		SET @unit_cost_a = @unit_cost;
	  
		FETCH tableCur INTO @organization_id, @unitcount, @item_id, @description, @style_id, @style_desc, @rtl_loc_id, @store_name, @invctl_document_id, @invctl_document_nbr, @create_date_timestamp, @unit_count, @unit_cost;
		IF (@pending_unitCount >= 0 OR @@FETCH_STATUS < 0  OR @item_id <> @item_id_a) AND @insert = 1
		BEGIN
		  SET @comment = '';
		  IF ((@item_id_a <> @item_id AND @pending_unitCount > 0) OR @@FETCH_STATUS < 0)
		  BEGIN
			 IF @pending_unitCount > 0
			 BEGIN
			   SET @comment = '_rptLackDocStockVal';
			 END
		  END
		  IF @pending_unitCount < 0
			 BEGIN
			   SET @invctl_document_id_a = '_rptNoAvailDocStockVal';
			   SET @unit_cost_a = null;
			   SET @unit_count_a = null;
			   SET @current_unit_count = null;
			   SET @create_date_timestamp_a = null;
			   SET @comment = '_rptLackDocStockVal';
			 END
		  INSERT INTO rpt_fifo_detail (organization_id, rtl_loc_id, item_id, invctl_doc_id, user_name, invctl_doc_create_date, description, store_name, 
				 unit_count, current_unit_count, unit_cost, unit_count_a, current_cost, comment, pending_count, style_id, style_desc, invctl_doc_line_nbr)
		  VALUES(@organization_id_a, @rtl_loc_id_a, @item_id_a, @invctl_document_id_a, @user_name_param, @create_date_timestamp_a, @description_a, @store_name_a,
				 @unit_count_a, @current_unit_count, @unit_cost_a, @unitcount_a, @current_unit_count * @unit_cost_a, @comment, @pending_unitCount, @style_id_a, @style_desc_a, @invctl_document_nbr_a);
		END
    END
    CLOSE tableCur;
    DEALLOCATE tableCur;
  END
END
GO
/* 
 * PROCEDURE: [dbo].[sp_fifo_summary] 
 */

PRINT 'dbo.sp_fifo_summary';

IF EXISTS (Select * From sysobjects Where name = 'sp_fifo_summary' and type = 'P')
  DROP PROCEDURE sp_fifo_summary;
GO

CREATE PROCEDURE [dbo].[sp_fifo_summary] 
    @merch_level_1_param nvarchar(60), 
    @merch_level_2_param nvarchar(60), 
    @merch_level_3_param nvarchar(60), 
    @merch_level_4_param nvarchar(60),
    @item_id_param          nvarchar(60),
    @style_id_param         nvarchar(60),
    @rtl_loc_id_param	 nvarchar(MAX), 
    @organization_id_param	int,
    @user_name_param        nvarchar(30),
    @stock_val_date_param   DATETIME
 
AS
BEGIN
  --TRUNCATE TABLE rpt_fifo;
  DELETE FROM rpt_fifo WHERE user_name = @user_name_param
  EXEC sp_fifo_detail @merch_level_1_param, @merch_level_2_param, @merch_level_3_param, @merch_level_4_param, @item_id_param, @style_id_param, @rtl_loc_id_param, @organization_id_param, @user_name_param, @stock_val_date_param
  
  DECLARE 
      @organization_id		 int,
      @unit_count			 DECIMAL(14,4),
      @item_id				 nvarchar(60),
      @description			 nvarchar(254),
      @style_id				 nvarchar(60),
      @style_desc			 nvarchar(254),
      @rtl_loc_id			 int,
      @store_name			 nvarchar(254),
      @unit_cost			 DECIMAL(17,6),
      @comment				 nvarchar(254)
  
  DECLARE tableCur CURSOR READ_ONLY FOR 
  
	  SELECT MAX(sla.organization_id), MAX(COALESCE(sla.unitcount,0)) + MAX(COALESCE(ts.quantity, 0)) AS quantity, 
	      sla.item_id, MAX(i.description), style.item_id, MAX(style.description), sla.rtl_loc_id, 
	      MAX(l.store_name), MAX(COALESCE(fifo_detail.unit_cost,0)), MAX(fifo_detail.comment)
	  FROM loc_rtl_loc l, fn_integerListToTable(@rtl_loc_id_param) fn, inv_stock_ledger_acct sla
	  	  
	  LEFT OUTER JOIN
	  (SELECT itm_mov.organization_id, itm_mov.rtl_loc_id, itm_mov.item_id, 
			SUM(COALESCE(quantity,0) * CASE WHEN adjustment_flag = 1 THEN 1 ELSE -1 END) AS quantity
	   FROM rpt_trl_stock_movement_view itm_mov
	   WHERE CONVERT(char(10),business_date,120) > CONVERT(CHAR(10),@stock_val_date_param,120) 
	   GROUP BY itm_mov.organization_id, itm_mov.rtl_loc_id, itm_mov.item_id) ts
	   ON sla.organization_id = ts.organization_id
     		AND sla.rtl_loc_id = ts.rtl_loc_id
			AND sla.item_id = ts.item_id
	  LEFT OUTER JOIN (
			SELECT organization_id, item_id, SUM(current_cost)/SUM(current_unit_count) as unit_cost, MAX(comment) as comment
			FROM rpt_fifo_detail
			GROUP BY organization_id, item_id ) fifo_detail
	  ON sla.organization_id = fifo_detail.organization_id AND 
		   sla.item_id = fifo_detail.item_id
	  INNER JOIN itm_item i
		ON sla.item_id = i.item_id AND
		   sla.organization_id = i.organization_id
		LEFT OUTER JOIN itm_item style
		ON i.parent_item_id = style.item_id AND 
		   i.organization_id = style.organization_id
	  WHERE @merch_level_1_param in (i.merch_level_1,'%') AND @merch_level_2_param in (i.merch_level_2,'%') AND 
            @merch_level_3_param IN (i.merch_level_3,'%') AND @merch_level_4_param IN (i.merch_level_4,'%') AND
            @item_id_param IN (i.item_id,'%') AND @style_id_param IN (i.parent_item_id,'%') AND
		    fn.number = sla.rtl_loc_id AND
		    sla.organization_id = l.organization_id AND 
		    sla.rtl_loc_id = l.rtl_loc_id AND
              sla.bucket_id = 'ON_HAND' AND
		    COALESCE(sla.unitcount,0) + COALESCE(ts.quantity, 0) <> 0
	  GROUP BY sla.rtl_loc_id, style.item_id, sla.item_id
	  ORDER BY sla.rtl_loc_id, sla.item_id DESC;

  BEGIN
    OPEN tableCur;
    FETCH tableCur INTO @organization_id, @unit_count, @item_id, @description, @style_id, @style_desc, @rtl_loc_id, @store_name, @unit_cost, @comment;
    WHILE @@FETCH_STATUS = 0 
    BEGIN
       IF @unit_cost = 0
         SET @unit_count = 0
       INSERT INTO rpt_fifo (organization_id, rtl_loc_id, store_name, item_id, user_name, description,  
		   style_id, style_desc, unit_count, unit_cost, comment)
	   VALUES(@organization_id, @rtl_loc_id, @store_name, @item_id, @user_name_param, @description, 
	       @style_id, @style_desc, @unit_count, @unit_cost, @comment); 
	   FETCH tableCur INTO @organization_id, @unit_count, @item_id, @description, @style_id, @style_desc, @rtl_loc_id, @store_name, @unit_cost, @comment;
    END
    CLOSE tableCur;
    DEALLOCATE tableCur;
  END
END
GO
/* 
 * PROCEDURE: [dbo].[sp_ins_upd_flash_sales] 
 */

IF EXISTS (Select * From sysobjects Where name = 'sp_ins_upd_flash_sales' and type = 'P')
  DROP PROCEDURE sp_ins_upd_flash_sales;
GO

CREATE PROCEDURE dbo.sp_ins_upd_flash_sales (
    @argOrgId int,
    @argRtlLocId int,
    @argBusinessDate datetime,
    @argWkstnId bigint,
    @pLineEnum nvarchar(254),
    @argQty decimal(11, 2),
    @argNetAmt decimal(17, 6),
    @vCurrencyId nvarchar(3) = 'USD')
AS
if CONTEXT_INFO()=0x0111001101110000010111110110011001101100011000010111001101101000
begin
  UPDATE rpt_flash_sales
    SET line_count = line_count + @argQty,
        line_amt = line_amt + @argNetAmt,
        update_date = getutcdate(),
        update_user_id = user
    WHERE organization_id = @argOrgId
      AND rtl_loc_id = @argRtlLocId
      AND wkstn_id = @argWkstnId
      AND business_date = @argBusinessDate
      AND line_enum = @pLineEnum;
    
  IF @@ROWCOUNT = 0  
    INSERT INTO rpt_flash_sales 
        (organization_id, rtl_loc_id, wkstn_id, line_enum, line_count, line_amt, foreign_amt, 
        business_date, currency_id, create_date, create_user_id)
      VALUES 
        (@argOrgId, @argRtlLocId, @argWkstnId, @pLineEnum, @argQty, @argNetAmt, 0, @argBusinessDate, 
        @vCurrencyId, getutcdate(), user);
end
else
	raiserror('Cannot be run directly.',10,1)
GO
/* 
 * PROCEDURE: [dbo].[sp_ins_upd_hourly_sales] 
 */

IF EXISTS (Select * From sysobjects Where name = 'sp_ins_upd_hourly_sales' and type = 'P')
  DROP PROCEDURE sp_ins_upd_hourly_sales;
GO

CREATE PROCEDURE dbo.sp_ins_upd_hourly_sales (
    @argOrgId int,
    @argRtlLocId int,
    @argBusinessDate datetime,
    @argWkstnId bigint,
    @argHour datetime,
    @argQty decimal(11, 2),
    @argNetAmt decimal(17, 6),
    @argGrossAmt decimal(17, 6),
    @argTransCount int,
    @argCurrencyId nvarchar(3) = 'USD')
AS
if CONTEXT_INFO()=0x0111001101110000010111110110011001101100011000010111001101101000
begin
  UPDATE rpt_sales_by_hour
    SET qty = coalesce(qty, 0) + coalesce(@argQty,0),
        trans_count = coalesce(trans_count, 0) + coalesce(@argTransCount,0),
        net_sales = coalesce(net_sales, 0) + coalesce(@argNetAmt,0),
        gross_sales = coalesce(gross_sales, 0) + coalesce(@argGrossAmt,0),
        update_date = getutcdate(),
        update_user_id = user
    WHERE organization_id = @argOrgId
      AND rtl_loc_id = @argRtlLocId
      AND wkstn_id = @argWkstnId
      AND business_date = @argBusinessDate
      AND hour = datepart(hh, @argHour);
                
IF @@ROWCOUNT = 0  
  INSERT INTO rpt_sales_by_hour (organization_id, rtl_loc_id, wkstn_id, hour, qty, trans_count,
      net_sales, business_date, gross_sales, currency_id, create_date, create_user_id)
    VALUES 
      (@argOrgId, @argRtlLocId, @argWkstnId, datepart(hh, @argHour), @argQty, @argTransCount, 
      @argNetAmt ,@argBusinessDate, @argGrossAmt, @argCurrencyId, getutcdate(), user);
end
else
	raiserror('Cannot be run directly.',10,1)
GO
/* 
 * PROCEDURE: [dbo].[sp_ins_upd_merchlvl1_sales] 
 */

IF EXISTS (Select * From sysobjects Where name = 'sp_ins_upd_merchlvl1_sales' and type = 'P')
  DROP PROCEDURE sp_ins_upd_merchlvl1_sales;
GO

CREATE PROCEDURE dbo.sp_ins_upd_merchlvl1_sales (
    @argOrgId int,
    @argRtlLocId int,
    @argBusinessDate datetime,
    @argWkstnId bigint,
    @pDeptId nvarchar(254),
    @argQty decimal(11, 2),
    @argNetAmt decimal(17, 6),
    @argGrossAmt decimal(17, 6),
    @argCurrencyId nvarchar(3) = 'USD')
AS
if CONTEXT_INFO()=0x0111001101110000010111110110011001101100011000010111001101101000
begin
  UPDATE rpt_merchlvl1_sales
    SET line_count = line_count + @argQty,
        line_amt = line_amt + @argNetAmt,
        gross_amt = gross_amt + @argGrossAmt,
        update_date = getutcdate(),
        update_user_id = user
    WHERE organization_id = @argOrgId
      AND rtl_loc_id = @argRtlLocId
      AND wkstn_id = @argWkstnId
      AND business_date = @argBusinessDate
      AND merch_level_1 = @pDeptId;
        
  IF @@ROWCOUNT = 0  
    INSERT INTO rpt_merchlvl1_sales (organization_id, rtl_loc_id, wkstn_id, merch_level_1, line_count, 
        line_amt, business_date, gross_amt, currency_id, create_date, create_user_id)
    VALUES 
        (@argOrgId, @argRtlLocId, @argWkstnId, @pDeptId, @argQty, 
        @argNetAmt ,@argBusinessDate, @argGrossAmt, @argCurrencyId, getutcdate(), user);
end
else
	raiserror('Cannot be run directly.',10,1)
GO
IF EXISTS (Select * From sysobjects Where name = 'sp_next_sequence_value' and type = 'P')
  DROP PROCEDURE sp_next_sequence_value;
GO

CREATE PROCEDURE dbo.sp_next_sequence_value(
  @argOrganizationId      int,
  @argRetailLocationId    int,
  @argWorkstationId       int,
  @argSequenceId          nvarchar(255),
  @argSequenceMode        nvarchar(60),
  @argIncrement           bit,
  @argIncrementalValue    int,
  @argMaximumValue        int,
  @argInitialValue        int,
  @argSequenceValue       int OUTPUT)
AS
BEGIN 
  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
  BEGIN TRANSACTION
    DECLARE @vCurrentSequence int;
    SELECT @vCurrentSequence = t.sequence_nbr
        FROM com_sequence t WITH(TABLOCKX HOLDLOCK)
        WHERE t.organization_id = @argOrganizationId
        AND t.rtl_loc_id = @argRetailLocationId
        AND t.wkstn_id = @argWorkstationId
        AND t.sequence_id = @argSequenceId
        AND t.sequence_mode = @argSequenceMode
        
    IF @vCurrentSequence IS NOT NULL
    BEGIN
      SET @argSequenceValue = @vCurrentSequence + @argIncrementalValue
      IF(@argSequenceValue > @argMaximumValue) 
        SET @argSequenceValue = @argInitialValue + @argIncrementalValue
        
        -- handle initial value -1
      IF (@argIncrement = '1') 
      BEGIN
        UPDATE com_sequence
        SET sequence_nbr = @argSequenceValue
        WHERE organization_id = @argOrganizationId
        AND rtl_loc_id = @argRetailLocationId
        AND wkstn_id = @argWorkstationId
        AND sequence_id = @argSequenceId
        AND sequence_mode = @argSequenceMode
      END
    END
    ELSE 
    BEGIN
    
      IF (@argIncrement = '1')
        SET @argSequenceValue = @argInitialValue + @argIncrementalValue
      ELSE
        SET @argSequenceValue = @argInitialValue
      
      INSERT INTO com_sequence (organization_id, rtl_loc_id, wkstn_id, sequence_id, sequence_mode, sequence_nbr) 
      VALUES (@argOrganizationId, @argRetailLocationId, @argWorkstationId, @argSequenceId, @argSequenceMode, @argSequenceValue)
    END
  COMMIT TRANSACTION
  RETURN @argSequenceValue
END
GO
PRINT 'sp_replace_org_id';
GO
IF EXISTS (Select * From sysobjects Where name = 'sp_replace_org_id' and type = 'P')
  DROP PROCEDURE sp_replace_org_id;
GO

CREATE PROCEDURE dbo.sp_replace_org_id (
    @argNewOrgId int)
AS
-------------------------------------------------------------------------------------------------------------------
-- Procedure         :  sp_replace_org_id
-- Description       :  This procedure is designed to run in only the training database.  This will change the
--						organization_id on all table to the value passed into the procedure.
-- Version           :  19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
--               Initially created
-- PGH 08/12/10  Change the cursor to read only and added a secion to skrink the transaction log.
-- BCW 09/24/15  Changed argNewOrgId from nvarchar to int.
-------------------------------------------------------------------------------------------------------------------
  DECLARE @returnValue	int,
		@sql		 nvarchar(500),
		@tableName	 nvarchar(60),
		@LogFile		sysname
  
  DECLARE tableCur CURSOR READ_ONLY FOR 
    SELECT col.table_name 
      FROM information_schema.columns col, information_schema.tables tab
      WHERE col.table_name = tab.table_name AND 
            tab.table_type = 'BASE TABLE' AND 
            col.column_name = 'organization_id';
 
  BEGIN
    SET @returnValue = 0;
    
    OPEN tableCur;
    WHILE 1 = 1 BEGIN
      FETCH tableCur INTO @tableName;
      IF @@FETCH_STATUS <> 0
        BREAK;

      BEGIN TRY
		
        SET @sql = 'UPDATE ' + @tableName + ' SET organization_id = ' + cast(@argNewOrgId as nvarchar(10));
        PRINT @sql;
        EXEC (@sql);
        
      END TRY
      BEGIN CATCH
        DECLARE @errorMessage nvarchar(4000);
        DECLARE @errorSeverity int;
        DECLARE @errorState int;

        SELECT @errorMessage = ERROR_MESSAGE(),
               @errorSeverity = ERROR_SEVERITY(),
               @errorState = ERROR_STATE();
 
        SET @returnValue = -1;
          
        RAISERROR (@errorMessage, @errorSeverity, @errorState);
      END CATCH
    END
      
    CLOSE tableCur;
    DEALLOCATE tableCur;

	DECLARE LogFileCur CURSOR READ_ONLY FOR 
   		select name 
			from sys.database_files 
			where type = 1;
 
    OPEN LogFileCur;
	WHILE 1 = 1 BEGIN
      FETCH LogFileCur INTO @LogFile;
      IF @@FETCH_STATUS <> 0
        BREAK;
	
		DBCC SHRINKFILE (@LogFile , 0, TRUNCATEONLY);
    END
      
    CLOSE LogFileCur;
    DEALLOCATE LogFileCur;

    RETURN @returnValue;
  END
GO
/* 
 * PROCEDURE: [dbo].[sp_replace_value] 
 */

IF EXISTS (Select * From sysobjects Where name = 'sp_replace_value' and type = 'P')
  DROP PROCEDURE sp_replace_value;
GO

CREATE PROCEDURE dbo.sp_replace_value (
    @argOrgId int,
    @argColumnName nvarchar(60),
    @argNewValue nvarchar(256))
AS
  DECLARE @sql nvarchar(500);
  DECLARE @tableName nvarchar(60);
  
  DECLARE tableCursor CURSOR FOR
    SELECT col.table_name
      FROM information_schema.columns col, information_schema.tables tab
      WHERE col.table_name = tab.table_name 
        AND tab.table_type = 'BASE TABLE' 
        AND col.column_name = @argColumnName;

  BEGIN
    OPEN tableCursor;
    WHILE 1 = 1
    BEGIN
      FETCH tableCursor INTO @tableName;
      
      IF @@FETCH_STATUS <> 0
        BREAK;
        
      SET @sql = 'UPDATE ' + @tableName + ' SET ' + @argColumnName + ' = ''' + @argNewValue + ''' WHERE organization_id = ' + @argOrgId;
      EXEC (@sql);
    END
    CLOSE tableCursor;
    DEALLOCATE tableCursor;
  END
GO
IF EXISTS (Select * From sysobjects Where name = 'sp_set_sequence_value' and type = 'P')
  DROP PROCEDURE sp_set_sequence_value;
GO

CREATE PROCEDURE dbo.sp_set_sequence_value(
  @argOrganizationId      int,
  @argRetailLocationId    int,
  @argWorkstationId       int,
  @argSequenceId          nvarchar(255),
  @argSequenceMode        nvarchar(60),
  @argSequenceValue       int)
AS
BEGIN
  SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
  BEGIN TRANSACTION
    UPDATE com_sequence WITH(TABLOCKX HOLDLOCK)
        SET sequence_nbr = @argSequenceValue
        WHERE organization_id = @argOrganizationId
        AND rtl_loc_id = @argRetailLocationId
        AND wkstn_id = @argWorkstationId
        AND sequence_id = @argSequenceId    
        And sequence_mode = @argSequenceMode
  COMMIT TRANSACTION
END
GO
PRINT 'dbo.sp_shrink';
GO

IF OBJECT_ID('dbo.sp_shrink') IS NOT NULL
	DROP PROCEDURE dbo.sp_shrink;
GO
	
CREATE PROCEDURE dbo.sp_shrink (--@as_db_name	 nvarchar = 'xstore',
					  			  @ai_free_space	int	= 10)
AS
BEGIN
-------------------------------------------------------------------------------------------------------------------
--                     
-- Procedure         : sp_shrink (as_db_name nvarchar, ai_free_space int)
-- Parameters		 : as_db_name
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
	DECLARE
		@ls_owner_nm			sysname,
		@ls_table_nm			sysname,
		@ls_index_nm			sysname,
		@li_index_id			integer,
		@li_fillfactor			integer,
		@ls_domain			 nchar(3),
		@ls_sqlcmd			 nvarchar(256);
		
	DECLARE Table_List CURSOR FOR
		SELECT schema_name(schema_id), object_name (object_id)
			FROM sys.tables
			WHERE type = 'U'
	
	--
	-- Loop through the tables and rebuild the indexes with 100% fill factor
	--
	OPEN Table_List

	FETCH NEXT
	FROM Table_List
	INTO @ls_owner_nm, @ls_table_nm

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @ls_sqlcmd = 'ALTER INDEX ALL  on [' + @ls_owner_nm + '].[' + @ls_table_nm + '] REBUILD WITH (FILLFACTOR=100)';  -- Online only works with Enterprise Edition
		--print @ls_sqlcmd;
		exec (@ls_sqlcmd);

		FETCH NEXT
		FROM Table_List
		INTO @ls_owner_nm, @ls_table_nm
	END;
	
	CLOSE Table_List;
	DEALLOCATE Table_List;

	--
	-- Shrink the database to the desired size
	--
	print 'Free Space%: ' + str(@ai_free_space);
	DBCC SHRINKDATABASE (0, @ai_free_space);

	DECLARE Index_List CURSOR FOR
		SELECT schema_name(t.schema_id), object_name(i.object_id), i.index_id, i.name
			FROM sys.indexes i
			JOIN sys.tables t on i.object_id = t.object_id
			WHERE t.type = 'U'
			  and i.index_id > 0
	
	--
	-- Loop through the indexes and rebuild the indexes
	--
	OPEN Index_List

	FETCH NEXT
	FROM Index_List
	INTO @ls_owner_nm, @ls_table_nm, @li_index_id, @ls_index_nm

	WHILE @@FETCH_STATUS = 0
	BEGIN

		set @ls_domain = substring(@ls_table_nm, 1, 3);
		--print 'Domain: ' + @ls_domain;
		--print 'Table: ' + @ls_table_nm;
		--print 'Index: ' + @ls_index_nm;
		IF @ls_domain in ('TND', 'COM', 'DSC', 'LOC', 'TAX', 'CRM', 'DOC', 'HRS', 'SCH', 'SEC') -- Non-Transaction tables
			set @li_fillfactor = 100;
		ELSE								-- transaction tables
			IF @li_index_id < 2
				set @li_fillfactor = 90;		-- clustered / heap indexes
			ELSE
				set @li_fillfactor = 95;		-- non-clustered indexes
		
		SET @ls_sqlcmd = 'ALTER INDEX [' + @ls_index_nm + ']  on [' + @ls_owner_nm + '].[' + @ls_table_nm + '] REBUILD WITH (FILLFACTOR=' + ltrim(str(@li_fillfactor)) + ')';  -- Online only works with Enterprise Edition
		--print @ls_sqlcmd;
		exec (@ls_sqlcmd);

		FETCH NEXT
		FROM Index_List
		INTO @ls_owner_nm, @ls_table_nm, @li_index_id, @ls_index_nm
	END;
	
	CLOSE Index_List;
	DEALLOCATE Index_List;
END;
GO
/* 
 * PROCEDURE: [dbo].[sp_shrinkLog] 
 */

IF EXISTS (Select * From sysobjects Where name = 'sp_shrinkLog' and type = 'P')
  DROP PROCEDURE sp_shrinkLog;
GO

CREATE PROCEDURE sp_shrinkLog (
    @argDbName AS nvarchar(255), 
    @argNewSize AS int)
AS
  DECLARE @fileId AS int;
  DECLARE @serverVersion AS sql_variant;
  DECLARE logCursor CURSOR FOR 
    SELECT fileid FROM sysfiles 
      WHERE (status & 0x40) = 0x040;
  
  OPEN logCursor;
  
  FETCH NEXT FROM logCursor INTO @fileId;
  
  WHILE @@FETCH_STATUS = 0 BEGIN
    IF @argNewSize = 0  OR (SELECT size * 8 /1024 FROM sysfiles WHERE fileId=2) > @argNewSize
      DBCC SHRINKFILE (@fileId) -- default shrink
    ELSE
      DBCC SHRINKFILE (@fileId, @argNewSize);
  
    FETCH NEXT FROM logCursor INTO @fileId;
  END
  
  CLOSE logCursor;
  DEALLOCATE logCursor;
  
--
-- FB: 205359 - Removing the Backup Log because it was removed in SQL Server 2008
--
--  SELECT @serverVersion = SERVERPROPERTY('productversion');
--  
--  IF SUBSTRING(CONVERT(varchar(max), @serverVersion), 1, 2) = '10'       -- SQL Server 2008
--    BACKUP LOG @argDbName TO DISK = 'NUL:';    
--  ELSE                                          -- SQL Server 2005
--    BACKUP LOG @argDbName WITH TRUNCATE_ONLY;     
GO
-------------------------------------------------------------------------------------------------------------
--
-- Procedure         : SP_TRUNCATE_TABLE
-- Description       : This procedure executes 'truncate' statement on the given table.
-- Version           : 16.0
-------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                               --
-------------------------------------------------------------------------------------------------------------
-- WHO              DATE              DESCRIPTION                                                          --
-------------------------------------------------------------------------------------------------------------
-- Nuwan Wijekoon 02/07/2019         Initial Version
-- 
-------------------------------------------------------------------------------------------------------------


PRINT 'dbo.sp_truncate_table';

IF EXISTS (Select * From sysobjects Where name = 'sp_truncate_table' and type = 'P')
  DROP PROCEDURE dbo.sp_truncate_table;
GO

create procedure dbo.sp_truncate_table(@argTableName nvarchar(255))
WITH EXECUTE AS OWNER
as
declare @vPrepStatement nvarchar(4000)

BEGIN
  set @vPrepStatement = CONCAT('TRUNCATE TABLE dbo.', @argTableName);
  exec(@vPrepStatement);
END;

GO
/* 
 * PROCEDURE: [dbo].[sp_xstoreOrgCopy] 
 */

IF EXISTS (Select * From sysobjects Where name = 'sp_xstoreOrgCopy' and type = 'P')
  DROP PROCEDURE sp_xstoreOrgCopy;
GO

CREATE PROCEDURE dbo.sp_xstoreOrgCopy (
    @pSrcOrgId int,
    @pDstOrgId int,
    @pOption nvarchar(25) = NULL)
AS
  IF (@pSrcOrgId = @pDstOrgId) 
  BEGIN
    RAISERROR('Source cannot be the same as destination', 16, 1);
    RETURN(1);
  END
  
  DECLARE @tableName  nvarchar(255);
  DECLARE @deleteStr  nvarchar(255);
  DECLARE @insertStmt nvarchar(4000);
  DECLARE @selectStmt nvarchar(4000);
  DECLARE @colName    nvarchar(255);
  DECLARE @dataType   nvarchar(30);
  DECLARE @value      nvarchar(255);
  DECLARE @optDeletes int;
  DECLARE @optInserts int;
  DECLARE @optExec    int;

  IF LOWER(@pOption) = 'delete'
    SELECT @optDeletes = 1, @optInserts = 0, @optExec = 0;
  ELSE IF LOWER(@pOption) = 'insert'
    SELECT @optDeletes = 0, @optInserts = 1, @optExec = 0;
  ELSE IF LOWER(@pOption) = 'exec'
    SELECT @optDeletes = 1, @optInserts = 1, @optExec = 1;
  ELSE 
    SELECT @optDeletes = 1, @optInserts = 1, @optExec = 0;

  -- get a cursor of all tables that have a column named 'organization_id'  
  DECLARE tableCur CURSOR FOR
    SELECT DISTINCT tab.name 
      FROM sysobjects tab 
        INNER JOIN syscolumns col ON tab.id = col.id 
      WHERE tab.type = 'U' AND col.name = 'organization_id' ORDER BY tab.name;
  
  OPEN tableCur;

  WHILE 1 = 1 
  BEGIN
    FETCH NEXT FROM tableCur INTO @tableName;

    IF @@FETCH_STATUS <> 0 
      BREAK;

    IF @optDeletes <> 0 
      BEGIN
        SET @deleteStr = 'DELETE FROM ' + @tableName + ' WHERE organization_id = ' + CAST(@pDstOrgId AS nvarchar) + ';'
        PRINT (@deleteStr);
        IF @optExec <> 0 EXEC (@deleteStr);
      END

    IF @optInserts <> 0 
      BEGIN
        SET @insertStmt = 'INSERT INTO ' + @tableName + ' (organization_id';
        SET @selectStmt = 'SELECT ' + CAST(@pDstOrgId AS nvarchar);
    
        DECLARE colCur CURSOR FOR 
          SELECT column_name, data_type 
            FROM information_schema.columns 
           WHERE table_name = @tableName 
             AND data_type <> 'uniqueidentifier'
             AND column_name NOT IN ('organization_id', 'create_date', 'create_user_id', 'update_date', 'update_user_id', 
                                     'PROCESSED_DATE', 'PROCESSED_ID', 'record_state', 'record_timestamp', 'dss_timestamp');
        OPEN colCur;
     
        WHILE 1 = 1
          BEGIN
            FETCH NEXT FROM colCur INTO @colName, @dataType;
    
            IF @@FETCH_STATUS <> 0
              BREAK;
            
            SET @insertStmt = @insertStmt + ', ' + @colName;
            SET @selectStmt = @selectStmt + ', ';
            
            IF @colName LIKE '%_org_id'
              BEGIN
                SET @selectStmt = @selectStmt + CONVERT(varchar, @pDstOrgId);
              END
            ELSE
              BEGIN
                SET @selectStmt = @selectStmt + @colName;
              END
          END
    
        SET @insertStmt = @insertStmt + ') (' + @selectStmt + ' FROM ' + @tableName 
              + ' WHERE organization_id = ' + CAST(@pSrcOrgId AS nvarchar) + ');'
        
        PRINT (@insertStmt);
        IF @optExec <> 0 EXEC (@insertStmt);
          
        CLOSE colCur;
        DEALLOCATE colCur;
      END
  END

  CLOSE tableCur;
  DEALLOCATE tableCur;
  GO
GO
/* 
 * PROCEDURE: [dbo].[sp_xstore_delete_all] 
 */

IF EXISTS (Select * From sysobjects Where name = 'sp_xstore_delete_all' and type = 'P')
  DROP PROCEDURE sp_xstore_delete_all;
GO

CREATE PROCEDURE dbo.sp_xstore_delete_all
AS
  DECLARE @tableName nvarchar(255);
  DECLARE @sql nvarchar(255);
  DECLARE tableCursor CURSOR FAST_FORWARD FOR
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'dbo' AND table_type = 'BASE TABLE'
    ORDER BY table_name;
    
  OPEN tableCursor;

  WHILE 1 = 1
  BEGIN
    FETCH NEXT FROM tableCursor INTO @tableName;
    IF @@FETCH_STATUS <> 0 BREAK;
    
    SET @sql = 'TRUNCATE TABLE dbo.' + @tableName;
    PRINT @sql;
    EXEC(@sql);
  END

  CLOSE tableCursor;
  DEALLOCATE tableCursor;
GO
/* 
 * PROCEDURE: [dbo].[sp_xstore_list_all] 
 */

IF EXISTS (Select * From sysobjects Where name = 'sp_xstore_list_all' and type = 'P')
  DROP PROCEDURE sp_xstore_list_all;
GO

CREATE PROCEDURE dbo.sp_xstore_list_all
AS
  CREATE TABLE
  #t
  (
    tableName nvarchar(100),
    tableRowCount int
  );
  
  DECLARE @tableName nvarchar(255);
  DECLARE tableCursor CURSOR FOR
    SELECT name FROM sysobjects WHERE type = 'u' ORDER BY name;
  
  OPEN tableCursor;
  
  WHILE 1 = 1 BEGIN
    FETCH NEXT FROM tableCursor INTO @tableName;
    
    IF @@FETCH_STATUS <> 0
      BREAK;
  
    INSERT INTO #t (tableName, tableRowCount)
      EXEC ('SELECT ''' + @tableName + ''', COUNT(*) FROM [' + @tableName + '] WITH (NOLOCK)');
  END
  
  CLOSE tableCursor;
  DEALLOCATE tableCursor;
  SELECT * FROM #t ORDER BY tableRowCount DESC;
  DROP TABLE #t;
GO

/* 
 * FUNCTION: [dbo].[fn_NLS_LOWER] 
 */

PRINT 'fn_NLS_LOWER';

IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_NLS_LOWER')
	DROP FUNCTION dbo.fn_NLS_LOWER
GO

CREATE FUNCTION fn_NLS_LOWER (@argString nvarchar(MAX))
RETURNS nvarchar(MAX)
AS
BEGIN
	RETURN LOWER(@argString)
END
GO
/* 
 * FUNCTION: [dbo].[fn_NLS_UPPER] 
 */

PRINT 'fn_NLS_UPPER';

IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_NLS_UPPER')
	DROP FUNCTION dbo.fn_NLS_UPPER
GO

CREATE FUNCTION fn_NLS_UPPER (@argString nvarchar(MAX))
RETURNS nvarchar(MAX)
AS
BEGIN
	RETURN UPPER(@argString)
END
GO
/* 
 * FUNCTION: [dbo].[fn_ParseDate] 
 */

PRINT 'dbo.fn_ParseDate';

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_ParseDate]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
	DROP FUNCTION [dbo].[fn_ParseDate]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION fn_ParseDate (@argDateString nvarchar(24))
RETURNS datetime
AS
BEGIN
	-- Declare the return variable here
	DECLARE @vs_year nvarchar(4),
	 @vs_month nvarchar(2), 
	 @vs_day nvarchar(2), 
	 @vs_hour nvarchar(2)='00', 
	 @vs_minute nvarchar(2)='00', 
	 @vs_second nvarchar(2)='00', 
	 @vs_ms nvarchar(4)='000'

	SET @vs_year = LEFT(@argDateString,4)
	SET @argDateString = RIGHT(@argDateString,len(@argDateString)-5)
	SET @vs_month = LEFT(@argDateString,2)
	SET @argDateString = RIGHT(@argDateString,len(@argDateString)-3)
	SET @vs_day = LEFT(@argDateString,2)
	if len(@argDateString)>5
	begin
		SET @argDateString = RIGHT(@argDateString,len(@argDateString)-3)
		SET @vs_hour = LEFT(@argDateString,2)
		if len(@argDateString)>4
		begin
			SET @argDateString = RIGHT(@argDateString,len(@argDateString)-3)
			SET @vs_minute = LEFT(@argDateString,2)
			if len(@argDateString)>4
			begin
				SET @argDateString = RIGHT(@argDateString,len(@argDateString)-3)
				SET @vs_second = LEFT(@argDateString,2)
				if len(@argDateString)>3
					SET @vs_ms = RIGHT(@argDateString,len(@argDateString)-3)
			end
		end
	end
	-- Return the result of the function
	RETURN convert(datetime,@vs_year + '-' + @vs_month + '-' + @vs_day + ' ' + @vs_hour + ':' + @vs_minute + ':' + @vs_second + '.' + @vs_ms,120)

END
GO

PRINT 'dbo.sp_dbMaintenance';
GO

IF OBJECT_ID('dbo.sp_dbMaintenance') IS NOT NULL
	DROP PROCEDURE dbo.sp_dbMaintenance;
GO

CREATE PROCEDURE dbo.sp_dbMaintenance
AS
-------------------------------------------------------------------------------------------------------------------
--                                                                                                               --
-- Procedure         : sp_dbMaintenance
-- Description       : Performs standard maitntenance to a SQL Server database
--						1) Check recovery model and last backup
--						2) Index Reorganize
--						3) CheckDB
-- Version           : 19.0                                                                                       --
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-- ST  01/30/07  Initially created
-- PGH 02/11/10  Rewriten for 2005 / 2008
-------------------------------------------------------------------------------------------------------------------
DECLARE @dbName				sysname,
		@dbRecovery		 nvarchar(60),
		@LastFullBackup		datetime,
		@LastTransBackup	datetime,
		@MinFragmentation	decimal
--		@dbBk			 nvarchar(255),
--		@logBk			 nvarchar(255),
--		@doBk				bit

BEGIN
	-- config
	SET @MinFragmentation = 30 --Percent
--	SET @dbBk = 'c:\xstoredb\backup\xstoreDb.bk' -- db back up destinataion
--	SET @logBk = 'c:\xstoredb\backup\xstoreLog.bk'  -- log file back up destination
--	SET @doBK = 0 -- set to true for backup
	-- end config

	SET @dbName = db_name();
	SELECT @dbRecovery = recovery_model_desc FROM SYS.DATABASES WHERE NAME =DB_NAME();
	SELECT @LastFullBackup = max(backup_finish_date) from msdb..backupset
		WHERE type = 'D'
		  AND database_name = DB_NAME();
	SELECT @LastTransBackup = max(backup_finish_date) from msdb..backupset
		WHERE type = 'L'
		  AND database_name = DB_NAME();
		  
	--
	-- 1) Check Backup Status
	--
	
	PRINT '';
	PRINT ' Database Backup Info:';
	PRINT '		Database Name:	   ' + db_name();
	PRINT '		Recovery Mode:	   ' + @dbRecovery;
	PRINT '		Last Full Backup:  ' + COALESCE(cast(@LastFullBackup as nvarchar), ' ');
	PRINT '     Last Trans Backup: ' + COALESCE(cast(@LastTransBackup as nvarchar), ' ');
	PRINT '';

	SELECT  CASE df.data_space_id
				WHEN 0 THEN 'LOG'
				ELSE  ds.name
			END AS [FileGroupName],
			df.name AS [FileName], 
			df.physical_name AS [PhysicalName], 
			round((cast(df.size as decimal) / 128) , 2) AS [Size], 
			round((FILEPROPERTY(df.name, 'SpaceUsed')/ 128.0),2) AS [SpaceUsed],	--Changed from Available Space to Used Space
			cast(ROUND(((FILEPROPERTY(df.name, 'SpaceUsed')/ 128.0) / (cast(df.size as decimal) / 128)) * 100, 0) as int)
				AS [SpaceUsedPCT],
			CASE is_percent_growth
			WHEN 0 THEN growth / 128
			ELSE growth
		END AS [Growth],
		CASE is_percent_growth
			WHEN 0 THEN 'MB'
			ELSE 'PCT'
		END AS [Growth Type],
		CASE df.max_size
			WHEN -1 THEN df.max_size
			ELSE max_size / 128
		END AS [Max Growth Size],					
		state_desc
	FROM sys.database_files df
	LEFT JOIN sys.data_spaces ds on ds.data_space_id = df.data_space_id;
	
	--
	-- 2) Index Reorganize
	--
	
	PRINT 'Reorganizing Indexes'
	EXEC dbo.sp_defrag_indexes @MinFragmentation
	
	-- 3) Update the stats
	--PRINT 'Updating Statistics'
	--EXEC sp_updatestats -- with default parameters runs stats for sample rows on all tables
	

	-- 3) Check DB
	PRINT 'CheckDB';
	DBCC CHECKDB WITH NO_INFOMSGS;

	-- 5) Backup Database
	--IF @doBk = 1
	--	BEGIN
	--		BACKUP DATABASE @dbName TO DISK = @dbBk
	--		BACKUP LOG @dbName TO DISK = @logBk
	--	END
END
GO
-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : SP_FLASH
-- Description       : Loads data into the Report tables which are then used by the flash reports.
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....     	Initial Version
-- PGH  02/23/10    Removed the currencyid paramerer, then joining the loc_rtl_loc table to get the default
--                  currencyid for the location.  If the default is not set, defaulting to 'USD'. 
-- BCW  03/07/12	Updated per Padma Golli's instructions.
-- BCW  06/21/12	Updated per Emily Tan's instructions.
-- BCW	12/05/13	Replaced the sale cursor by writing the transaction line item directly into the rpt_sale_line table.
-------------------------------------------------------------------------------------------------------------------
PRINT 'dbo.sp_flash';

IF EXISTS (Select * From sysobjects Where name = 'sp_flash' and type = 'P')
  DROP PROCEDURE sp_flash;
GO

CREATE PROCEDURE dbo.sp_flash (
@argOrganizationId int,  /*organization id*/
@argRetailLocationId int,  /*retail location or store number*/
@argBusinessDate datetime,  /*business date*/
@argWrkstnId bigint,  /*register*/
@argTransSeq bigint)  /*trans sequence*/
as

declare @old_context_info varbinary(128)=context_info();
SET CONTEXT_INFO 0x0111001101110000010111110110011001101100011000010111001101101000

declare -- Quantities
@vActualQuantity decimal(11, 2),
@vGrossQuantity decimal(11, 2),
@vQuantity decimal(11, 2),
@vTotQuantity decimal(11, 2)

declare -- Amounts
@vNetAmount decimal(17, 6),
@vGrossAmount decimal(17, 6),
@vTotGrossAmt decimal(17, 6),
@vTotNetAmt decimal(17, 6),
@vDiscountAmt decimal(17, 6),
@vOverrideAmt decimal(17, 6),
@vPaidAmt decimal(17, 6),
@vTenderAmt decimal(17, 6),
@vForeign_amt decimal(17, 6),
@vLayawayPrice decimal(17, 6),
@vUnitPrice decimal(17, 6)

declare -- Non Physical Items
@vNonPhys nvarchar(30),
@vNonPhysSaleType nvarchar(30),
@vNonPhysType nvarchar(30),
@vNonPhysPrice decimal(17, 6),
@vNonPhysQuantity decimal(11, 2)

declare -- Status codes
@vTransStatcode nvarchar(30),
@vTransTypcode nvarchar(30),
@vSaleLineItmTypcode nvarchar(30),
@vTndrStatcode nvarchar(60),
@vLineitemStatcode nvarchar(30)

declare -- others
@vTransTimeStamp datetime,
@vTransDate datetime,
@vTransCount int,
@vTndrCount int,
@vPostVoidFlag bit,
@vReturnFlag bit,
@vTaxTotal decimal(17, 6),
@vPaid nvarchar(30),
@vLineEnum nvarchar(150),
@vTndrId nvarchar(60),
@vItemId nvarchar(60),
@vRtransLineItmSeq int,
@vDepartmentId nvarchar(90),
@vTndridProp nvarchar(60),
@vCurrencyId nvarchar(3),
@vTndrTypCode nvarchar(30)

declare
@vSerialNbr nvarchar(60),
@vPriceModAmt decimal(17, 6),
@vPriceModReascode nvarchar(60),
@vNonPhysExcludeFlag bit,
@vCustPartyId nvarchar(60),
@vCustLastName nvarchar(90),
@vCustFirstName nvarchar(90),
@vItemDesc nvarchar(120),
@vBeginTimeInt int


select @vTransStatcode = trans_statcode,
@vTransTypcode = trans_typcode,
@vTransTimeStamp = begin_datetime,
@vTransDate = trans_date,
@vTaxTotal = taxtotal,
@vPostVoidFlag = post_void_flag,
@vBeginTimeInt = begin_time_int
from trn_trans with (nolock)
where organization_id = @argOrganizationId
and rtl_loc_id = @argRetailLocationId
and wkstn_id = @argWrkstnId
and business_date = @argBusinessDate
and trans_seq = @argTransSeq

if @@rowcount = 0 
  return  /* Invalid transaction */

select @vCurrencyId = max(currency_id)
from ttr_tndr_lineitm ttl with (nolock)
inner join tnd_tndr tnd with (nolock) on ttl.organization_id=tnd.organization_id and ttl.tndr_id=tnd.tndr_id
where ttl.organization_id = @argOrganizationId
and rtl_loc_id = @argRetailLocationId
and wkstn_id = @argWrkstnId
and business_date = @argBusinessDate
and trans_seq = @argTransSeq

if @vCurrencyId is null
select @vCurrencyId = max(currency_id)
from loc_rtl_loc with (nolock)
where organization_id = @argOrganizationId
and rtl_loc_id = @argRetailLocationId

-- Sundar commented the following as rpt sale line has to capture all the transactions
-- if @vTransStatcode != 'COMPLETE' and @vTransStatcode != 'SUSPEND' 
--  return

set @vTransCount = 1 /* initializing the transaction count */


-- update trans
update trn_trans set flash_sales_flag = 1
where organization_id = @argOrganizationId
and rtl_loc_id = @argRetailLocationId 
and wkstn_id = @argWrkstnId 
and trans_seq = @argTransSeq
and business_date = @argBusinessDate

-- BCW Added code to only update post voids if the original transaction 
if @vPostVoidFlag=1 and not exists(select 1 from rpt_sale_line where organization_id = @argOrganizationId
          and rtl_loc_id = @argRetailLocationId
          and wkstn_id = @argWrkstnId
          and trans_seq = @argTransSeq
          and business_date = @argBusinessDate)
      begin
       insert into rpt_sale_line WITH(ROWLOCK)
      (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq,
      quantity, actual_quantity, gross_quantity, unit_price, net_amt, gross_amt, item_id, 
      item_desc, merch_level_1, serial_nbr, return_flag, override_amt, trans_timestamp, trans_date,
      discount_amt, cust_party_id, last_name, first_name, trans_statcode, sale_lineitm_typcode, begin_time_int,
      currency_id, exclude_from_net_sales_flag)
      select tsl.organization_id, tsl.rtl_loc_id, tsl.business_date, tsl.wkstn_id, tsl.trans_seq, tsl.rtrans_lineitm_seq,
      tsl.net_quantity, tsl.quantity, tsl.gross_quantity, tsl.unit_price,
      -- For VAT taxed items there are rounding problems by which the usage of the tsl.net_amt could create problems.
      -- So, we are calculating it using the tax amount which could have more decimals and because that it is more accurate
      case when vat_amt is null or tsl.gross_amt=0 then tsl.net_amt else tsl.gross_amt-tsl.vat_amt-coalesce(d.discount_amt,0) end,
      tsl.gross_amt, tsl.item_id,
      i.DESCRIPTION, coalesce(tsl.merch_level_1,i.MERCH_LEVEL_1,N'DEFAULT'), tsl.serial_nbr, tsl.return_flag, coalesce(o.override_amt,0), @vTransTimeStamp, @vTransDate, 
      coalesce(d.discount_amt,0), tr.cust_party_id, cust.last_name, cust.first_name, 'VOID', tsl.sale_lineitm_typcode, 
      @vBeginTimeInt, @vCurrencyId, tsl.exclude_from_net_sales_flag
      from trl_sale_lineitm tsl with (nolock) 
      inner join trl_rtrans_lineitm r with (nolock)
      on tsl.organization_id=r.organization_id
      and tsl.rtl_loc_id=r.rtl_loc_id
      and tsl.wkstn_id=r.wkstn_id
      and tsl.trans_seq=r.trans_seq
      and tsl.business_date=r.business_date
      and tsl.rtrans_lineitm_seq=r.rtrans_lineitm_seq
      and r.rtrans_lineitm_typcode = N'ITEM'
      left join xom_order_mod xom  with (nolock)
      on tsl.organization_id=xom.organization_id
      and tsl.rtl_loc_id=xom.rtl_loc_id
      and tsl.wkstn_id=xom.wkstn_id
      and tsl.trans_seq=xom.trans_seq
      and tsl.business_date=xom.business_date
      and tsl.rtrans_lineitm_seq=xom.rtrans_lineitm_seq
      left join xom_order_line_detail xold  with (nolock)
      on xom.organization_id=xold.organization_id
      and xom.order_id=xold.order_id
      and xom.detail_seq=xold.detail_seq
      and xom.detail_line_number=xold.detail_line_number
      left join itm_item i
      on tsl.organization_id=i.ORGANIZATION_ID
      and tsl.item_id=i.ITEM_ID
      left join (select extended_amt override_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
        FROM trl_rtl_price_mod with(nolock)
        WHERE void_flag = 0 and rtl_price_mod_reascode=N'PRICE_OVERRIDE') o
      on tsl.organization_id = o.organization_id 
        AND tsl.rtl_loc_id = o.rtl_loc_id
        AND tsl.business_date = o.business_date 
        AND tsl.wkstn_id = o.wkstn_id 
        AND tsl.trans_seq = o.trans_seq
        AND tsl.rtrans_lineitm_seq = o.rtrans_lineitm_seq
      left join (select sum(extended_amt) discount_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
        FROM trl_rtl_price_mod with(nolock)
        WHERE void_flag = 0 and rtl_price_mod_reascode in (N'LINE_ITEM_DISCOUNT', N'TRANSACTION_DISCOUNT',N'GROUP_DISCOUNT', N'NEW_PRICE_RULE', N'DEAL')
        group by organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq) d
      on tsl.organization_id = d.organization_id 
        AND tsl.rtl_loc_id = d.rtl_loc_id
        AND tsl.business_date = d.business_date 
        AND tsl.wkstn_id = d.wkstn_id 
        AND tsl.trans_seq = d.trans_seq
        AND tsl.rtrans_lineitm_seq = d.rtrans_lineitm_seq
      left join trl_rtrans tr with(nolock)
      on tsl.organization_id = tr.organization_id 
        AND tsl.rtl_loc_id = tr.rtl_loc_id
        AND tsl.business_date = tr.business_date 
        AND tsl.wkstn_id = tr.wkstn_id 
        AND tsl.trans_seq = tr.trans_seq
      left join crm_party cust with(nolock)
      on tsl.organization_id = cust.organization_id 
        AND tr.cust_party_id = cust.party_id
      where tsl.organization_id = @argOrganizationId
      and tsl.rtl_loc_id = @argRetailLocationId
      and tsl.wkstn_id = @argWrkstnId
      and tsl.business_date = @argBusinessDate
      and tsl.trans_seq = @argTransSeq
      and r.void_flag=0
      and ((tsl.SALE_LINEITM_TYPCODE <> N'ORDER'and (xom.detail_type IS NULL OR xold.status_code = N'FULFILLED') )
      or (tsl.SALE_LINEITM_TYPCODE = N'ORDER' and xom.detail_type in (N'FEE', N'PAYMENT') ))
  return;
  end

-- collect transaction data
if abs(@vTaxTotal) > 0 and (@vTransTypcode <> 'POST_VOID' and @vPostVoidFlag = 0) and @vTransStatcode = 'COMPLETE'
  exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
  @argWrkstnId,'TOTALTAX', 1, @vTaxTotal, @vCurrencyId          

IF @vTransTypcode = 'TENDER_CONTROL' and @vPostVoidFlag = 0
  -- process for paid in paid out 
  begin 
    select @vPaid = typcode,@vPaidAmt = amt 
    from tsn_tndr_control_trans with (nolock)  
    where typcode like 'PAID%'
          and organization_id = @argOrganizationId
          and rtl_loc_id = @argRetailLocationId
          and wkstn_id = @argWrkstnId
          and trans_seq = @argTransSeq
          and business_date = @argBusinessDate
            
    IF @@rowcount = 1
      -- it is paid in or paid out
      begin 
        if @vPaid = 'PAID_IN' or @vPaid = 'PAIDIN'
          set @vLineEnum = 'paidin'
        else
          set @vLineEnum = 'paidout'
        -- update flash sales
        if @vTransStatcode = 'COMPLETE'                
          exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
          @argWrkstnId,@vLineEnum, 1, @vPaidAmt, @vCurrencyId

      end 
  end
-- collect tenders  data
if @vPostVoidFlag = 0 and @vTransTypcode <> 'POST_VOID'
  begin

    declare tenderCursor cursor for 
    select t.amt, t.foreign_amt, t.tndr_id, t.tndr_statcode,tr.string_value,tnd.tndr_typcode
    from ttr_tndr_lineitm t with (nolock) 
    inner join trl_rtrans_lineitm r with (nolock)
    on t.organization_id=r.organization_id
    and t.rtl_loc_id=r.rtl_loc_id
    and t.wkstn_id=r.wkstn_id
    and t.trans_seq=r.trans_seq
    and t.business_date=r.business_date
    and t.rtrans_lineitm_seq=r.rtrans_lineitm_seq
  inner join tnd_tndr tnd with (nolock)
    on t.organization_id=tnd.organization_id
    and t.tndr_id=tnd.tndr_id 
  left outer join trl_rtrans_lineitm_p tr with (nolock)
    on tr.organization_id=r.organization_id
    and tr.rtl_loc_id=r.rtl_loc_id
    and tr.wkstn_id=r.wkstn_id
    and tr.trans_seq=r.trans_seq
    and tr.business_date=r.business_date
    and tr.rtrans_lineitm_seq=r.rtrans_lineitm_seq
  and property_code = 'tender_id'
    where t.organization_id = @argOrganizationId
    and t.rtl_loc_id = @argRetailLocationId 
    and t.wkstn_id = @argWrkstnId 
    and t.trans_seq = @argTransSeq
    and t.business_date = @argBusinessDate
    and r.void_flag = 0
  and t.tndr_id <> 'ACCOUNT_CREDIT'

    open tenderCursor
    while 1=1 
      begin
        fetch next from tenderCursor into @vTenderAmt,@vForeign_amt,@vTndrid,@vTndrStatcode,@vTndridProp,@vTndrTypCode           
        if @@fetch_status <> 0 
          BREAK
        if @vTndrTypCode='VOUCHER' or @vTndrStatcode <> 'Change'
          set @vTndrCount = 1  -- only for original tenders
        else 
          set @vTndrCount = 0

         if @vTndridProp IS NOT NULL
           set @vTndrid = @vTndridProp
          
        if @vLineEnum = 'paidout'
          begin
            set @vTenderAmt = coalesce(@vTenderAmt, 0) * -1
            set @vForeign_amt = coalesce(@vForeign_amt, 0) * -1
          end

        -- update flash
        if @vTransStatcode = 'COMPLETE'                
          exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
          @argWrkstnId,@vTndrid,@vTndrCount,@vTenderAmt,@vCurrencyId
    
        if @vTenderAmt > 0 and @vTransStatcode = 'COMPLETE'                
          exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
          @argWrkstnId,'TendersTakenIn', 1,@vTenderAmt,@vCurrencyId
        else
          exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
          @argWrkstnId,'TendersRefunded', 1,@vTenderAmt,@vCurrencyId
    
      end
    close tenderCursor
    deallocate tendercursor
  end

-- collect post void info
if @vTransTypcode = 'POST_VOID' or @vPostVoidFlag = 1
  begin

    set @vTransCount = -1 /* reversing the count */
    if @vPostVoidFlag = 0
      begin
        set @vPostVoidFlag = 1
        -- get the original post voided transaction and set it as original parameters
        select  @argOrganizationId = voided_org_id,
          @argRetailLocationId = voided_rtl_store_id, 
          @argWrkstnId = voided_wkstn_id, 
          @argBusinessDate = voided_business_date, 
          @argTransSeq = voided_trans_id 
        from trn_post_void_trans with (nolock)
        where organization_id = @argOrganizationId
        and rtl_loc_id = @argRetailLocationId
        and wkstn_id = @argWrkstnId
        and business_date = @argBusinessDate
        and trans_seq = @argTransSeq
    
        /* NOTE: From now on the parameter value carries the original post voided
           information rather than the current transaction information in 
           case of post void trans type. This will apply for sales data 
           processing.
        */
              
        if @@rowcount = 0 
           return -- don't know the original post voided record

    if exists(select 1 from rpt_sale_line where organization_id = @argOrganizationId
          and rtl_loc_id = @argRetailLocationId
          and wkstn_id = @argWrkstnId
          and trans_seq = @argTransSeq
          and business_date = @argBusinessDate
      and trans_statcode = 'VOID')
      return;
      end
    -- update the rpt sale line for post void
   update rpt_sale_line
    set trans_statcode='VOID'
    where organization_id = @argOrganizationId
    and rtl_loc_id = @argRetailLocationId
    and wkstn_id = @argWrkstnId
    and business_date = @argBusinessDate
    and trans_seq = @argTransSeq        

    -- reverse padin paidout
    select @vPaid = typcode,@vPaidAmt = amt 
    from tsn_tndr_control_trans with (nolock)  
    where typcode like 'PAID%'
          and organization_id = @argOrganizationId
          and rtl_loc_id = @argRetailLocationId
          and wkstn_id = @argWrkstnId
          and trans_seq = @argTransSeq
          and business_date = @argBusinessDate
            
    IF @@rowcount = 1
      -- it is paid in or paid out
      begin 
        if @vPaid = 'PAID_IN' or @vPaid = 'PAIDIN'
          set @vLineEnum = 'paidin'
        else
          set @vLineEnum = 'paidout'
        set @vPaidAmt = @vPaidAmt * -1
        -- update flash sales  
        if @vTransStatcode = 'COMPLETE'                                
          exec sp_ins_upd_flash_sales @argOrganizationId, @argRetailLocationId, @vTransDate,
          @argWrkstnId, @vLineEnum, -1, @vPaidAmt, @vCurrencyId 

      end 
    -- reverse tax
    select @vTaxTotal=taxtotal from trn_trans with (nolock)
    where organization_id = @argOrganizationId
    and rtl_loc_id = @argRetailLocationId
    and wkstn_id = @argWrkstnId
    and business_date = @argBusinessDate
    and trans_seq = @argTransSeq
    

    if abs(@vTaxTotal) > 0 and @vTransStatcode = 'COMPLETE'
      begin
        set @vTaxTotal = @vTaxTotal * -1
        exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
        @argWrkstnId,'TOTALTAX',-1,@vTaxTotal,@vCurrencyId
      end

    -- reverse tenders
    declare postVoidTenderCursor cursor for 
    select t.amt, t.foreign_amt, t.tndr_id, t.tndr_statcode,tr.string_value
    from ttr_tndr_lineitm t with (nolock) 
    inner join trl_rtrans_lineitm r with (nolock)
    on t.organization_id=r.organization_id
    and t.rtl_loc_id=r.rtl_loc_id
    and t.wkstn_id=r.wkstn_id
    and t.trans_seq=r.trans_seq
    and t.business_date=r.business_date
    and t.rtrans_lineitm_seq=r.rtrans_lineitm_seq
  left outer join trl_rtrans_lineitm_p tr with (nolock)
    on tr.organization_id=r.organization_id
    and tr.rtl_loc_id=r.rtl_loc_id
    and tr.wkstn_id=r.wkstn_id
    and tr.trans_seq=r.trans_seq
    and tr.business_date=r.business_date
    and tr.rtrans_lineitm_seq=r.rtrans_lineitm_seq
  and property_code = 'tender_id'
    where t.organization_id = @argOrganizationId
    and t.rtl_loc_id = @argRetailLocationId 
    and t.wkstn_id = @argWrkstnId 
    and t.trans_seq = @argTransSeq
    and t.business_date = @argBusinessDate
    and r.void_flag = 0
  and t.tndr_id <> 'ACCOUNT_CREDIT'

    open postVoidTenderCursor
    while 1=1 
      begin
        fetch next from postVoidTenderCursor into @vTenderAmt,@vForeign_amt,@vTndrid,@vTndrStatcode,@vTndridProp            
        if @@fetch_status <> 0 
                     BREAK
        if @vTndrStatcode <> 'Change'
          set @vTndrCount = -1  -- only for original tenders
        else 
          set @vTndrCount = 0

         if @vTndridProp IS NOT NULL
           set @vTndrid = @vTndridProp

        -- update flash
        set @vTenderAmt = @vTenderAmt * -1
 
       if @vTransStatcode = 'COMPLETE'
          exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
          @argWrkstnId,@vTndrid,@vTndrCount,@vTenderAmt,@vCurrencyId

        if @vTenderAmt < 0 and @vTransStatcode = 'COMPLETE'
          exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
          @argWrkstnId,'TendersTakenIn',-1,@vTenderAmt,@vCurrencyId
        else
          exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
          @argWrkstnId,'TendersRefunded',-1,@vTenderAmt,@vCurrencyId
  
      end
    close postVoidTenderCursor
    deallocate postVoidTenderCursor
  end

-- collect sales data
      if @vPostVoidFlag = 0 and @vTransTypcode <> 'POST_VOID' -- dont do it for rpt sale line
      begin
         insert into rpt_sale_line WITH(ROWLOCK)
        (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq,
        quantity, actual_quantity, gross_quantity, unit_price, net_amt, gross_amt, item_id, 
        item_desc, merch_level_1, serial_nbr, return_flag, override_amt, trans_timestamp, trans_date,
        discount_amt, cust_party_id, last_name, first_name, trans_statcode, sale_lineitm_typcode, 
        begin_time_int,currency_id, exclude_from_net_sales_flag)
    select tsl.organization_id, tsl.rtl_loc_id, tsl.business_date, tsl.wkstn_id, tsl.trans_seq, tsl.rtrans_lineitm_seq,
    tsl.net_quantity, tsl.quantity, tsl.gross_quantity, tsl.unit_price,
    -- For VAT taxed items there are rounding problems by which the usage of the tsl.net_amt could create problems.
    -- So, we are calculating it using the tax amount which could have more decimals and because that it is more accurate
    case when vat_amt is null or tsl.gross_amt=0 then tsl.net_amt else tsl.gross_amt-tsl.vat_amt-coalesce(d.discount_amt,0) end,
    tsl.gross_amt, tsl.item_id,
    i.DESCRIPTION, coalesce(tsl.merch_level_1,i.MERCH_LEVEL_1,N'DEFAULT'), tsl.serial_nbr, tsl.return_flag, coalesce(o.override_amt,0), @vTransTimeStamp, @vTransDate,
    coalesce(d.discount_amt,0), tr.cust_party_id, cust.last_name, cust.first_name, @vTransStatcode, tsl.sale_lineitm_typcode, 
    @vBeginTimeInt, @vCurrencyId, tsl.exclude_from_net_sales_flag
    from trl_sale_lineitm tsl with (nolock) 
    inner join trl_rtrans_lineitm r with (nolock)
    on tsl.organization_id=r.organization_id
    and tsl.rtl_loc_id=r.rtl_loc_id
    and tsl.wkstn_id=r.wkstn_id
    and tsl.trans_seq=r.trans_seq
    and tsl.business_date=r.business_date
    and tsl.rtrans_lineitm_seq=r.rtrans_lineitm_seq
    and r.rtrans_lineitm_typcode = N'ITEM'
    left join xom_order_mod xom  with (nolock)
    on tsl.organization_id=xom.organization_id
    and tsl.rtl_loc_id=xom.rtl_loc_id
    and tsl.wkstn_id=xom.wkstn_id
    and tsl.trans_seq=xom.trans_seq
    and tsl.business_date=xom.business_date
    and tsl.rtrans_lineitm_seq=xom.rtrans_lineitm_seq
    left join xom_order_line_detail xold  with (nolock)
    on xom.organization_id=xold.organization_id
    and xom.order_id=xold.order_id
    and xom.detail_seq=xold.detail_seq
    and xom.detail_line_number=xold.detail_line_number
    left join itm_item i
    on tsl.organization_id=i.ORGANIZATION_ID
    and tsl.item_id=i.ITEM_ID
    left join (select extended_amt override_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
      FROM trl_rtl_price_mod with(nolock)
      WHERE void_flag = 0 and rtl_price_mod_reascode=N'PRICE_OVERRIDE') o
    on tsl.organization_id = o.organization_id 
      AND tsl.rtl_loc_id = o.rtl_loc_id
      AND tsl.business_date = o.business_date 
      AND tsl.wkstn_id = o.wkstn_id 
      AND tsl.trans_seq = o.trans_seq
      AND tsl.rtrans_lineitm_seq = o.rtrans_lineitm_seq
    left join (select sum(extended_amt) discount_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
      FROM trl_rtl_price_mod with(nolock)
      WHERE void_flag = 0 and rtl_price_mod_reascode in (N'LINE_ITEM_DISCOUNT', N'TRANSACTION_DISCOUNT',N'GROUP_DISCOUNT', N'NEW_PRICE_RULE', N'DEAL')
      group by organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq) d
    on tsl.organization_id = d.organization_id 
      AND tsl.rtl_loc_id = d.rtl_loc_id
      AND tsl.business_date = d.business_date 
      AND tsl.wkstn_id = d.wkstn_id 
      AND tsl.trans_seq = d.trans_seq
      AND tsl.rtrans_lineitm_seq = d.rtrans_lineitm_seq
    left join trl_rtrans tr with(nolock)
    on tsl.organization_id = tr.organization_id 
      AND tsl.rtl_loc_id = tr.rtl_loc_id
      AND tsl.business_date = tr.business_date 
      AND tsl.wkstn_id = tr.wkstn_id 
      AND tsl.trans_seq = tr.trans_seq
    left join crm_party cust with(nolock)
    on tsl.organization_id = cust.organization_id 
      AND tr.cust_party_id = cust.party_id
    where tsl.organization_id = @argOrganizationId
    and tsl.rtl_loc_id = @argRetailLocationId
    and tsl.wkstn_id = @argWrkstnId
    and tsl.business_date = @argBusinessDate
    and tsl.trans_seq = @argTransSeq
    and r.void_flag=0
    and ((tsl.SALE_LINEITM_TYPCODE <> N'ORDER'and (xom.detail_type IS NULL OR xold.status_code = N'FULFILLED') )
    or (tsl.SALE_LINEITM_TYPCODE = N'ORDER' and xom.detail_type in (N'FEE', N'PAYMENT') ))
   end
    
    if @vTransStatcode = 'COMPLETE' -- only when complete populate flash sales
    begin 
    -- returns
    select @vQuantity=sum(case @vPostVoidFlag when 0 then -1 else 1 end * coalesce(quantity,0)),@vNetAmount=sum(case @vPostVoidFlag when 1 then -1 else 1 end * coalesce(net_amt,0)) 
    from rpt_sale_line rsl with(nolock)
    where rsl.organization_id = @argOrganizationId
      and rtl_loc_id = @argRetailLocationId
      and wkstn_id = @argWrkstnId
      and business_date = @argBusinessDate
      and trans_seq= @argTransSeq
      and return_flag=1
      and coalesce(exclude_from_net_sales_flag,0)=0
 
      if abs(@vQuantity)>0 or abs(@vNetAmount)>0
        -- populate now to flash tables
        exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
        @argWrkstnId,'Returns',@vQuantity, @vNetAmount, @vCurrencyId

    select @vGrossQuantity=sum(case when return_flag=@vPostVoidFlag then 1 else -1 end * coalesce(gross_quantity,0)),
    @vQuantity=sum(case when return_flag=@vPostVoidFlag then 1 else -1 end * coalesce(quantity,0)),
    @vGrossAmount=sum(case @vPostVoidFlag when 1 then -1 else 1 end * coalesce(gross_amt,0)),
    @vNetAmount=sum(case @vPostVoidFlag when 1 then -1 else 1 end * coalesce(net_amt,0)),
    @vOverrideAmt=sum(case @vPostVoidFlag when 1 then 1 else -1 end * coalesce(override_amt,0)),
    @vDiscountAmt=sum(case @vPostVoidFlag when 1 then 1 else -1 end * coalesce(discount_amt,0)) 
    from rpt_sale_line rsl with(nolock)
    where rsl.organization_id = @argOrganizationId
      and rtl_loc_id = @argRetailLocationId
      and wkstn_id = @argWrkstnId
      and business_date = @argBusinessDate
      and trans_seq= @argTransSeq
      AND QUANTITY <> 0
      AND sale_lineitm_typcode not in ('ONHOLD','WORK_ORDER')
      and coalesce(exclude_from_net_sales_flag,0)=0

      -- For VAT taxed items there are rounding problems by which the usage of the SUM(net_amt) could create problems
      -- So we decided to set it as simple difference between the gross amount and the discount, which results in the expected value for both SALES and VAT without rounding issues
      -- We excluded the possibility to round also the tax because several reasons:
      -- 1) It will be possible that the final result is not accurate if both values have 5 as exceeding decimal
      -- 2) The value of the tax is rounded by specific legal requirements, and must match with what specified on the fiscal receipts
      -- 3) The number of decimals used for the tax amount in the database is less (6) than the one used in the calculator (10); 
      --    anyway, this last one is the most accurate, so we cannot rely on the value on the database which is at line level (rpt_sale_line) and could be affected by several roundings
      SET @vNetAmount = @vGrossAmount + @vDiscountAmt - @vTaxTotal

      -- Gross Sales update  
      if abs(@vGrossAmount) > 0
        exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
        @argWrkstnId,'GROSSSALES',@vGrossQuantity, @vGrossAmount, @vCurrencyId
      -- Net Sales update
      if abs(@vNetAmount) > 0
        exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
        @argWrkstnId,'NETSALES',@vQuantity, @vNetAmount, @vCurrencyId  
      -- Discounts
      if abs(@vOverrideAmt) > 0
        exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
        @argWrkstnId,'OVERRIDES',@vQuantity, @vOverrideAmt, @vCurrencyId  
      -- Discounts  
      if abs(@vDiscountAmt) > 0
        exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
        @argWrkstnId,'DISCOUNTS',@vQuantity, @vDiscountAmt, @vCurrencyId  

    -- Hourly sales updates (add for all the line items in the transaction)
      set @vTotQuantity = coalesce(@vTotQuantity, 0) + @vQuantity
      set @vTotNetAmt = coalesce(@vTotNetAmt, 0) + @vNetAmount
      set @vTotGrossAmt = coalesce(@vTotGrossAmt, 0) + @vGrossAmount

      -- non merchandise
      -- Non Merchandise (returns after processing)
    declare saleCursor cursor fast_forward for
    select rsl.item_id,sale_lineitm_typcode,actual_quantity,unit_price,case @vPostVoidFlag when 1 then -1 else 1 end * coalesce(gross_amt,0),case when return_flag=@vPostVoidFlag then 1 else -1 end * coalesce(gross_quantity,0),merch_level_1,case @vPostVoidFlag when 1 then -1 else 1 end * coalesce(net_amt,0),case when return_flag=@vPostVoidFlag then 1 else -1 end * coalesce(quantity,0),return_flag
    from rpt_sale_line rsl with(nolock)
    where rsl.organization_id = @argOrganizationId
      and rtl_loc_id = @argRetailLocationId
      and wkstn_id = @argWrkstnId
      and business_date = @argBusinessDate
      and trans_seq= @argTransSeq
      AND QUANTITY <> 0
      AND sale_lineitm_typcode not in ('ONHOLD','WORK_ORDER')
      and coalesce(exclude_from_net_sales_flag,0)=0

    open saleCursor

    while 1=1
    begin

    fetch from saleCursor into @vItemId,@vSaleLineItmTypcode,@vActualQuantity,@vUnitPrice,@vGrossAmount,@vGrossQuantity,@vDepartmentId,@vNetAmount,@vQuantity,@vReturnFlag;
    if @@FETCH_STATUS <> 0
    break;

      select @vNonPhysType = non_phys_item_typcode from itm_non_phys_item with (nolock)
      where item_id = @vItemId and organization_id = @argOrganizationId    
      IF @@rowcount = 1
        begin      
        -- check for layaway or sp. order payment / deposit
          if @vPostVoidFlag <> @vReturnFlag
            begin
              set @vNonPhysPrice = @vUnitPrice * -1
              set @vNonPhysQuantity = @vActualQuantity * -1
            end
          else
            begin
              set @vNonPhysPrice = @vUnitPrice
              set @vNonPhysQuantity = @vActualQuantity
            end
        
          if @vNonPhysType = 'LAYAWAY_DEPOSIT'
            set @vNonPhys = 'LayawayDeposits'
          else if @vNonPhysType = 'LAYAWAY_PAYMENT'
            set @vNonPhys = 'LayawayPayments'
          else if @vNonPhysType = 'SP_ORDER_DEPOSIT'
            set @vNonPhys = 'SpOrderDeposits'        
          else if @vNonPhysType = 'SP_ORDER_PAYMENT'
            set @vNonPhys = 'SpOrderPayments'        
          else if @vNonPhysType = 'PRESALE_DEPOSIT'
            set @vNonPhys = 'PresaleDeposits'
          else if @vNonPhysType = 'PRESALE_PAYMENT'
            set @vNonPhys = 'PresalePayments'
          else 
            begin
              set @vNonPhys = 'NonMerchandise'
              set @vNonPhysPrice = @vGrossAmount
              set @vNonPhysQuantity = @vGrossQuantity
            end
          -- update flash sales for non physical payments / deposits
          exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
          @argWrkstnId,@vNonPhys,@vNonPhysQuantity, @vNonphysPrice, @vCurrencyId
        end  
      else
      set @vNonPhys = '' -- reset 

      -- process layaways and special orders (not sales)
      if @vSaleLineitmTypcode = 'LAYAWAY' or @vSaleLineitmTypcode = 'SPECIAL_ORDER'
        begin
          if (not (@vNonPhys = 'LayawayDeposits' or @vNonPhys = 'LayawayPayments' 
            or @vNonPhys = 'SpOrderDeposits' or @vNonPhys = 'SpOrderPayments' 
            or @vNonPhys = 'PresaleDeposits' or @vNonPhys = 'PresalePayments')) 
            and ((@vLineitemStatcode is null) or (@vLineitemStatcode <> 'CANCEL'))
            begin
            
              set @vNonPhysSaleType = 'SpOrderItems'
              if @vSaleLineitmTypcode = 'LAYAWAY'
                set @vNonPhysSaleType = 'LayawayItems'
              else if @vSaleLineitmTypcode = 'PRESALE'
                set @vNonPhysSaleType = 'PresaleItems'
              
              -- update flash sales for layaway items
              set @vLayawayPrice = @vUnitPrice * coalesce(@vActualQuantity, 0)
              exec sp_ins_upd_flash_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
              @argWrkstnId,@vNonPhys,@vActualQuantity, @vLayawayPrice, @vCurrencyId
            end  
        end
      -- end flash sales update
      -- department sales
      exec sp_ins_upd_merchlvl1_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
      @argWrkstnId,@vDepartmentId,@vQuantity,@vNetAmount,@vGrossAmount,@vCurrencyId      
    end -- sale cursor ends
  close saleCursor
  deallocate saleCursor 
  end -- only when transaction is complete populate flash sales ends

-- update hourly sales
   exec sp_ins_upd_hourly_sales @argOrganizationId,@argRetailLocationId,@vTransDate,
   @argWrkstnId,@vTransTimeStamp,@vTotquantity,@vTotNetAmt,@vTotGrossAmt,@vTransCount,@vCurrencyId 
if @old_context_info is null
	SET CONTEXT_INFO 0x
else
	SET CONTEXT_INFO @old_context_info
GO
-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : SP_REPORT
-- Description       : This procedure is to be executed on the XCenter database to populate the flash report tables.
--                      It calls sp_flash for each record in the trn_trans table where the flash_sales_flag is zero
--                      to generate the data.  All of the report / business logic will be kept in sp_flash.
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-- PGH 04/25/11		Added the options FAST_FORWARD READ_ONLY to the main cursor to improve performance.
-- BCW 12/05/13		Added optional parameters and logging.
-------------------------------------------------------------------------------------------------------------------
PRINT 'dbo.sp_report';

IF EXISTS (Select * From sysobjects Where name = 'sp_report' and type = 'P')
  DROP PROCEDURE sp_report;
GO

CREATE PROCEDURE sp_report
(
  @job_id     INT     =0,
  @firstLoc_id  INT     =0,
  @lastLoc_id   INT     =999999999,
  @start_date   DATETIME  ='1/1/1900',
  @end_date   DATETIME  ='12/31/9999',
  @batch_count  INT     =-1,
  @nologging    BIT     =0
)
AS
  DECLARE -- Keys
    @vOrganizationId    int,
    @vRetailLocationId  int,
    @vBusinessDate    datetime,
    @vWrkstnId      bigint,
    @vTransSeq      bigint,
    @starttime      DATETIME,
    @sql          nvarchar(MAX);

set @starttime=GETDATE()

  DECLARE @staging TABLE (
    organization_id  INT       NOT NULL,
    rtl_loc_id       INT       NOT NULL,
    business_date    DATETIME  NOT NULL,
    wkstn_id         BIGINT    NOT NULL,
    trans_seq        BIGINT    NOT NULL
  )

if OBJECT_ID('log_sp_report') IS NULL
  SET @nologging=1

SET @sql = 'SELECT '

if @batch_count > -1
  SET @sql = @sql + ' top(' + cast(@batch_count as nvarchar(10)) + ') '
SET @sql = @sql + 'trn.organization_id, 
          trn.rtl_loc_id, 
          trn.business_date, 
          trn.wkstn_id, 
          trn.trans_seq
   FROM trn_trans trn with (READPAST)

   LEFT JOIN tsn_tndr_control_trans tndr
    ON trn.organization_id = tndr.organization_id
    AND trn.rtl_loc_id     = tndr.rtl_loc_id
    AND trn.business_date  = tndr.business_date
    AND trn.wkstn_id       = tndr.wkstn_id
    AND trn.trans_seq      = tndr.trans_seq
    AND trn.flash_sales_flag = 0

   WHERE trn.flash_sales_flag = 0
   AND trn.trans_typcode in (''RETAIL_SALE'',''POST_VOID'',''TENDER_CONTROL'')
   AND trn.trans_statcode not like ''CANCEL%''
   AND (tndr.typcode IS NULL OR tndr.typcode IN (''PAID_IN'', ''PAID_OUT''))
   AND (trn.trans_typcode <> ''TENDER_CONTROL'' AND tndr.typcode IS NULL)'

if @firstLoc_id <> 0 OR @lastLoc_id <> 999999999
  SET @sql = @sql + ' AND trn.rtl_loc_id between ' + cast(@firstLoc_id as nvarchar(10)) + ' AND ' + cast(@lastLoc_id as varchar(10))

if @start_date <> '1/1/1900' OR @end_date <> '12/31/9999'
  SET @sql = @sql + ' AND trn.business_date between ''' + cast(@start_date as nvarchar(19)) + ''' AND ''' + cast(@end_date as varchar(19)) + ''''

if @nologging = 0
SET @sql = @sql + ' ORDER BY trn.business_date, trn.rtl_loc_id, trn.begin_datetime';

INSERT @staging (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq) exec(@sql)

  DECLARE cur_main CURSOR FAST_FORWARD FOR
  SELECT organization_id, 
          rtl_loc_id, 
          business_date, 
          wkstn_id, 
          trans_seq
   FROM @staging

  if @nologging=0
    insert into log_sp_report WITH(ROWLOCK) (job_id,loc_id,business_date,job_start,completed,expected)
    select @job_id, rtl_loc_id, business_date, @starttime, 0, COUNT(*)
    from @staging
    group by rtl_loc_id,business_date

  OPEN cur_main;

  WHILE 1 = 1 BEGIN
    FETCH FROM cur_main 
      INTO @vOrganizationId,
           @vRetailLocationId, 
           @vBusinessDate, 
           @vWrkstnId, 
           @vTransSeq;
  
  IF @@FETCH_STATUS <> 0 
      BREAK;

  if @nologging=0
    update log_sp_report WITH(ROWLOCK) set start_dt = GETDATE() where loc_id = @vRetailLocationId and business_date=@vBusinessDate and job_start=@starttime and job_id=@job_id and start_dt is null

  EXEC sp_flash @vOrganizationId,
          @vRetailLocationId, 
          @vBusinessDate, 
          @vWrkstnId, 
          @vTransSeq;

  if @nologging=0
    update log_sp_report WITH(ROWLOCK) set completed = completed + 1,end_dt = GETDATE() where loc_id = @vRetailLocationId and business_date=@vBusinessDate and job_start=@starttime and job_id=@job_id

  END;
  CLOSE cur_main;
  DEALLOCATE cur_main;

if @nologging=0
  update log_sp_report WITH(ROWLOCK) set job_end = GETDATE() where job_start=@starttime and job_id=@job_id
GO
/* 
 * TRIGGER: [dbo].[trg_insert_trl_returned_item_journal] 
 */

PRINT 'TRIGGER: trg_insert_trl_returned_item_journal';


IF EXISTS (Select * From sysobjects Where name = 'trg_insert_trl_returned_item_journal' and type = 'TR')
  DROP TRIGGER trg_insert_trl_returned_item_journal;
GO

CREATE TRIGGER trg_insert_trl_returned_item_journal
    ON trl_returned_item_journal
    AFTER INSERT
AS
  BEGIN
    DECLARE @new_organization_id int,
            @new_rtl_loc_id int,
            @new_wkstn_id bigint,
            @new_business_date datetime,
            @new_trans_seq bigint,
            @new_rtrans_lineitm_seq int,
            @new_returned_count decimal(11, 2);

    SELECT @new_organization_id = organization_id,
           @new_rtl_loc_id = rtl_loc_id,
           @new_wkstn_id = wkstn_id,
           @new_business_date = business_date,
           @new_trans_seq = trans_seq,    
           @new_rtrans_lineitm_seq = rtrans_lineitm_seq,
           @new_returned_count = returned_count
      FROM inserted;

    IF EXISTS (
        Select 1 From trn_trans trans
          Where trans.organization_id = @new_organization_id
            And trans.rtl_loc_id = @new_rtl_loc_id
            And trans.wkstn_id = @new_wkstn_id
            And trans.business_date = @new_business_date
            And trans.trans_seq = @new_trans_seq) 
    BEGIN
      IF EXISTS (
          Select 1 From trl_returned_item_count With (NOLOCK) 
            Where organization_id = @new_organization_id 
              And rtl_loc_id = @new_rtl_loc_id 
              And wkstn_id = @new_wkstn_id 
              And business_date = @new_business_date 
              And trans_seq = @new_trans_seq 
              And rtrans_lineitm_seq = @new_rtrans_lineitm_seq)
      BEGIN
        UPDATE trl_returned_item_count 
          SET returned_count = returned_count + @new_returned_count
          WHERE organization_id = @new_organization_id 
            AND rtl_loc_id = @new_rtl_loc_id 
            AND wkstn_id = @new_wkstn_id 
            AND business_date = @new_business_date 
            AND trans_seq = @new_trans_seq 
            AND rtrans_lineitm_seq = @new_rtrans_lineitm_seq;
      END
    ELSE
      BEGIN
        INSERT INTO trl_returned_item_count
            (organization_id, rtl_loc_id, wkstn_id, business_date, trans_seq, rtrans_lineitm_seq, returned_count)
          VALUES
            (@new_organization_id, @new_rtl_loc_id, @new_wkstn_id, @new_business_date, 
            @new_trans_seq, @new_rtrans_lineitm_seq, @new_returned_count);
      END
    END
  END
GO
-- ***************************************************************************
-- This script will apply after all schema artifacts have been upgraded to a given version.  It is
-- generally useful for performing conversions between legacy and modern representations of affected
-- data sets.
--
-- Source version:  18.0.x
-- Target version:  19.0.0
-- DB platform:     Microsoft SQL Server 2012/2014/2016
-- ***************************************************************************

-- LEAVE BLANK LINE BELOW

INSERT INTO ctl_version_history (
    organization_id, base_schema_version, customer_schema_version, base_schema_date, 
    create_user_id, create_date, update_user_id, update_date)
VALUES (
    $(OrgID), '20.0.1.0.40', '0.0.0 - 0.0', getDate(), 
    'Oracle', getDate(), 'Oracle', getDate());

GO
