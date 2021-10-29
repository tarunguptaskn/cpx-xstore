-- ***************************************************************************
-- This script "de-hybridizes" a previously "hybridized" script, discarding schema
-- structures which are removed during the upgrade but were kept for backwards schema compatibility.  It is generally invoked once
-- against any databases which, at one point, needed to simultaneously accommodate clients running
-- on two versions of Xstore.
--
--
-- Source version:  19.0.*
-- Target version:  20.0.0
-- DB platform:     Microsoft SQL Server 2012/2014/2016
-- ***************************************************************************
PRINT '**************************************';
PRINT '*****       UNHYBRIDIZING        *****';
PRINT '***** From:  19.0.*              *****';
PRINT '*****   To:  20.0.0              *****';
PRINT '**************************************';
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

PRINT '     Step Drop the trigger RECEIPT_DATA_COPY_CFDI starting...';
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'RECEIPT_DATA_COPY_CFDI') AND type in (N'TR'))
BEGIN
  DROP TRIGGER RECEIPT_DATA_COPY_CFDI;
  PRINT 'Trigger RECEIPT_DATA_COPY_CFDI dropped';
END
GO
PRINT '     Step Drop the trigger RECEIPT_DATA_COPY_CFDI end.';



PRINT '     Step Drop Column: DTX[TemporaryStoreRequest] Column[[Column=start_date, Column=end_date]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('loc_temp_store_request', 'start_date') ) IS NULL
  PRINT '     Default value Constraint for column [loc_temp_store_request].[start_date] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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



PRINT '     Step Drop Column: DTX[SaleReturnLineItem] Column[[Column=RETURNED_QUANTITY]] starting...';
IF (SELECT [dbo].[SP_DEFAULT_CONSTRAINT_EXISTS]('trl_sale_lineitm', 'RETURNED_QUANTITY') ) IS NULL
  PRINT '     Default value Constraint for column [trl_sale_lineitm].[RETURNED_QUANTITY] is missing';
ELSE
  BEGIN
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
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
  DECLARE @sql varchar(max) 
  SET @sql = '    ALTER TABLE [cwo_work_order_acct] DROP CONSTRAINT ['+dbo.SP_PK_CONSTRAINT_EXISTS('cwo_work_order_acct')+'];' 
  EXEC(@sql) 
    PRINT '     PK cwo_work_order_acct dropped';
  END
GO


PRINT '     Step Drop Primary Key: DTX[WorkOrderAccount] end.';



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



PRINT '     Step Removing legal entity extended properties starting...';
BEGIN
  DELETE FROM loc_legal_entity_p WHERE property_code IN ('SHARE_CAPITAL', 'COMPANIES_REGISTER_NUMBER')
  PRINT '        ' + CAST(@@rowcount AS NVARCHAR(10)) + ' Shared capital and Companies register number removed';
END
GO
PRINT '     Step Removing legal entity extended properties end.';



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




PRINT '***** Body scripts end *****';


-- Keep at end of the script

PRINT '**************************************';
PRINT 'Finalizing release version 20.0.0';
PRINT '**************************************';
GO

PRINT '***************************************************************************';
PRINT 'Database now un-hybridized to support clients running against the following versions:';
PRINT '     20.0.0';
PRINT 'This database is no longer compatible with clients running against legacy versions';
PRINT 'previously supported while hybridized.  Please ensure that all clients are updated';
PRINT 'to the appropriate release.';
PRINT '***************************************************************************';
GO
