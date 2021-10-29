-- ***************************************************************************
-- This script "hybridizes" a database such that its schema will be compatible with application
-- clients running on two different versions of Xstore.
-- 
-- This is useful when an Xstore version upgrade is being implemented gradually, such that at any 
-- given time, some clients may be running under the old version of the application while others are
-- running under the new version.  Xcenter is the most common target for scripts of this kind, as it
-- generally must support all of an organization's Xstore clients simultaneously.
--
-- NOTE: Do NOT run an "upgrade" script against a database you wish instead to hybridize until such
-- time as all clients have been upgraded to the target Xstore version.
-- 
-- "Hybridize" scripts are less destructive than their "upgrade" counterparts.  Whereas the 
-- latter is free to remove all remnants of the legacy schema it upgrades, the former -- which must
-- still support clients compatible with that legacy schema -- cannot.  Table and column drops, for
-- example, are usually excluded from "hybridize" scripts or handled in some other non-destructive 
-- manner.  "Hybridize" scripts and "upgrade" scripts are therefore mutually exclusive during a 
-- phased upgrade process.
--
-- After an A-to-B upgrade process is complete, convert any A-and-B databases previously modified by
-- this script to their A-to-B final forms by running the following against them in the order 
-- specified:
-- (1) "unhybridize" A-and-B
--
-- Source version:  19.0.*
-- Target version:  20.0.0
-- DB platform:     Microsoft SQL Server 2012/2014/2016
-- ***************************************************************************

PRINT '*******************************************';
PRINT '*****           HYBRIDIZING           *****';
PRINT '***** From:  19.0.*                   *****';
PRINT '*****   To:  20.0.0                   *****';
PRINT '*******************************************';
GO


PRINT '***** Prefix scripts start *****';


IF  OBJECT_ID('Create_Property_Table') is not null
       DROP PROCEDURE Create_Property_Table
GO

CREATE PROCEDURE Create_Property_Table
  -- Add the parameters for the stored procedure here
  @tableName varchar(30)
AS
BEGIN
  declare @sql varchar(max),
      @column varchar(30),
      @pk varchar(max),
      @datatype varchar(10),
      @maxlen varchar(4),
      @prec varchar(3),
      @scale varchar(3),
      @deflt varchar(50);
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

  set @sql=@sql + 'property_code varchar(30) NOT NULL,
    type varchar(30) NULL,
    string_value varchar(4000) NULL,
    date_value datetime NULL,
    decimal_value decimal(17,6) NULL,
    create_date datetime NULL,
    create_user_id varchar(256) NULL,
    update_date datetime NULL,
    update_user_id varchar(256) NULL,
    record_state varchar(30) NULL,
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

CREATE FUNCTION dbo.SP_DEFAULT_CONSTRAINT_EXISTS (@tableName varchar(max), @columnName varchar(max))
RETURNS varchar(255)
AS 
BEGIN
    DECLARE @return varchar(255)
    
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

CREATE FUNCTION dbo.SP_PK_CONSTRAINT_EXISTS (@tableName varchar(max))
RETURNS varchar(255)
AS 
BEGIN
    DECLARE @return varchar(255)
    
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
[uuid] VARCHAR(36) NOT NULL,
[rtl_loc_id] INT,
[wkstn_id] BIGINT,
[timestamp_end] DATETIME,
[cust_email] VARCHAR(254),
[sale_items_count] INT,
[trans_total] DECIMAL(17, 6),
[serialized_data] VARBINARY(MAX) NOT NULL,
[processed_flag] BIT DEFAULT (0) NOT NULL,
[create_user_id] VARCHAR(256),
[create_date] DATETIME,
[update_user_id] VARCHAR(256),
[update_date] DATETIME,
[record_state] VARCHAR(30), 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_offline_pos_transaction] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('ctl_offline_pos_transaction')+'];' 
  EXEC(@sql) 
    PRINT '     PK ctl_offline_pos_transaction dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction_P') ) IS NULL
  PRINT '     PK ctl_offline_pos_transaction_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_offline_pos_transaction_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('ctl_offline_pos_transaction_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK ctl_offline_pos_transaction_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction', 'uuid') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_offline_pos_transaction].[uuid] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_offline_pos_transaction] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_offline_pos_transaction','uuid')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_offline_pos_transaction.uuid default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_offline_pos_transaction ALTER COLUMN [uuid] VARCHAR(36) NOT NULL');
  PRINT '     Column ctl_offline_pos_transaction.uuid modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_offline_pos_transaction_P', 'uuid') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_offline_pos_transaction_P].[uuid] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_offline_pos_transaction_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_offline_pos_transaction_P','uuid')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_offline_pos_transaction_P.uuid default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_offline_pos_transaction_P ALTER COLUMN [uuid] VARCHAR(36) NOT NULL');
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
  DECLARE @sql varchar(max) 
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
[attachment_type] VARCHAR(60) NOT NULL,
[attachment_data] VARBINARY(MAX),
[create_user_id] VARCHAR(256),
[create_date] DATETIME,
[update_user_id] VARCHAR(256),
[update_date] DATETIME,
[record_state] VARCHAR(30), 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [tnd_tndr_options] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('tnd_tndr_options','fiscal_tndr_id')+'];' 
  EXEC(@sql) 
  PRINT '     tnd_tndr_options.fiscal_tndr_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE tnd_tndr_options ALTER COLUMN [fiscal_tndr_id] VARCHAR(60)');
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



PRINT '     Step Drop the trigger RECEIPT_DATA_COPY_CFDI starting...';
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'RECEIPT_DATA_COPY_CFDI') AND type in (N'TR'))
BEGIN
  DROP TRIGGER RECEIPT_DATA_COPY_CFDI;
  PRINT 'Trigger RECEIPT_DATA_COPY_CFDI dropped';
END
GO
PRINT '     Step Drop the trigger RECEIPT_DATA_COPY_CFDI end.';



PRINT '     Step Create the trigger RECEIPT_DATA_COPY_CFDI starting...';
DECLARE @SQL AS NVARCHAR(MAX)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'RECEIPT_DATA_COPY_CFDI') AND type in (N'TR'))
BEGIN
  PRINT 'Trigger to copy CFDI_XML to trn_trans_attachment table';
  SET @SQL = 'CREATE TRIGGER [dbo].[RECEIPT_DATA_COPY_CFDI] ON [dbo].[trn_receipt_data]
  AFTER INSERT AS
  BEGIN
    INSERT INTO trn_trans_attachment (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, attachment_type, attachment_data, create_date, create_user_id)
    SELECT t1.organization_id, t1.rtl_loc_id, t1.business_date, t1.wkstn_id, t1.trans_seq, ''MX_INVOICE'', t1.receipt_data, t1.create_date, ''SYSTEM''
    FROM inserted t1
    LEFT JOIN trn_trans_attachment t2
    ON t2.organization_id = t1.organization_id
    AND t2.rtl_loc_id = t1.rtl_loc_id
    AND t2.business_date = t1.business_date
    AND t2.wkstn_id = t1.wkstn_id
    AND t2.trans_seq = t1.trans_seq
    AND t2.attachment_type = ''MX_INVOICE''
    WHERE t1.receipt_id = ''CFDI_XML'' AND t1.receipt_data IS NOT NULL 
    AND t2.organization_id IS NULL;
  END'
  EXEC (@SQL)
END
GO
PRINT '     Step Create the trigger RECEIPT_DATA_COPY_CFDI end.';



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
[deal_id] VARCHAR(60) NOT NULL,
[rtl_loc_id] INT NOT NULL,
[create_user_id] VARCHAR(256),
[create_date] DATETIME,
[update_user_id] VARCHAR(256),
[update_date] DATETIME,
[record_state] VARCHAR(30), 
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
[request_type] VARCHAR(30),
[store_created_flag] BIT,
[description] VARCHAR(254),
[start_date_str] VARCHAR(8) NOT NULL,
[end_date_str] VARCHAR(8),
[active_date_str] VARCHAR(8),
[assigned_server_host] VARCHAR(254),
[assigned_server_port] INT,
[status] VARCHAR(30) NOT NULL,
[approve_reject_notes] VARCHAR(254),
[use_store_tax_loc_flag] BIT DEFAULT (1) NOT NULL,
[create_user_id] VARCHAR(256),
[create_date] DATETIME,
[update_user_id] VARCHAR(256),
[update_date] DATETIME,
[record_state] VARCHAR(30), 
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
    EXEC('    ALTER TABLE loc_temp_store_request ADD [start_date_str] VARCHAR(8) DEFAULT (''changeit'') NOT NULL');
    PRINT '     Column loc_temp_store_request.start_date_str created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_temp_store_request') AND name in (N'end_date_str'))
  PRINT '      Column loc_temp_store_request.end_date_str already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_temp_store_request ADD [end_date_str] VARCHAR(8)');
    PRINT '     Column loc_temp_store_request.end_date_str created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_temp_store_request') AND name in (N'active_date_str'))
  PRINT '      Column loc_temp_store_request.active_date_str already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_temp_store_request ADD [active_date_str] VARCHAR(8)');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_temp_store_request] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_temp_store_request','start_date_str')+'];' 
  EXEC(@sql) 
  PRINT '     loc_temp_store_request.start_date_str default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_temp_store_request ALTER COLUMN [start_date_str] VARCHAR(8) NOT NULL');
  PRINT '     Column loc_temp_store_request.start_date_str modify';
END
GO
PRINT '     Step Alter Column: DTX[TemporaryStoreRequest] Field[[Field=startDateStr]] end.';



PRINT '     Step Alter Column: DTX[PartyIdCrossReference] Field[[Field=organizationId, Field=partyId]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref') ) IS NULL
  PRINT '     PK crm_party_id_xref is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_id_xref')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_id_xref dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref_P') ) IS NULL
  PRINT '     PK crm_party_id_xref_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_id_xref_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_id_xref_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_id_xref', 'organization_id') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_id_xref].[organization_id] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_id_xref')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_id_xref dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_id_xref_P') ) IS NULL
  PRINT '     PK crm_party_id_xref_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_id_xref_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_id_xref_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_id_xref_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_id_xref', 'party_id') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_id_xref].[party_id] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('trn_report_data')+'];' 
  EXEC(@sql) 
    PRINT '     PK trn_report_data dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data_P') ) IS NULL
  PRINT '     PK trn_report_data_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('trn_report_data_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK trn_report_data_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_report_data', 'report_id') ) IS NULL
  PRINT '     Default value Constraint for column [trn_report_data].[report_id] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trn_report_data','report_id')+'];' 
  EXEC(@sql) 
  PRINT '     trn_report_data.report_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE trn_report_data ALTER COLUMN [report_id] VARCHAR(60) NOT NULL');
  PRINT '     Column trn_report_data.report_id modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_report_data_P', 'report_id') ) IS NULL
  PRINT '     Default value Constraint for column [trn_report_data_P].[report_id] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('trn_report_data_P','report_id')+'];' 
  EXEC(@sql) 
  PRINT '     trn_report_data_P.report_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE trn_report_data_P ALTER COLUMN [report_id] VARCHAR(60) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_wkstn_config_data] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_wkstn_config_data','field_name')+'];' 
  EXEC(@sql) 
  PRINT '     loc_wkstn_config_data.field_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_wkstn_config_data ALTER COLUMN [field_name] VARCHAR(100) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_wkstn_config_data] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_wkstn_config_data','field_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_wkstn_config_data.field_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_wkstn_config_data ALTER COLUMN [field_value] VARCHAR(1024)');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_org_hierarchy')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_org_hierarchy dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy_P') ) IS NULL
  PRINT '     PK loc_org_hierarchy_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_org_hierarchy_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_org_hierarchy_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_org_hierarchy', 'org_code') ) IS NULL
  PRINT '     Default value Constraint for column [loc_org_hierarchy].[org_code] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_org_hierarchy','org_code')+'];' 
  EXEC(@sql) 
  PRINT '     loc_org_hierarchy.org_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy ALTER COLUMN [org_code] VARCHAR(30) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_org_hierarchy_P','org_code')+'];' 
  EXEC(@sql) 
  PRINT '     loc_org_hierarchy_P.org_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy_P ALTER COLUMN [org_code] VARCHAR(30) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_org_hierarchy')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_org_hierarchy dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_org_hierarchy_P') ) IS NULL
  PRINT '     PK loc_org_hierarchy_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_org_hierarchy_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_org_hierarchy_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_org_hierarchy', 'org_value') ) IS NULL
  PRINT '     Default value Constraint for column [loc_org_hierarchy].[org_value] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_org_hierarchy','org_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_org_hierarchy.org_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy ALTER COLUMN [org_value] VARCHAR(60) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_org_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_org_hierarchy_P','org_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_org_hierarchy_P.org_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_org_hierarchy_P ALTER COLUMN [org_value] VARCHAR(60) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_pricing_hierarchy')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_pricing_hierarchy dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy_P') ) IS NULL
  PRINT '     PK loc_pricing_hierarchy_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_pricing_hierarchy_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_pricing_hierarchy_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_pricing_hierarchy', 'level_code') ) IS NULL
  PRINT '     Default value Constraint for column [loc_pricing_hierarchy].[level_code] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_pricing_hierarchy','level_code')+'];' 
  EXEC(@sql) 
  PRINT '     loc_pricing_hierarchy.level_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy ALTER COLUMN [level_code] VARCHAR(30) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_pricing_hierarchy_P','level_code')+'];' 
  EXEC(@sql) 
  PRINT '     loc_pricing_hierarchy_P.level_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy_P ALTER COLUMN [level_code] VARCHAR(30) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_pricing_hierarchy')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_pricing_hierarchy dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('loc_pricing_hierarchy_P') ) IS NULL
  PRINT '     PK loc_pricing_hierarchy_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('loc_pricing_hierarchy_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK loc_pricing_hierarchy_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_pricing_hierarchy', 'level_value') ) IS NULL
  PRINT '     Default value Constraint for column [loc_pricing_hierarchy].[level_value] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_pricing_hierarchy','level_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_pricing_hierarchy.level_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy ALTER COLUMN [level_value] VARCHAR(60) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [loc_pricing_hierarchy_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('loc_pricing_hierarchy_P','level_value')+'];' 
  EXEC(@sql) 
  PRINT '     loc_pricing_hierarchy_P.level_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE loc_pricing_hierarchy_P ALTER COLUMN [level_value] VARCHAR(60) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [itm_restrict_gs1] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('itm_restrict_gs1','org_code')+'];' 
  EXEC(@sql) 
  PRINT '     itm_restrict_gs1.org_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE itm_restrict_gs1 ALTER COLUMN [org_code] VARCHAR(30) NOT NULL');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [itm_restrict_gs1] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('itm_restrict_gs1','org_value')+'];' 
  EXEC(@sql) 
  PRINT '     itm_restrict_gs1.org_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE itm_restrict_gs1 ALTER COLUMN [org_value] VARCHAR(60) NOT NULL');
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_locale_information] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_locale_information')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_locale_information dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_locale_information_P') ) IS NULL
  PRINT '     PK crm_party_locale_information_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_locale_information_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_locale_information_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_locale_information_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_locale_information', 'party_locale_seq') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_locale_information].[party_locale_seq] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_email] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_email')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_email dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('crm_party_email_P') ) IS NULL
  PRINT '     PK crm_party_email_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_party_email_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('crm_party_email_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK crm_party_email_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party_email', 'email_sequence') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party_email].[email_sequence] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_trans_type] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_nfe_trans_type','notes')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_nfe_trans_type.notes default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_nfe_trans_type ALTER COLUMN [notes] VARCHAR(2000)');
  PRINT '     Column cpaf_nfe_trans_type.notes modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_nfe_trans_type', 'rule_type') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_nfe_trans_type].[rule_type] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_trans_type] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_nfe_trans_type','rule_type')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_nfe_trans_type.rule_type default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_nfe_trans_type ALTER COLUMN [rule_type] VARCHAR(30)');
  PRINT '     Column cpaf_nfe_trans_type.rule_type modify';
END
GO
PRINT '     Step Alter Column: DTX[PafNfeTransType] Field[[Field=notes, Field=ruleType]] end.';



PRINT '     Step Alter Column: DTX[TransactionReportData] Field[[Field=workstationId]] starting...';
IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data') ) IS NULL
  PRINT '     PK trn_report_data is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('trn_report_data')+'];' 
  EXEC(@sql) 
    PRINT '     PK trn_report_data dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('trn_report_data_P') ) IS NULL
  PRINT '     PK trn_report_data_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [trn_report_data_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('trn_report_data_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK trn_report_data_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trn_report_data', 'wkstn_id') ) IS NULL
  PRINT '     Default value Constraint for column [trn_report_data].[wkstn_id] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [rms_related_item_head] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('rms_related_item_head')+'];' 
  EXEC(@sql) 
    PRINT '     PK rms_related_item_head dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('rms_related_item_head', 'relationship_id') ) IS NULL
  PRINT '     Default value Constraint for column [rms_related_item_head].[relationship_id] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_tax_cst] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('cpaf_nfe_tax_cst')+'];' 
  EXEC(@sql) 
    PRINT '     PK cpaf_nfe_tax_cst dropped';
  END
GO


IF (SELECT [dbo].[SP_PK_CONSTRAINT_EXISTS]('cpaf_nfe_tax_cst_P') ) IS NULL
  PRINT '     PK cpaf_nfe_tax_cst_P is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_tax_cst_P] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('cpaf_nfe_tax_cst_P')+'];' 
  EXEC(@sql) 
    PRINT '     PK cpaf_nfe_tax_cst_P dropped';
  END
GO


IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_nfe_tax_cst', 'tax_loc_id') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_nfe_tax_cst].[tax_loc_id] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_tax_cst] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_nfe_tax_cst','tax_loc_id')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_nfe_tax_cst.tax_loc_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_nfe_tax_cst ALTER COLUMN [tax_loc_id] VARCHAR(60) NOT NULL');
  PRINT '     Column cpaf_nfe_tax_cst.tax_loc_id modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_nfe_tax_cst_P', 'tax_loc_id') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_nfe_tax_cst_P].[tax_loc_id] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_nfe_tax_cst_P] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_nfe_tax_cst_P','tax_loc_id')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_nfe_tax_cst_P.tax_loc_id default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_nfe_tax_cst_P ALTER COLUMN [tax_loc_id] VARCHAR(60) NOT NULL');
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [com_measurement] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('com_measurement','symbol')+'];' 
  EXEC(@sql) 
  PRINT '     com_measurement.symbol default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE com_measurement ALTER COLUMN [symbol] VARCHAR(254) NOT NULL');
  PRINT '     Column com_measurement.symbol modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('com_measurement', 'name') ) IS NULL
  PRINT '     Default value Constraint for column [com_measurement].[name] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [com_measurement] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('com_measurement','name')+'];' 
  EXEC(@sql) 
  PRINT '     com_measurement.name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE com_measurement ALTER COLUMN [name] VARCHAR(254) NOT NULL');
  PRINT '     Column com_measurement.name modify';
END
GO
PRINT '     Step Alter Column: DTX[Measurement] Field[[Field=symbol, Field=name]] end.';



PRINT '     Step Alter Column: DTX[PafSatResponse] Field[[Field=signatureQRCODE]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_sat_response', 'signature_QR_code') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_sat_response].[signature_QR_code] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cpaf_sat_response] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cpaf_sat_response','signature_QR_code')+'];' 
  EXEC(@sql) 
  PRINT '     cpaf_sat_response.signature_QR_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cpaf_sat_response ALTER COLUMN [signature_qr_code] VARCHAR(2000)');
  PRINT '     Column cpaf_sat_response.signature_QR_code modify';
END
GO
PRINT '     Step Alter Column: DTX[PafSatResponse] Field[[Field=signatureQRCODE]] end.';



PRINT '     Step Alter Column: DTX[PafNfeQueueTrans] Field[[Field=inactive]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cpaf_nfe_queue_trans', 'inactive_flag') ) IS NULL
  PRINT '     Default value Constraint for column [cpaf_nfe_queue_trans].[inactive_flag] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_device_information] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_device_information','device_name')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_device_information.device_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_device_information ALTER COLUMN [device_name] VARCHAR(255)');
  PRINT '     Column ctl_device_information.device_name modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_device_information', 'device_type') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_device_information].[device_type] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_device_information] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_device_information','device_type')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_device_information.device_type default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_device_information ALTER COLUMN [device_type] VARCHAR(255)');
  PRINT '     Column ctl_device_information.device_type modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_device_information', 'model') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_device_information].[model] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_device_information] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_device_information','model')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_device_information.model default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_device_information ALTER COLUMN [model] VARCHAR(255)');
  PRINT '     Column ctl_device_information.model modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_device_information', 'serial_number') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_device_information].[serial_number] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_device_information] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_device_information','serial_number')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_device_information.serial_number default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_device_information ALTER COLUMN [serial_number] VARCHAR(255)');
  PRINT '     Column ctl_device_information.serial_number modify';
END
GO
PRINT '     Step Alter Column: DTX[DeviceInformation] Field[[Field=deviceName, Field=deviceType, Field=model, Field=serialNumber]] end.';



PRINT '     Step Alter Column: DTX[SaleInvoice] Field[[Field=confirmSentFlag, Field=returnFlag, Field=confirmFlag, Field=voidPendingFlag]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('civc_invoice', 'confirm_sent_flag') ) IS NULL
  PRINT '     Default value Constraint for column [civc_invoice].[confirm_sent_flag] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [tax_tax_bracket] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('tax_tax_bracket','org_code')+'];' 
  EXEC(@sql) 
  PRINT '     tax_tax_bracket.org_code default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE tax_tax_bracket ALTER COLUMN [org_code] VARCHAR(30)');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [tax_tax_bracket] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('tax_tax_bracket','org_value')+'];' 
  EXEC(@sql) 
  PRINT '     tax_tax_bracket.org_value default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE tax_tax_bracket ALTER COLUMN [org_value] VARCHAR(60)');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_event_log] DROP CONSTRAINT [''+dbo.SP_DEFAULT_CONSTRAINT_EXISTS(''ctl_event_log'',''log_message'')+''];' 
  EXEC(@sql) 
  PRINT '     ctl_event_log.log_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_event_log ALTER COLUMN [log_message] VARCHAR(MAX) NOT NULL');
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
    EXEC('    ALTER TABLE RMS_RELATED_ITEM_HEAD ADD [record_state] VARCHAR(30)');
    PRINT '     RMS_RELATED_ITEM_HEAD.record_state created';
  END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RMS_DIFF_GROUP_DETAIL') AND name in (N'record_state'))
  PRINT '      RMS_DIFF_GROUP_DETAIL.record_state already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE RMS_DIFF_GROUP_DETAIL ADD [record_state] VARCHAR(30)');
    PRINT '     RMS_DIFF_GROUP_DETAIL.record_state created';
  END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'LOG_SP_REPORT') AND name in (N'record_state'))
  PRINT '      LOG_SP_REPORT.record_state already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE LOG_SP_REPORT ADD [record_state] VARCHAR(30)');
    PRINT '     LOG_SP_REPORT.record_state created';
  END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RMS_DIFF_GROUP_HEAD') AND name in (N'record_state'))
  PRINT '      RMS_DIFF_GROUP_HEAD.record_state already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE RMS_DIFF_GROUP_HEAD ADD [record_state] VARCHAR(30)');
    PRINT '     RMS_DIFF_GROUP_HEAD.record_state created';
  END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'RMS_DIFF_IDS') AND name in (N'record_state'))
  PRINT '      RMS_DIFF_IDS.record_state already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE RMS_DIFF_IDS ADD [record_state] VARCHAR(30)');
    PRINT '     RMS_DIFF_IDS.record_state created';
  END
GO

BEGIN
    EXEC('ALTER TABLE trn_report_data ALTER COLUMN [record_state] VARCHAR(30)');
  PRINT '     trn_report_data.record_state modify';
END
GO

BEGIN
    EXEC('ALTER TABLE loc_wkstn_config_data ALTER COLUMN [record_state] VARCHAR(30)');
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
    EXEC('    ALTER TABLE log_sp_report ADD [create_user_id] VARCHAR(256)');
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
    EXEC('    ALTER TABLE log_sp_report ADD [update_user_id] VARCHAR(256)');
    PRINT '     Column log_sp_report.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[SpReport] Column[[Field=createDate, Field=createUserId, Field=updateDate, Field=updateUserId]] end.';



PRINT '     Step Add Column: DTX[RelatedItemHead] Column[[Field=createUserId, Field=updateUserId]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_related_item_head') AND name in (N'create_user_id'))
  PRINT '      Column rms_related_item_head.create_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_related_item_head ADD [create_user_id] VARCHAR(256)');
    PRINT '     Column rms_related_item_head.create_user_id created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_related_item_head') AND name in (N'update_user_id'))
  PRINT '      Column rms_related_item_head.update_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_related_item_head ADD [update_user_id] VARCHAR(256)');
    PRINT '     Column rms_related_item_head.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[RelatedItemHead] Column[[Field=createUserId, Field=updateUserId]] end.';



PRINT '     Step Add Column: DTX[DiffGroupDetail] Column[[Field=createUserId, Field=updateUserId]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_group_detail') AND name in (N'create_user_id'))
  PRINT '      Column rms_diff_group_detail.create_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_group_detail ADD [create_user_id] VARCHAR(256)');
    PRINT '     Column rms_diff_group_detail.create_user_id created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_group_detail') AND name in (N'update_user_id'))
  PRINT '      Column rms_diff_group_detail.update_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_group_detail ADD [update_user_id] VARCHAR(256)');
    PRINT '     Column rms_diff_group_detail.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[DiffGroupDetail] Column[[Field=createUserId, Field=updateUserId]] end.';



PRINT '     Step Add Column: DTX[DiffGroupHead] Column[[Field=createUserId, Field=updateUserId]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_group_head') AND name in (N'create_user_id'))
  PRINT '      Column rms_diff_group_head.create_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_group_head ADD [create_user_id] VARCHAR(256)');
    PRINT '     Column rms_diff_group_head.create_user_id created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_group_head') AND name in (N'update_user_id'))
  PRINT '      Column rms_diff_group_head.update_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_group_head ADD [update_user_id] VARCHAR(256)');
    PRINT '     Column rms_diff_group_head.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[DiffGroupHead] Column[[Field=createUserId, Field=updateUserId]] end.';



PRINT '     Step Add Column: DTX[DiffIds] Column[[Field=createUserId, Field=updateUserId]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_ids') AND name in (N'create_user_id'))
  PRINT '      Column rms_diff_ids.create_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_ids ADD [create_user_id] VARCHAR(256)');
    PRINT '     Column rms_diff_ids.create_user_id created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'rms_diff_ids') AND name in (N'update_user_id'))
  PRINT '      Column rms_diff_ids.update_user_id already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE rms_diff_ids ADD [update_user_id] VARCHAR(256)');
    PRINT '     Column rms_diff_ids.update_user_id created';
  END
GO


PRINT '     Step Add Column: DTX[DiffIds] Column[[Field=createUserId, Field=updateUserId]] end.';



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
    EXEC('    ALTER TABLE loc_legal_entity ADD [legal_form] VARCHAR(60)');
    PRINT '     Column loc_legal_entity.legal_form created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'social_capital'))
  PRINT '      Column loc_legal_entity.social_capital already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [social_capital] VARCHAR(60)');
    PRINT '     Column loc_legal_entity.social_capital created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'companies_register_number'))
  PRINT '      Column loc_legal_entity.companies_register_number already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [companies_register_number] VARCHAR(30)');
    PRINT '     Column loc_legal_entity.companies_register_number created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'fax_number'))
  PRINT '      Column loc_legal_entity.fax_number already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [fax_number] VARCHAR(32)');
    PRINT '     Column loc_legal_entity.fax_number created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'phone_number'))
  PRINT '      Column loc_legal_entity.phone_number already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [phone_number] VARCHAR(32)');
    PRINT '     Column loc_legal_entity.phone_number created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'web_site'))
  PRINT '      Column loc_legal_entity.web_site already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [web_site] VARCHAR(254)');
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
[card_token] VARCHAR(254) NOT NULL,
[card_alias] VARCHAR(254),
[card_type] VARCHAR(60),
[card_last_four] VARCHAR(4),
[expr_date] VARCHAR(64),
[shopper_ref] VARCHAR(254),
[create_user_id] VARCHAR(256),
[create_date] DATETIME,
[update_user_id] VARCHAR(256),
[update_date] DATETIME,
[record_state] VARCHAR(30), 
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
    EXEC('    ALTER TABLE cfra_rcpt_dup ADD [document_type] VARCHAR(30)');
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cfra_technical_event_log] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cfra_technical_event_log','signature_source')+'];' 
  EXEC(@sql) 
  PRINT '     cfra_technical_event_log.signature_source default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cfra_technical_event_log ALTER COLUMN [signature_source] VARCHAR(4000)');
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
[reprint_id] VARCHAR(30) NOT NULL,
[doc_number] VARCHAR(30) NOT NULL,
[reprint_number] INT,
[operator_code] VARCHAR(30),
[business_date] DATETIME,
[reprint_date] DATETIME,
[document_type] VARCHAR(32) NOT NULL,
[inv_rtl_loc_id] INT,
[inv_wkstn_id] BIGINT,
[inv_business_year] INT,
[inv_sequence_id] VARCHAR(255),
[inv_sequence_nbr] BIGINT,
[postponement_flag] BIT DEFAULT (0),
[signature] VARCHAR(1024),
[signature_source] VARCHAR(1024),
[signature_version] INT,
[create_user_id] VARCHAR(256),
[create_date] DATETIME,
[update_user_id] VARCHAR(256),
[update_date] DATETIME,
[record_state] VARCHAR(30), 
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



PRINT '     Step Trigger for Incoming Mexican pending invoice conversion removed starting...';
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('civc_invoice_mx_pending') AND type in (N'TR'))
BEGIN
  DROP TRIGGER civc_invoice_mx_pending;
  PRINT 'Trigger civc_invoice_mx_pending dropped';
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('civc_invoice_xref_mx_pending') AND type in (N'TR'))
BEGIN
  DROP TRIGGER civc_invoice_xref_mx_pending;
  PRINT 'Trigger civc_invoice_xref_mx_pending dropped';
END
GO
PRINT '     Step Trigger for Incoming Mexican pending invoice conversion removed end.';



PRINT '     Step Trigger for Incoming Mexican pending invoice conversion created starting...';
DECLARE @SQL AS NVARCHAR(MAX)
BEGIN
  SET @SQL = 'CREATE TRIGGER civc_invoice_mx_pending ON civc_invoice 
  AFTER INSERT AS 
  BEGIN 
    UPDATE civc_invoice SET sequence_id = ''PENDING_'' + t0.sequence_id , invoice_type = ''PENDING_GLOBAL_'' + t0.invoice_type
    FROM inserted t0
    INNER JOIN civc_invoice t1
    ON t1.organization_id = t0.organization_id
    AND t1.rtl_loc_id = t0.rtl_loc_id
    AND t1.wkstn_id = t0.wkstn_id
    AND t1.business_year = t0.business_year
    AND t1.sequence_id = t0.sequence_id
    AND t1.sequence_nbr = t0.sequence_nbr
    INNER JOIN loc_rtl_loc t2 
    ON t1.organization_id = t2.organization_id 
    AND t1.rtl_loc_id = t2.rtl_loc_id 
    WHERE t0.ext_invoice_id IS NULL
    AND t0.sequence_id NOT LIKE ''PENDING%''
    AND t2.country = ''MX''
  END'
  EXEC (@SQL)
  PRINT '        Trigger for Incoming Mexican pending invoice conversion created';
END
GO

DECLARE @SQL AS NVARCHAR(MAX)
BEGIN
  SET @SQL = 'CREATE TRIGGER civc_invoice_xref_mx_pending ON civc_invoice_xref 
  AFTER INSERT AS 
  BEGIN 
    UPDATE civc_invoice_xref SET civc_invoice_xref.sequence_id = ''PENDING_'' + civc_invoice_xref.sequence_id 
    FROM civc_invoice_xref 
    INNER JOIN civc_invoice 
      ON civc_invoice.organization_id = civc_invoice_xref.organization_id 
            AND civc_invoice.rtl_loc_id = civc_invoice_xref.rtl_loc_id 
            AND civc_invoice.wkstn_id = civc_invoice_xref.wkstn_id
            AND civc_invoice.business_year = civc_invoice_xref.business_year
            AND civc_invoice.sequence_id = ''PENDING_'' + civc_invoice_xref.sequence_id
            AND civc_invoice.sequence_nbr = civc_invoice_xref.sequence_nbr
            AND civc_invoice.sequence_id LIKE ''PENDING%''
    WHERE civc_invoice_xref.sequence_id NOT LIKE ''PENDING%'';
  END'
  EXEC (@SQL)
  PRINT '        Trigger for Incoming Mexican pending invoice reference conversion created';
END
GO
PRINT '     Step Trigger for Incoming Mexican pending invoice conversion created end.';



PRINT '     Step Alter Column: DTX[Party] Field[[Field=organizationName]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_party', 'organization_name') ) IS NULL
  PRINT '     Default value Constraint for column [crm_party].[organization_name] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_party] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_party','organization_name')+'];' 
  EXEC(@sql) 
  PRINT '     crm_party.organization_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_party ALTER COLUMN [organization_name] VARCHAR(254)');
  PRINT '     Column crm_party.organization_name modify';
END
GO
PRINT '     Step Alter Column: DTX[Party] Field[[Field=organizationName]] end.';



PRINT '     Step Alter Column: DTX[FulfillmentModifier] Field[[Field=organizationName]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_fulfillment_mod', 'organization_name') ) IS NULL
  PRINT '     Default value Constraint for column [xom_fulfillment_mod].[organization_name] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [xom_fulfillment_mod] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_fulfillment_mod','organization_name')+'];' 
  EXEC(@sql) 
  PRINT '     xom_fulfillment_mod.organization_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_fulfillment_mod ALTER COLUMN [organization_name] VARCHAR(254)');
  PRINT '     Column xom_fulfillment_mod.organization_name modify';
END
GO
PRINT '     Step Alter Column: DTX[FulfillmentModifier] Field[[Field=organizationName]] end.';



PRINT '     Step Alter Column: DTX[CustomerModifier] Field[[Field=organizationName]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_customer_mod', 'organization_name') ) IS NULL
  PRINT '     Default value Constraint for column [xom_customer_mod].[organization_name] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [xom_customer_mod] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_customer_mod','organization_name')+'];' 
  EXEC(@sql) 
  PRINT '     xom_customer_mod.organization_name default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_customer_mod ALTER COLUMN [organization_name] VARCHAR(254)');
  PRINT '     Column xom_customer_mod.organization_name modify';
END
GO
PRINT '     Step Alter Column: DTX[CustomerModifier] Field[[Field=organizationName]] end.';



PRINT '     Step Alter Column: DTX[DeTseDeviceConfig] Field[[Field=tseCertificate, Field=tseConfig]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cger_tse_device', 'tse_certificate') ) IS NULL
  PRINT '     Default value Constraint for column [cger_tse_device].[tse_certificate] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cger_tse_device] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cger_tse_device','tse_certificate')+'];' 
  EXEC(@sql) 
  PRINT '     cger_tse_device.tse_certificate default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cger_tse_device ALTER COLUMN [tse_certificate] VARCHAR(4000)');
  PRINT '     Column cger_tse_device.tse_certificate modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('cger_tse_device', 'tse_config') ) IS NULL
  PRINT '     Default value Constraint for column [cger_tse_device].[tse_config] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cger_tse_device] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('cger_tse_device','tse_config')+'];' 
  EXEC(@sql) 
  PRINT '     cger_tse_device.tse_config default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE cger_tse_device ALTER COLUMN [tse_config] VARCHAR(4000)');
  PRINT '     Column cger_tse_device.tse_config modify';
END
GO
PRINT '     Step Alter Column: DTX[DeTseDeviceConfig] Field[[Field=tseCertificate, Field=tseConfig]] end.';



PRINT '     Step Alter Column: DTX[ReceiptText] Field[[Field=receiptText]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('com_receipt_text', 'receipt_text') ) IS NULL
  PRINT '     Default value Constraint for column [com_receipt_text].[receipt_text] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [com_receipt_text] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('com_receipt_text','receipt_text')+'];' 
  EXEC(@sql) 
  PRINT '     com_receipt_text.receipt_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE com_receipt_text ALTER COLUMN [receipt_text] VARCHAR(4000) NOT NULL');
  PRINT '     Column com_receipt_text.receipt_text modify';
END
GO
PRINT '     Step Alter Column: DTX[ReceiptText] Field[[Field=receiptText]] end.';



PRINT '     Step Alter Column: DTX[DatabaseTranslation] Field[[Field=translation]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('com_translations', 'translation') ) IS NULL
  PRINT '     Default value Constraint for column [com_translations].[translation] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [com_translations] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('com_translations','translation')+'];' 
  EXEC(@sql) 
  PRINT '     com_translations.translation default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE com_translations ALTER COLUMN [translation] VARCHAR(4000)');
  PRINT '     Column com_translations.translation modify';
END
GO
PRINT '     Step Alter Column: DTX[DatabaseTranslation] Field[[Field=translation]] end.';



PRINT '     Step Alter Column: DTX[CustomerConsentInfo] Field[[Field=consent1Text, Field=consent2Text, Field=consent3Text, Field=consent4Text, Field=consent5Text, Field=termsAndConditions]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent1_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent1_text] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent1_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent1_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent1_text] VARCHAR(4000)');
  PRINT '     Column crm_consent_info.consent1_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent2_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent2_text] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent2_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent2_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent2_text] VARCHAR(4000)');
  PRINT '     Column crm_consent_info.consent2_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent3_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent3_text] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent3_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent3_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent3_text] VARCHAR(4000)');
  PRINT '     Column crm_consent_info.consent3_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent4_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent4_text] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent4_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent4_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent4_text] VARCHAR(4000)');
  PRINT '     Column crm_consent_info.consent4_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'consent5_text') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[consent5_text] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','consent5_text')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.consent5_text default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [consent5_text] VARCHAR(4000)');
  PRINT '     Column crm_consent_info.consent5_text modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('crm_consent_info', 'terms_and_conditions') ) IS NULL
  PRINT '     Default value Constraint for column [crm_consent_info].[terms_and_conditions] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [crm_consent_info] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('crm_consent_info','terms_and_conditions')+'];' 
  EXEC(@sql) 
  PRINT '     crm_consent_info.terms_and_conditions default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE crm_consent_info ALTER COLUMN [terms_and_conditions] VARCHAR(4000)');
  PRINT '     Column crm_consent_info.terms_and_conditions modify';
END
GO
PRINT '     Step Alter Column: DTX[CustomerConsentInfo] Field[[Field=consent1Text, Field=consent2Text, Field=consent3Text, Field=consent4Text, Field=consent5Text, Field=termsAndConditions]] end.';



PRINT '     Step Alter Column: DTX[DataLoaderFailure] Field[[Field=failedData, Field=failureMessage]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_dataloader_failure', 'failed_data') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_dataloader_failure].[failed_data] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_dataloader_failure] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_dataloader_failure','failed_data')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_dataloader_failure.failed_data default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_dataloader_failure ALTER COLUMN [failed_data] VARCHAR(4000)');
  PRINT '     Column ctl_dataloader_failure.failed_data modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('ctl_dataloader_failure', 'failure_message') ) IS NULL
  PRINT '     Default value Constraint for column [ctl_dataloader_failure].[failure_message] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [ctl_dataloader_failure] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('ctl_dataloader_failure','failure_message')+'];' 
  EXEC(@sql) 
  PRINT '     ctl_dataloader_failure.failure_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE ctl_dataloader_failure ALTER COLUMN [failure_message] VARCHAR(4000) NOT NULL');
  PRINT '     Column ctl_dataloader_failure.failure_message modify';
END
GO
PRINT '     Step Alter Column: DTX[DataLoaderFailure] Field[[Field=failedData, Field=failureMessage]] end.';



PRINT '     Step Alter Column: DTX[EmployeeAnswers] Field[[Field=challengeAnswer]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('hrs_employee_answers', 'challenge_answer') ) IS NULL
  PRINT '     Default value Constraint for column [hrs_employee_answers].[challenge_answer] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [hrs_employee_answers] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('hrs_employee_answers','challenge_answer')+'];' 
  EXEC(@sql) 
  PRINT '     hrs_employee_answers.challenge_answer default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE hrs_employee_answers ALTER COLUMN [challenge_answer] VARCHAR(4000)');
  PRINT '     Column hrs_employee_answers.challenge_answer modify';
END
GO
PRINT '     Step Alter Column: DTX[EmployeeAnswers] Field[[Field=challengeAnswer]] end.';



PRINT '     Step Alter Column: DTX[Shipment] Field[[Field=shippingLabel]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('inv_shipment', 'shipping_label') ) IS NULL
  PRINT '     Default value Constraint for column [inv_shipment].[shipping_label] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [inv_shipment] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('inv_shipment','shipping_label')+'];' 
  EXEC(@sql) 
  PRINT '     inv_shipment.shipping_label default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE inv_shipment ALTER COLUMN [shipping_label] VARCHAR(4000)');
  PRINT '     Column inv_shipment.shipping_label modify';
END
GO
PRINT '     Step Alter Column: DTX[Shipment] Field[[Field=shippingLabel]] end.';



PRINT '     Step Alter Column: DTX[CustomizationModifier] Field[[Field=customizationMessage]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_customization_mod', 'customization_message') ) IS NULL
  PRINT '     Default value Constraint for column [xom_customization_mod].[customization_message] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [xom_customization_mod] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_customization_mod','customization_message')+'];' 
  EXEC(@sql) 
  PRINT '     xom_customization_mod.customization_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_customization_mod ALTER COLUMN [customization_message] VARCHAR(4000)');
  PRINT '     Column xom_customization_mod.customization_message modify';
END
GO
PRINT '     Step Alter Column: DTX[CustomizationModifier] Field[[Field=customizationMessage]] end.';



PRINT '     Step Alter Column: DTX[Order] Field[[Field=giftMessage, Field=orderMessage, Field=statusCodeReasonNote]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order', 'gift_message') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order].[gift_message] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [xom_order] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order','gift_message')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order.gift_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order ALTER COLUMN [gift_message] VARCHAR(4000)');
  PRINT '     Column xom_order.gift_message modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order', 'order_message') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order].[order_message] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [xom_order] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order','order_message')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order.order_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order ALTER COLUMN [order_message] VARCHAR(4000)');
  PRINT '     Column xom_order.order_message modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order', 'status_code_reason_note') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order].[status_code_reason_note] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [xom_order] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order','status_code_reason_note')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order.status_code_reason_note default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order ALTER COLUMN [status_code_reason_note] VARCHAR(4000)');
  PRINT '     Column xom_order.status_code_reason_note modify';
END
GO
PRINT '     Step Alter Column: DTX[Order] Field[[Field=giftMessage, Field=orderMessage, Field=statusCodeReasonNote]] end.';



PRINT '     Step Alter Column: DTX[OrderLineDetail] Field[[Field=lineMessage, Field=statusCodeReasonNote]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order_line_detail', 'line_message') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order_line_detail].[line_message] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [xom_order_line_detail] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order_line_detail','line_message')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order_line_detail.line_message default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order_line_detail ALTER COLUMN [line_message] VARCHAR(4000)');
  PRINT '     Column xom_order_line_detail.line_message modify';
END
GO
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('xom_order_line_detail', 'status_code_reason_note') ) IS NULL
  PRINT '     Default value Constraint for column [xom_order_line_detail].[status_code_reason_note] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [xom_order_line_detail] DROP CONSTRAINT ['+dbo.SP_DEFAULT_CONSTRAINT_EXISTS('xom_order_line_detail','status_code_reason_note')+'];' 
  EXEC(@sql) 
  PRINT '     xom_order_line_detail.status_code_reason_note default value dropped';
  END
GO


BEGIN
    EXEC('ALTER TABLE xom_order_line_detail ALTER COLUMN [status_code_reason_note] VARCHAR(4000)');
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
      EXEC('ALTER TABLE ' + @TableName + ' ALTER COLUMN [' + @ColumnName + '] VARCHAR(256)');
      PRINT '     Column ' + @TableName + '.' + @ColumnName + ' modify';
   END
   FETCH NEXT FROM Table_Cursor INTO @TableName, @ColumnName
END
GO
CLOSE Table_Cursor
DEALLOCATE Table_Cursor
PRINT '     Step Upgrade row modification information to the new size end.';



PRINT '     Step Update string_value from VARCHAR(MAX) to VARCHAR(4000) - Only for MS SQL Server starting...';
DECLARE @TableName AS NVARCHAR(1000)
DECLARE @SQL AS NVARCHAR(1000)
DECLARE Table_Cursor CURSOR FOR SELECT TABLE_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME LIKE '%[_]P' AND COLUMN_NAME = 'STRING_VALUE' AND CHARACTER_MAXIMUM_LENGTH <> 4000 ORDER BY TABLE_NAME
OPEN Table_Cursor
FETCH NEXT FROM Table_Cursor INTO @TableName
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'PRINT ''     Step Alter Column: DTX[' + @TableName + '] Field[Field=string_value] starting...'';
BEGIN
   EXEC(''ALTER TABLE ' + @TableName + ' ALTER COLUMN [string_value] VARCHAR(4000)'');
   PRINT ''     Column ' + @TableName + '.string_value modify'';
END
PRINT ''     Step Alter Column: DTX[' + @TableName + '] Field[Field=string_value] end...'';'
    EXEC (@SQL)
    FETCH NEXT FROM Table_Cursor INTO @TableName
END
GO
CLOSE Table_Cursor
DEALLOCATE Table_Cursor
PRINT '     Step Update string_value from VARCHAR(MAX) to VARCHAR(4000) - Only for MS SQL Server end.';



PRINT '     Step Add Table: DTX[PtAts] starting...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('CPOR_ATS'))
  PRINT '      Table cpor_ats already exists';
ELSE
  BEGIN
    EXEC('CREATE TABLE [dbo].[cpor_ats](
[organization_id] INT NOT NULL,
[rtl_loc_id] INT NOT NULL,
[wkstn_id] BIGINT NOT NULL,
[sequence_id] VARCHAR(255) NOT NULL,
[series] VARCHAR(1) NOT NULL,
[year] BIGINT NOT NULL,
[ats] VARCHAR(70),
[create_user_id] VARCHAR(256),
[create_date] DATETIME,
[update_user_id] VARCHAR(256),
[update_date] DATETIME,
[record_state] VARCHAR(30), 
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
    EXEC('    ALTER TABLE loc_wkstn_config_data ADD [link_column] VARCHAR(30)');
    PRINT '     Column loc_wkstn_config_data.link_column created';
  END
GO


PRINT '     Step Add Column: DTX[WorkstationConfigData] Column[[Field=linkColumn]] end.';



PRINT '     Step Add Column: DTX[LegalEntity] Column[[Field=establishmentCode, Field=registrationCity]] starting...';
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'establishment_code'))
  PRINT '      Column loc_legal_entity.establishment_code already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [establishment_code] VARCHAR(30)');
    PRINT '     Column loc_legal_entity.establishment_code created';
  END
GO


IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'loc_legal_entity') AND name in (N'registration_city'))
  PRINT '      Column loc_legal_entity.registration_city already exists';
ELSE
  BEGIN
    EXEC('    ALTER TABLE loc_legal_entity ADD [registration_city] VARCHAR(254)');
    PRINT '     Column loc_legal_entity.registration_city created';
  END
GO


PRINT '     Step Add Column: DTX[LegalEntity] Column[[Field=establishmentCode, Field=registrationCity]] end.';




PRINT '***** Body scripts end *****';


PRINT '***************************************************************************';
PRINT 'Database now hybridized to support clients running against the following versions:';
PRINT '    19.0.*';
PRINT '    20.0.0';
PRINT 'Please run the corresponding un-hybridize script against this database once all';
PRINT 'clients on earlier supported versions have been updated to the latest supported release.';
PRINT '***************************************************************************';
-- LEAVE BLANK LINE BELOW
