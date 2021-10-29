-- ***************************************************************************
-- This script "de-hybridizes" a previously "hybridized" script, discarding schema
-- structures which are removed during the upgrade but were kept for backwards schema compatibility.  It is generally invoked once
-- against any databases which, at one point, needed to simultaneously accommodate clients running
-- on two versions of Xstore.
--
--
-- Source version:  19.0.*
-- Target version:  20
-- DB platform:     Oracle 12c
-- ***************************************************************************
PROMPT '**************************************';
PROMPT '*****       UNHYBRIDIZING        *****';
PROMPT '***** From:  19.0.*              *****';
PROMPT '*****   To:  20.0.0              *****';
PROMPT '**************************************';

--
-- Variables
--
DEFINE dbDataTableSpace = '$(DbTblspace)_DATA';-- Name of data file tablespace
DEFINE dbIndexTableSpace = '$(DbTblspace)_INDEX';-- Name of index file tablespace 


alter session set current_schema=$(DbSchema);


PROMPT '***** Prefix scripts start *****';


EXEC dbms_output.put_line('--- CREATING SP_COLUMN_EXISTS --- ');
CREATE OR REPLACE function SP_COLUMN_EXISTS (
 table_name     varchar2,
 column_name    varchar2
) return boolean is
 v_count integer;
begin
  select count(*) into v_count
    from all_tab_columns
   where owner = upper('$(DbSchema)')
     and table_name = upper(SP_COLUMN_EXISTS.table_name)
     and column_name = upper(SP_COLUMN_EXISTS.column_name);
  if v_count = 0 then
    return false;
  else
    return true;
  end if;
end SP_COLUMN_EXISTS;
/

EXEC dbms_output.put_line('--- CREATING SP_TABLE_EXISTS --- ');
create or replace function SP_TABLE_EXISTS (
  table_name varchar2
) return boolean is
  v_count integer;
begin
  select count(*) into v_count
    from all_tables
   where owner = upper('$(DbSchema)')
     and table_name = upper(SP_TABLE_EXISTS.table_name);
  if v_count = 0 then
    return false;
  else
    return true;
  end if;
end SP_TABLE_EXISTS;
/

EXEC dbms_output.put_line('--- CREATING SP_TRIGGER_EXISTS --- ');
create or replace function SP_TRIGGER_EXISTS (
  trigger_name varchar2
) return boolean is
  v_count integer;
begin
  select count(*) into v_count
    from user_triggers
   where trigger_name = upper(SP_TRIGGER_EXISTS.trigger_name);
  if v_count = 0 then
    return false;
  else
    return true;
  end if;
end SP_TRIGGER_EXISTS;
/

EXEC dbms_output.put_line('--- CREATING CREATE_PROPERTY_TABLE --- ');
CREATE OR REPLACE PROCEDURE CREATE_PROPERTY_TABLE
    (vtableNameIn varchar2)
IS
    vsql varchar2(32000);
    vcolumns varchar2(32000);
    vpk varchar2(32000);
    vcnt number(10);
    vtableName varchar2(128);
    vLF char(1) := '
';
    CURSOR mycur IS
      SELECT tc.COLUMN_NAME, tc.DATA_TYPE, tc.CHAR_LENGTH, tc.DATA_PRECISION, tc.DATA_SCALE, tc.DATA_DEFAULT
        FROM USER_CONSTRAINTS c
          INNER JOIN USER_CONS_COLUMNS cc
            ON c.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
           AND c.OWNER = cc.OWNER
          INNER JOIN USER_TAB_COLUMNS tc
            ON cc.TABLE_NAME = tc.TABLE_NAME
           AND cc.COLUMN_NAME = tc.COLUMN_NAME
       WHERE c.TABLE_NAME = UPPER(vtableNameIn)
         AND c.CONSTRAINT_TYPE = 'P' 
      ORDER BY cc.POSITION;
BEGIN
    vtableName := UPPER(vtableNameIn);
    IF SP_TABLE_EXISTS(vtableName || '_P') = true THEN
        dbms_output.put_line(vtableName || '_P already exists');
        return;
    END IF;
    IF SP_TABLE_EXISTS(vtableName) = false THEN
        dbms_output.put_line(vtableName || ' does not exist');
        return;
    END IF;
    IF substr(vtableName, -2) = '_P' THEN
        dbms_output.put_line('will not create a property table for a property table: ' || vtableName);
        return;
    END IF;

    SELECT count(*) into vcnt 
      FROM ALL_CONSTRAINTS CONS, ALL_CONS_COLUMNS COLS
     WHERE COLS.TABLE_NAME = UPPER(vtableName) 
       AND CONS.CONSTRAINT_TYPE = 'P' 
       AND CONS.CONSTRAINT_NAME = COLS.CONSTRAINT_NAME 
       AND COLS.COLUMN_NAME='ORGANIZATION_ID';
    IF vcnt = 0 THEN
        dbms_output.put_line('no primary key');
        return;
    END IF;

    vpk := '';
    vcolumns := '';

    FOR myval IN mycur
    LOOP
      vpk := vpk || myval.column_name || ', ';

      vcolumns := vcolumns || vLF || '  ' || myval.column_name || ' ' || myval.data_type;
      IF myval.data_type LIKE '%CHAR%' THEN
          vcolumns := vcolumns || '(' || myval.char_length || ' char)';
      ELSIF myval.data_type='NUMBER' THEN
          vcolumns := vcolumns || '(' || myval.data_precision || ',' || myval.data_scale || ')';
      END IF;

      IF LENGTH(myval.data_default) > 0 THEN
        IF NOT UPPER(myval.data_default) LIKE '%NEXTVAL' THEN
            vcolumns := vcolumns || ' DEFAULT ' || myval.data_default;
        END IF;
      END IF;

      vcolumns := vcolumns || ' NOT NULL,';
    END LOOP;

    vsql := 'CREATE TABLE ' || vtableName || '_P ('
            || vcolumns || vLF
            || '  PROPERTY_CODE  VARCHAR2(30 char) NOT NULL,' || vLF
            || '  TYPE           VARCHAR2(30 char),' || vLF
            || '  STRING_VALUE   VARCHAR2(4000 char),' || vLF
            || '  DATE_VALUE     TIMESTAMP(6),' || vLF
            || '  DECIMAL_VALUE  NUMBER(17,6),' || vLF
            || '  CREATE_DATE    TIMESTAMP(6),' || vLF
            || '  CREATE_USER_ID VARCHAR2(256 char),' || vLF
            || '  UPDATE_DATE    TIMESTAMP(6),' || vLF
            || '  UPDATE_USER_ID VARCHAR2(256 char),' || vLF
            || '  RECORD_STATE   VARCHAR2(30 char),' || vLF
            || '  CONSTRAINT PK';
   IF LENGTH(vtableName) > 25 THEN
     vsql := vsql || REPLACE(vtableName,'_','');
   ELSE
     vsql := vsql || '_' || vtableName || '_';
   END IF;

   vsql := vsql || 'P PRIMARY KEY (' || vpk || 'PROPERTY_CODE)
    USING INDEX
TABLESPACE &dbIndexTableSpace.
)
TABLESPACE &dbDataTableSpace.';

   dbms_output.put_line('--- CREATING TABLE ' || vtableName || '_P ---');
   dbms_output.put_line(vsql);
   EXECUTE IMMEDIATE vsql;
   EXECUTE IMMEDIATE   'GRANT SELECT,INSERT,UPDATE,DELETE ON ' || vtableName || '_P' || ' TO posusers';
   EXECUTE IMMEDIATE   'GRANT SELECT,INSERT,UPDATE,DELETE ON ' || vtableName || '_P' || ' TO dbausers';

END;
/

EXEC dbms_output.put_line('--- CREATING SP_INDEX_EXISTS --- ');
CREATE OR REPLACE function SP_INDEX_EXISTS (
 index_name     varchar2
) return boolean is
 v_count integer;
begin
  select count(*) into v_count
    from user_indexes
   where index_name = upper(SP_INDEX_EXISTS.index_name);
  if v_count = 0 then
    return false;
  else
    return true;
  end if;
end SP_INDEX_EXISTS;
/

EXEC dbms_output.put_line('--- CREATING SP_PRIMARYKEY_EXISTS --- ');
CREATE OR REPLACE function SP_PRIMARYKEY_EXISTS (
 constraint_name     varchar2
) return boolean is
 v_count integer;
begin
  select count(*) into v_count
    from all_constraints
   where owner = upper('$(DbSchema)')
     and constraint_name = upper(SP_PRIMARYKEY_EXISTS.constraint_name)
     and constraint_type = 'P';
  if v_count = 0 then
    return false;
  else
    return true;
  end if;
end SP_PRIMARYKEY_EXISTS;
/

EXEC dbms_output.put_line('--- CREATING SP_IS_NULLABLE --- ');
CREATE OR REPLACE function SP_IS_NULLABLE (
 table_name     varchar2,
 column_name    varchar2
) return boolean is
 v_count integer;
begin
  select count(*) into v_count
    from all_tab_columns
   where owner = upper('$(DbSchema)')
     and table_name = upper(SP_IS_NULLABLE.table_name)
     and column_name = upper(SP_IS_NULLABLE.column_name)
     AND nullable = 'Y';
  if v_count = 0 then
    return false;
  else
    return true;
  end if;
end SP_IS_NULLABLE;
/

EXEC dbms_output.put_line('--- CREATING SP_PK_CONSTRAINT_EXISTS --- ');
CREATE OR REPLACE function SP_PK_CONSTRAINT_EXISTS (
 table_name     varchar2
) return varchar2 is
 v_pk varchar2(256);
begin
  select initcap(CONSTRAINT_NAME) into v_pk
    from all_constraints
   where owner = upper('$(DbSchema)')
     and table_name = upper(SP_PK_CONSTRAINT_EXISTS.table_name)
     and constraint_type = 'P'
     and ROWNUM = 1;
   return v_pk;
   EXCEPTION
   WHEN NO_DATA_FOUND
   then return 'NOT_FOUND';
end SP_PK_CONSTRAINT_EXISTS;
/

PROMPT '***** Prefix scripts end *****';


PROMPT '***** Body scripts start *****';

BEGIN
    dbms_output.put_line('     Step Drop the trigger RECEIPT_DATA_COPY_CFDI starting...');
END;
/
BEGIN
  IF NOT SP_TRIGGER_EXISTS ('RECEIPT_DATA_COPY_CFDI') THEN
    dbms_output.put_line('Trigger RECEIPT_DATA_COPY_CFDI already dropped');
  ELSE
    BEGIN
      EXECUTE IMMEDIATE 'DROP TRIGGER RECEIPT_DATA_COPY_CFDI';
      dbms_output.put_line('Trigger RECEIPT_DATA_COPY_CFDI dropped');
    END;
  END IF;
END;
/
BEGIN
    dbms_output.put_line('     Step Drop the trigger RECEIPT_DATA_COPY_CFDI end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[TemporaryStoreRequest] Column[[Column=start_date, Column=end_date]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('loc_temp_store_request','start_date') THEN
       dbms_output.put_line('      Column loc_temp_store_request.start_date is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_temp_store_request DROP COLUMN start_date';
        dbms_output.put_line('     Column loc_temp_store_request.start_date dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('loc_temp_store_request','end_date') THEN
       dbms_output.put_line('      Column loc_temp_store_request.end_date is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_temp_store_request DROP COLUMN end_date';
        dbms_output.put_line('     Column loc_temp_store_request.end_date dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[TemporaryStoreRequest] Column[[Column=start_date, Column=end_date]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[SaleReturnLineItem] Column[[Column=RETURNED_QUANTITY]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_sale_lineitm','RETURNED_QUANTITY') THEN
       dbms_output.put_line('      Column trl_sale_lineitm.RETURNED_QUANTITY is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_sale_lineitm DROP COLUMN RETURNED_QUANTITY';
        dbms_output.put_line('     Column trl_sale_lineitm.RETURNED_QUANTITY dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[SaleReturnLineItem] Column[[Column=RETURNED_QUANTITY]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[DeviceRegistration] Column[[Column=ENV_INSTALL_DATE]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('ctl_device_registration','ENV_INSTALL_DATE') THEN
       dbms_output.put_line('      Column ctl_device_registration.ENV_INSTALL_DATE is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_device_registration DROP COLUMN ENV_INSTALL_DATE';
        dbms_output.put_line('     Column ctl_device_registration.ENV_INSTALL_DATE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[DeviceRegistration] Column[[Column=ENV_INSTALL_DATE]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[TenderSerializedCount] Column[[Column=DIFFERENCE_AMT]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('tsn_serialized_tndr_count','DIFFERENCE_AMT') THEN
       dbms_output.put_line('      Column tsn_serialized_tndr_count.DIFFERENCE_AMT is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE tsn_serialized_tndr_count DROP COLUMN DIFFERENCE_AMT';
        dbms_output.put_line('     Column tsn_serialized_tndr_count.DIFFERENCE_AMT dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[TenderSerializedCount] Column[[Column=DIFFERENCE_AMT]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[VoucherTenderLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('ttr_voucher_tndr_lineitm','TRACK1') THEN
       dbms_output.put_line('      Column ttr_voucher_tndr_lineitm.TRACK1 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ttr_voucher_tndr_lineitm DROP COLUMN TRACK1';
        dbms_output.put_line('     Column ttr_voucher_tndr_lineitm.TRACK1 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('ttr_voucher_tndr_lineitm','TRACK2') THEN
       dbms_output.put_line('      Column ttr_voucher_tndr_lineitm.TRACK2 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ttr_voucher_tndr_lineitm DROP COLUMN TRACK2';
        dbms_output.put_line('     Column ttr_voucher_tndr_lineitm.TRACK2 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('ttr_voucher_tndr_lineitm','TRACK3') THEN
       dbms_output.put_line('      Column ttr_voucher_tndr_lineitm.TRACK3 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ttr_voucher_tndr_lineitm DROP COLUMN TRACK3';
        dbms_output.put_line('     Column ttr_voucher_tndr_lineitm.TRACK3 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[VoucherTenderLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[CreditDebitTenderLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('ttr_credit_debit_tndr_lineitm','TRACK1') THEN
       dbms_output.put_line('      Column ttr_credit_debit_tndr_lineitm.TRACK1 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ttr_credit_debit_tndr_lineitm DROP COLUMN TRACK1';
        dbms_output.put_line('     Column ttr_credit_debit_tndr_lineitm.TRACK1 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('ttr_credit_debit_tndr_lineitm','TRACK2') THEN
       dbms_output.put_line('      Column ttr_credit_debit_tndr_lineitm.TRACK2 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ttr_credit_debit_tndr_lineitm DROP COLUMN TRACK2';
        dbms_output.put_line('     Column ttr_credit_debit_tndr_lineitm.TRACK2 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('ttr_credit_debit_tndr_lineitm','TRACK3') THEN
       dbms_output.put_line('      Column ttr_credit_debit_tndr_lineitm.TRACK3 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ttr_credit_debit_tndr_lineitm DROP COLUMN TRACK3';
        dbms_output.put_line('     Column ttr_credit_debit_tndr_lineitm.TRACK3 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[CreditDebitTenderLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[VoucherSaleLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3, Column=serial_nbr]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_voucher_sale_lineitm','TRACK1') THEN
       dbms_output.put_line('      Column trl_voucher_sale_lineitm.TRACK1 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_voucher_sale_lineitm DROP COLUMN TRACK1';
        dbms_output.put_line('     Column trl_voucher_sale_lineitm.TRACK1 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_voucher_sale_lineitm','TRACK2') THEN
       dbms_output.put_line('      Column trl_voucher_sale_lineitm.TRACK2 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_voucher_sale_lineitm DROP COLUMN TRACK2';
        dbms_output.put_line('     Column trl_voucher_sale_lineitm.TRACK2 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_voucher_sale_lineitm','TRACK3') THEN
       dbms_output.put_line('      Column trl_voucher_sale_lineitm.TRACK3 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_voucher_sale_lineitm DROP COLUMN TRACK3';
        dbms_output.put_line('     Column trl_voucher_sale_lineitm.TRACK3 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_voucher_sale_lineitm','serial_nbr') THEN
       dbms_output.put_line('      Column trl_voucher_sale_lineitm.serial_nbr is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_voucher_sale_lineitm DROP COLUMN serial_nbr';
        dbms_output.put_line('     Column trl_voucher_sale_lineitm.serial_nbr dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[VoucherSaleLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3, Column=serial_nbr]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[VoucherDiscountLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3, Column=serial_nbr]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_voucher_discount_lineitm','TRACK1') THEN
       dbms_output.put_line('      Column trl_voucher_discount_lineitm.TRACK1 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_voucher_discount_lineitm DROP COLUMN TRACK1';
        dbms_output.put_line('     Column trl_voucher_discount_lineitm.TRACK1 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_voucher_discount_lineitm','TRACK2') THEN
       dbms_output.put_line('      Column trl_voucher_discount_lineitm.TRACK2 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_voucher_discount_lineitm DROP COLUMN TRACK2';
        dbms_output.put_line('     Column trl_voucher_discount_lineitm.TRACK2 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_voucher_discount_lineitm','TRACK3') THEN
       dbms_output.put_line('      Column trl_voucher_discount_lineitm.TRACK3 is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_voucher_discount_lineitm DROP COLUMN TRACK3';
        dbms_output.put_line('     Column trl_voucher_discount_lineitm.TRACK3 dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_voucher_discount_lineitm','serial_nbr') THEN
       dbms_output.put_line('      Column trl_voucher_discount_lineitm.serial_nbr is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_voucher_discount_lineitm DROP COLUMN serial_nbr';
        dbms_output.put_line('     Column trl_voucher_discount_lineitm.serial_nbr dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[VoucherDiscountLineItem] Column[[Column=TRACK1, Column=TRACK2, Column=TRACK3, Column=serial_nbr]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[RetailTransaction] Column[[Column=TOTAL, Column=SUBTOTAL, Column=TAXTOTAL]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_rtrans','TOTAL') THEN
       dbms_output.put_line('      Column trl_rtrans.TOTAL is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans DROP COLUMN TOTAL';
        dbms_output.put_line('     Column trl_rtrans.TOTAL dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_rtrans','SUBTOTAL') THEN
       dbms_output.put_line('      Column trl_rtrans.SUBTOTAL is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans DROP COLUMN SUBTOTAL';
        dbms_output.put_line('     Column trl_rtrans.SUBTOTAL dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_rtrans','TAXTOTAL') THEN
       dbms_output.put_line('      Column trl_rtrans.TAXTOTAL is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans DROP COLUMN TAXTOTAL';
        dbms_output.put_line('     Column trl_rtrans.TAXTOTAL dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[RetailTransaction] Column[[Column=TOTAL, Column=SUBTOTAL, Column=TAXTOTAL]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[TenderLineItem] Column[[Column=APPROVAL_CODE, Column=ACCT_USER_NAME, Column=PARTY_ID]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('ttr_tndr_lineitm','APPROVAL_CODE') THEN
       dbms_output.put_line('      Column ttr_tndr_lineitm.APPROVAL_CODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ttr_tndr_lineitm DROP COLUMN APPROVAL_CODE';
        dbms_output.put_line('     Column ttr_tndr_lineitm.APPROVAL_CODE dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('ttr_tndr_lineitm','ACCT_USER_NAME') THEN
       dbms_output.put_line('      Column ttr_tndr_lineitm.ACCT_USER_NAME is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ttr_tndr_lineitm DROP COLUMN ACCT_USER_NAME';
        dbms_output.put_line('     Column ttr_tndr_lineitm.ACCT_USER_NAME dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('ttr_tndr_lineitm','PARTY_ID') THEN
       dbms_output.put_line('      Column ttr_tndr_lineitm.PARTY_ID is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ttr_tndr_lineitm DROP COLUMN PARTY_ID';
        dbms_output.put_line('     Column ttr_tndr_lineitm.PARTY_ID dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[TenderLineItem] Column[[Column=APPROVAL_CODE, Column=ACCT_USER_NAME, Column=PARTY_ID]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[InventoryMovementPending] Column[[Column=DEST_BUCKET_ID, Column=DEST_LOCATION_ID]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('inv_movement_pending','DEST_BUCKET_ID') THEN
       dbms_output.put_line('      Column inv_movement_pending.DEST_BUCKET_ID is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE inv_movement_pending DROP COLUMN DEST_BUCKET_ID';
        dbms_output.put_line('     Column inv_movement_pending.DEST_BUCKET_ID dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('inv_movement_pending','DEST_LOCATION_ID') THEN
       dbms_output.put_line('      Column inv_movement_pending.DEST_LOCATION_ID is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE inv_movement_pending DROP COLUMN DEST_LOCATION_ID';
        dbms_output.put_line('     Column inv_movement_pending.DEST_LOCATION_ID dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[InventoryMovementPending] Column[[Column=DEST_BUCKET_ID, Column=DEST_LOCATION_ID]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[PosTransaction] Column[[Column=SESSION_RTL_LOC_ID]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('trn_trans','SESSION_RTL_LOC_ID') THEN
       dbms_output.put_line('      Column trn_trans.SESSION_RTL_LOC_ID is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trn_trans DROP COLUMN SESSION_RTL_LOC_ID';
        dbms_output.put_line('     Column trn_trans.SESSION_RTL_LOC_ID dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[PosTransaction] Column[[Column=SESSION_RTL_LOC_ID]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[TransactionVersion] Column[[Column=CUSTOMER_APP_DATE]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('trn_trans_version','CUSTOMER_APP_DATE') THEN
       dbms_output.put_line('      Column trn_trans_version.CUSTOMER_APP_DATE is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trn_trans_version DROP COLUMN CUSTOMER_APP_DATE';
        dbms_output.put_line('     Column trn_trans_version.CUSTOMER_APP_DATE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[TransactionVersion] Column[[Column=CUSTOMER_APP_DATE]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[DocumentInventoryLocationModifier] Column[[Column=VOID_FLAG]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('inv_inventory_loc_mod','VOID_FLAG') THEN
       dbms_output.put_line('      Column inv_inventory_loc_mod.VOID_FLAG is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE inv_inventory_loc_mod DROP COLUMN VOID_FLAG';
        dbms_output.put_line('     Column inv_inventory_loc_mod.VOID_FLAG dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[DocumentInventoryLocationModifier] Column[[Column=VOID_FLAG]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[CustomerItemAccount] Column[[Column=LAST_ACTIVITY_DATE, Column=ACCT_SETUP_DATE, Column=CUST_ACCT_STATCODE]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('cat_cust_item_acct','LAST_ACTIVITY_DATE') THEN
       dbms_output.put_line('      Column cat_cust_item_acct.LAST_ACTIVITY_DATE is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cat_cust_item_acct DROP COLUMN LAST_ACTIVITY_DATE';
        dbms_output.put_line('     Column cat_cust_item_acct.LAST_ACTIVITY_DATE dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('cat_cust_item_acct','ACCT_SETUP_DATE') THEN
       dbms_output.put_line('      Column cat_cust_item_acct.ACCT_SETUP_DATE is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cat_cust_item_acct DROP COLUMN ACCT_SETUP_DATE';
        dbms_output.put_line('     Column cat_cust_item_acct.ACCT_SETUP_DATE dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('cat_cust_item_acct','CUST_ACCT_STATCODE') THEN
       dbms_output.put_line('      Column cat_cust_item_acct.CUST_ACCT_STATCODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cat_cust_item_acct DROP COLUMN CUST_ACCT_STATCODE';
        dbms_output.put_line('     Column cat_cust_item_acct.CUST_ACCT_STATCODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[CustomerItemAccount] Column[[Column=LAST_ACTIVITY_DATE, Column=ACCT_SETUP_DATE, Column=CUST_ACCT_STATCODE]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[Schedule] Column[[Column=POSTED_DATE, Column=POSTED_FLAG]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('sch_schedule','POSTED_DATE') THEN
       dbms_output.put_line('      Column sch_schedule.POSTED_DATE is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE sch_schedule DROP COLUMN POSTED_DATE';
        dbms_output.put_line('     Column sch_schedule.POSTED_DATE dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_COLUMN_EXISTS ('sch_schedule','POSTED_FLAG') THEN
       dbms_output.put_line('      Column sch_schedule.POSTED_FLAG is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE sch_schedule DROP COLUMN POSTED_FLAG';
        dbms_output.put_line('     Column sch_schedule.POSTED_FLAG dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[Schedule] Column[[Column=POSTED_DATE, Column=POSTED_FLAG]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[InventoryDocumentModifier] Column[[Column=INVCTL_DOCUMENT_RTL_LOC_ID]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('trl_invctl_document_mod','INVCTL_DOCUMENT_RTL_LOC_ID') THEN
       dbms_output.put_line('      Column trl_invctl_document_mod.INVCTL_DOCUMENT_RTL_LOC_ID is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_invctl_document_mod DROP COLUMN INVCTL_DOCUMENT_RTL_LOC_ID';
        dbms_output.put_line('     Column trl_invctl_document_mod.INVCTL_DOCUMENT_RTL_LOC_ID dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[InventoryDocumentModifier] Column[[Column=INVCTL_DOCUMENT_RTL_LOC_ID]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[LineItemGenericStorage] Column[[Column=FORM_KEY]] starting...');
END;
/
BEGIN
  IF NOT SP_COLUMN_EXISTS ('trn_generic_lineitm_storage','FORM_KEY') THEN
       dbms_output.put_line('      Column trn_generic_lineitm_storage.FORM_KEY is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trn_generic_lineitm_storage DROP COLUMN FORM_KEY';
        dbms_output.put_line('     Column trn_generic_lineitm_storage.FORM_KEY dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Column: DTX[LineItemGenericStorage] Column[[Column=FORM_KEY]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Primary Key: DTX[WorkOrderAccount] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('cwo_work_order_acct');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK cwo_work_order_acct is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cwo_work_order_acct DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK cwo_work_order_acct dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Primary Key: DTX[WorkOrderAccount] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ExternalSystemMap] Index[IDX_COM_EXTERNAL_SYSTEM_MAP02] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('com_external_system_map');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK com_external_system_map is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_external_system_map DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK com_external_system_map dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('com_external_system_map_P');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK com_external_system_map_P is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_external_system_map_P DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK com_external_system_map_P dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_COM_EXTERNAL_SYSTEM_MAP02') THEN
      dbms_output.put_line('     Index IDX_COM_EXTERNAL_SYSTEM_MAP02 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_COM_EXTERNAL_SYSTEM_MAP02';
    dbms_output.put_line('     Index IDX_COM_EXTERNAL_SYSTEM_MAP02 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('com_external_system_map');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK com_external_system_map already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_external_system_map ADD CONSTRAINT pk_com_external_system_map PRIMARY KEY (system_id, organization_id) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_com_external_system_map created');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('com_external_system_map_P');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK com_external_system_map_P already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_external_system_map_P ADD CONSTRAINT pk_com_external_system_map_P PRIMARY KEY (system_id, organization_id, property_code) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_com_external_system_map_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ExternalSystemMap] Index[IDX_COM_EXTERNAL_SYSTEM_MAP02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ExternalSystemMap] Index[IDX_COM_EXTERNAL_SYSTEM_MAP01] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('com_external_system_map');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK com_external_system_map is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_external_system_map DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK com_external_system_map dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('com_external_system_map_P');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK com_external_system_map_P is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_external_system_map_P DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK com_external_system_map_P dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_COM_EXTERNAL_SYSTEM_MAP01') THEN
      dbms_output.put_line('     Index IDX_COM_EXTERNAL_SYSTEM_MAP01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_COM_EXTERNAL_SYSTEM_MAP01';
    dbms_output.put_line('     Index IDX_COM_EXTERNAL_SYSTEM_MAP01 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('com_external_system_map');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK com_external_system_map already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_external_system_map ADD CONSTRAINT pk_com_external_system_map PRIMARY KEY (system_id, organization_id) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_com_external_system_map created');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('com_external_system_map_P');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK com_external_system_map_P already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_external_system_map_P ADD CONSTRAINT pk_com_external_system_map_P PRIMARY KEY (system_id, organization_id, property_code) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_com_external_system_map_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ExternalSystemMap] Index[IDX_COM_EXTERNAL_SYSTEM_MAP01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerAccount] Index[IDX_CAT_CUST_ACCT01] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('cat_cust_acct');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK cat_cust_acct is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cat_cust_acct DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK cat_cust_acct dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('cat_cust_acct_P');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK cat_cust_acct_P is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cat_cust_acct_P DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK cat_cust_acct_P dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CAT_CUST_ACCT01') THEN
      dbms_output.put_line('     Index IDX_CAT_CUST_ACCT01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CAT_CUST_ACCT01';
    dbms_output.put_line('     Index IDX_CAT_CUST_ACCT01 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('cat_cust_acct');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK cat_cust_acct already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cat_cust_acct ADD CONSTRAINT pk_cat_cust_acct PRIMARY KEY (organization_id, cust_acct_code, cust_acct_id) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_cat_cust_acct created');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('cat_cust_acct_P');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK cat_cust_acct_P already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cat_cust_acct_P ADD CONSTRAINT pk_cat_cust_acct_P PRIMARY KEY (organization_id, cust_acct_code, cust_acct_id, property_code) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_cat_cust_acct_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerAccount] Index[IDX_CAT_CUST_ACCT01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[OrderModifier] Index[IDX_XOM_ORDER_MOD01] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('xom_order_mod');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK xom_order_mod is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order_mod DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK xom_order_mod dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('xom_order_mod_P');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK xom_order_mod_P is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order_mod_P DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK xom_order_mod_P dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_XOM_ORDER_MOD01') THEN
      dbms_output.put_line('     Index IDX_XOM_ORDER_MOD01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_XOM_ORDER_MOD01';
    dbms_output.put_line('     Index IDX_XOM_ORDER_MOD01 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('xom_order_mod');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK xom_order_mod already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order_mod ADD CONSTRAINT pk_xom_order_mod PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_xom_order_mod created');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('xom_order_mod_P');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK xom_order_mod_P already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order_mod_P ADD CONSTRAINT pk_xom_order_mod_P PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq, property_code) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_xom_order_mod_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[OrderModifier] Index[IDX_XOM_ORDER_MOD01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemOptions] Index[XST_ITM_ITEM_OPTIONS_JOIN] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('itm_item_options');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK itm_item_options is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE itm_item_options DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK itm_item_options dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('itm_item_options_P');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK itm_item_options_P is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE itm_item_options_P DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK itm_item_options_P dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_ITEM_OPTIONS_JOIN') THEN
      dbms_output.put_line('     Index XST_ITM_ITEM_OPTIONS_JOIN is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_ITEM_OPTIONS_JOIN';
    dbms_output.put_line('     Index XST_ITM_ITEM_OPTIONS_JOIN dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('itm_item_options');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK itm_item_options already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE itm_item_options ADD CONSTRAINT pk_itm_item_options PRIMARY KEY (organization_id, item_id, level_code, level_value) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_itm_item_options created');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('itm_item_options_P');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK itm_item_options_P already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE itm_item_options_P ADD CONSTRAINT pk_itm_item_options_P PRIMARY KEY (organization_id, item_id, level_code, level_value, property_code) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_itm_item_options_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemOptions] Index[XST_ITM_ITEM_OPTIONS_JOIN] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Removing legal entity extended properties starting...');
END;
/
BEGIN
  DELETE FROM loc_legal_entity_p WHERE property_code IN ('SHARE_CAPITAL', 'COMPANIES_REGISTER_NUMBER');
  dbms_output.put_line('        ' || TO_CHAR(SQL%ROWCOUNT) || ' Shared capital and Companies register number removed');
END;
/
BEGIN
    dbms_output.put_line('     Step Removing legal entity extended properties end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Trigger for Incoming Mexican pending invoice conversion removed starting...');
END;
/
BEGIN
  IF NOT SP_TRIGGER_EXISTS ('CIVC_INVOICE_MX_PENDING') THEN
    dbms_output.put_line('Trigger CIVC_INVOICE_MX_PENDING does not exist');
  ELSE
    EXECUTE IMMEDIATE 'DROP TRIGGER CIVC_INVOICE_MX_PENDING';
    dbms_output.put_line('Trigger CIVC_INVOICE_MX_PENDING dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_TRIGGER_EXISTS ('CIVC_INVOICE_XREF_MX_PENDING') THEN
    dbms_output.put_line('Trigger CIVC_INVOICE_XREF_MX_PENDING does not exist');
  ELSE
    BEGIN
      EXECUTE IMMEDIATE 'DROP TRIGGER CIVC_INVOICE_XREF_MX_PENDING';
      dbms_output.put_line('Trigger CIVC_INVOICE_XREF_MX_PENDING dropped');
    END;
  END IF;
END;
/
BEGIN
    dbms_output.put_line('     Step Trigger for Incoming Mexican pending invoice conversion removed end.');
END;
/




PROMPT '***** Body scripts end *****';


-- Keep at end of the script

PROMPT '**************************************';
PROMPT 'Finalizing release version 20.0.0';
PROMPT '**************************************';
/

PROMPT '***************************************************************************';
PROMPT 'Database now un-hybridized to support clients running against the following versions:';
PROMPT '     20.0.0';
PROMPT 'This database is no longer compatible with clients running against legacy versions';
PROMPT 'previously supported while hybridized.  Please ensure that all clients are updated';
PROMPT 'to the appropriate release.';
PROMPT '***************************************************************************';
/
