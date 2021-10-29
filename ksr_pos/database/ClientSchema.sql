SET SERVEROUTPUT ON SIZE 100000

SPOOL dbupdate.log;

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
-- DB platform:     Oracle 12c
-- ***************************************************************************
-- ***************************************************************************
-- ***************************************************************************

--
-- Variables
--
DEFINE dbDataTableSpace = '$(DbTblspace)_DATA';-- Name of data file tablespace
DEFINE dbIndexTableSpace = '$(DbTblspace)_INDEX';-- Name of index file tablespace 



-- 19.0.x -> 20.0.0
-- ***************************************************************************
-- ***************************************************************************

BEGIN
  dbms_output.put_line('**************************************');
  dbms_output.put_line('* UPGRADE to release 20.0');
  dbms_output.put_line('**************************************');
END;
/

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
    dbms_output.put_line('     Step Add Table: DTX[OfflinePOSTransaction] starting...');
END;
/
BEGIN
  IF SP_TABLE_EXISTS ('CTL_OFFLINE_POS_TRANSACTION') THEN
       dbms_output.put_line('      Table ctl_offline_pos_transaction already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE TABLE ctl_offline_pos_transaction(
organization_id NUMBER(10, 0) NOT NULL,
uuid VARCHAR2(36 char) NOT NULL,
rtl_loc_id NUMBER(10, 0),
wkstn_id NUMBER(19, 0),
timestamp_end TIMESTAMP(6),
cust_email VARCHAR2(254 char),
sale_items_count NUMBER(10, 0),
trans_total NUMBER(17, 6),
serialized_data BLOB NOT NULL,
processed_flag NUMBER(1, 0) DEFAULT 0 NOT NULL,
create_user_id VARCHAR2(256 char),
create_date TIMESTAMP(6),
update_user_id VARCHAR2(256 char),
update_date TIMESTAMP(6),
record_state VARCHAR2(30 char), 
CONSTRAINT pk_ctlofflinepostransaction PRIMARY KEY (organization_id, uuid) USING INDEX TABLESPACE &dbIndexTableSpace.
)
TABLESPACE &dbDataTableSpace.
';
        dbms_output.put_line('      Table ctl_offline_pos_transaction created');
    EXECUTE IMMEDIATE 'GRANT SELECT,INSERT,UPDATE,DELETE ON ctl_offline_pos_transaction TO POSUSERS,DBAUSERS';
  END IF;
END;
/

BEGIN
  IF SP_TABLE_EXISTS ('CTL_OFFLINE_POS_TRANSACTION_P') THEN
       dbms_output.put_line('      Table CTL_OFFLINE_POS_TRANSACTION_P already exists');
  ELSE
    CREATE_PROPERTY_TABLE('ctl_offline_pos_transaction');
    dbms_output.put_line('     Table ctl_offline_pos_transaction_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Table: DTX[OfflinePOSTransaction] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[OfflinePOSTransaction] Field[[Field=uuid, Field=workstationId]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_offline_pos_transaction MODIFY uuid VARCHAR2(36 char) DEFAULT (null)';
    dbms_output.put_line('     Column ctl_offline_pos_transaction.uuid modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('ctl_offline_pos_transaction','uuid') THEN
      dbms_output.put_line('     Column ctl_offline_pos_transaction.uuid already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_offline_pos_transaction MODIFY uuid NOT NULL';
    dbms_output.put_line('     Column ctl_offline_pos_transaction.uuid modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_offline_pos_transaction_P MODIFY uuid VARCHAR2(36 char) DEFAULT (null)';
    dbms_output.put_line('     Column ctl_offline_pos_transaction_P.uuid modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('ctl_offline_pos_transaction_P','uuid') THEN
      dbms_output.put_line('     Column ctl_offline_pos_transaction_P.uuid already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_offline_pos_transaction_P MODIFY uuid NOT NULL';
    dbms_output.put_line('     Column ctl_offline_pos_transaction_P.uuid modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_offline_pos_transaction MODIFY wkstn_id NUMBER(19, 0) DEFAULT (null)';
    dbms_output.put_line('     Column ctl_offline_pos_transaction.wkstn_id modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('ctl_offline_pos_transaction','wkstn_id') THEN
      dbms_output.put_line('     Column ctl_offline_pos_transaction.wkstn_id already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_offline_pos_transaction MODIFY wkstn_id NULL';
    dbms_output.put_line('     Column ctl_offline_pos_transaction.wkstn_id modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[OfflinePOSTransaction] Field[[Field=uuid, Field=workstationId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[DeTseDeviceRegister] Column[[Field=voidFlag]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('cger_tse_device_register','void_flag') THEN
       dbms_output.put_line('      Column cger_tse_device_register.void_flag already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cger_tse_device_register ADD void_flag NUMBER(1, 0) DEFAULT 0';
    dbms_output.put_line('     Column cger_tse_device_register.void_flag created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[DeTseDeviceRegister] Column[[Field=voidFlag]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Table: DTX[TransactionAttachment] starting...');
END;
/
BEGIN
  IF SP_TABLE_EXISTS ('TRN_TRANS_ATTACHMENT') THEN
       dbms_output.put_line('      Table trn_trans_attachment already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE TABLE trn_trans_attachment(
organization_id NUMBER(10, 0) NOT NULL,
rtl_loc_id NUMBER(10, 0) NOT NULL,
business_date TIMESTAMP(6) NOT NULL,
wkstn_id NUMBER(19, 0) NOT NULL,
trans_seq NUMBER(19, 0) NOT NULL,
attachment_type VARCHAR2(60 char) NOT NULL,
attachment_data BLOB,
create_user_id VARCHAR2(256 char),
create_date TIMESTAMP(6),
update_user_id VARCHAR2(256 char),
update_date TIMESTAMP(6),
record_state VARCHAR2(30 char), 
CONSTRAINT pk_trn_trans_attachment PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, attachment_type) USING INDEX TABLESPACE &dbIndexTableSpace.
)
TABLESPACE &dbDataTableSpace.
';
        dbms_output.put_line('      Table trn_trans_attachment created');
    EXECUTE IMMEDIATE 'GRANT SELECT,INSERT,UPDATE,DELETE ON trn_trans_attachment TO POSUSERS,DBAUSERS';
  END IF;
END;
/

BEGIN
  IF SP_TABLE_EXISTS ('TRN_TRANS_ATTACHMENT_P') THEN
       dbms_output.put_line('      Table TRN_TRANS_ATTACHMENT_P already exists');
  ELSE
    CREATE_PROPERTY_TABLE('trn_trans_attachment');
    dbms_output.put_line('     Table trn_trans_attachment_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Table: DTX[TransactionAttachment] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TenderOptions] Field[[Field=fiscalTenderId]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE tnd_tndr_options MODIFY fiscal_tndr_id VARCHAR2(60 char) DEFAULT (null)';
    dbms_output.put_line('     Column tnd_tndr_options.fiscal_tndr_id modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('tnd_tndr_options','fiscal_tndr_id') THEN
      dbms_output.put_line('     Column tnd_tndr_options.fiscal_tndr_id already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE tnd_tndr_options MODIFY fiscal_tndr_id NULL';
    dbms_output.put_line('     Column tnd_tndr_options.fiscal_tndr_id modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TenderOptions] Field[[Field=fiscalTenderId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Move the old data in to the new column starting...');
END;
/
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
/
BEGIN
    dbms_output.put_line('     Step Move the old data in to the new column end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[TenderExchangeRate] Column[[Field=printAsInverted]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('tnd_exchange_rate','print_as_inverted') THEN
       dbms_output.put_line('      Column tnd_exchange_rate.print_as_inverted already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE tnd_exchange_rate ADD print_as_inverted NUMBER(1, 0) DEFAULT 0';
    dbms_output.put_line('     Column tnd_exchange_rate.print_as_inverted created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[TenderExchangeRate] Column[[Field=printAsInverted]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Table: DTX[DealLoc] starting...');
END;
/
BEGIN
  IF SP_TABLE_EXISTS ('PRC_DEAL_LOC') THEN
       dbms_output.put_line('      Table prc_deal_loc already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE TABLE prc_deal_loc(
organization_id NUMBER(10, 0) NOT NULL,
deal_id VARCHAR2(60 char) NOT NULL,
rtl_loc_id NUMBER(10, 0) NOT NULL,
create_user_id VARCHAR2(256 char),
create_date TIMESTAMP(6),
update_user_id VARCHAR2(256 char),
update_date TIMESTAMP(6),
record_state VARCHAR2(30 char), 
CONSTRAINT pk_prc_deal_loc PRIMARY KEY (organization_id, deal_id, rtl_loc_id) USING INDEX TABLESPACE &dbIndexTableSpace.
)
TABLESPACE &dbDataTableSpace.
';
        dbms_output.put_line('      Table prc_deal_loc created');
    EXECUTE IMMEDIATE 'GRANT SELECT,INSERT,UPDATE,DELETE ON prc_deal_loc TO POSUSERS,DBAUSERS';
  END IF;
END;
/

BEGIN
  IF SP_TABLE_EXISTS ('PRC_DEAL_LOC_P') THEN
       dbms_output.put_line('      Table PRC_DEAL_LOC_P already exists');
  ELSE
    CREATE_PROPERTY_TABLE('prc_deal_loc');
    dbms_output.put_line('     Table prc_deal_loc_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Table: DTX[DealLoc] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Population of PRC_DEAL_LOC starting...');
END;
/
BEGIN
  IF NOT SP_TABLE_EXISTS ('PRC_DEAL_LOC') OR (0=$(StoreID)) THEN
    dbms_output.put_line('Population of PRC_DEAL_LOC not executed');
  ELSE
    EXECUTE IMMEDIATE 'MERGE INTO PRC_DEAL_LOC l
    USING (SELECT organization_id, deal_id, create_date, create_user_id, update_date, update_user_id FROM prc_deal) d 
      ON (l.organization_id = d.organization_id AND l.deal_id = d.deal_id)
    WHEN NOT MATCHED THEN
      INSERT (l.organization_id, l.deal_id, l.rtl_loc_id, l.create_date, l.create_user_id, l.update_date, l.update_user_id)
      VALUES (d.organization_id, d.deal_id, $(StoreID), d.create_date, d.create_user_id, d.update_date, d.update_user_id)';
    dbms_output.put_line('Population of PRC_DEAL_LOC completed');
  END IF;
END;
/
BEGIN
    dbms_output.put_line('     Step Population of PRC_DEAL_LOC end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Table: DTX[TemporaryStoreRequest] starting...');
END;
/
BEGIN
  IF SP_TABLE_EXISTS ('LOC_TEMP_STORE_REQUEST') THEN
       dbms_output.put_line('      Table loc_temp_store_request already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE TABLE loc_temp_store_request(
organization_id NUMBER(10, 0) NOT NULL,
rtl_loc_id NUMBER(10, 0) NOT NULL,
request_id NUMBER(19, 0) NOT NULL,
request_type VARCHAR2(30 char),
store_created_flag NUMBER(1, 0),
description VARCHAR2(254 char),
start_date_str VARCHAR2(8 char) NOT NULL,
end_date_str VARCHAR2(8 char),
active_date_str VARCHAR2(8 char),
assigned_server_host VARCHAR2(254 char),
assigned_server_port NUMBER(10, 0),
status VARCHAR2(30 char) NOT NULL,
approve_reject_notes VARCHAR2(254 char),
use_store_tax_loc_flag NUMBER(1, 0) DEFAULT 1 NOT NULL,
create_user_id VARCHAR2(256 char),
create_date TIMESTAMP(6),
update_user_id VARCHAR2(256 char),
update_date TIMESTAMP(6),
record_state VARCHAR2(30 char), 
CONSTRAINT pk_loc_temp_store_request PRIMARY KEY (organization_id, rtl_loc_id, request_id) USING INDEX TABLESPACE &dbIndexTableSpace.
)
TABLESPACE &dbDataTableSpace.
';
        dbms_output.put_line('      Table loc_temp_store_request created');
    EXECUTE IMMEDIATE 'GRANT SELECT,INSERT,UPDATE,DELETE ON loc_temp_store_request TO POSUSERS,DBAUSERS';
  END IF;
END;
/

BEGIN
  IF SP_TABLE_EXISTS ('LOC_TEMP_STORE_REQUEST_P') THEN
       dbms_output.put_line('      Table LOC_TEMP_STORE_REQUEST_P already exists');
  ELSE
    CREATE_PROPERTY_TABLE('loc_temp_store_request');
    dbms_output.put_line('     Table loc_temp_store_request_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Table: DTX[TemporaryStoreRequest] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[TemporaryStoreRequest] Column[[Field=startDateStr, Field=endDateStr, Field=activeDateStr]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('loc_temp_store_request','start_date_str') THEN
       dbms_output.put_line('      Column loc_temp_store_request.start_date_str already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_temp_store_request ADD start_date_str VARCHAR2(8 char) DEFAULT ''changeit'' NOT NULL';
    dbms_output.put_line('     Column loc_temp_store_request.start_date_str created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('loc_temp_store_request','end_date_str') THEN
       dbms_output.put_line('      Column loc_temp_store_request.end_date_str already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_temp_store_request ADD end_date_str VARCHAR2(8 char)';
    dbms_output.put_line('     Column loc_temp_store_request.end_date_str created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('loc_temp_store_request','active_date_str') THEN
       dbms_output.put_line('      Column loc_temp_store_request.active_date_str already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_temp_store_request ADD active_date_str VARCHAR2(8 char)';
    dbms_output.put_line('     Column loc_temp_store_request.active_date_str created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[TemporaryStoreRequest] Column[[Field=startDateStr, Field=endDateStr, Field=activeDateStr]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Converting data from old to new columns in LOC_TEMP_STORE_REQUEST starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS('LOC_TEMP_STORE_REQUEST', 'start_date') AND SP_COLUMN_EXISTS('LOC_TEMP_STORE_REQUEST', 'start_date_str') THEN
    EXECUTE IMMEDIATE '    UPDATE loc_temp_store_request SET start_date_str = to_char(start_date, ''yyyymmdd'') WHERE start_date IS NOT NULL';
    dbms_output.put_line('        LOC_TEMP_STORE_REQUEST.start_date_str populated');
  END IF;

  IF SP_COLUMN_EXISTS('LOC_TEMP_STORE_REQUEST', 'end_date') AND SP_COLUMN_EXISTS('LOC_TEMP_STORE_REQUEST', 'end_date_str') THEN
    EXECUTE IMMEDIATE '    UPDATE loc_temp_store_request SET end_date_str = to_char(end_date, ''yyyymmdd'') WHERE end_date IS NOT NULL';
    dbms_output.put_line('        LOC_TEMP_STORE_REQUEST.end_date_str populated');
  END IF;
END;
/
BEGIN
    dbms_output.put_line('     Step Converting data from old to new columns in LOC_TEMP_STORE_REQUEST end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TemporaryStoreRequest] Field[[Field=startDateStr]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_temp_store_request MODIFY start_date_str VARCHAR2(8 char) DEFAULT (null)';
    dbms_output.put_line('     Column loc_temp_store_request.start_date_str modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_temp_store_request','start_date_str') THEN
      dbms_output.put_line('     Column loc_temp_store_request.start_date_str already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_temp_store_request MODIFY start_date_str NOT NULL';
    dbms_output.put_line('     Column loc_temp_store_request.start_date_str modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TemporaryStoreRequest] Field[[Field=startDateStr]] end.');
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
    dbms_output.put_line('     Step Alter Column: DTX[PartyIdCrossReference] Field[[Field=organizationId, Field=partyId]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_id_xref MODIFY organization_id NUMBER(10, 0) DEFAULT (null)';
    dbms_output.put_line('     Column crm_party_id_xref.organization_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('crm_party_id_xref','organization_id') THEN
      dbms_output.put_line('     Column crm_party_id_xref.organization_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_id_xref MODIFY organization_id NOT NULL';
    dbms_output.put_line('     Column crm_party_id_xref.organization_id modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_id_xref_P MODIFY organization_id NUMBER(10, 0) DEFAULT (null)';
    dbms_output.put_line('     Column crm_party_id_xref_P.organization_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('crm_party_id_xref_P','organization_id') THEN
      dbms_output.put_line('     Column crm_party_id_xref_P.organization_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_id_xref_P MODIFY organization_id NOT NULL';
    dbms_output.put_line('     Column crm_party_id_xref_P.organization_id modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_id_xref MODIFY party_id NUMBER(19, 0) DEFAULT (null)';
    dbms_output.put_line('     Column crm_party_id_xref.party_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('crm_party_id_xref','party_id') THEN
      dbms_output.put_line('     Column crm_party_id_xref.party_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_id_xref MODIFY party_id NOT NULL';
    dbms_output.put_line('     Column crm_party_id_xref.party_id modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_id_xref_P MODIFY party_id NUMBER(19, 0) DEFAULT (null)';
    dbms_output.put_line('     Column crm_party_id_xref_P.party_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('crm_party_id_xref_P','party_id') THEN
      dbms_output.put_line('     Column crm_party_id_xref_P.party_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_id_xref_P MODIFY party_id NOT NULL';
    dbms_output.put_line('     Column crm_party_id_xref_P.party_id modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PartyIdCrossReference] Field[[Field=organizationId, Field=partyId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TransactionReportData] Field[[Field=reportId]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE trn_report_data MODIFY report_id VARCHAR2(60 char) DEFAULT (null)';
    dbms_output.put_line('     Column trn_report_data.report_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('trn_report_data','report_id') THEN
      dbms_output.put_line('     Column trn_report_data.report_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trn_report_data MODIFY report_id NOT NULL';
    dbms_output.put_line('     Column trn_report_data.report_id modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE trn_report_data_P MODIFY report_id VARCHAR2(60 char) DEFAULT (null)';
    dbms_output.put_line('     Column trn_report_data_P.report_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('trn_report_data_P','report_id') THEN
      dbms_output.put_line('     Column trn_report_data_P.report_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trn_report_data_P MODIFY report_id NOT NULL';
    dbms_output.put_line('     Column trn_report_data_P.report_id modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TransactionReportData] Field[[Field=reportId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[WorkstationConfigData] Field[[Field=fieldName, Field=fieldValue]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_wkstn_config_data MODIFY field_name VARCHAR2(100 char) DEFAULT (null)';
    dbms_output.put_line('     Column loc_wkstn_config_data.field_name modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_wkstn_config_data','field_name') THEN
      dbms_output.put_line('     Column loc_wkstn_config_data.field_name already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_wkstn_config_data MODIFY field_name NOT NULL';
    dbms_output.put_line('     Column loc_wkstn_config_data.field_name modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_wkstn_config_data MODIFY field_value VARCHAR2(1024 char) DEFAULT (null)';
    dbms_output.put_line('     Column loc_wkstn_config_data.field_value modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('loc_wkstn_config_data','field_value') THEN
      dbms_output.put_line('     Column loc_wkstn_config_data.field_value already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_wkstn_config_data MODIFY field_value NULL';
    dbms_output.put_line('     Column loc_wkstn_config_data.field_value modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[WorkstationConfigData] Field[[Field=fieldName, Field=fieldValue]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Update columns from Strings types(VARCHAR and NCLOB) to CLOB starting...');
END;
/


CREATE OR REPLACE PROCEDURE SP_FROM_STRING_TO_CLOB (
 table_name     varchar2,
 column_name     varchar2
) IS 
BEGIN
    dbms_output.put_line('Update '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||' from STRING to CLOB start...');
  
    IF SP_COLUMN_EXISTS (SP_FROM_STRING_TO_CLOB.table_name, SP_FROM_STRING_TO_CLOB.column_name||'___tmp') THEN
         dbms_output.put_line('      Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||'___tmp already exists');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE '||SP_FROM_STRING_TO_CLOB.table_name||' ADD '||SP_FROM_STRING_TO_CLOB.column_name||'___tmp CLOB';
      dbms_output.put_line('     Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||'___tmp created');
    END IF;
  
    IF SP_COLUMN_EXISTS (SP_FROM_STRING_TO_CLOB.table_name, SP_FROM_STRING_TO_CLOB.column_name||'___tmp') THEN
      IF SP_COLUMN_EXISTS (SP_FROM_STRING_TO_CLOB.table_name, SP_FROM_STRING_TO_CLOB.column_name) THEN
        EXECUTE IMMEDIATE 'UPDATE '||SP_FROM_STRING_TO_CLOB.table_name||' SET '||SP_FROM_STRING_TO_CLOB.column_name||'___tmp = TO_CLOB('||SP_FROM_STRING_TO_CLOB.column_name||')';
        dbms_output.put_line('     Data copy to '||SP_FROM_STRING_TO_CLOB.column_name||'___tmp column');
      ELSE
        dbms_output.put_line('     Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||' do not exist');
      END IF;
    ELSE
      dbms_output.put_line('     Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||'___tmp do not exist');
    END IF;
  
    IF SP_COLUMN_EXISTS (SP_FROM_STRING_TO_CLOB.table_name, SP_FROM_STRING_TO_CLOB.column_name||'___tmp') THEN
      IF SP_COLUMN_EXISTS (SP_FROM_STRING_TO_CLOB.table_name, SP_FROM_STRING_TO_CLOB.column_name) THEN
        EXECUTE IMMEDIATE 'ALTER TABLE '||SP_FROM_STRING_TO_CLOB.table_name||' DROP COLUMN '||SP_FROM_STRING_TO_CLOB.column_name;
        dbms_output.put_line('     Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||' removed');
      ELSE
        dbms_output.put_line('     Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||' do not exist');
      END IF;
    ELSE
      dbms_output.put_line('     Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||'___tmp do not exist');
    END IF;
  
    IF SP_COLUMN_EXISTS (SP_FROM_STRING_TO_CLOB.table_name, SP_FROM_STRING_TO_CLOB.column_name||'___tmp') THEN
      IF SP_COLUMN_EXISTS (SP_FROM_STRING_TO_CLOB.table_name, SP_FROM_STRING_TO_CLOB.column_name) THEN
        dbms_output.put_line('     Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||' should not exist');
      ELSE
        EXECUTE IMMEDIATE 'ALTER TABLE '||SP_FROM_STRING_TO_CLOB.table_name||' RENAME COLUMN '||SP_FROM_STRING_TO_CLOB.column_name||'___tmp TO '||SP_FROM_STRING_TO_CLOB.column_name;
        dbms_output.put_line('     Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||'___temp is renamed to: '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name);
      END IF;
    ELSE
      dbms_output.put_line('     Column '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||'___tmp do not exist');
    END IF;
  
    dbms_output.put_line('Update '||SP_FROM_STRING_TO_CLOB.table_name||'.'||SP_FROM_STRING_TO_CLOB.column_name||' from STRING to CLOB end...');
  

END SP_FROM_STRING_TO_CLOB;
/


----------------------------

BEGIN
  SP_FROM_STRING_TO_CLOB ('hrs_employee_task_notes', 'note');
END;
/

BEGIN
  SP_FROM_STRING_TO_CLOB ('cpaf_nfe_queue', 'response_text');
END;
/

BEGIN
  SP_FROM_STRING_TO_CLOB ('cpaf_nfe_queue', 'inf_cpl');
END;
/

BEGIN
  SP_FROM_STRING_TO_CLOB ('cpaf_nfe_queue', 'xml');
END;
/

BEGIN
  SP_FROM_STRING_TO_CLOB ('cpaf_nfe_queue_log', 'response_text');
END;
/

BEGIN
  SP_FROM_STRING_TO_CLOB ('cpaf_sat_response', 'xml_string');
END;
/

BEGIN
  SP_FROM_STRING_TO_CLOB ('cpaf_nfe', 'inf_cpl');
END;
/

BEGIN
  SP_FROM_STRING_TO_CLOB ('cpaf_nfe', 'xml');
END;
/

---------------------------------------------

BEGIN
  EXECUTE IMMEDIATE 'DROP PROCEDURE SP_FROM_STRING_TO_CLOB';
END;
/


BEGIN
    dbms_output.put_line('     Step Update columns from Strings types(VARCHAR and NCLOB) to CLOB end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[OrgHierarchy] Field[[Field=levelCode, Field=levelValue]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_org_hierarchy MODIFY org_code VARCHAR2(30 char) DEFAULT ''*''';
    dbms_output.put_line('     Column loc_org_hierarchy.org_code modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_org_hierarchy','org_code') THEN
      dbms_output.put_line('     Column loc_org_hierarchy.org_code already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_org_hierarchy MODIFY org_code NOT NULL';
    dbms_output.put_line('     Column loc_org_hierarchy.org_code modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_org_hierarchy_P MODIFY org_code VARCHAR2(30 char) DEFAULT ''*''';
    dbms_output.put_line('     Column loc_org_hierarchy_P.org_code modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_org_hierarchy_P','org_code') THEN
      dbms_output.put_line('     Column loc_org_hierarchy_P.org_code already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_org_hierarchy_P MODIFY org_code NOT NULL';
    dbms_output.put_line('     Column loc_org_hierarchy_P.org_code modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_org_hierarchy MODIFY org_value VARCHAR2(60 char) DEFAULT ''*''';
    dbms_output.put_line('     Column loc_org_hierarchy.org_value modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_org_hierarchy','org_value') THEN
      dbms_output.put_line('     Column loc_org_hierarchy.org_value already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_org_hierarchy MODIFY org_value NOT NULL';
    dbms_output.put_line('     Column loc_org_hierarchy.org_value modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_org_hierarchy_P MODIFY org_value VARCHAR2(60 char) DEFAULT ''*''';
    dbms_output.put_line('     Column loc_org_hierarchy_P.org_value modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_org_hierarchy_P','org_value') THEN
      dbms_output.put_line('     Column loc_org_hierarchy_P.org_value already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_org_hierarchy_P MODIFY org_value NOT NULL';
    dbms_output.put_line('     Column loc_org_hierarchy_P.org_value modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[OrgHierarchy] Field[[Field=levelCode, Field=levelValue]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PricingHierarchy] Field[[Field=levelCode, Field=levelValue]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_pricing_hierarchy MODIFY level_code VARCHAR2(30 char) DEFAULT ''*''';
    dbms_output.put_line('     Column loc_pricing_hierarchy.level_code modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_pricing_hierarchy','level_code') THEN
      dbms_output.put_line('     Column loc_pricing_hierarchy.level_code already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_pricing_hierarchy MODIFY level_code NOT NULL';
    dbms_output.put_line('     Column loc_pricing_hierarchy.level_code modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_pricing_hierarchy_P MODIFY level_code VARCHAR2(30 char) DEFAULT ''*''';
    dbms_output.put_line('     Column loc_pricing_hierarchy_P.level_code modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_pricing_hierarchy_P','level_code') THEN
      dbms_output.put_line('     Column loc_pricing_hierarchy_P.level_code already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_pricing_hierarchy_P MODIFY level_code NOT NULL';
    dbms_output.put_line('     Column loc_pricing_hierarchy_P.level_code modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_pricing_hierarchy MODIFY level_value VARCHAR2(60 char) DEFAULT ''*''';
    dbms_output.put_line('     Column loc_pricing_hierarchy.level_value modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_pricing_hierarchy','level_value') THEN
      dbms_output.put_line('     Column loc_pricing_hierarchy.level_value already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_pricing_hierarchy MODIFY level_value NOT NULL';
    dbms_output.put_line('     Column loc_pricing_hierarchy.level_value modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_pricing_hierarchy_P MODIFY level_value VARCHAR2(60 char) DEFAULT ''*''';
    dbms_output.put_line('     Column loc_pricing_hierarchy_P.level_value modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_pricing_hierarchy_P','level_value') THEN
      dbms_output.put_line('     Column loc_pricing_hierarchy_P.level_value already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_pricing_hierarchy_P MODIFY level_value NOT NULL';
    dbms_output.put_line('     Column loc_pricing_hierarchy_P.level_value modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PricingHierarchy] Field[[Field=levelCode, Field=levelValue]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[ItemRestrictGS1] Field[[Field=orgCode, Field=orgValue]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE itm_restrict_gs1 MODIFY org_code VARCHAR2(30 char) DEFAULT ''*''';
    dbms_output.put_line('     Column itm_restrict_gs1.org_code modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('itm_restrict_gs1','org_code') THEN
      dbms_output.put_line('     Column itm_restrict_gs1.org_code already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE itm_restrict_gs1 MODIFY org_code NOT NULL';
    dbms_output.put_line('     Column itm_restrict_gs1.org_code modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE itm_restrict_gs1 MODIFY org_value VARCHAR2(60 char) DEFAULT ''*''';
    dbms_output.put_line('     Column itm_restrict_gs1.org_value modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('itm_restrict_gs1','org_value') THEN
      dbms_output.put_line('     Column itm_restrict_gs1.org_value already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE itm_restrict_gs1 MODIFY org_value NOT NULL';
    dbms_output.put_line('     Column itm_restrict_gs1.org_value modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[ItemRestrictGS1] Field[[Field=orgCode, Field=orgValue]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[KitComponent] Field[[Field=quantityPerKit]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE itm_kit_component MODIFY quantity_per_kit NUMBER(10, 0) DEFAULT 1';
    dbms_output.put_line('     Column itm_kit_component.quantity_per_kit modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('itm_kit_component','quantity_per_kit') THEN
      dbms_output.put_line('     Column itm_kit_component.quantity_per_kit already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE itm_kit_component MODIFY quantity_per_kit NULL';
    dbms_output.put_line('     Column itm_kit_component.quantity_per_kit modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[KitComponent] Field[[Field=quantityPerKit]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PartyLocaleInformation] Field[[Field=sequence]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_locale_information MODIFY party_locale_seq NUMBER(10, 0) DEFAULT (null)';
    dbms_output.put_line('     Column crm_party_locale_information.party_locale_seq modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('crm_party_locale_information','party_locale_seq') THEN
      dbms_output.put_line('     Column crm_party_locale_information.party_locale_seq already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_locale_information MODIFY party_locale_seq NOT NULL';
    dbms_output.put_line('     Column crm_party_locale_information.party_locale_seq modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_locale_information_P MODIFY party_locale_seq NUMBER(10, 0) DEFAULT (null)';
    dbms_output.put_line('     Column crm_party_locale_information_P.party_locale_seq modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('crm_party_locale_information_P','party_locale_seq') THEN
      dbms_output.put_line('     Column crm_party_locale_information_P.party_locale_seq already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_locale_information_P MODIFY party_locale_seq NOT NULL';
    dbms_output.put_line('     Column crm_party_locale_information_P.party_locale_seq modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PartyLocaleInformation] Field[[Field=sequence]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PartyEmail] Field[[Field=sequence]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_email MODIFY email_sequence NUMBER(10, 0) DEFAULT (null)';
    dbms_output.put_line('     Column crm_party_email.email_sequence modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('crm_party_email','email_sequence') THEN
      dbms_output.put_line('     Column crm_party_email.email_sequence already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_email MODIFY email_sequence NOT NULL';
    dbms_output.put_line('     Column crm_party_email.email_sequence modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_email_P MODIFY email_sequence NUMBER(10, 0) DEFAULT (null)';
    dbms_output.put_line('     Column crm_party_email_P.email_sequence modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('crm_party_email_P','email_sequence') THEN
      dbms_output.put_line('     Column crm_party_email_P.email_sequence already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party_email_P MODIFY email_sequence NOT NULL';
    dbms_output.put_line('     Column crm_party_email_P.email_sequence modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PartyEmail] Field[[Field=sequence]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[EmployeePassword] Field[[Field=effectiveDate]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE hrs_employee_password MODIFY effective_date TIMESTAMP(6) DEFAULT (null)';
    dbms_output.put_line('     Column hrs_employee_password.effective_date modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('hrs_employee_password','effective_date') THEN
      dbms_output.put_line('     Column hrs_employee_password.effective_date already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE hrs_employee_password MODIFY effective_date NOT NULL';
    dbms_output.put_line('     Column hrs_employee_password.effective_date modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[EmployeePassword] Field[[Field=effectiveDate]] end.');
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
    dbms_output.put_line('     Step Add Primary Key: DTX[WorkOrderAccount] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('cwo_work_order_acct');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK cwo_work_order_acct already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cwo_work_order_acct ADD CONSTRAINT pk_cwo_work_order_acct PRIMARY KEY (organization_id, cust_acct_code, cust_acct_id) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_cwo_work_order_acct created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Primary Key: DTX[WorkOrderAccount] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PafNfeTransType] Field[[Field=notes, Field=ruleType]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_trans_type MODIFY notes VARCHAR2(2000 char) DEFAULT (null)';
    dbms_output.put_line('     Column cpaf_nfe_trans_type.notes modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('cpaf_nfe_trans_type','notes') THEN
      dbms_output.put_line('     Column cpaf_nfe_trans_type.notes already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_trans_type MODIFY notes NULL';
    dbms_output.put_line('     Column cpaf_nfe_trans_type.notes modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_trans_type MODIFY rule_type VARCHAR2(30 char) DEFAULT (null)';
    dbms_output.put_line('     Column cpaf_nfe_trans_type.rule_type modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('cpaf_nfe_trans_type','rule_type') THEN
      dbms_output.put_line('     Column cpaf_nfe_trans_type.rule_type already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_trans_type MODIFY rule_type NULL';
    dbms_output.put_line('     Column cpaf_nfe_trans_type.rule_type modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PafNfeTransType] Field[[Field=notes, Field=ruleType]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TransactionReportData] Field[[Field=workstationId]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE trn_report_data MODIFY wkstn_id NUMBER(10, 0) DEFAULT (null)';
    dbms_output.put_line('     Column trn_report_data.wkstn_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('trn_report_data','wkstn_id') THEN
      dbms_output.put_line('     Column trn_report_data.wkstn_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trn_report_data MODIFY wkstn_id NOT NULL';
    dbms_output.put_line('     Column trn_report_data.wkstn_id modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE trn_report_data_P MODIFY wkstn_id NUMBER(10, 0) DEFAULT (null)';
    dbms_output.put_line('     Column trn_report_data_P.wkstn_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('trn_report_data_P','wkstn_id') THEN
      dbms_output.put_line('     Column trn_report_data_P.wkstn_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trn_report_data_P MODIFY wkstn_id NOT NULL';
    dbms_output.put_line('     Column trn_report_data_P.wkstn_id modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TransactionReportData] Field[[Field=workstationId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Set the correct length for RelatedItemHead starting...');
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('rms_related_item_head');
BEGIN
    dbms_output.put_line('Update rms_related_item_head.relationship_id to decrease size start...');
  
    IF SP_COLUMN_EXISTS ('rms_related_item_head', 'relationship_id___tmp') THEN
         dbms_output.put_line('      Column rms_related_item_head.relationship_id___tmp already exists');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE rms_related_item_head ADD relationship_id___tmp NUMBER(19, 0) DEFAULT (null)';
      dbms_output.put_line('     Column rms_related_item_head.relationship_id___tmp created');
    END IF;
  
    IF SP_COLUMN_EXISTS ('rms_related_item_head', 'relationship_id___tmp') THEN
      IF SP_COLUMN_EXISTS ('rms_related_item_head', 'relationship_id') THEN
        EXECUTE IMMEDIATE 'UPDATE rms_related_item_head SET relationship_id___tmp = relationship_id';
        dbms_output.put_line('     Data copy to relationship_id___tmp column');
      ELSE
        dbms_output.put_line('     Column rms_related_item_head.relationship_id do not exist');
      END IF;
    ELSE
      dbms_output.put_line('     Column rms_related_item_head.relationship_id___tmp do not exist');
    END IF;
  
    IF pk_name = 'NOT_FOUND'  THEN
        dbms_output.put_line('     PK rms_related_item_head is missing');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE rms_related_item_head DROP CONSTRAINT ' || pk_name || '';
      dbms_output.put_line('     PK rms_related_item_head dropped');
    END IF;
  
    IF SP_COLUMN_EXISTS ('rms_related_item_head', 'relationship_id___tmp') THEN
      IF SP_COLUMN_EXISTS ('rms_related_item_head', 'relationship_id') THEN
        EXECUTE IMMEDIATE 'ALTER TABLE rms_related_item_head DROP COLUMN relationship_id';
        dbms_output.put_line('     Column rms_related_item_head.relationship_id removed');
      ELSE
        dbms_output.put_line('     Column rms_related_item_head.relationship_id do not exist');
      END IF;
    ELSE
      dbms_output.put_line('     Column rms_related_item_head.relationship_id___tmp do not exist');
    END IF;
  
    IF SP_COLUMN_EXISTS ('rms_related_item_head', 'relationship_id___tmp') THEN
      IF SP_COLUMN_EXISTS ('rms_related_item_head', 'relationship_id') THEN
        dbms_output.put_line('     Column rms_related_item_head.relationship_id should not exist');
      ELSE
        EXECUTE IMMEDIATE 'ALTER TABLE rms_related_item_head RENAME COLUMN relationship_id___tmp TO relationship_id';
        dbms_output.put_line('     Column rms_related_item_head.relationship_id___temp is renamed to: rms_related_item_head.relationship_id');
      END IF;
    ELSE
      dbms_output.put_line('     Column rms_related_item_head.relationship_id___tmp do not exist');
    END IF;
  
    dbms_output.put_line('Update rms_related_item_head.relationship_id to decrease size end...');
  

END;
/

BEGIN
    dbms_output.put_line('     Step Set the correct length for RelatedItemHead end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[RelatedItemHead] Field[[Field=relationshipId]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE rms_related_item_head MODIFY relationship_id NUMBER(19, 0) DEFAULT (null)';
    dbms_output.put_line('     Column rms_related_item_head.relationship_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('rms_related_item_head','relationship_id') THEN
      dbms_output.put_line('     Column rms_related_item_head.relationship_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_related_item_head MODIFY relationship_id NOT NULL';
    dbms_output.put_line('     Column rms_related_item_head.relationship_id modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[RelatedItemHead] Field[[Field=relationshipId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PafNfeTaxCst] Field[[Field=taxLocationId]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_tax_cst MODIFY tax_loc_id VARCHAR2(60 char) DEFAULT (null)';
    dbms_output.put_line('     Column cpaf_nfe_tax_cst.tax_loc_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('cpaf_nfe_tax_cst','tax_loc_id') THEN
      dbms_output.put_line('     Column cpaf_nfe_tax_cst.tax_loc_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_tax_cst MODIFY tax_loc_id NOT NULL';
    dbms_output.put_line('     Column cpaf_nfe_tax_cst.tax_loc_id modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_tax_cst_P MODIFY tax_loc_id VARCHAR2(60 char) DEFAULT (null)';
    dbms_output.put_line('     Column cpaf_nfe_tax_cst_P.tax_loc_id modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('cpaf_nfe_tax_cst_P','tax_loc_id') THEN
      dbms_output.put_line('     Column cpaf_nfe_tax_cst_P.tax_loc_id already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_tax_cst_P MODIFY tax_loc_id NOT NULL';
    dbms_output.put_line('     Column cpaf_nfe_tax_cst_P.tax_loc_id modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PafNfeTaxCst] Field[[Field=taxLocationId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DiffGroupDetail] Field[[Field=displaySeq]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE rms_diff_group_detail MODIFY display_seq NUMBER(4, 0) DEFAULT (null)';
    dbms_output.put_line('     Column rms_diff_group_detail.display_seq modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('rms_diff_group_detail','display_seq') THEN
      dbms_output.put_line('     Column rms_diff_group_detail.display_seq already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_diff_group_detail MODIFY display_seq NULL';
    dbms_output.put_line('     Column rms_diff_group_detail.display_seq modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DiffGroupDetail] Field[[Field=displaySeq]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[Measurement] Field[[Field=symbol, Field=name]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE com_measurement MODIFY symbol VARCHAR2(254 char) DEFAULT (null)';
    dbms_output.put_line('     Column com_measurement.symbol modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('com_measurement','symbol') THEN
      dbms_output.put_line('     Column com_measurement.symbol already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_measurement MODIFY symbol NOT NULL';
    dbms_output.put_line('     Column com_measurement.symbol modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE com_measurement MODIFY name VARCHAR2(254 char) DEFAULT (null)';
    dbms_output.put_line('     Column com_measurement.name modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('com_measurement','name') THEN
      dbms_output.put_line('     Column com_measurement.name already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_measurement MODIFY name NOT NULL';
    dbms_output.put_line('     Column com_measurement.name modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[Measurement] Field[[Field=symbol, Field=name]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PafSatResponse] Field[[Field=signatureQRCODE]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_sat_response MODIFY signature_qr_code VARCHAR2(2000 char) DEFAULT (null)';
    dbms_output.put_line('     Column cpaf_sat_response.signature_QR_code modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('cpaf_sat_response','signature_QR_code') THEN
      dbms_output.put_line('     Column cpaf_sat_response.signature_QR_code already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_sat_response MODIFY signature_QR_code NULL';
    dbms_output.put_line('     Column cpaf_sat_response.signature_QR_code modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PafSatResponse] Field[[Field=signatureQRCODE]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PafNfeQueueTrans] Field[[Field=inactive]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_queue_trans MODIFY inactive_flag NUMBER(1, 0) DEFAULT 0';
    dbms_output.put_line('     Column cpaf_nfe_queue_trans.inactive_flag modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('cpaf_nfe_queue_trans','inactive_flag') THEN
      dbms_output.put_line('     Column cpaf_nfe_queue_trans.inactive_flag already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cpaf_nfe_queue_trans MODIFY inactive_flag NOT NULL';
    dbms_output.put_line('     Column cpaf_nfe_queue_trans.inactive_flag modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[PafNfeQueueTrans] Field[[Field=inactive]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[InventoryDocumentCrossReference] Field[[Field=createDate, Field=updateDate]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE inv_invctl_document_xref MODIFY create_date TIMESTAMP(6) DEFAULT (null)';
    dbms_output.put_line('     Column inv_invctl_document_xref.create_date modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('inv_invctl_document_xref','create_date') THEN
      dbms_output.put_line('     Column inv_invctl_document_xref.create_date already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE inv_invctl_document_xref MODIFY create_date NULL';
    dbms_output.put_line('     Column inv_invctl_document_xref.create_date modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE inv_invctl_document_xref MODIFY update_date TIMESTAMP(6) DEFAULT (null)';
    dbms_output.put_line('     Column inv_invctl_document_xref.update_date modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('inv_invctl_document_xref','update_date') THEN
      dbms_output.put_line('     Column inv_invctl_document_xref.update_date already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE inv_invctl_document_xref MODIFY update_date NULL';
    dbms_output.put_line('     Column inv_invctl_document_xref.update_date modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[InventoryDocumentCrossReference] Field[[Field=createDate, Field=updateDate]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Update version table to use identity type starting...');
END;
/


BEGIN
    dbms_output.put_line('Update ctl_version_history to use IDENTITY type');
END;
/


BEGIN
  IF NOT SP_PRIMARYKEY_EXISTS ('pk_ctl_version_history') THEN
      dbms_output.put_line('     pk_ctl_version_history is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_version_history DROP CONSTRAINT pk_ctl_version_history';
    dbms_output.put_line('     pk_ctl_version_history dropped');
  END IF;
END;
/

DECLARE default_val varchar2(255);
BEGIN
  IF NOT SP_COLUMN_EXISTS ('ctl_version_history','seq') THEN
       dbms_output.put_line('      ctl_version_history.seq is missing');
  ELSE
    SELECT DATA_DEFAULT INTO default_val
      FROM DBA_TAB_COLUMNS
      WHERE TABLE_NAME = 'CTL_VERSION_HISTORY'
      AND COLUMN_NAME = 'SEQ'
      AND OWNER = upper('$(DbSchema)');
    
    IF LENGTH(default_val) > 0 THEN
      dbms_output.put_line('      ctl_version_history.seq have already a default valie');
    ELSE
      IF default_val IS NOT NULL AND UPPER(default_val) LIKE '%NEXTVAL' THEN
        dbms_output.put_line('      ctl_version_history.seq is already an IDENTITY on the default value');
      ELSE
        EXECUTE IMMEDIATE 'ALTER TABLE ctl_version_history DROP COLUMN seq';
        dbms_output.put_line('Table ctl_version_history.seq dropped');
      END IF;
    END IF;
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('ctl_version_history','seq') THEN
       dbms_output.put_line('      ctl_version_history.seq already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_version_history ADD seq  NUMBER(19, 0)  GENERATED BY DEFAULT ON NULL AS IDENTITY';
    dbms_output.put_line('     ctl_version_history.seq created');
  END IF;
END;
/

BEGIN
  IF SP_PRIMARYKEY_EXISTS ('pk_ctl_version_history') THEN
      dbms_output.put_line('     pk_ctl_version_history already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_version_history ADD CONSTRAINT pk_ctl_version_history PRIMARY KEY (organization_id, seq) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     pk_ctl_version_history created');
  END IF;
END;
/



BEGIN
  IF NOT SP_TRIGGER_EXISTS ('CTL_VERSION_HISTORY_SEQ_TRGR') THEN
    dbms_output.put_line('Trigger CTL_VERSION_HISTORY_SEQ_TRGR already dropped');
  ELSE
    BEGIN
      EXECUTE IMMEDIATE 'DROP TRIGGER CTL_VERSION_HISTORY_SEQ_TRGR';
      dbms_output.put_line('Trigger CTL_VERSION_HISTORY_SEQ_TRGR dropped');
    END;
  END IF;
END;
/
BEGIN
    dbms_output.put_line('     Step Update version table to use identity type end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[StateJournal] Field[[Field=timeStamp]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE loc_state_journal MODIFY time_stamp TIMESTAMP(6) DEFAULT (null)';
    dbms_output.put_line('     Column loc_state_journal.time_stamp modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('loc_state_journal','time_stamp') THEN
      dbms_output.put_line('     Column loc_state_journal.time_stamp already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_state_journal MODIFY time_stamp NOT NULL';
    dbms_output.put_line('     Column loc_state_journal.time_stamp modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[StateJournal] Field[[Field=timeStamp]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DeviceInformation] Field[[Field=deviceName, Field=deviceType, Field=model, Field=serialNumber]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_device_information MODIFY device_name VARCHAR2(255 char) DEFAULT (null)';
    dbms_output.put_line('     Column ctl_device_information.device_name modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('ctl_device_information','device_name') THEN
      dbms_output.put_line('     Column ctl_device_information.device_name already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_device_information MODIFY device_name NULL';
    dbms_output.put_line('     Column ctl_device_information.device_name modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_device_information MODIFY device_type VARCHAR2(255 char) DEFAULT (null)';
    dbms_output.put_line('     Column ctl_device_information.device_type modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('ctl_device_information','device_type') THEN
      dbms_output.put_line('     Column ctl_device_information.device_type already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_device_information MODIFY device_type NULL';
    dbms_output.put_line('     Column ctl_device_information.device_type modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_device_information MODIFY model VARCHAR2(255 char) DEFAULT (null)';
    dbms_output.put_line('     Column ctl_device_information.model modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('ctl_device_information','model') THEN
      dbms_output.put_line('     Column ctl_device_information.model already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_device_information MODIFY model NULL';
    dbms_output.put_line('     Column ctl_device_information.model modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_device_information MODIFY serial_number VARCHAR2(255 char) DEFAULT (null)';
    dbms_output.put_line('     Column ctl_device_information.serial_number modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('ctl_device_information','serial_number') THEN
      dbms_output.put_line('     Column ctl_device_information.serial_number already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_device_information MODIFY serial_number NULL';
    dbms_output.put_line('     Column ctl_device_information.serial_number modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DeviceInformation] Field[[Field=deviceName, Field=deviceType, Field=model, Field=serialNumber]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[SaleInvoice] Field[[Field=confirmSentFlag, Field=returnFlag, Field=confirmFlag, Field=voidPendingFlag]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE civc_invoice MODIFY confirm_sent_flag NUMBER(1, 0) DEFAULT 0';
    dbms_output.put_line('     Column civc_invoice.confirm_sent_flag modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('civc_invoice','confirm_sent_flag') THEN
      dbms_output.put_line('     Column civc_invoice.confirm_sent_flag already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE civc_invoice MODIFY confirm_sent_flag NULL';
    dbms_output.put_line('     Column civc_invoice.confirm_sent_flag modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE civc_invoice MODIFY return_flag NUMBER(1, 0) DEFAULT 0';
    dbms_output.put_line('     Column civc_invoice.return_flag modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('civc_invoice','return_flag') THEN
      dbms_output.put_line('     Column civc_invoice.return_flag already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE civc_invoice MODIFY return_flag NULL';
    dbms_output.put_line('     Column civc_invoice.return_flag modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE civc_invoice MODIFY confirm_flag NUMBER(1, 0) DEFAULT 0';
    dbms_output.put_line('     Column civc_invoice.confirm_flag modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('civc_invoice','confirm_flag') THEN
      dbms_output.put_line('     Column civc_invoice.confirm_flag already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE civc_invoice MODIFY confirm_flag NULL';
    dbms_output.put_line('     Column civc_invoice.confirm_flag modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE civc_invoice MODIFY void_pending_flag NUMBER(1, 0) DEFAULT 0';
    dbms_output.put_line('     Column civc_invoice.void_pending_flag modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('civc_invoice','void_pending_flag') THEN
      dbms_output.put_line('     Column civc_invoice.void_pending_flag already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE civc_invoice MODIFY void_pending_flag NULL';
    dbms_output.put_line('     Column civc_invoice.void_pending_flag modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[SaleInvoice] Field[[Field=confirmSentFlag, Field=returnFlag, Field=confirmFlag, Field=voidPendingFlag]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TaxBracket] Field[[Field=orgCode, Field=orgValue]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE tax_tax_bracket MODIFY org_code VARCHAR2(30 char) DEFAULT ''*''';
    dbms_output.put_line('     Column tax_tax_bracket.org_code modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('tax_tax_bracket','org_code') THEN
      dbms_output.put_line('     Column tax_tax_bracket.org_code already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE tax_tax_bracket MODIFY org_code NULL';
    dbms_output.put_line('     Column tax_tax_bracket.org_code modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE tax_tax_bracket MODIFY org_value VARCHAR2(60 char) DEFAULT ''*''';
    dbms_output.put_line('     Column tax_tax_bracket.org_value modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('tax_tax_bracket','org_value') THEN
      dbms_output.put_line('     Column tax_tax_bracket.org_value already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE tax_tax_bracket MODIFY org_value NULL';
    dbms_output.put_line('     Column tax_tax_bracket.org_value modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[TaxBracket] Field[[Field=orgCode, Field=orgValue]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Align ctl_event_log to the Oracle definition starting...');
END;
/
-- Leave this file here to workaround a known issue for new database maintenance function
BEGIN
    dbms_output.put_line('     Step Align ctl_event_log to the Oracle definition end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add record state column to the missing tables starting...');
END;
/
BEGIN
    dbms_output.put_line('     Adding missing record state column...');
END;
/


BEGIN
  IF SP_COLUMN_EXISTS ('RMS_RELATED_ITEM_HEAD','record_state') THEN
       dbms_output.put_line('      RMS_RELATED_ITEM_HEAD.record_state already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE RMS_RELATED_ITEM_HEAD ADD record_state VARCHAR2(30 char)';
    dbms_output.put_line('     RMS_RELATED_ITEM_HEAD.record_state created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('RMS_DIFF_GROUP_DETAIL','record_state') THEN
       dbms_output.put_line('      RMS_DIFF_GROUP_DETAIL.record_state already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE RMS_DIFF_GROUP_DETAIL ADD record_state VARCHAR2(30 char)';
    dbms_output.put_line('     RMS_DIFF_GROUP_DETAIL.record_state created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('LOG_SP_REPORT','record_state') THEN
       dbms_output.put_line('      LOG_SP_REPORT.record_state already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE LOG_SP_REPORT ADD record_state VARCHAR2(30 char)';
    dbms_output.put_line('     LOG_SP_REPORT.record_state created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('RMS_DIFF_GROUP_HEAD','record_state') THEN
       dbms_output.put_line('      RMS_DIFF_GROUP_HEAD.record_state already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE RMS_DIFF_GROUP_HEAD ADD record_state VARCHAR2(30 char)';
    dbms_output.put_line('     RMS_DIFF_GROUP_HEAD.record_state created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('RMS_DIFF_IDS','record_state') THEN
       dbms_output.put_line('      RMS_DIFF_IDS.record_state already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE RMS_DIFF_IDS ADD record_state VARCHAR2(30 char)';
    dbms_output.put_line('     RMS_DIFF_IDS.record_state created');
  END IF;
END;
/
BEGIN
    dbms_output.put_line('     Step Add record state column to the missing tables end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[SpReport] Column[[Field=createDate, Field=createUserId, Field=updateDate, Field=updateUserId]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('log_sp_report','create_date') THEN
       dbms_output.put_line('      Column log_sp_report.create_date already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE log_sp_report ADD create_date TIMESTAMP(6)';
    dbms_output.put_line('     Column log_sp_report.create_date created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('log_sp_report','create_user_id') THEN
       dbms_output.put_line('      Column log_sp_report.create_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE log_sp_report ADD create_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column log_sp_report.create_user_id created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('log_sp_report','update_date') THEN
       dbms_output.put_line('      Column log_sp_report.update_date already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE log_sp_report ADD update_date TIMESTAMP(6)';
    dbms_output.put_line('     Column log_sp_report.update_date created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('log_sp_report','update_user_id') THEN
       dbms_output.put_line('      Column log_sp_report.update_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE log_sp_report ADD update_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column log_sp_report.update_user_id created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[SpReport] Column[[Field=createDate, Field=createUserId, Field=updateDate, Field=updateUserId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[RelatedItemHead] Column[[Field=createUserId, Field=updateUserId]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('rms_related_item_head','create_user_id') THEN
       dbms_output.put_line('      Column rms_related_item_head.create_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_related_item_head ADD create_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column rms_related_item_head.create_user_id created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('rms_related_item_head','update_user_id') THEN
       dbms_output.put_line('      Column rms_related_item_head.update_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_related_item_head ADD update_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column rms_related_item_head.update_user_id created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[RelatedItemHead] Column[[Field=createUserId, Field=updateUserId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[DiffGroupDetail] Column[[Field=createUserId, Field=updateUserId]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('rms_diff_group_detail','create_user_id') THEN
       dbms_output.put_line('      Column rms_diff_group_detail.create_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_diff_group_detail ADD create_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column rms_diff_group_detail.create_user_id created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('rms_diff_group_detail','update_user_id') THEN
       dbms_output.put_line('      Column rms_diff_group_detail.update_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_diff_group_detail ADD update_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column rms_diff_group_detail.update_user_id created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[DiffGroupDetail] Column[[Field=createUserId, Field=updateUserId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[DiffGroupHead] Column[[Field=createUserId, Field=updateUserId]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('rms_diff_group_head','create_user_id') THEN
       dbms_output.put_line('      Column rms_diff_group_head.create_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_diff_group_head ADD create_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column rms_diff_group_head.create_user_id created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('rms_diff_group_head','update_user_id') THEN
       dbms_output.put_line('      Column rms_diff_group_head.update_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_diff_group_head ADD update_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column rms_diff_group_head.update_user_id created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[DiffGroupHead] Column[[Field=createUserId, Field=updateUserId]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[DiffIds] Column[[Field=createUserId, Field=updateUserId]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('rms_diff_ids','create_user_id') THEN
       dbms_output.put_line('      Column rms_diff_ids.create_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_diff_ids ADD create_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column rms_diff_ids.create_user_id created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('rms_diff_ids','update_user_id') THEN
       dbms_output.put_line('      Column rms_diff_ids.update_user_id already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rms_diff_ids ADD update_user_id VARCHAR2(256 char)';
    dbms_output.put_line('     Column rms_diff_ids.update_user_id created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[DiffIds] Column[[Field=createUserId, Field=updateUserId]] end.');
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
    dbms_output.put_line('     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITEM02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_SALE_LINEITEM02') THEN
      dbms_output.put_line('     Index IDX_TRL_SALE_LINEITEM02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_SALE_LINEITEM02 ON trl_sale_lineitm(organization_id, business_date, UPPER(sale_lineitm_typcode))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_SALE_LINEITEM02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITEM02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE03] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_RPT_SALE_LINE03') THEN
      dbms_output.put_line('     Index IDX_RPT_SALE_LINE03 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_RPT_SALE_LINE03 ON rpt_sale_line(organization_id, UPPER(trans_statcode), business_date, rtl_loc_id, wkstn_id, trans_seq, rtrans_lineitm_seq, quantity, net_amt)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_RPT_SALE_LINE03 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_RTRANS_LINEITM01') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_RTRANS_LINEITM01 ON trl_rtrans_lineitm(trans_seq, business_date, rtl_loc_id, wkstn_id, organization_id, rtrans_lineitm_seq)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_RTRANS_LINEITM02') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_RTRANS_LINEITM02 ON trl_rtrans_lineitm(organization_id, void_flag, business_date)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PartyEmail] Index[XST_CRM_PARTY_EMAIL01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_CRM_PARTY_EMAIL01') THEN
      dbms_output.put_line('     Index XST_CRM_PARTY_EMAIL01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_CRM_PARTY_EMAIL01 ON crm_party_email(UPPER(email_address))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index XST_CRM_PARTY_EMAIL01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PartyEmail] Index[XST_CRM_PARTY_EMAIL01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_RTRANS02') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_RTRANS02 ON trl_rtrans(cust_party_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_RTRANS02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TenderLineItem] Index[IDX_TTR_TNDR_LINEITM01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TTR_TNDR_LINEITM01') THEN
      dbms_output.put_line('     Index IDX_TTR_TNDR_LINEITM01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TTR_TNDR_LINEITM01 ON ttr_tndr_lineitm(trans_seq, business_date, rtl_loc_id, wkstn_id, organization_id, rtrans_lineitm_seq)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TTR_TNDR_LINEITM01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TenderLineItem] Index[IDX_TTR_TNDR_LINEITM01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemOptions] Index[IDX_ITM_ITEM_OPTIONS] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_OPTIONS') THEN
      dbms_output.put_line('     Index IDX_ITM_ITEM_OPTIONS already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_OPTIONS ON itm_item_options(organization_id, item_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_ITM_ITEM_OPTIONS created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemOptions] Index[IDX_ITM_ITEM_OPTIONS] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailPriceModifier] Index[IDX_TRL_RTL_PRICE_MOD01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_RTL_PRICE_MOD01') THEN
      dbms_output.put_line('     Index IDX_TRL_RTL_PRICE_MOD01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_RTL_PRICE_MOD01 ON trl_rtl_price_mod(trans_seq, business_date, rtl_loc_id, wkstn_id, organization_id, rtrans_lineitm_seq, rtl_price_mod_seq_nbr)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_RTL_PRICE_MOD01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailPriceModifier] Index[IDX_TRL_RTL_PRICE_MOD01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITM01] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_sale_lineitm');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_sale_lineitm is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_sale_lineitm DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK trl_sale_lineitm dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TRL_SALE_LINEITM01') THEN
      dbms_output.put_line('     Index IDX_TRL_SALE_LINEITM01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TRL_SALE_LINEITM01';
    dbms_output.put_line('     Index IDX_TRL_SALE_LINEITM01 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_sale_lineitm');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_sale_lineitm already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_sale_lineitm ADD CONSTRAINT pk_trl_sale_lineitm PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_trl_sale_lineitm created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITM01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITM01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_SALE_LINEITM01') THEN
      dbms_output.put_line('     Index IDX_TRL_SALE_LINEITM01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_SALE_LINEITM01 ON trl_sale_lineitm(trans_seq, business_date, rtl_loc_id, wkstn_id, organization_id, rtrans_lineitm_seq)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_SALE_LINEITM01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITM01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE01] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('rpt_sale_line');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK rpt_sale_line is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rpt_sale_line DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK rpt_sale_line dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_RPT_SALE_LINE01') THEN
      dbms_output.put_line('     Index IDX_RPT_SALE_LINE01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_RPT_SALE_LINE01';
    dbms_output.put_line('     Index IDX_RPT_SALE_LINE01 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('rpt_sale_line');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK rpt_sale_line already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rpt_sale_line ADD CONSTRAINT pk_rpt_sale_line PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_rpt_sale_line created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_RPT_SALE_LINE01') THEN
      dbms_output.put_line('     Index IDX_RPT_SALE_LINE01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_RPT_SALE_LINE01 ON rpt_sale_line(trans_seq, business_date, rtl_loc_id, wkstn_id, organization_id, rtrans_lineitm_seq)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_RPT_SALE_LINE01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE02] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('rpt_sale_line');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK rpt_sale_line is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rpt_sale_line DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK rpt_sale_line dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_RPT_SALE_LINE02') THEN
      dbms_output.put_line('     Index IDX_RPT_SALE_LINE02 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_RPT_SALE_LINE02';
    dbms_output.put_line('     Index IDX_RPT_SALE_LINE02 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('rpt_sale_line');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK rpt_sale_line already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE rpt_sale_line ADD CONSTRAINT pk_rpt_sale_line PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_rpt_sale_line created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_RPT_SALE_LINE02') THEN
      dbms_output.put_line('     Index IDX_RPT_SALE_LINE02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_RPT_SALE_LINE02 ON rpt_sale_line(cust_party_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_RPT_SALE_LINE02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK trl_rtrans_lineitm dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm_P');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm_P is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm_P DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK trl_rtrans_lineitm_P dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TRL_RTRANS_LINEITM01') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TRL_RTRANS_LINEITM01';
    dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM01 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm ADD CONSTRAINT pk_trl_rtrans_lineitm PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_trl_rtrans_lineitm created');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm_P');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm_P already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm_P ADD CONSTRAINT pk_trl_rtrans_lineitm_P PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq, property_code) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_trl_rtrans_lineitm_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_RTRANS_LINEITM01') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_RTRANS_LINEITM01 ON trl_rtrans_lineitm(trans_seq, business_date, rtl_loc_id, wkstn_id, organization_id, rtrans_lineitm_seq)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK trl_rtrans_lineitm dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm_P');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm_P is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm_P DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK trl_rtrans_lineitm_P dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TRL_RTRANS_LINEITM02') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM02 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TRL_RTRANS_LINEITM02';
    dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM02 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm ADD CONSTRAINT pk_trl_rtrans_lineitm PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_trl_rtrans_lineitm created');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm_P');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm_P already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm_P ADD CONSTRAINT pk_trl_rtrans_lineitm_P PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq, property_code) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_trl_rtrans_lineitm_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_RTRANS_LINEITM02') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_RTRANS_LINEITM02 ON trl_rtrans_lineitm(organization_id, void_flag, business_date)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM03] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK trl_rtrans_lineitm dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm_P');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm_P is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm_P DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK trl_rtrans_lineitm_P dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TRL_RTRANS_LINEITM03') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM03 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TRL_RTRANS_LINEITM03';
    dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM03 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm ADD CONSTRAINT pk_trl_rtrans_lineitm PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_trl_rtrans_lineitm created');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans_lineitm_P');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans_lineitm_P already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans_lineitm_P ADD CONSTRAINT pk_trl_rtrans_lineitm_P PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq, property_code) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_trl_rtrans_lineitm_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM03] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_RTRANS_LINEITM03') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM03 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_RTRANS_LINEITM03 ON trl_rtrans_lineitm(organization_id, rtl_loc_id, wkstn_id, trans_seq, void_flag)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_RTRANS_LINEITM03 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransactionLineItem] Index[IDX_TRL_RTRANS_LINEITM03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS01] starting...');
END;
/
DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans');
BEGIN
  IF pk_name = 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans is missing');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans DROP CONSTRAINT ' || pk_name || '';
    dbms_output.put_line('     PK trl_rtrans dropped');
  END IF;
END;
/

BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TRL_RTRANS01') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TRL_RTRANS01';
    dbms_output.put_line('     Index IDX_TRL_RTRANS01 dropped');
  END IF;
END;
/

DECLARE pk_name varchar2(256) := SP_PK_CONSTRAINT_EXISTS('trl_rtrans');
BEGIN
  IF pk_name <> 'NOT_FOUND'  THEN
      dbms_output.put_line('     PK trl_rtrans already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE trl_rtrans ADD CONSTRAINT pk_trl_rtrans PRIMARY KEY (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq) USING INDEX TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     PK pk_trl_rtrans created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_RTRANS01') THEN
      dbms_output.put_line('     Index IDX_TRL_RTRANS01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_RTRANS01 ON trl_rtrans(trans_seq, business_date, rtl_loc_id, wkstn_id, organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     Index IDX_TRL_RTRANS01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RetailTransaction] Index[IDX_TRL_RTRANS01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Upgrade some indexes to use the column with UPPER() starting...');
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[EventLogEntry] Index[IDX_CTL_EVENT_LOG02] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CTL_EVENT_LOG02') THEN
      dbms_output.put_line('     IDX_CTL_EVENT_LOG02 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CTL_EVENT_LOG02';
    dbms_output.put_line('     IDX_CTL_EVENT_LOG02 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[EventLogEntry] Index[IDX_CTL_EVENT_LOG02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[EventLogEntry] Index[IDX_CTL_EVENT_LOG02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_CTL_EVENT_LOG02') THEN
      dbms_output.put_line('     IDX_CTL_EVENT_LOG02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CTL_EVENT_LOG02 ON ctl_event_log(arrival_timestamp, organization_id, UPPER(logger_category), create_date)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_CTL_EVENT_LOG02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[EventLogEntry] Index[IDX_CTL_EVENT_LOG02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL2] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_ITEM_MRCHLVL2') THEN
      dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL2 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_ITEM_MRCHLVL2';
    dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL2 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL2] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL2] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_ITM_ITEM_MRCHLVL2') THEN
      dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL2 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_ITM_ITEM_MRCHLVL2 ON itm_item(organization_id, UPPER(merch_level_2))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL2 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL2] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL1] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_ITEM_MRCHLVL1') THEN
      dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL1 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_ITEM_MRCHLVL1';
    dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL1 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL1] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL1] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_ITM_ITEM_MRCHLVL1') THEN
      dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL1 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_ITM_ITEM_MRCHLVL1 ON itm_item(organization_id, UPPER(merch_level_1))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL1 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL1] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxLocation] Index[IDX_TAX_TAX_LOC_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TAX_TAX_LOC_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_LOC_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TAX_TAX_LOC_ORGNODE';
    dbms_output.put_line('     IDX_TAX_TAX_LOC_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxLocation] Index[IDX_TAX_TAX_LOC_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxLocation] Index[IDX_TAX_TAX_LOC_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TAX_TAX_LOC_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_LOC_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TAX_TAX_LOC_ORGNODE ON tax_tax_loc(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_TAX_TAX_LOC_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxLocation] Index[IDX_TAX_TAX_LOC_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL4] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_ITEM_MRCHLVL4') THEN
      dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL4 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_ITEM_MRCHLVL4';
    dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL4 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL4] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL4] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_ITM_ITEM_MRCHLVL4') THEN
      dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL4 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_ITM_ITEM_MRCHLVL4 ON itm_item(organization_id, UPPER(merch_level_4))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL4 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL4] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkOrderCategory] Index[IDX_CWO_WORK_ORDER_CAT_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CWO_WORK_ORDER_CAT_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_WORK_ORDER_CAT_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CWO_WORK_ORDER_CAT_ORGNODE';
    dbms_output.put_line('     IDX_CWO_WORK_ORDER_CAT_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkOrderCategory] Index[IDX_CWO_WORK_ORDER_CAT_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkOrderCategory] Index[IDX_CWO_WORK_ORDER_CAT_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_CWO_WORK_ORDER_CAT_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_WORK_ORDER_CAT_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CWO_WORK_ORDER_CAT_ORGNODE ON cwo_work_order_category(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_CWO_WORK_ORDER_CAT_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkOrderCategory] Index[IDX_CWO_WORK_ORDER_CAT_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL3] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_ITEM_MRCHLVL3') THEN
      dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL3 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_ITEM_MRCHLVL3';
    dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL3 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL3] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL3] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_ITM_ITEM_MRCHLVL3') THEN
      dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL3 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_ITM_ITEM_MRCHLVL3 ON itm_item(organization_id, UPPER(merch_level_3))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_ITM_ITEM_MRCHLVL3 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_MRCHLVL3] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemCrossReference] Index[IDX_ITM_ITEM_XREFERENCEORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM_XREFERENCEORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_XREFERENCEORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM_XREFERENCEORGNODE';
    dbms_output.put_line('     IDX_ITM_ITEM_XREFERENCEORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemCrossReference] Index[IDX_ITM_ITEM_XREFERENCEORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemCrossReference] Index[IDX_ITM_ITEM_XREFERENCEORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_XREFERENCEORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_XREFERENCEORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_XREFERENCEORGNODE ON itm_item_cross_reference(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM_XREFERENCEORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemCrossReference] Index[IDX_ITM_ITEM_XREFERENCEORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemMessageCrossReference] Index[IDX_ITM_ITEM_MSG_XREF_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM_MSG_XREF_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_MSG_XREF_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM_MSG_XREF_ORGNODE';
    dbms_output.put_line('     IDX_ITM_ITEM_MSG_XREF_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemMessageCrossReference] Index[IDX_ITM_ITEM_MSG_XREF_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemMessageCrossReference] Index[IDX_ITM_ITEM_MSG_XREF_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_MSG_XREF_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_MSG_XREF_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_MSG_XREF_ORGNODE ON itm_item_msg_cross_reference(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM_MSG_XREF_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemMessageCrossReference] Index[IDX_ITM_ITEM_MSG_XREF_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Shipper] Index[IDX_INV_SHIPPER_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_INV_SHIPPER_ORGNODE') THEN
      dbms_output.put_line('     IDX_INV_SHIPPER_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_INV_SHIPPER_ORGNODE';
    dbms_output.put_line('     IDX_INV_SHIPPER_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Shipper] Index[IDX_INV_SHIPPER_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Shipper] Index[IDX_INV_SHIPPER_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_INV_SHIPPER_ORGNODE') THEN
      dbms_output.put_line('     IDX_INV_SHIPPER_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_INV_SHIPPER_ORGNODE ON inv_shipper(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_INV_SHIPPER_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Shipper] Index[IDX_INV_SHIPPER_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemDimensionValue] Index[IDX_ITM_ITEM_DIM_VALUE_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM_DIM_VALUE_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_DIM_VALUE_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM_DIM_VALUE_ORGNODE';
    dbms_output.put_line('     IDX_ITM_ITEM_DIM_VALUE_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemDimensionValue] Index[IDX_ITM_ITEM_DIM_VALUE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemDimensionValue] Index[IDX_ITM_ITEM_DIM_VALUE_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_DIM_VALUE_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_DIM_VALUE_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_DIM_VALUE_ORGNODE ON itm_item_dimension_value(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM_DIM_VALUE_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemDimensionValue] Index[IDX_ITM_ITEM_DIM_VALUE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RefundSchedule] Index[IDX_ITM_REFND_SCHEDULE_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_REFND_SCHEDULE_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_REFND_SCHEDULE_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_REFND_SCHEDULE_ORGNODE';
    dbms_output.put_line('     IDX_ITM_REFND_SCHEDULE_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RefundSchedule] Index[IDX_ITM_REFND_SCHEDULE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RefundSchedule] Index[IDX_ITM_REFND_SCHEDULE_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_REFND_SCHEDULE_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_REFND_SCHEDULE_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_REFND_SCHEDULE_ORGNODE ON itm_refund_schedule(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_REFND_SCHEDULE_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RefundSchedule] Index[IDX_ITM_REFND_SCHEDULE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD04] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_XOM_CUSTOMER_MOD04') THEN
      dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD04 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_XOM_CUSTOMER_MOD04';
    dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD04 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD04] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD04] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_XOM_CUSTOMER_MOD04') THEN
      dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD04 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_XOM_CUSTOMER_MOD04 ON xom_customer_mod(UPPER(telephone2), organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD04 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD04] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITEM02] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TRL_SALE_LINEITEM02') THEN
      dbms_output.put_line('     IDX_TRL_SALE_LINEITEM02 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TRL_SALE_LINEITEM02';
    dbms_output.put_line('     IDX_TRL_SALE_LINEITEM02 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITEM02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITEM02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRL_SALE_LINEITEM02') THEN
      dbms_output.put_line('     IDX_TRL_SALE_LINEITEM02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRL_SALE_LINEITEM02 ON trl_sale_lineitm(organization_id, business_date, UPPER(sale_lineitm_typcode))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_TRL_SALE_LINEITEM02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleReturnLineItem] Index[IDX_TRL_SALE_LINEITEM02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemMessage] Index[IDX_ITM_ITEM_MSG_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM_MSG_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_MSG_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM_MSG_ORGNODE';
    dbms_output.put_line('     IDX_ITM_ITEM_MSG_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemMessage] Index[IDX_ITM_ITEM_MSG_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemMessage] Index[IDX_ITM_ITEM_MSG_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_MSG_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_MSG_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_MSG_ORGNODE ON itm_item_msg(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM_MSG_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemMessage] Index[IDX_ITM_ITEM_MSG_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[MatrixSortOrder] Index[IDX_ITM_MATRIX_SORTORD_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_MATRIX_SORTORD_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_MATRIX_SORTORD_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_MATRIX_SORTORD_ORGNODE';
    dbms_output.put_line('     IDX_ITM_MATRIX_SORTORD_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[MatrixSortOrder] Index[IDX_ITM_MATRIX_SORTORD_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[MatrixSortOrder] Index[IDX_ITM_MATRIX_SORTORD_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_MATRIX_SORTORD_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_MATRIX_SORTORD_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_MATRIX_SORTORD_ORGNODE ON itm_matrix_sort_order(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_MATRIX_SORTORD_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[MatrixSortOrder] Index[IDX_ITM_MATRIX_SORTORD_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ReportData] Index[IDX_COM_REPORT_DATA_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_COM_REPORT_DATA_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_REPORT_DATA_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_COM_REPORT_DATA_ORGNODE';
    dbms_output.put_line('     IDX_COM_REPORT_DATA_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ReportData] Index[IDX_COM_REPORT_DATA_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ReportData] Index[IDX_COM_REPORT_DATA_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_COM_REPORT_DATA_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_REPORT_DATA_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_COM_REPORT_DATA_ORGNODE ON com_report_data(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_COM_REPORT_DATA_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ReportData] Index[IDX_COM_REPORT_DATA_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxAuthority] Index[IDX_TAX_TAX_AUTHORITY_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TAX_TAX_AUTHORITY_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_AUTHORITY_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TAX_TAX_AUTHORITY_ORGNODE';
    dbms_output.put_line('     IDX_TAX_TAX_AUTHORITY_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxAuthority] Index[IDX_TAX_TAX_AUTHORITY_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxAuthority] Index[IDX_TAX_TAX_AUTHORITY_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TAX_TAX_AUTHORITY_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_AUTHORITY_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TAX_TAX_AUTHORITY_ORGNODE ON tax_tax_authority(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_TAX_TAX_AUTHORITY_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxAuthority] Index[IDX_TAX_TAX_AUTHORITY_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE03] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_RPT_SALE_LINE03') THEN
      dbms_output.put_line('     IDX_RPT_SALE_LINE03 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_RPT_SALE_LINE03';
    dbms_output.put_line('     IDX_RPT_SALE_LINE03 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE03] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_RPT_SALE_LINE03') THEN
      dbms_output.put_line('     IDX_RPT_SALE_LINE03 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_RPT_SALE_LINE03 ON rpt_sale_line(organization_id, UPPER(trans_statcode), business_date, rtl_loc_id, wkstn_id, trans_seq, rtrans_lineitm_seq, quantity, net_amt)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_RPT_SALE_LINE03 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SaleLine] Index[IDX_RPT_SALE_LINE03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[OrgHierarchy] Index[XST_LOC_ORGHIER_LVLMGR] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_LOC_ORGHIER_LVLMGR') THEN
      dbms_output.put_line('     XST_LOC_ORGHIER_LVLMGR is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_LOC_ORGHIER_LVLMGR';
    dbms_output.put_line('     XST_LOC_ORGHIER_LVLMGR dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[OrgHierarchy] Index[XST_LOC_ORGHIER_LVLMGR] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[OrgHierarchy] Index[XST_LOC_ORGHIER_LVLMGR] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_LOC_ORGHIER_LVLMGR') THEN
      dbms_output.put_line('     XST_LOC_ORGHIER_LVLMGR already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_LOC_ORGHIER_LVLMGR ON loc_org_hierarchy(UPPER(level_mgr))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_LOC_ORGHIER_LVLMGR created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[OrgHierarchy] Index[XST_LOC_ORGHIER_LVLMGR] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxBracket] Index[IDX_TAX_TAX_BRACKET_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TAX_TAX_BRACKET_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_BRACKET_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TAX_TAX_BRACKET_ORGNODE';
    dbms_output.put_line('     IDX_TAX_TAX_BRACKET_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxBracket] Index[IDX_TAX_TAX_BRACKET_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxBracket] Index[IDX_TAX_TAX_BRACKET_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TAX_TAX_BRACKET_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_BRACKET_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TAX_TAX_BRACKET_ORGNODE ON tax_tax_bracket(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_TAX_TAX_BRACKET_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxBracket] Index[IDX_TAX_TAX_BRACKET_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD02] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_XOM_CUSTOMER_MOD02') THEN
      dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD02 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_XOM_CUSTOMER_MOD02';
    dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD02 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_XOM_CUSTOMER_MOD02') THEN
      dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_XOM_CUSTOMER_MOD02 ON xom_customer_mod(UPPER(last_name), UPPER(first_name), UPPER(telephone1), UPPER(telephone2), organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WarrantyItemPrice] Index[IDXITMWARRANTYITEMPRICEORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDXITMWARRANTYITEMPRICEORGNODE') THEN
      dbms_output.put_line('     IDXITMWARRANTYITEMPRICEORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDXITMWARRANTYITEMPRICEORGNODE';
    dbms_output.put_line('     IDXITMWARRANTYITEMPRICEORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WarrantyItemPrice] Index[IDXITMWARRANTYITEMPRICEORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WarrantyItemPrice] Index[IDXITMWARRANTYITEMPRICEORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDXITMWARRANTYITEMPRICEORGNODE') THEN
      dbms_output.put_line('     IDXITMWARRANTYITEMPRICEORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDXITMWARRANTYITEMPRICEORGNODE ON itm_warranty_item_price(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDXITMWARRANTYITEMPRICEORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WarrantyItemPrice] Index[IDXITMWARRANTYITEMPRICEORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD03] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_XOM_CUSTOMER_MOD03') THEN
      dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD03 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_XOM_CUSTOMER_MOD03';
    dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD03 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD03] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_XOM_CUSTOMER_MOD03') THEN
      dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD03 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_XOM_CUSTOMER_MOD03 ON xom_customer_mod(UPPER(telephone1), organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_XOM_CUSTOMER_MOD03 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CustomerModifier] Index[IDX_XOM_CUSTOMER_MOD03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealDocumentXref] Index[IDX_PRC_DEAL_DOC_XREF_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_PRC_DEAL_DOC_XREF_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_DOC_XREF_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_PRC_DEAL_DOC_XREF_ORGNODE';
    dbms_output.put_line('     IDX_PRC_DEAL_DOC_XREF_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealDocumentXref] Index[IDX_PRC_DEAL_DOC_XREF_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealDocumentXref] Index[IDX_PRC_DEAL_DOC_XREF_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_PRC_DEAL_DOC_XREF_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_DOC_XREF_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_PRC_DEAL_DOC_XREF_ORGNODE ON prc_deal_document_xref(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_PRC_DEAL_DOC_XREF_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealDocumentXref] Index[IDX_PRC_DEAL_DOC_XREF_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Shift] Index[IDX_SCH_SHIFT_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_SCH_SHIFT_ORGNODE') THEN
      dbms_output.put_line('     IDX_SCH_SHIFT_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_SCH_SHIFT_ORGNODE';
    dbms_output.put_line('     IDX_SCH_SHIFT_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Shift] Index[IDX_SCH_SHIFT_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Shift] Index[IDX_SCH_SHIFT_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_SCH_SHIFT_ORGNODE') THEN
      dbms_output.put_line('     IDX_SCH_SHIFT_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_SCH_SHIFT_ORGNODE ON sch_shift(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_SCH_SHIFT_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Shift] Index[IDX_SCH_SHIFT_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerAccountPlan] Index[IDX_CAT_CUST_ACCT_PLAN_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CAT_CUST_ACCT_PLAN_ORGNODE') THEN
      dbms_output.put_line('     IDX_CAT_CUST_ACCT_PLAN_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CAT_CUST_ACCT_PLAN_ORGNODE';
    dbms_output.put_line('     IDX_CAT_CUST_ACCT_PLAN_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CustomerAccountPlan] Index[IDX_CAT_CUST_ACCT_PLAN_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CustomerAccountPlan] Index[IDX_CAT_CUST_ACCT_PLAN_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_CAT_CUST_ACCT_PLAN_ORGNODE') THEN
      dbms_output.put_line('     IDX_CAT_CUST_ACCT_PLAN_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CAT_CUST_ACCT_PLAN_ORGNODE ON cat_cust_acct_plan(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_CAT_CUST_ACCT_PLAN_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CustomerAccountPlan] Index[IDX_CAT_CUST_ACCT_PLAN_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemCrossReference] Index[XST_ITM_XREF_ITEMID] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_XREF_ITEMID') THEN
      dbms_output.put_line('     XST_ITM_XREF_ITEMID is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_XREF_ITEMID';
    dbms_output.put_line('     XST_ITM_XREF_ITEMID dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemCrossReference] Index[XST_ITM_XREF_ITEMID] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemCrossReference] Index[XST_ITM_XREF_ITEMID] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_ITM_XREF_ITEMID') THEN
      dbms_output.put_line('     XST_ITM_XREF_ITEMID already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_ITM_XREF_ITEMID ON itm_item_cross_reference(organization_id, UPPER(item_id))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_ITM_XREF_ITEMID created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemCrossReference] Index[XST_ITM_XREF_ITEMID] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShippingCost] Index[IDX_COM_SHIPPING_COST_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_COM_SHIPPING_COST_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_SHIPPING_COST_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_COM_SHIPPING_COST_ORGNODE';
    dbms_output.put_line('     IDX_COM_SHIPPING_COST_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShippingCost] Index[IDX_COM_SHIPPING_COST_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShippingCost] Index[IDX_COM_SHIPPING_COST_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_COM_SHIPPING_COST_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_SHIPPING_COST_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_COM_SHIPPING_COST_ORGNODE ON com_shipping_cost(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_COM_SHIPPING_COST_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShippingCost] Index[IDX_COM_SHIPPING_COST_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_ID_PARENTID] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_ITEM_ID_PARENTID') THEN
      dbms_output.put_line('     XST_ITM_ITEM_ID_PARENTID is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_ITEM_ID_PARENTID';
    dbms_output.put_line('     XST_ITM_ITEM_ID_PARENTID dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_ID_PARENTID] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_ID_PARENTID] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_ITM_ITEM_ID_PARENTID') THEN
      dbms_output.put_line('     XST_ITM_ITEM_ID_PARENTID already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_ITM_ITEM_ID_PARENTID ON itm_item(organization_id, UPPER(parent_item_id), item_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_ITM_ITEM_ID_PARENTID created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_ID_PARENTID] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkOrderInvoiceGlAccount] Index[IDX_CWO_INVOICE_GL_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CWO_INVOICE_GL_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_INVOICE_GL_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CWO_INVOICE_GL_ORGNODE';
    dbms_output.put_line('     IDX_CWO_INVOICE_GL_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkOrderInvoiceGlAccount] Index[IDX_CWO_INVOICE_GL_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkOrderInvoiceGlAccount] Index[IDX_CWO_INVOICE_GL_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_CWO_INVOICE_GL_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_INVOICE_GL_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CWO_INVOICE_GL_ORGNODE ON cwo_invoice_gl(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_CWO_INVOICE_GL_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkOrderInvoiceGlAccount] Index[IDX_CWO_INVOICE_GL_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PosTransaction] Index[IDX_TRN_TRANS02] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TRN_TRANS02') THEN
      dbms_output.put_line('     IDX_TRN_TRANS02 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TRN_TRANS02';
    dbms_output.put_line('     IDX_TRN_TRANS02 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PosTransaction] Index[IDX_TRN_TRANS02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PosTransaction] Index[IDX_TRN_TRANS02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRN_TRANS02') THEN
      dbms_output.put_line('     IDX_TRN_TRANS02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRN_TRANS02 ON trn_trans(organization_id, UPPER(trans_statcode), post_void_flag, business_date)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_TRN_TRANS02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PosTransaction] Index[IDX_TRN_TRANS02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxRateRuleOverride] Index[IDXTAXTAXRULEOVERRIDEORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDXTAXTAXRULEOVERRIDEORGNODE') THEN
      dbms_output.put_line('     IDXTAXTAXRULEOVERRIDEORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDXTAXTAXRULEOVERRIDEORGNODE';
    dbms_output.put_line('     IDXTAXTAXRULEOVERRIDEORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxRateRuleOverride] Index[IDXTAXTAXRULEOVERRIDEORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxRateRuleOverride] Index[IDXTAXTAXRULEOVERRIDEORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDXTAXTAXRULEOVERRIDEORGNODE') THEN
      dbms_output.put_line('     IDXTAXTAXRULEOVERRIDEORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDXTAXTAXRULEOVERRIDEORGNODE ON tax_tax_rate_rule_override(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDXTAXTAXRULEOVERRIDEORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxRateRuleOverride] Index[IDXTAXTAXRULEOVERRIDEORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PosTransaction] Index[IDX_TRN_TRANS03] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TRN_TRANS03') THEN
      dbms_output.put_line('     IDX_TRN_TRANS03 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TRN_TRANS03';
    dbms_output.put_line('     IDX_TRN_TRANS03 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PosTransaction] Index[IDX_TRN_TRANS03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PosTransaction] Index[IDX_TRN_TRANS03] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TRN_TRANS03') THEN
      dbms_output.put_line('     IDX_TRN_TRANS03 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TRN_TRANS03 ON trn_trans(rtl_loc_id, business_date, UPPER(trans_typcode), UPPER(trans_statcode), post_void_flag, organization_id, wkstn_id, trans_seq)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_TRN_TRANS03 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PosTransaction] Index[IDX_TRN_TRANS03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealItemAction] Index[IDX_PRC_DEAL_ITEM_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_PRC_DEAL_ITEM_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_ITEM_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_PRC_DEAL_ITEM_ORGNODE';
    dbms_output.put_line('     IDX_PRC_DEAL_ITEM_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealItemAction] Index[IDX_PRC_DEAL_ITEM_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealItemAction] Index[IDX_PRC_DEAL_ITEM_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_PRC_DEAL_ITEM_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_ITEM_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_PRC_DEAL_ITEM_ORGNODE ON prc_deal_item(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_PRC_DEAL_ITEM_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealItemAction] Index[IDX_PRC_DEAL_ITEM_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Vendor] Index[IDX_ITM_VENDOR_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_VENDOR_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_VENDOR_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_VENDOR_ORGNODE';
    dbms_output.put_line('     IDX_ITM_VENDOR_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Vendor] Index[IDX_ITM_VENDOR_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Vendor] Index[IDX_ITM_VENDOR_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_VENDOR_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_VENDOR_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_VENDOR_ORGNODE ON itm_vendor(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_VENDOR_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Vendor] Index[IDX_ITM_VENDOR_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShippingFeeTier] Index[XST_COM_SHIP_TIER_SHIP_METHOD] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_COM_SHIP_TIER_SHIP_METHOD') THEN
      dbms_output.put_line('     XST_COM_SHIP_TIER_SHIP_METHOD is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_COM_SHIP_TIER_SHIP_METHOD';
    dbms_output.put_line('     XST_COM_SHIP_TIER_SHIP_METHOD dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShippingFeeTier] Index[XST_COM_SHIP_TIER_SHIP_METHOD] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShippingFeeTier] Index[XST_COM_SHIP_TIER_SHIP_METHOD] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_COM_SHIP_TIER_SHIP_METHOD') THEN
      dbms_output.put_line('     XST_COM_SHIP_TIER_SHIP_METHOD already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_COM_SHIP_TIER_SHIP_METHOD ON com_shipping_fee_tier(UPPER(ship_method))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_COM_SHIP_TIER_SHIP_METHOD created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShippingFeeTier] Index[XST_COM_SHIP_TIER_SHIP_METHOD] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Order] Index[IDX_XOM_ORDER03] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_XOM_ORDER03') THEN
      dbms_output.put_line('     IDX_XOM_ORDER03 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_XOM_ORDER03';
    dbms_output.put_line('     IDX_XOM_ORDER03 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Order] Index[IDX_XOM_ORDER03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Order] Index[IDX_XOM_ORDER03] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_XOM_ORDER03') THEN
      dbms_output.put_line('     IDX_XOM_ORDER03 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_XOM_ORDER03 ON xom_order(UPPER(order_type), UPPER(status_code), organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_XOM_ORDER03 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Order] Index[IDX_XOM_ORDER03] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Order] Index[IDX_XOM_ORDER04] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_XOM_ORDER04') THEN
      dbms_output.put_line('     IDX_XOM_ORDER04 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_XOM_ORDER04';
    dbms_output.put_line('     IDX_XOM_ORDER04 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Order] Index[IDX_XOM_ORDER04] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Order] Index[IDX_XOM_ORDER04] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_XOM_ORDER04') THEN
      dbms_output.put_line('     IDX_XOM_ORDER04 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_XOM_ORDER04 ON xom_order(UPPER(status_code), organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_XOM_ORDER04 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Order] Index[IDX_XOM_ORDER04] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PricingHierarchy] Index[XST_LOC_PRICEHIER_PARENT] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_LOC_PRICEHIER_PARENT') THEN
      dbms_output.put_line('     XST_LOC_PRICEHIER_PARENT is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_LOC_PRICEHIER_PARENT';
    dbms_output.put_line('     XST_LOC_PRICEHIER_PARENT dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PricingHierarchy] Index[XST_LOC_PRICEHIER_PARENT] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PricingHierarchy] Index[XST_LOC_PRICEHIER_PARENT] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_LOC_PRICEHIER_PARENT') THEN
      dbms_output.put_line('     XST_LOC_PRICEHIER_PARENT already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_LOC_PRICEHIER_PARENT ON loc_pricing_hierarchy(UPPER(parent_code), UPPER(parent_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_LOC_PRICEHIER_PARENT created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PricingHierarchy] Index[XST_LOC_PRICEHIER_PARENT] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Order] Index[IDX_XOM_ORDER02] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_XOM_ORDER02') THEN
      dbms_output.put_line('     IDX_XOM_ORDER02 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_XOM_ORDER02';
    dbms_output.put_line('     IDX_XOM_ORDER02 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Order] Index[IDX_XOM_ORDER02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Order] Index[IDX_XOM_ORDER02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_XOM_ORDER02') THEN
      dbms_output.put_line('     IDX_XOM_ORDER02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_XOM_ORDER02 ON xom_order(order_id, UPPER(order_type), UPPER(status_code), organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_XOM_ORDER02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Order] Index[IDX_XOM_ORDER02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[IDX_ITM_ITEM_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM_ORGNODE';
    dbms_output.put_line('     IDX_ITM_ITEM_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[IDX_ITM_ITEM_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[IDX_ITM_ITEM_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_ORGNODE ON itm_item(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[IDX_ITM_ITEM_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SalesGoal] Index[IDX_SLS_SALES_GOAL_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_SLS_SALES_GOAL_ORGNODE') THEN
      dbms_output.put_line('     IDX_SLS_SALES_GOAL_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_SLS_SALES_GOAL_ORGNODE';
    dbms_output.put_line('     IDX_SLS_SALES_GOAL_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[SalesGoal] Index[IDX_SLS_SALES_GOAL_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SalesGoal] Index[IDX_SLS_SALES_GOAL_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_SLS_SALES_GOAL_ORGNODE') THEN
      dbms_output.put_line('     IDX_SLS_SALES_GOAL_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_SLS_SALES_GOAL_ORGNODE ON sls_sales_goal(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_SLS_SALES_GOAL_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[SalesGoal] Index[IDX_SLS_SALES_GOAL_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShippingFee] Index[IDX_COM_SHIPPING_FEE_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_COM_SHIPPING_FEE_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_SHIPPING_FEE_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_COM_SHIPPING_FEE_ORGNODE';
    dbms_output.put_line('     IDX_COM_SHIPPING_FEE_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShippingFee] Index[IDX_COM_SHIPPING_FEE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShippingFee] Index[IDX_COM_SHIPPING_FEE_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_COM_SHIPPING_FEE_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_SHIPPING_FEE_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_COM_SHIPPING_FEE_ORGNODE ON com_shipping_fee(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_COM_SHIPPING_FEE_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShippingFee] Index[IDX_COM_SHIPPING_FEE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[EmployeeMessage] Index[IDX_HRS_EMPLOYEE_MSG_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_HRS_EMPLOYEE_MSG_ORGNODE') THEN
      dbms_output.put_line('     IDX_HRS_EMPLOYEE_MSG_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_HRS_EMPLOYEE_MSG_ORGNODE';
    dbms_output.put_line('     IDX_HRS_EMPLOYEE_MSG_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[EmployeeMessage] Index[IDX_HRS_EMPLOYEE_MSG_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[EmployeeMessage] Index[IDX_HRS_EMPLOYEE_MSG_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_HRS_EMPLOYEE_MSG_ORGNODE') THEN
      dbms_output.put_line('     IDX_HRS_EMPLOYEE_MSG_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_HRS_EMPLOYEE_MSG_ORGNODE ON hrs_employee_message(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_HRS_EMPLOYEE_MSG_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[EmployeeMessage] Index[IDX_HRS_EMPLOYEE_MSG_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RestrictionType] Index[IDX_ITM_RESTRICT_TYPE_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_RESTRICT_TYPE_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_RESTRICT_TYPE_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_RESTRICT_TYPE_ORGNODE';
    dbms_output.put_line('     IDX_ITM_RESTRICT_TYPE_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RestrictionType] Index[IDX_ITM_RESTRICT_TYPE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RestrictionType] Index[IDX_ITM_RESTRICT_TYPE_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_RESTRICT_TYPE_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_RESTRICT_TYPE_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_RESTRICT_TYPE_ORGNODE ON itm_restriction_type(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_RESTRICT_TYPE_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RestrictionType] Index[IDX_ITM_RESTRICT_TYPE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PartyTelephone] Index[XST_CRM_PARTY_TELEPHONE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_CRM_PARTY_TELEPHONE') THEN
      dbms_output.put_line('     XST_CRM_PARTY_TELEPHONE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_CRM_PARTY_TELEPHONE';
    dbms_output.put_line('     XST_CRM_PARTY_TELEPHONE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PartyTelephone] Index[XST_CRM_PARTY_TELEPHONE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PartyTelephone] Index[XST_CRM_PARTY_TELEPHONE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_CRM_PARTY_TELEPHONE') THEN
      dbms_output.put_line('     XST_CRM_PARTY_TELEPHONE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_CRM_PARTY_TELEPHONE ON crm_party_telephone(UPPER(telephone_number))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_CRM_PARTY_TELEPHONE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PartyTelephone] Index[XST_CRM_PARTY_TELEPHONE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxRateRule] Index[IDX_TAX_TAX_RATE_RULE_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TAX_TAX_RATE_RULE_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_RATE_RULE_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TAX_TAX_RATE_RULE_ORGNODE';
    dbms_output.put_line('     IDX_TAX_TAX_RATE_RULE_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxRateRule] Index[IDX_TAX_TAX_RATE_RULE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxRateRule] Index[IDX_TAX_TAX_RATE_RULE_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TAX_TAX_RATE_RULE_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_RATE_RULE_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TAX_TAX_RATE_RULE_ORGNODE ON tax_tax_rate_rule(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_TAX_TAX_RATE_RULE_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxRateRule] Index[IDX_TAX_TAX_RATE_RULE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealWeek] Index[IDX_PRC_DEAL_WEEK_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_PRC_DEAL_WEEK_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_WEEK_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_PRC_DEAL_WEEK_ORGNODE';
    dbms_output.put_line('     IDX_PRC_DEAL_WEEK_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealWeek] Index[IDX_PRC_DEAL_WEEK_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealWeek] Index[IDX_PRC_DEAL_WEEK_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_PRC_DEAL_WEEK_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_WEEK_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_PRC_DEAL_WEEK_ORGNODE ON prc_deal_week(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_PRC_DEAL_WEEK_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealWeek] Index[IDX_PRC_DEAL_WEEK_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_TYPCODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_ITEM_TYPCODE') THEN
      dbms_output.put_line('     XST_ITM_ITEM_TYPCODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_ITEM_TYPCODE';
    dbms_output.put_line('     XST_ITM_ITEM_TYPCODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_TYPCODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_TYPCODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_ITM_ITEM_TYPCODE') THEN
      dbms_output.put_line('     XST_ITM_ITEM_TYPCODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_ITM_ITEM_TYPCODE ON itm_item(organization_id, UPPER(item_typcode))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_ITM_ITEM_TYPCODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_TYPCODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WarrantyJournal] Index[IDXITMWARRANTYJOURNALORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDXITMWARRANTYJOURNALORGNODE') THEN
      dbms_output.put_line('     IDXITMWARRANTYJOURNALORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDXITMWARRANTYJOURNALORGNODE';
    dbms_output.put_line('     IDXITMWARRANTYJOURNALORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WarrantyJournal] Index[IDXITMWARRANTYJOURNALORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WarrantyJournal] Index[IDXITMWARRANTYJOURNALORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDXITMWARRANTYJOURNALORGNODE') THEN
      dbms_output.put_line('     IDXITMWARRANTYJOURNALORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDXITMWARRANTYJOURNALORGNODE ON itm_warranty_journal(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDXITMWARRANTYJOURNALORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WarrantyJournal] Index[IDXITMWARRANTYJOURNALORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[IDX_ITM_ITEM02] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM02') THEN
      dbms_output.put_line('     IDX_ITM_ITEM02 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM02';
    dbms_output.put_line('     IDX_ITM_ITEM02 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[IDX_ITM_ITEM02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[IDX_ITM_ITEM02] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM02') THEN
      dbms_output.put_line('     IDX_ITM_ITEM02 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM02 ON itm_item(item_id, UPPER(item_typcode), UPPER(merch_level_1), organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM02 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[IDX_ITM_ITEM02] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShippingFeeTier] Index[IDX_COMSHIPPINGFEETIERORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_COMSHIPPINGFEETIERORGNODE') THEN
      dbms_output.put_line('     IDX_COMSHIPPINGFEETIERORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_COMSHIPPINGFEETIERORGNODE';
    dbms_output.put_line('     IDX_COMSHIPPINGFEETIERORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShippingFeeTier] Index[IDX_COMSHIPPINGFEETIERORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShippingFeeTier] Index[IDX_COMSHIPPINGFEETIERORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_COMSHIPPINGFEETIERORGNODE') THEN
      dbms_output.put_line('     IDX_COMSHIPPINGFEETIERORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_COMSHIPPINGFEETIERORGNODE ON com_shipping_fee_tier(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_COMSHIPPINGFEETIERORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShippingFeeTier] Index[IDX_COMSHIPPINGFEETIERORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Party] Index[XST_CRM_PARTY_NAME_LAST_FIRST] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_CRM_PARTY_NAME_LAST_FIRST') THEN
      dbms_output.put_line('     XST_CRM_PARTY_NAME_LAST_FIRST is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_CRM_PARTY_NAME_LAST_FIRST';
    dbms_output.put_line('     XST_CRM_PARTY_NAME_LAST_FIRST dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Party] Index[XST_CRM_PARTY_NAME_LAST_FIRST] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Party] Index[XST_CRM_PARTY_NAME_LAST_FIRST] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_CRM_PARTY_NAME_LAST_FIRST') THEN
      dbms_output.put_line('     XST_CRM_PARTY_NAME_LAST_FIRST already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_CRM_PARTY_NAME_LAST_FIRST ON crm_party(UPPER(last_name), UPPER(first_name))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_CRM_PARTY_NAME_LAST_FIRST created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Party] Index[XST_CRM_PARTY_NAME_LAST_FIRST] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkOrderPricing] Index[IDX_CWOWORKORDERPRICINGORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CWOWORKORDERPRICINGORGNODE') THEN
      dbms_output.put_line('     IDX_CWOWORKORDERPRICINGORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CWOWORKORDERPRICINGORGNODE';
    dbms_output.put_line('     IDX_CWOWORKORDERPRICINGORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkOrderPricing] Index[IDX_CWOWORKORDERPRICINGORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkOrderPricing] Index[IDX_CWOWORKORDERPRICINGORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_CWOWORKORDERPRICINGORGNODE') THEN
      dbms_output.put_line('     IDX_CWOWORKORDERPRICINGORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CWOWORKORDERPRICINGORGNODE ON cwo_work_order_pricing(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_CWOWORKORDERPRICINGORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkOrderPricing] Index[IDX_CWOWORKORDERPRICINGORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DocumentDefinition] Index[IDX_DOC_DOCUMENT_DEF_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_DOC_DOCUMENT_DEF_ORGNODE') THEN
      dbms_output.put_line('     IDX_DOC_DOCUMENT_DEF_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_DOC_DOCUMENT_DEF_ORGNODE';
    dbms_output.put_line('     IDX_DOC_DOCUMENT_DEF_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DocumentDefinition] Index[IDX_DOC_DOCUMENT_DEF_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DocumentDefinition] Index[IDX_DOC_DOCUMENT_DEF_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_DOC_DOCUMENT_DEF_ORGNODE') THEN
      dbms_output.put_line('     IDX_DOC_DOCUMENT_DEF_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_DOC_DOCUMENT_DEF_ORGNODE ON doc_document_definition(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_DOC_DOCUMENT_DEF_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DocumentDefinition] Index[IDX_DOC_DOCUMENT_DEF_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Party] Index[XST_CRM_PARTY_NAME_FIRST_LAST] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_CRM_PARTY_NAME_FIRST_LAST') THEN
      dbms_output.put_line('     XST_CRM_PARTY_NAME_FIRST_LAST is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_CRM_PARTY_NAME_FIRST_LAST';
    dbms_output.put_line('     XST_CRM_PARTY_NAME_FIRST_LAST dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Party] Index[XST_CRM_PARTY_NAME_FIRST_LAST] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Party] Index[XST_CRM_PARTY_NAME_FIRST_LAST] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_CRM_PARTY_NAME_FIRST_LAST') THEN
      dbms_output.put_line('     XST_CRM_PARTY_NAME_FIRST_LAST already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_CRM_PARTY_NAME_FIRST_LAST ON crm_party(UPPER(first_name), UPPER(last_name))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_CRM_PARTY_NAME_FIRST_LAST created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Party] Index[XST_CRM_PARTY_NAME_FIRST_LAST] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Deal] Index[IDX_PRC_DEAL_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_PRC_DEAL_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_PRC_DEAL_ORGNODE';
    dbms_output.put_line('     IDX_PRC_DEAL_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Deal] Index[IDX_PRC_DEAL_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Deal] Index[IDX_PRC_DEAL_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_PRC_DEAL_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_PRC_DEAL_ORGNODE ON prc_deal(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_PRC_DEAL_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Deal] Index[IDX_PRC_DEAL_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemDealProperty] Index[IDX_ITM_ITEM_PROP_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM_PROP_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_PROP_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM_PROP_ORGNODE';
    dbms_output.put_line('     IDX_ITM_ITEM_PROP_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemDealProperty] Index[IDX_ITM_ITEM_PROP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemDealProperty] Index[IDX_ITM_ITEM_PROP_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_PROP_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_PROP_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_PROP_ORGNODE ON itm_item_deal_prop(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM_PROP_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemDealProperty] Index[IDX_ITM_ITEM_PROP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealTrigger] Index[IDX_PRC_DEAL_TRIG_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_PRC_DEAL_TRIG_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_TRIG_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_PRC_DEAL_TRIG_ORGNODE';
    dbms_output.put_line('     IDX_PRC_DEAL_TRIG_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealTrigger] Index[IDX_PRC_DEAL_TRIG_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealTrigger] Index[IDX_PRC_DEAL_TRIG_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_PRC_DEAL_TRIG_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_TRIG_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_PRC_DEAL_TRIG_ORGNODE ON prc_deal_trig(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_PRC_DEAL_TRIG_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealTrigger] Index[IDX_PRC_DEAL_TRIG_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemMessageTypes] Index[IDX_ITM_ITEM_MSG_TYPES_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM_MSG_TYPES_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_MSG_TYPES_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM_MSG_TYPES_ORGNODE';
    dbms_output.put_line('     IDX_ITM_ITEM_MSG_TYPES_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemMessageTypes] Index[IDX_ITM_ITEM_MSG_TYPES_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemMessageTypes] Index[IDX_ITM_ITEM_MSG_TYPES_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_MSG_TYPES_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_MSG_TYPES_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_MSG_TYPES_ORGNODE ON itm_item_msg_types(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM_MSG_TYPES_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemMessageTypes] Index[IDX_ITM_ITEM_MSG_TYPES_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CategoryServiceLocation] Index[IDX_CWO_CAT_SERVCE_LOC_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CWO_CAT_SERVCE_LOC_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_CAT_SERVCE_LOC_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CWO_CAT_SERVCE_LOC_ORGNODE';
    dbms_output.put_line('     IDX_CWO_CAT_SERVCE_LOC_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[CategoryServiceLocation] Index[IDX_CWO_CAT_SERVCE_LOC_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CategoryServiceLocation] Index[IDX_CWO_CAT_SERVCE_LOC_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_CWO_CAT_SERVCE_LOC_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_CAT_SERVCE_LOC_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CWO_CAT_SERVCE_LOC_ORGNODE ON cwo_category_service_loc(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_CWO_CAT_SERVCE_LOC_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[CategoryServiceLocation] Index[IDX_CWO_CAT_SERVCE_LOC_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxGroup] Index[IDX_TAX_TAX_GROUP_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TAX_TAX_GROUP_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_GROUP_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TAX_TAX_GROUP_ORGNODE';
    dbms_output.put_line('     IDX_TAX_TAX_GROUP_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxGroup] Index[IDX_TAX_TAX_GROUP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxGroup] Index[IDX_TAX_TAX_GROUP_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TAX_TAX_GROUP_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_GROUP_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TAX_TAX_GROUP_ORGNODE ON tax_tax_group(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_TAX_TAX_GROUP_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxGroup] Index[IDX_TAX_TAX_GROUP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RestrictionCalendar] Index[IDX_ITM_RESTRICT_CAL_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_RESTRICT_CAL_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_RESTRICT_CAL_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_RESTRICT_CAL_ORGNODE';
    dbms_output.put_line('     IDX_ITM_RESTRICT_CAL_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[RestrictionCalendar] Index[IDX_ITM_RESTRICT_CAL_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RestrictionCalendar] Index[IDX_ITM_RESTRICT_CAL_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_RESTRICT_CAL_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_RESTRICT_CAL_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_RESTRICT_CAL_ORGNODE ON itm_restriction_calendar(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_RESTRICT_CAL_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[RestrictionCalendar] Index[IDX_ITM_RESTRICT_CAL_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Coupon] Index[IDX_DSC_COUPON_XREF_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_DSC_COUPON_XREF_ORGNODE') THEN
      dbms_output.put_line('     IDX_DSC_COUPON_XREF_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_DSC_COUPON_XREF_ORGNODE';
    dbms_output.put_line('     IDX_DSC_COUPON_XREF_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Coupon] Index[IDX_DSC_COUPON_XREF_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Coupon] Index[IDX_DSC_COUPON_XREF_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_DSC_COUPON_XREF_ORGNODE') THEN
      dbms_output.put_line('     IDX_DSC_COUPON_XREF_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_DSC_COUPON_XREF_ORGNODE ON dsc_coupon_xref(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_DSC_COUPON_XREF_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Coupon] Index[IDX_DSC_COUPON_XREF_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealCustomerGroups] Index[IDX_PRC_DEAL_CUSTGROUPSORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_PRC_DEAL_CUSTGROUPSORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_CUSTGROUPSORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_PRC_DEAL_CUSTGROUPSORGNODE';
    dbms_output.put_line('     IDX_PRC_DEAL_CUSTGROUPSORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealCustomerGroups] Index[IDX_PRC_DEAL_CUSTGROUPSORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealCustomerGroups] Index[IDX_PRC_DEAL_CUSTGROUPSORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_PRC_DEAL_CUSTGROUPSORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_CUSTGROUPSORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_PRC_DEAL_CUSTGROUPSORGNODE ON prc_deal_cust_groups(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_PRC_DEAL_CUSTGROUPSORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealCustomerGroups] Index[IDX_PRC_DEAL_CUSTGROUPSORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkstationConfigData] Index[IDX_LOC_WKSTN_CONFIG_DATA01] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_LOC_WKSTN_CONFIG_DATA01') THEN
      dbms_output.put_line('     IDX_LOC_WKSTN_CONFIG_DATA01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_LOC_WKSTN_CONFIG_DATA01';
    dbms_output.put_line('     IDX_LOC_WKSTN_CONFIG_DATA01 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkstationConfigData] Index[IDX_LOC_WKSTN_CONFIG_DATA01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkstationConfigData] Index[IDX_LOC_WKSTN_CONFIG_DATA01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_LOC_WKSTN_CONFIG_DATA01') THEN
      dbms_output.put_line('     IDX_LOC_WKSTN_CONFIG_DATA01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_LOC_WKSTN_CONFIG_DATA01 ON loc_wkstn_config_data(organization_id, rtl_loc_id, wkstn_id, UPPER(field_name), create_timestamp)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_LOC_WKSTN_CONFIG_DATA01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkstationConfigData] Index[IDX_LOC_WKSTN_CONFIG_DATA01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DocumentDefinitionProperties] Index[IDX_DOCDOCUMENTDEFPROPORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_DOCDOCUMENTDEFPROPORGNODE') THEN
      dbms_output.put_line('     IDX_DOCDOCUMENTDEFPROPORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_DOCDOCUMENTDEFPROPORGNODE';
    dbms_output.put_line('     IDX_DOCDOCUMENTDEFPROPORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DocumentDefinitionProperties] Index[IDX_DOCDOCUMENTDEFPROPORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DocumentDefinitionProperties] Index[IDX_DOCDOCUMENTDEFPROPORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_DOCDOCUMENTDEFPROPORGNODE') THEN
      dbms_output.put_line('     IDX_DOCDOCUMENTDEFPROPORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_DOCDOCUMENTDEFPROPORGNODE ON doc_document_def_properties(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_DOCDOCUMENTDEFPROPORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DocumentDefinitionProperties] Index[IDX_DOCDOCUMENTDEFPROPORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[MerchandiseHierarchy] Index[IDX_ITM_MERCH_HIRARCHY_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_MERCH_HIRARCHY_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_MERCH_HIRARCHY_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_MERCH_HIRARCHY_ORGNODE';
    dbms_output.put_line('     IDX_ITM_MERCH_HIRARCHY_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[MerchandiseHierarchy] Index[IDX_ITM_MERCH_HIRARCHY_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[MerchandiseHierarchy] Index[IDX_ITM_MERCH_HIRARCHY_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_MERCH_HIRARCHY_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_MERCH_HIRARCHY_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_MERCH_HIRARCHY_ORGNODE ON itm_merch_hierarchy(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_MERCH_HIRARCHY_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[MerchandiseHierarchy] Index[IDX_ITM_MERCH_HIRARCHY_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_DESCRIPTION] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_ITEM_DESCRIPTION') THEN
      dbms_output.put_line('     XST_ITM_ITEM_DESCRIPTION is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_ITEM_DESCRIPTION';
    dbms_output.put_line('     XST_ITM_ITEM_DESCRIPTION dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Item] Index[XST_ITM_ITEM_DESCRIPTION] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_DESCRIPTION] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_ITM_ITEM_DESCRIPTION') THEN
      dbms_output.put_line('     XST_ITM_ITEM_DESCRIPTION already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_ITM_ITEM_DESCRIPTION ON itm_item(organization_id, UPPER(description))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_ITM_ITEM_DESCRIPTION created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Item] Index[XST_ITM_ITEM_DESCRIPTION] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemCrossReference] Index[XST_ITM_XREF_UPC_ITEMID] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_ITM_XREF_UPC_ITEMID') THEN
      dbms_output.put_line('     XST_ITM_XREF_UPC_ITEMID is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_ITM_XREF_UPC_ITEMID';
    dbms_output.put_line('     XST_ITM_XREF_UPC_ITEMID dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemCrossReference] Index[XST_ITM_XREF_UPC_ITEMID] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemCrossReference] Index[XST_ITM_XREF_UPC_ITEMID] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_ITM_XREF_UPC_ITEMID') THEN
      dbms_output.put_line('     XST_ITM_XREF_UPC_ITEMID already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_ITM_XREF_UPC_ITEMID ON itm_item_cross_reference(manufacturer_upc, UPPER(item_id), organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_ITM_XREF_UPC_ITEMID created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemCrossReference] Index[XST_ITM_XREF_UPC_ITEMID] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemPromptProperty] Index[IDX_ITM_ITM_PRMPT_PROP_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITM_PRMPT_PROP_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITM_PRMPT_PROP_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITM_PRMPT_PROP_ORGNODE';
    dbms_output.put_line('     IDX_ITM_ITM_PRMPT_PROP_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemPromptProperty] Index[IDX_ITM_ITM_PRMPT_PROP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemPromptProperty] Index[IDX_ITM_ITM_PRMPT_PROP_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITM_PRMPT_PROP_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITM_PRMPT_PROP_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITM_PRMPT_PROP_ORGNODE ON itm_item_prompt_properties(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITM_PRMPT_PROP_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemPromptProperty] Index[IDX_ITM_ITM_PRMPT_PROP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemDimensionType] Index[IDX_ITM_ITEM_DIM_TYPE_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM_DIM_TYPE_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_DIM_TYPE_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM_DIM_TYPE_ORGNODE';
    dbms_output.put_line('     IDX_ITM_ITEM_DIM_TYPE_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemDimensionType] Index[IDX_ITM_ITEM_DIM_TYPE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemDimensionType] Index[IDX_ITM_ITEM_DIM_TYPE_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_DIM_TYPE_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_DIM_TYPE_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_DIM_TYPE_ORGNODE ON itm_item_dimension_type(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM_DIM_TYPE_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemDimensionType] Index[IDX_ITM_ITEM_DIM_TYPE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShipperMethod] Index[IDX_INV_SHIPPER_METHOD_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_INV_SHIPPER_METHOD_ORGNODE') THEN
      dbms_output.put_line('     IDX_INV_SHIPPER_METHOD_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_INV_SHIPPER_METHOD_ORGNODE';
    dbms_output.put_line('     IDX_INV_SHIPPER_METHOD_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ShipperMethod] Index[IDX_INV_SHIPPER_METHOD_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShipperMethod] Index[IDX_INV_SHIPPER_METHOD_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_INV_SHIPPER_METHOD_ORGNODE') THEN
      dbms_output.put_line('     IDX_INV_SHIPPER_METHOD_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_INV_SHIPPER_METHOD_ORGNODE ON inv_shipper_method(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_INV_SHIPPER_METHOD_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ShipperMethod] Index[IDX_INV_SHIPPER_METHOD_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ReportLookup] Index[IDX_COM_REPORT_LOOKUP_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_COM_REPORT_LOOKUP_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_REPORT_LOOKUP_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_COM_REPORT_LOOKUP_ORGNODE';
    dbms_output.put_line('     IDX_COM_REPORT_LOOKUP_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ReportLookup] Index[IDX_COM_REPORT_LOOKUP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ReportLookup] Index[IDX_COM_REPORT_LOOKUP_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_COM_REPORT_LOOKUP_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_REPORT_LOOKUP_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_COM_REPORT_LOOKUP_ORGNODE ON com_report_lookup(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_COM_REPORT_LOOKUP_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ReportLookup] Index[IDX_COM_REPORT_LOOKUP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Document] Index[IDX_DOC_DOCUMENT_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_DOC_DOCUMENT_ORGNODE') THEN
      dbms_output.put_line('     IDX_DOC_DOCUMENT_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_DOC_DOCUMENT_ORGNODE';
    dbms_output.put_line('     IDX_DOC_DOCUMENT_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Document] Index[IDX_DOC_DOCUMENT_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Document] Index[IDX_DOC_DOCUMENT_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_DOC_DOCUMENT_ORGNODE') THEN
      dbms_output.put_line('     IDX_DOC_DOCUMENT_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_DOC_DOCUMENT_ORGNODE ON doc_document(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_DOC_DOCUMENT_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Document] Index[IDX_DOC_DOCUMENT_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealFieldTest] Index[IDX_PRC_DEAL_FIELD_TST_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_PRC_DEAL_FIELD_TST_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_FIELD_TST_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_PRC_DEAL_FIELD_TST_ORGNODE';
    dbms_output.put_line('     IDX_PRC_DEAL_FIELD_TST_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DealFieldTest] Index[IDX_PRC_DEAL_FIELD_TST_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealFieldTest] Index[IDX_PRC_DEAL_FIELD_TST_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_PRC_DEAL_FIELD_TST_ORGNODE') THEN
      dbms_output.put_line('     IDX_PRC_DEAL_FIELD_TST_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_PRC_DEAL_FIELD_TST_ORGNODE ON prc_deal_field_test(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_PRC_DEAL_FIELD_TST_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DealFieldTest] Index[IDX_PRC_DEAL_FIELD_TST_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Address] Index[IDX_COM_ADDRESS_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_COM_ADDRESS_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_ADDRESS_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_COM_ADDRESS_ORGNODE';
    dbms_output.put_line('     IDX_COM_ADDRESS_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Address] Index[IDX_COM_ADDRESS_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Address] Index[IDX_COM_ADDRESS_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_COM_ADDRESS_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_ADDRESS_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_COM_ADDRESS_ORGNODE ON com_address(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_COM_ADDRESS_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Address] Index[IDX_COM_ADDRESS_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Party] Index[XST_CRM_PARTY_CUSTID] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_CRM_PARTY_CUSTID') THEN
      dbms_output.put_line('     XST_CRM_PARTY_CUSTID is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_CRM_PARTY_CUSTID';
    dbms_output.put_line('     XST_CRM_PARTY_CUSTID dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Party] Index[XST_CRM_PARTY_CUSTID] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Party] Index[XST_CRM_PARTY_CUSTID] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_CRM_PARTY_CUSTID') THEN
      dbms_output.put_line('     XST_CRM_PARTY_CUSTID already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_CRM_PARTY_CUSTID ON crm_party(UPPER(cust_id), organization_id)
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_CRM_PARTY_CUSTID created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Party] Index[XST_CRM_PARTY_CUSTID] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemLabelProperties] Index[IDX_ITM_ITEM_LABL_PROP_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_ITEM_LABL_PROP_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_LABL_PROP_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_ITEM_LABL_PROP_ORGNODE';
    dbms_output.put_line('     IDX_ITM_ITEM_LABL_PROP_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemLabelProperties] Index[IDX_ITM_ITEM_LABL_PROP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemLabelProperties] Index[IDX_ITM_ITEM_LABL_PROP_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_ITEM_LABL_PROP_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_ITEM_LABL_PROP_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_ITEM_LABL_PROP_ORGNODE ON itm_item_label_properties(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_ITEM_LABL_PROP_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemLabelProperties] Index[IDX_ITM_ITEM_LABL_PROP_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ServiceLocation] Index[IDX_CWO_SERVICE_LOC_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CWO_SERVICE_LOC_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_SERVICE_LOC_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CWO_SERVICE_LOC_ORGNODE';
    dbms_output.put_line('     IDX_CWO_SERVICE_LOC_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ServiceLocation] Index[IDX_CWO_SERVICE_LOC_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ServiceLocation] Index[IDX_CWO_SERVICE_LOC_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_CWO_SERVICE_LOC_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_SERVICE_LOC_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CWO_SERVICE_LOC_ORGNODE ON cwo_service_loc(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_CWO_SERVICE_LOC_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ServiceLocation] Index[IDX_CWO_SERVICE_LOC_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[KitComponent] Index[IDX_ITM_KIT_COMPONENT_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_KIT_COMPONENT_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_KIT_COMPONENT_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_KIT_COMPONENT_ORGNODE';
    dbms_output.put_line('     IDX_ITM_KIT_COMPONENT_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[KitComponent] Index[IDX_ITM_KIT_COMPONENT_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[KitComponent] Index[IDX_ITM_KIT_COMPONENT_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_KIT_COMPONENT_ORGNODE') THEN
      dbms_output.put_line('     IDX_ITM_KIT_COMPONENT_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_KIT_COMPONENT_ORGNODE ON itm_kit_component(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_KIT_COMPONENT_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[KitComponent] Index[IDX_ITM_KIT_COMPONENT_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Party] Index[XST_CRM_PARTY_NAME_LAST] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_CRM_PARTY_NAME_LAST') THEN
      dbms_output.put_line('     XST_CRM_PARTY_NAME_LAST is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_CRM_PARTY_NAME_LAST';
    dbms_output.put_line('     XST_CRM_PARTY_NAME_LAST dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[Party] Index[XST_CRM_PARTY_NAME_LAST] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Party] Index[XST_CRM_PARTY_NAME_LAST] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_CRM_PARTY_NAME_LAST') THEN
      dbms_output.put_line('     XST_CRM_PARTY_NAME_LAST already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_CRM_PARTY_NAME_LAST ON crm_party(UPPER(last_name))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_CRM_PARTY_NAME_LAST created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[Party] Index[XST_CRM_PARTY_NAME_LAST] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PartyIdCrossReference] Index[IDX_CRM_PARTY_ID_XREF01] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CRM_PARTY_ID_XREF01') THEN
      dbms_output.put_line('     IDX_CRM_PARTY_ID_XREF01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CRM_PARTY_ID_XREF01';
    dbms_output.put_line('     IDX_CRM_PARTY_ID_XREF01 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[PartyIdCrossReference] Index[IDX_CRM_PARTY_ID_XREF01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PartyIdCrossReference] Index[IDX_CRM_PARTY_ID_XREF01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_CRM_PARTY_ID_XREF01') THEN
      dbms_output.put_line('     IDX_CRM_PARTY_ID_XREF01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CRM_PARTY_ID_XREF01 ON crm_party_id_xref(alternate_id_owner, UPPER(alternate_id))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_CRM_PARTY_ID_XREF01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[PartyIdCrossReference] Index[IDX_CRM_PARTY_ID_XREF01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[OrgHierarchy] Index[XST_LOC_ORGHIER_PARENT] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('XST_LOC_ORGHIER_PARENT') THEN
      dbms_output.put_line('     XST_LOC_ORGHIER_PARENT is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX XST_LOC_ORGHIER_PARENT';
    dbms_output.put_line('     XST_LOC_ORGHIER_PARENT dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[OrgHierarchy] Index[XST_LOC_ORGHIER_PARENT] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[OrgHierarchy] Index[XST_LOC_ORGHIER_PARENT] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('XST_LOC_ORGHIER_PARENT') THEN
      dbms_output.put_line('     XST_LOC_ORGHIER_PARENT already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX XST_LOC_ORGHIER_PARENT ON loc_org_hierarchy(UPPER(parent_code), UPPER(parent_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     XST_LOC_ORGHIER_PARENT created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[OrgHierarchy] Index[XST_LOC_ORGHIER_PARENT] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TransactionPropertyPrompt] Index[IDXCOMTRNSPRMPTPRPRTIESORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDXCOMTRNSPRMPTPRPRTIESORGNODE') THEN
      dbms_output.put_line('     IDXCOMTRNSPRMPTPRPRTIESORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDXCOMTRNSPRMPTPRPRTIESORGNODE';
    dbms_output.put_line('     IDXCOMTRNSPRMPTPRPRTIESORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TransactionPropertyPrompt] Index[IDXCOMTRNSPRMPTPRPRTIESORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TransactionPropertyPrompt] Index[IDXCOMTRNSPRMPTPRPRTIESORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDXCOMTRNSPRMPTPRPRTIESORGNODE') THEN
      dbms_output.put_line('     IDXCOMTRNSPRMPTPRPRTIESORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDXCOMTRNSPRMPTPRPRTIESORGNODE ON com_trans_prompt_properties(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDXCOMTRNSPRMPTPRPRTIESORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TransactionPropertyPrompt] Index[IDXCOMTRNSPRMPTPRPRTIESORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DatabaseTranslation] Index[IDX_COM_TRANSLATIONS_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_COM_TRANSLATIONS_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_TRANSLATIONS_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_COM_TRANSLATIONS_ORGNODE';
    dbms_output.put_line('     IDX_COM_TRANSLATIONS_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[DatabaseTranslation] Index[IDX_COM_TRANSLATIONS_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DatabaseTranslation] Index[IDX_COM_TRANSLATIONS_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_COM_TRANSLATIONS_ORGNODE') THEN
      dbms_output.put_line('     IDX_COM_TRANSLATIONS_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_COM_TRANSLATIONS_ORGNODE ON com_translations(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_COM_TRANSLATIONS_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[DatabaseTranslation] Index[IDX_COM_TRANSLATIONS_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxGroupRule] Index[IDX_TAX_TAX_GROUP_RULE_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_TAX_TAX_GROUP_RULE_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_GROUP_RULE_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_TAX_TAX_GROUP_RULE_ORGNODE';
    dbms_output.put_line('     IDX_TAX_TAX_GROUP_RULE_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[TaxGroupRule] Index[IDX_TAX_TAX_GROUP_RULE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxGroupRule] Index[IDX_TAX_TAX_GROUP_RULE_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_TAX_TAX_GROUP_RULE_ORGNODE') THEN
      dbms_output.put_line('     IDX_TAX_TAX_GROUP_RULE_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_TAX_TAX_GROUP_RULE_ORGNODE ON tax_tax_group_rule(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_TAX_TAX_GROUP_RULE_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[TaxGroupRule] Index[IDX_TAX_TAX_GROUP_RULE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemRestrictGS1] Index[IDX_ITM_RESTRICT_GS1] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_ITM_RESTRICT_GS1') THEN
      dbms_output.put_line('     IDX_ITM_RESTRICT_GS1 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_ITM_RESTRICT_GS1';
    dbms_output.put_line('     IDX_ITM_RESTRICT_GS1 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[ItemRestrictGS1] Index[IDX_ITM_RESTRICT_GS1] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemRestrictGS1] Index[IDX_ITM_RESTRICT_GS1] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_ITM_RESTRICT_GS1') THEN
      dbms_output.put_line('     IDX_ITM_RESTRICT_GS1 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_ITM_RESTRICT_GS1 ON itm_restrict_gs1(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_ITM_RESTRICT_GS1 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[ItemRestrictGS1] Index[IDX_ITM_RESTRICT_GS1] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkOrderPriceCode] Index[IDX_CWO_PRICE_CODE_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_CWO_PRICE_CODE_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_PRICE_CODE_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_CWO_PRICE_CODE_ORGNODE';
    dbms_output.put_line('     IDX_CWO_PRICE_CODE_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkOrderPriceCode] Index[IDX_CWO_PRICE_CODE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkOrderPriceCode] Index[IDX_CWO_PRICE_CODE_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_CWO_PRICE_CODE_ORGNODE') THEN
      dbms_output.put_line('     IDX_CWO_PRICE_CODE_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_CWO_PRICE_CODE_ORGNODE ON cwo_price_code(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_CWO_PRICE_CODE_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkOrderPriceCode] Index[IDX_CWO_PRICE_CODE_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[InventoryCountSheetLineItem] Index[IDX_INV_COUNT_SHEET_LINEITM01] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_INV_COUNT_SHEET_LINEITM01') THEN
      dbms_output.put_line('     IDX_INV_COUNT_SHEET_LINEITM01 is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_INV_COUNT_SHEET_LINEITM01';
    dbms_output.put_line('     IDX_INV_COUNT_SHEET_LINEITM01 dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[InventoryCountSheetLineItem] Index[IDX_INV_COUNT_SHEET_LINEITM01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[InventoryCountSheetLineItem] Index[IDX_INV_COUNT_SHEET_LINEITM01] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_INV_COUNT_SHEET_LINEITM01') THEN
      dbms_output.put_line('     IDX_INV_COUNT_SHEET_LINEITM01 already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_INV_COUNT_SHEET_LINEITM01 ON inv_count_sheet_lineitm(inv_count_id, UPPER(inv_bucket_id), UPPER(item_id), UPPER(alternate_id), UPPER(description))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_INV_COUNT_SHEET_LINEITM01 created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[InventoryCountSheetLineItem] Index[IDX_INV_COUNT_SHEET_LINEITM01] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WarrantyItemCrossReference] Index[IDXITMWARRANTYITEMXREFORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDXITMWARRANTYITEMXREFORGNODE') THEN
      dbms_output.put_line('     IDXITMWARRANTYITEMXREFORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDXITMWARRANTYITEMXREFORGNODE';
    dbms_output.put_line('     IDXITMWARRANTYITEMXREFORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WarrantyItemCrossReference] Index[IDXITMWARRANTYITEMXREFORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WarrantyItemCrossReference] Index[IDXITMWARRANTYITEMXREFORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDXITMWARRANTYITEMXREFORGNODE') THEN
      dbms_output.put_line('     IDXITMWARRANTYITEMXREFORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDXITMWARRANTYITEMXREFORGNODE ON itm_warranty_item_xref(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDXITMWARRANTYITEMXREFORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WarrantyItemCrossReference] Index[IDXITMWARRANTYITEMXREFORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkCodes] Index[IDX_HRS_WORK_CODES_ORGNODE] starting...');
END;
/
BEGIN
  IF NOT SP_INDEX_EXISTS ('IDX_HRS_WORK_CODES_ORGNODE') THEN
      dbms_output.put_line('     IDX_HRS_WORK_CODES_ORGNODE is missing');
  ELSE
    EXECUTE IMMEDIATE 'DROP INDEX IDX_HRS_WORK_CODES_ORGNODE';
    dbms_output.put_line('     IDX_HRS_WORK_CODES_ORGNODE dropped');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Drop Index: DTX[WorkCodes] Index[IDX_HRS_WORK_CODES_ORGNODE] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkCodes] Index[IDX_HRS_WORK_CODES_ORGNODE] starting...');
END;
/
BEGIN
  IF SP_INDEX_EXISTS ('IDX_HRS_WORK_CODES_ORGNODE') THEN
      dbms_output.put_line('     IDX_HRS_WORK_CODES_ORGNODE already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE INDEX IDX_HRS_WORK_CODES_ORGNODE ON hrs_work_codes(UPPER(org_code), UPPER(org_value))
        TABLESPACE &dbIndexTableSpace.';
    dbms_output.put_line('     IDX_HRS_WORK_CODES_ORGNODE created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Index: DTX[WorkCodes] Index[IDX_HRS_WORK_CODES_ORGNODE] end.');
END;
/
BEGIN
    dbms_output.put_line('     Step Upgrade some indexes to use the column with UPPER() end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[LegalEntity] Column[[Field=legalForm, Field=socialCapital, Field=companiesRegisterNumber, Field=faxNumber, Field=phoneNumber, Field=webSite]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('loc_legal_entity','legal_form') THEN
       dbms_output.put_line('      Column loc_legal_entity.legal_form already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_legal_entity ADD legal_form VARCHAR2(60 char)';
    dbms_output.put_line('     Column loc_legal_entity.legal_form created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('loc_legal_entity','social_capital') THEN
       dbms_output.put_line('      Column loc_legal_entity.social_capital already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_legal_entity ADD social_capital VARCHAR2(60 char)';
    dbms_output.put_line('     Column loc_legal_entity.social_capital created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('loc_legal_entity','companies_register_number') THEN
       dbms_output.put_line('      Column loc_legal_entity.companies_register_number already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_legal_entity ADD companies_register_number VARCHAR2(30 char)';
    dbms_output.put_line('     Column loc_legal_entity.companies_register_number created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('loc_legal_entity','fax_number') THEN
       dbms_output.put_line('      Column loc_legal_entity.fax_number already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_legal_entity ADD fax_number VARCHAR2(32 char)';
    dbms_output.put_line('     Column loc_legal_entity.fax_number created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('loc_legal_entity','phone_number') THEN
       dbms_output.put_line('      Column loc_legal_entity.phone_number already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_legal_entity ADD phone_number VARCHAR2(32 char)';
    dbms_output.put_line('     Column loc_legal_entity.phone_number created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('loc_legal_entity','web_site') THEN
       dbms_output.put_line('      Column loc_legal_entity.web_site already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_legal_entity ADD web_site VARCHAR2(254 char)';
    dbms_output.put_line('     Column loc_legal_entity.web_site created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[LegalEntity] Column[[Field=legalForm, Field=socialCapital, Field=companiesRegisterNumber, Field=faxNumber, Field=phoneNumber, Field=webSite]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[MobileServer] Column[[Field=wkstnRangeStart, Field=wkstnRangeEnd]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('ctl_mobile_server','wkstn_range_start') THEN
       dbms_output.put_line('      Column ctl_mobile_server.wkstn_range_start already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_mobile_server ADD wkstn_range_start NUMBER(10, 0)';
    dbms_output.put_line('     Column ctl_mobile_server.wkstn_range_start created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('ctl_mobile_server','wkstn_range_end') THEN
       dbms_output.put_line('      Column ctl_mobile_server.wkstn_range_end already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_mobile_server ADD wkstn_range_end NUMBER(10, 0)';
    dbms_output.put_line('     Column ctl_mobile_server.wkstn_range_end created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[MobileServer] Column[[Field=wkstnRangeStart, Field=wkstnRangeEnd]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[Party] Column[[Field=saveCardPayments]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('crm_party','save_card_payments_flag') THEN
       dbms_output.put_line('      Column crm_party.save_card_payments_flag already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party ADD save_card_payments_flag NUMBER(1, 0) DEFAULT 0 NOT NULL';
    dbms_output.put_line('     Column crm_party.save_card_payments_flag created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[Party] Column[[Field=saveCardPayments]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Table: DTX[CustomerPaymentCard] starting...');
END;
/
BEGIN
  IF SP_TABLE_EXISTS ('CRM_CUSTOMER_PAYMENT_CARD') THEN
       dbms_output.put_line('      Table crm_customer_payment_card already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE TABLE crm_customer_payment_card(
organization_id NUMBER(10, 0) NOT NULL,
party_id NUMBER(19, 0) NOT NULL,
card_token VARCHAR2(254 char) NOT NULL,
card_alias VARCHAR2(254 char),
card_type VARCHAR2(60 char),
card_last_four VARCHAR2(4 char),
expr_date VARCHAR2(64 char),
shopper_ref VARCHAR2(254 char),
create_user_id VARCHAR2(256 char),
create_date TIMESTAMP(6),
update_user_id VARCHAR2(256 char),
update_date TIMESTAMP(6),
record_state VARCHAR2(30 char), 
CONSTRAINT pk_crm_customer_payment_card PRIMARY KEY (organization_id, party_id, card_token) USING INDEX TABLESPACE &dbIndexTableSpace.
)
TABLESPACE &dbDataTableSpace.
';
        dbms_output.put_line('      Table crm_customer_payment_card created');
    EXECUTE IMMEDIATE 'GRANT SELECT,INSERT,UPDATE,DELETE ON crm_customer_payment_card TO POSUSERS,DBAUSERS';
  END IF;
END;
/

BEGIN
  IF SP_TABLE_EXISTS ('CRM_CUSTOMER_PAYMENT_CARD_P') THEN
       dbms_output.put_line('      Table CRM_CUSTOMER_PAYMENT_CARD_P already exists');
  ELSE
    CREATE_PROPERTY_TABLE('crm_customer_payment_card');
    dbms_output.put_line('     Table crm_customer_payment_card_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Table: DTX[CustomerPaymentCard] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[TemporaryStoreRequest] Column[[Field=useStoreTaxLocation]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('loc_temp_store_request','use_store_tax_loc_flag') THEN
       dbms_output.put_line('      Column loc_temp_store_request.use_store_tax_loc_flag already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_temp_store_request ADD use_store_tax_loc_flag NUMBER(1, 0) DEFAULT 1 NOT NULL';
    dbms_output.put_line('     Column loc_temp_store_request.use_store_tax_loc_flag created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[TemporaryStoreRequest] Column[[Field=useStoreTaxLocation]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[FrRcptDuplicate] Column[[Field=signatureVersion]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('cfra_rcpt_dup','signature_version') THEN
       dbms_output.put_line('      Column cfra_rcpt_dup.signature_version already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cfra_rcpt_dup ADD signature_version NUMBER(6, 0)';
    dbms_output.put_line('     Column cfra_rcpt_dup.signature_version created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[FrRcptDuplicate] Column[[Field=signatureVersion]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[FrTechnicalEventLog] Column[[Field=signatureVersion]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('cfra_technical_event_log','signature_version') THEN
       dbms_output.put_line('      Column cfra_technical_event_log.signature_version already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cfra_technical_event_log ADD signature_version NUMBER(6, 0)';
    dbms_output.put_line('     Column cfra_technical_event_log.signature_version created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[FrTechnicalEventLog] Column[[Field=signatureVersion]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[FrTechnicalEventLog] Field[[Field=signatureSource]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE cfra_technical_event_log MODIFY signature_source VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column cfra_technical_event_log.signature_source modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('cfra_technical_event_log','signature_source') THEN
      dbms_output.put_line('     Column cfra_technical_event_log.signature_source already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cfra_technical_event_log MODIFY signature_source NULL';
    dbms_output.put_line('     Column cfra_technical_event_log.signature_source modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[FrTechnicalEventLog] Field[[Field=signatureSource]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Consolidating legal entity extended properties starting...');
END;
/
BEGIN
  UPDATE loc_legal_entity
  SET social_capital = (SELECT string_value
                        FROM loc_legal_entity_p
                        WHERE loc_legal_entity_p.organization_id = loc_legal_entity.organization_id
                        AND loc_legal_entity_p.legal_entity_id = loc_legal_entity.legal_entity_id
                        AND loc_legal_entity_p.property_code = 'SHARE_CAPITAL')
  WHERE loc_legal_entity.social_capital IS NULL;
  dbms_output.put_line('        ' || TO_CHAR(SQL%ROWCOUNT) || ' Social capital converted');
END;
/

BEGIN
  UPDATE loc_legal_entity
  SET companies_register_number = (SELECT string_value
                                   FROM loc_legal_entity_p
                                   WHERE loc_legal_entity_p.organization_id = loc_legal_entity.organization_id
                                   AND loc_legal_entity_p.legal_entity_id = loc_legal_entity.legal_entity_id
                                   AND loc_legal_entity_p.property_code = 'COMPANIES_REGISTER_NUMBER')
  WHERE loc_legal_entity.companies_register_number IS NULL;
  dbms_output.put_line('        ' || TO_CHAR(SQL%ROWCOUNT) || ' Companies_register_number capital converted');
END;
/
BEGIN
    dbms_output.put_line('     Step Consolidating legal entity extended properties end.');
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
    dbms_output.put_line('     Step Mexican pending invoice conversion in V20 format starting...');
END;
/
BEGIN
  EXECUTE IMMEDIATE 'UPDATE civc_invoice
  SET sequence_id = CONCAT(''PENDING_'', sequence_id), invoice_type = CONCAT(''PENDING_GLOBAL_'', invoice_type)
  WHERE CONCAT(CONCAT(organization_id, ''::''), rtl_loc_id) IN (SELECT CONCAT(CONCAT(organization_id, ''::''), rtl_loc_id) 
                                                                  FROM loc_rtl_loc 
                                                                  WHERE loc_rtl_loc.country = ''MX'')
  AND ext_invoice_id IS NULL
  AND sequence_id NOT LIKE ''PENDING%''';
  dbms_output.put_line('        ' || TO_CHAR(SQL%ROWCOUNT) || ' Mexican pending invoices converted');
END;
/

BEGIN
  EXECUTE IMMEDIATE 'UPDATE civc_invoice_xref
  SET sequence_id = CONCAT(''PENDING_'', sequence_id)
  WHERE CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(organization_id, ''::''), rtl_loc_id), ''::''), wkstn_id), ''::''), business_year), ''::''), CONCAT(''PENDING_'', sequence_id)), ''::''), sequence_nbr)
        IN (SELECT CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(organization_id, ''::''), rtl_loc_id), ''::''), wkstn_id), ''::''), business_year), ''::''), sequence_id), ''::''), sequence_nbr)
                                                                  FROM civc_invoice 
                                                                  WHERE sequence_id LIKE ''PENDING%'')
  AND sequence_id NOT LIKE ''PENDING%''';

  dbms_output.put_line('        ' || TO_CHAR(SQL%ROWCOUNT) || ' Mexican pending invoices relations converted');
END;
/
BEGIN
    dbms_output.put_line('     Step Mexican pending invoice conversion in V20 format end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[Party] Field[[Field=organizationName]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party MODIFY organization_name VARCHAR2(254 char) DEFAULT (null)';
    dbms_output.put_line('     Column crm_party.organization_name modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('crm_party','organization_name') THEN
      dbms_output.put_line('     Column crm_party.organization_name already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_party MODIFY organization_name NULL';
    dbms_output.put_line('     Column crm_party.organization_name modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[Party] Field[[Field=organizationName]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[FulfillmentModifier] Field[[Field=organizationName]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE xom_fulfillment_mod MODIFY organization_name VARCHAR2(254 char) DEFAULT (null)';
    dbms_output.put_line('     Column xom_fulfillment_mod.organization_name modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('xom_fulfillment_mod','organization_name') THEN
      dbms_output.put_line('     Column xom_fulfillment_mod.organization_name already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_fulfillment_mod MODIFY organization_name NULL';
    dbms_output.put_line('     Column xom_fulfillment_mod.organization_name modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[FulfillmentModifier] Field[[Field=organizationName]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[CustomerModifier] Field[[Field=organizationName]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE xom_customer_mod MODIFY organization_name VARCHAR2(254 char) DEFAULT (null)';
    dbms_output.put_line('     Column xom_customer_mod.organization_name modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('xom_customer_mod','organization_name') THEN
      dbms_output.put_line('     Column xom_customer_mod.organization_name already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_customer_mod MODIFY organization_name NULL';
    dbms_output.put_line('     Column xom_customer_mod.organization_name modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[CustomerModifier] Field[[Field=organizationName]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DeTseDeviceConfig] Field[[Field=tseCertificate, Field=tseConfig]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE cger_tse_device MODIFY tse_certificate VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column cger_tse_device.tse_certificate modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('cger_tse_device','tse_certificate') THEN
      dbms_output.put_line('     Column cger_tse_device.tse_certificate already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cger_tse_device MODIFY tse_certificate NULL';
    dbms_output.put_line('     Column cger_tse_device.tse_certificate modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE cger_tse_device MODIFY tse_config VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column cger_tse_device.tse_config modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('cger_tse_device','tse_config') THEN
      dbms_output.put_line('     Column cger_tse_device.tse_config already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cger_tse_device MODIFY tse_config NULL';
    dbms_output.put_line('     Column cger_tse_device.tse_config modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DeTseDeviceConfig] Field[[Field=tseCertificate, Field=tseConfig]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[ReceiptText] Field[[Field=receiptText]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE com_receipt_text MODIFY receipt_text VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column com_receipt_text.receipt_text modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('com_receipt_text','receipt_text') THEN
      dbms_output.put_line('     Column com_receipt_text.receipt_text already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_receipt_text MODIFY receipt_text NOT NULL';
    dbms_output.put_line('     Column com_receipt_text.receipt_text modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[ReceiptText] Field[[Field=receiptText]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DatabaseTranslation] Field[[Field=translation]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE com_translations MODIFY translation VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column com_translations.translation modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('com_translations','translation') THEN
      dbms_output.put_line('     Column com_translations.translation already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE com_translations MODIFY translation NULL';
    dbms_output.put_line('     Column com_translations.translation modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DatabaseTranslation] Field[[Field=translation]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[CustomerConsentInfo] Field[[Field=consent1Text, Field=consent2Text, Field=consent3Text, Field=consent4Text, Field=consent5Text, Field=termsAndConditions]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent1_text VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column crm_consent_info.consent1_text modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('crm_consent_info','consent1_text') THEN
      dbms_output.put_line('     Column crm_consent_info.consent1_text already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent1_text NULL';
    dbms_output.put_line('     Column crm_consent_info.consent1_text modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent2_text VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column crm_consent_info.consent2_text modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('crm_consent_info','consent2_text') THEN
      dbms_output.put_line('     Column crm_consent_info.consent2_text already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent2_text NULL';
    dbms_output.put_line('     Column crm_consent_info.consent2_text modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent3_text VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column crm_consent_info.consent3_text modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('crm_consent_info','consent3_text') THEN
      dbms_output.put_line('     Column crm_consent_info.consent3_text already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent3_text NULL';
    dbms_output.put_line('     Column crm_consent_info.consent3_text modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent4_text VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column crm_consent_info.consent4_text modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('crm_consent_info','consent4_text') THEN
      dbms_output.put_line('     Column crm_consent_info.consent4_text already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent4_text NULL';
    dbms_output.put_line('     Column crm_consent_info.consent4_text modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent5_text VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column crm_consent_info.consent5_text modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('crm_consent_info','consent5_text') THEN
      dbms_output.put_line('     Column crm_consent_info.consent5_text already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY consent5_text NULL';
    dbms_output.put_line('     Column crm_consent_info.consent5_text modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY terms_and_conditions VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column crm_consent_info.terms_and_conditions modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('crm_consent_info','terms_and_conditions') THEN
      dbms_output.put_line('     Column crm_consent_info.terms_and_conditions already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE crm_consent_info MODIFY terms_and_conditions NULL';
    dbms_output.put_line('     Column crm_consent_info.terms_and_conditions modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[CustomerConsentInfo] Field[[Field=consent1Text, Field=consent2Text, Field=consent3Text, Field=consent4Text, Field=consent5Text, Field=termsAndConditions]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DataLoaderFailure] Field[[Field=failedData, Field=failureMessage]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_dataloader_failure MODIFY failed_data VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column ctl_dataloader_failure.failed_data modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('ctl_dataloader_failure','failed_data') THEN
      dbms_output.put_line('     Column ctl_dataloader_failure.failed_data already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_dataloader_failure MODIFY failed_data NULL';
    dbms_output.put_line('     Column ctl_dataloader_failure.failed_data modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_dataloader_failure MODIFY failure_message VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column ctl_dataloader_failure.failure_message modify');
END;
/
BEGIN
  IF NOT SP_IS_NULLABLE ('ctl_dataloader_failure','failure_message') THEN
      dbms_output.put_line('     Column ctl_dataloader_failure.failure_message already not nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE ctl_dataloader_failure MODIFY failure_message NOT NULL';
    dbms_output.put_line('     Column ctl_dataloader_failure.failure_message modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[DataLoaderFailure] Field[[Field=failedData, Field=failureMessage]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[EmployeeAnswers] Field[[Field=challengeAnswer]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE hrs_employee_answers MODIFY challenge_answer VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column hrs_employee_answers.challenge_answer modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('hrs_employee_answers','challenge_answer') THEN
      dbms_output.put_line('     Column hrs_employee_answers.challenge_answer already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE hrs_employee_answers MODIFY challenge_answer NULL';
    dbms_output.put_line('     Column hrs_employee_answers.challenge_answer modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[EmployeeAnswers] Field[[Field=challengeAnswer]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[Shipment] Field[[Field=shippingLabel]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE inv_shipment MODIFY shipping_label VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column inv_shipment.shipping_label modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('inv_shipment','shipping_label') THEN
      dbms_output.put_line('     Column inv_shipment.shipping_label already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE inv_shipment MODIFY shipping_label NULL';
    dbms_output.put_line('     Column inv_shipment.shipping_label modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[Shipment] Field[[Field=shippingLabel]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[CustomizationModifier] Field[[Field=customizationMessage]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE xom_customization_mod MODIFY customization_message VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column xom_customization_mod.customization_message modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('xom_customization_mod','customization_message') THEN
      dbms_output.put_line('     Column xom_customization_mod.customization_message already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_customization_mod MODIFY customization_message NULL';
    dbms_output.put_line('     Column xom_customization_mod.customization_message modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[CustomizationModifier] Field[[Field=customizationMessage]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[Order] Field[[Field=giftMessage, Field=orderMessage, Field=statusCodeReasonNote]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order MODIFY gift_message VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column xom_order.gift_message modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('xom_order','gift_message') THEN
      dbms_output.put_line('     Column xom_order.gift_message already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order MODIFY gift_message NULL';
    dbms_output.put_line('     Column xom_order.gift_message modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order MODIFY order_message VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column xom_order.order_message modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('xom_order','order_message') THEN
      dbms_output.put_line('     Column xom_order.order_message already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order MODIFY order_message NULL';
    dbms_output.put_line('     Column xom_order.order_message modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order MODIFY status_code_reason_note VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column xom_order.status_code_reason_note modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('xom_order','status_code_reason_note') THEN
      dbms_output.put_line('     Column xom_order.status_code_reason_note already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order MODIFY status_code_reason_note NULL';
    dbms_output.put_line('     Column xom_order.status_code_reason_note modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[Order] Field[[Field=giftMessage, Field=orderMessage, Field=statusCodeReasonNote]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[OrderLineDetail] Field[[Field=lineMessage, Field=statusCodeReasonNote]] starting...');
END;
/
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order_line_detail MODIFY line_message VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column xom_order_line_detail.line_message modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('xom_order_line_detail','line_message') THEN
      dbms_output.put_line('     Column xom_order_line_detail.line_message already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order_line_detail MODIFY line_message NULL';
    dbms_output.put_line('     Column xom_order_line_detail.line_message modify');
  END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order_line_detail MODIFY status_code_reason_note VARCHAR2(4000 char) DEFAULT (null)';
    dbms_output.put_line('     Column xom_order_line_detail.status_code_reason_note modify');
END;
/
BEGIN
  IF SP_IS_NULLABLE ('xom_order_line_detail','status_code_reason_note') THEN
      dbms_output.put_line('     Column xom_order_line_detail.status_code_reason_note already nullable');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE xom_order_line_detail MODIFY status_code_reason_note NULL';
    dbms_output.put_line('     Column xom_order_line_detail.status_code_reason_note modify');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Alter Column: DTX[OrderLineDetail] Field[[Field=lineMessage, Field=statusCodeReasonNote]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Update sp_flash stored procedure starting...');
END;
/
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
-- ... .....        Initial Version
-- PGH  02/23/10    Removed the currencyid paramerer, then joining the loc_rtl_loc table to get the default
--                  currencyid for the location.  If the default is not set, defaulting to 'USD'. 
-- BCW  06/21/12    Updated per Emily Tan's instructions.
-- BCW  12/06/13    Replaced the sale cursor by writing the transaction line item directly into the rpt_sale_line table.
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE SP_FLASH');

CREATE OR REPLACE PROCEDURE sp_flash 
  (argOrganizationId    IN NUMBER, 
   argRetailLocationId  IN NUMBER, 
   argBusinessDate      IN DATE, 
   argWrkstnId          IN NUMBER, 
   argTransSeq          IN NUMBER) 
AUTHID CURRENT_USER 
IS

myerror exception;
myreturn exception;

-- Arguments
pvOrganizationId        NUMBER(10);
pvRetailLocationId      NUMBER(10); 
pvBusinessDate          DATE;
pvWrkstnId              NUMBER(20,0);
pvTransSeq              NUMBER(20,0);

-- Quantities
vActualQuantity         NUMBER (11,2);
vGrossQuantity          NUMBER (11,2);
vQuantity               NUMBER (11,2);
vTotQuantity            NUMBER (11,2);

-- Amounts
vNetAmount              NUMBER (17,6);
vGrossAmount            NUMBER (17,6);
vTotGrossAmt            NUMBER (17,6);
vTotNetAmt              NUMBER (17,6);
vDiscountAmt            NUMBER (17,6);
vOverrideAmt            NUMBER (17,6);
vPaidAmt                NUMBER (17,6);
vTenderAmt              NUMBER (17,6);
vForeign_amt            NUMBER (17,6);
vLayawayPrice           NUMBER(17,6);
vUnitPrice              NUMBER (17,6);

-- Non Physical Items
vNonPhys                VARCHAR2(30 char);
vNonPhysSaleType        VARCHAR2(30 char);
vNonPhysType            VARCHAR2(30 char);
vNonPhysPrice           NUMBER (17,6);
vNonPhysQuantity        NUMBER (11,2);

-- Status codes
vTransStatcode          VARCHAR2(30 char);
vTransTypcode           VARCHAR2(30 char);
vSaleLineItmTypcode     VARCHAR2(30 char);
vTndrStatcode           VARCHAR2(60 char);
vLineitemStatcode       VARCHAR2(30 char);

-- others
vTransTimeStamp         TIMESTAMP;
vTransDate              TIMESTAMP;
vTransCount             NUMBER(10);
vTndrCount              NUMBER(10);
vPostVoidFlag           NUMBER(1);
vReturnFlag             NUMBER(1);
vTaxTotal               NUMBER (17,6);
vPaid                   VARCHAR2(30 char);
vLineEnum               VARCHAR2(150 char);
vTndrId                 VARCHAR2(60 char);
vItemId                 VARCHAR2(60 char);
vRtransLineItmSeq       NUMBER(10);
vDepartmentId           VARCHAR2(90 char);
vTndridProp             VARCHAR2(60 char);
vCurrencyId             VARCHAR2(3 char);
vTndrTypCode            VARCHAR2(30 char);

vSerialNbr              VARCHAR2(60 char);
vPriceModAmt            NUMBER(17,6);
vPriceModReascode       VARCHAR2(60 char);
vNonPhysExcludeFlag     NUMBER(1);
vCustPartyId            VARCHAR2(60 char);
vCustLastName           VARCHAR2(90 char);
vCustFirstName          VARCHAR2(90 char);
vItemDesc               VARCHAR2(254 char);
vBeginTimeInt           NUMBER(10);

-- counts
vRowCnt                 NUMBER(10);
vCntTrans               NUMBER(10);
vCntTndrCtl             NUMBER(10);
vCntPostVoid            NUMBER(10);
vCntRevTrans            NUMBER(10);
vCntNonPhysItm          NUMBER(10);
vCntNonPhys             NUMBER(10);
vCntCust                NUMBER(10);
vCntItem                NUMBER(10);
vCntParty               NUMBER(10);

-- cursors

CURSOR tenderCursor IS 
    SELECT t.amt, t.foreign_amt, t.tndr_id, t.tndr_statcode, tr.string_value, tnd.tndr_typcode 
        FROM TTR_TNDR_LINEITM t 
        inner join TRL_RTRANS_LINEITM r ON t.organization_id=r.organization_id
                                       AND t.rtl_loc_id=r.rtl_loc_id
                                       AND t.wkstn_id=r.wkstn_id
                                       AND t.trans_seq=r.trans_seq
                                       AND t.business_date=r.business_date
                                       AND t.rtrans_lineitm_seq=r.rtrans_lineitm_seq
        inner join TND_TNDR tnd ON t.organization_id=tnd.organization_id
                                       AND t.tndr_id=tnd.tndr_id                                   
    left outer join trl_rtrans_lineitm_p tr on tr.organization_id=r.organization_id
                    and tr.rtl_loc_id=r.rtl_loc_id
                    and tr.wkstn_id=r.wkstn_id
                    and tr.trans_seq=r.trans_seq
                    and tr.business_date=r.business_date
                    and tr.rtrans_lineitm_seq=r.rtrans_lineitm_seq
                    and lower(property_code) = 'tender_id'
        WHERE t.organization_id = pvOrganizationId
          AND t.rtl_loc_id = pvRetailLocationId
          AND t.wkstn_id = pvWrkstnId
          AND t.trans_seq = pvTransSeq
          AND t.business_date = pvBusinessDate
          AND r.void_flag = 0
          AND t.tndr_id <> 'ACCOUNT_CREDIT';

CURSOR postVoidTenderCursor IS 
    SELECT t.amt, t.foreign_amt, t.tndr_id, t.tndr_statcode, tr.string_value 
        FROM TTR_TNDR_LINEITM t 
        inner join TRL_RTRANS_LINEITM r ON t.organization_id=r.organization_id
                                       AND t.rtl_loc_id=r.rtl_loc_id
                                       AND t.wkstn_id=r.wkstn_id
                                       AND t.trans_seq=r.trans_seq
                                       AND t.business_date=r.business_date
                                       AND t.rtrans_lineitm_seq=r.rtrans_lineitm_seq
    left outer join trl_rtrans_lineitm_p tr on tr.organization_id=r.organization_id
                    and tr.rtl_loc_id=r.rtl_loc_id
                    and tr.wkstn_id=r.wkstn_id
                    and tr.trans_seq=r.trans_seq
                    and tr.business_date=r.business_date
                    and tr.rtrans_lineitm_seq=r.rtrans_lineitm_seq
                    and lower(property_code) = 'tender_id'
        WHERE t.organization_id = pvOrganizationId
          AND t.rtl_loc_id = pvRetailLocationId
          AND t.wkstn_id = pvWrkstnId
          AND t.trans_seq = pvTransSeq
          AND t.business_date = pvBusinessDate
          AND r.void_flag = 0
      AND t.tndr_id <> 'ACCOUNT_CREDIT';

CURSOR saleCursor IS
       select rsl.item_id,
       sale_lineitm_typcode,
       actual_quantity,
       unit_price,
       case vPostVoidFlag when 1 then -1 else 1 end * coalesce(gross_amt,0),
       case when return_flag=vPostVoidFlag then 1 else -1 end * coalesce(gross_quantity,0),
       merch_level_1,
       case vPostVoidFlag when 1 then -1 else 1 end * coalesce(net_amt,0),
       case when return_flag=vPostVoidFlag then 1 else -1 end * coalesce(quantity,0),
     return_flag 
       from rpt_sale_line rsl
     left join itm_non_phys_item inp on rsl.item_id=inp.item_id and rsl.organization_id=inp.organization_id
       WHERE rsl.organization_id = pvOrganizationId
          AND rtl_loc_id = pvRetailLocationId
          AND wkstn_id = pvWrkstnId
          AND business_date = pvBusinessDate
          AND trans_seq = pvTransSeq
      and QUANTITY <> 0
      and sale_lineitm_typcode not in ('ONHOLD','WORK_ORDER')
      and coalesce(exclude_from_net_sales_flag,0)=0;

-- Declarations end 

BEGIN
    -- initializations of args
    pvOrganizationId      := argOrganizationId;
    pvRetailLocationId    := argRetailLocationId;
    pvWrkstnId            := argWrkstnId;
    pvBusinessDate        := argBusinessDate;
    pvTransSeq            := argTransSeq;

    BEGIN
    SELECT tt.trans_statcode,
           tt.trans_typcode, 
           tt.begin_datetime, 
           tt.trans_date,
           tt.taxtotal, 
           tt.post_void_flag, 
           tt.begin_time_int,
           coalesce(t.currency_id, rl.currency_id)
        INTO vTransStatcode, 
             vTransTypcode, 
             vTransTimeStamp, 
             vTransDate,
             vTaxTotal, 
             vPostVoidFlag, 
             vBeginTimeInt,
             vCurrencyID
        FROM TRN_TRANS tt  
            LEFT JOIN loc_rtl_loc rl on tt.organization_id = rl.organization_id and tt.rtl_loc_id = rl.rtl_loc_id
      LEFT JOIN (select max(currency_id) currency_id,ttl.organization_id,ttl.rtl_loc_id,ttl.wkstn_id,ttl.business_date,ttl.trans_seq
      from ttr_tndr_lineitm ttl
      inner join tnd_tndr tnd on ttl.organization_id=tnd.organization_id and ttl.tndr_id=tnd.tndr_id
      group by ttl.organization_id,ttl.rtl_loc_id,ttl.wkstn_id,ttl.business_date,ttl.trans_seq) t ON
      tt.organization_id = t.organization_id
          AND tt.rtl_loc_id = t.rtl_loc_id
          AND tt.wkstn_id = t.wkstn_id
          AND tt.business_date = t.business_date
          AND tt.trans_seq = t.trans_seq
        WHERE tt.organization_id = pvOrganizationId
          AND tt.rtl_loc_id = pvRetailLocationId
          AND tt.wkstn_id = pvWrkstnId
          AND tt.business_date = pvBusinessDate
          AND tt.trans_seq = pvTransSeq;
    EXCEPTION
        WHEN no_data_found THEN
        NULL;
    END;
    
    vCntTrans := SQL%ROWCOUNT;
    
    IF vCntTrans = 1 THEN 
    
    -- so update the column on trn trans
        UPDATE TRN_TRANS SET flash_sales_flag = 1
            WHERE organization_id = pvOrganizationId
            AND rtl_loc_id = pvRetailLocationId
            AND wkstn_id = pvWrkstnId
            AND trans_seq = pvTransSeq
            AND business_date = pvBusinessDate;
    ELSE
        -- /* Invalid transaction */
        raise myerror;
        
    END IF;

    vTransCount := 1; -- /* initializing the transaction count */

  select count(*) into vCntTrans from rpt_sale_line
    WHERE organization_id = pvOrganizationId
    AND rtl_loc_id = pvRetailLocationId
    AND wkstn_id = pvWrkstnId
    AND trans_seq = pvTransSeq
    AND business_date = pvBusinessDate;

  IF vCntTrans = 0 AND vPostVoidFlag = 1 THEN
    insert into rpt_sale_line
    (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq,
    quantity, actual_quantity, gross_quantity, unit_price, net_amt, gross_amt, item_id, 
    item_desc, merch_level_1, serial_nbr, return_flag, override_amt, trans_timestamp, trans_date,
    discount_amt, cust_party_id, last_name, first_name, trans_statcode, sale_lineitm_typcode, begin_time_int, exclude_from_net_sales_flag)
    select tsl.organization_id, tsl.rtl_loc_id, tsl.business_date, tsl.wkstn_id, tsl.trans_seq, tsl.rtrans_lineitm_seq,
    tsl.net_quantity, tsl.quantity, tsl.gross_quantity, tsl.unit_price,
    -- For VAT taxed items there are rounding problems by which the usage of the tsl.net_amt could create problems.
    -- So, we are calculating it using the tax amount which could have more decimals and because that it is more accurate
    case when vat_amt is null then tsl.net_amt else tsl.gross_amt-tsl.vat_amt-coalesce(d.discount_amt,0) end, 
    tsl.gross_amt, tsl.item_id,
    i.DESCRIPTION, coalesce(tsl.merch_level_1,i.MERCH_LEVEL_1,'DEFAULT'), tsl.serial_nbr, tsl.return_flag, coalesce(o.override_amt,0), vTransTimeStamp, vTransDate,
    coalesce(d.discount_amt,0), tr.cust_party_id, cust.last_name, cust.first_name, 'VOID', tsl.sale_lineitm_typcode, vBeginTimeInt, tsl.exclude_from_net_sales_flag
    from trl_sale_lineitm tsl
    inner join trl_rtrans_lineitm r
    on tsl.organization_id=r.organization_id
    and tsl.rtl_loc_id=r.rtl_loc_id
    and tsl.wkstn_id=r.wkstn_id
    and tsl.trans_seq=r.trans_seq
    and tsl.business_date=r.business_date
    and tsl.rtrans_lineitm_seq=r.rtrans_lineitm_seq
    and r.rtrans_lineitm_typcode = 'ITEM'
    left join xom_order_mod xom
    on tsl.organization_id=xom.organization_id
    and tsl.rtl_loc_id=xom.rtl_loc_id
    and tsl.wkstn_id=xom.wkstn_id
    and tsl.trans_seq=xom.trans_seq
    and tsl.business_date=xom.business_date
    and tsl.rtrans_lineitm_seq=xom.rtrans_lineitm_seq
    left join xom_order_line_detail xold
    on xom.organization_id=xold.organization_id
    and xom.order_id=xold.order_id
    and xom.detail_seq=xold.detail_seq
    and xom.detail_line_number=xold.detail_line_number
    left join itm_item i
    on tsl.organization_id=i.ORGANIZATION_ID
    and tsl.item_id=i.ITEM_ID
    left join (select extended_amt override_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
      FROM trl_rtl_price_mod
      WHERE void_flag = 0 and rtl_price_mod_reascode='PRICE_OVERRIDE') o
    on tsl.organization_id = o.organization_id 
      AND tsl.rtl_loc_id = o.rtl_loc_id
      AND tsl.business_date = o.business_date 
      AND tsl.wkstn_id = o.wkstn_id 
      AND tsl.trans_seq = o.trans_seq
      AND tsl.rtrans_lineitm_seq = o.rtrans_lineitm_seq
    left join (select sum(extended_amt) discount_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
      FROM trl_rtl_price_mod
      WHERE void_flag = 0 and rtl_price_mod_reascode in ('LINE_ITEM_DISCOUNT', 'TRANSACTION_DISCOUNT', 'GROUP_DISCOUNT', 'NEW_PRICE_RULE', 'DEAL')
      group by organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq) d
    on tsl.organization_id = d.organization_id 
      AND tsl.rtl_loc_id = d.rtl_loc_id
      AND tsl.business_date = d.business_date 
      AND tsl.wkstn_id = d.wkstn_id 
      AND tsl.trans_seq = d.trans_seq
      AND tsl.rtrans_lineitm_seq = d.rtrans_lineitm_seq
    left join trl_rtrans tr
    on tsl.organization_id = tr.organization_id 
      AND tsl.rtl_loc_id = tr.rtl_loc_id
      AND tsl.business_date = tr.business_date 
      AND tsl.wkstn_id = tr.wkstn_id 
      AND tsl.trans_seq = tr.trans_seq
    left join crm_party cust
    on tsl.organization_id = cust.organization_id 
      AND tr.cust_party_id = cust.party_id
    where tsl.organization_id = pvOrganizationId
    and tsl.rtl_loc_id = pvRetailLocationId
    and tsl.wkstn_id = pvWrkstnId
    and tsl.business_date = pvBusinessDate
    and tsl.trans_seq = pvTransSeq
    and r.void_flag=0
    and ((tsl.SALE_LINEITM_TYPCODE <> 'ORDER'and (xom.detail_type IS NULL OR xold.status_code = 'FULFILLED') )
    or (tsl.SALE_LINEITM_TYPCODE = 'ORDER' and xom.detail_type in ('FEE', 'PAYMENT') ));
    raise myreturn;
  END IF;

    -- collect transaction data
    IF ABS(vTaxTotal) > 0 AND vTransTypcode <> 'POST_VOID' AND vPostVoidFlag = 0 AND vTransStatcode = 'COMPLETE' THEN
      
        sp_ins_upd_flash_sales (pvOrganizationId, 
                                pvRetailLocationId, 
                                vTransDate,
                                pvWrkstnId, 
                                'TOTALTAX', 
                                1, 
                                vTaxTotal, 
                                vCurrencyId);
      
    END IF;

    IF vTransTypcode = 'TENDER_CONTROL' AND vPostVoidFlag = 0 THEN    -- process for paid in paid out 
    
        BEGIN
        SELECT  typcode, amt INTO vPaid, vPaidAmt 
            FROM TSN_TNDR_CONTROL_TRANS 
            WHERE typcode LIKE 'PAID%'
              AND organization_id = pvOrganizationId
              AND rtl_loc_id = pvRetailLocationId
              AND wkstn_id = pvWrkstnId
              AND trans_seq = pvTransSeq
              AND business_date = pvBusinessDate;
           EXCEPTION
        WHEN no_data_found THEN
            NULL;
        END;


        vCntTndrCtl := SQL%ROWCOUNT;
    
        IF vCntTndrCtl = 1 THEN   
            
                IF vTransStatcode = 'COMPLETE' THEN
                        -- it is paid in or paid out
                    IF vPaid = 'PAID_IN' OR vPaid = 'PAIDIN' THEN
                        vLineEnum := 'paidin';
                    ELSE
                        vLineEnum := 'paidout';
                    END IF; 
                        -- update flash sales                 
                        sp_ins_upd_flash_sales (pvOrganizationId, 
                                               pvRetailLocationId, 
                                               vTransDate,
                                               pvWrkstnId, 
                                               vLineEnum, 
                                               1, 
                                               vPaidAmt, 
                                               vCurrencyId);
                END IF;
        END IF;
    END IF;
  
  -- collect tenders  data
  IF vPostVoidFlag = 0 AND vTransTypcode <> 'POST_VOID' THEN
  BEGIN
    OPEN tenderCursor;
    LOOP
        FETCH tenderCursor INTO vTenderAmt, vForeign_amt, vTndrid, vTndrStatcode, vTndridProp, vTndrTypCode; 
        EXIT WHEN tenderCursor%NOTFOUND;
  
        IF vTndrTypCode='VOUCHER' OR vTndrStatcode <> 'Change' THEN
            vTndrCount := 1;-- only for original tenders
        ELSE 
            vTndrCount := 0;
        END IF;

        if vTndridProp IS NOT NULL THEN
           vTndrid := vTndridProp;
    end if;

       IF vLineEnum = 'paidout' THEN
            vTenderAmt := vTenderAmt * -1;
            vForeign_amt := vForeign_amt * -1;
        END IF;

        -- update flash
        IF vTransStatcode = 'COMPLETE' THEN
            sp_ins_upd_flash_sales (pvOrganizationId, 
                                    pvRetailLocationId, 
                                    vTransDate, 
                                    pvWrkstnId, 
                                    vTndrid, 
                                    vTndrCount, 
                                    vTenderAmt, 
                                    vCurrencyId);
        END IF;

        IF vTenderAmt > 0 AND vTransStatcode = 'COMPLETE' THEN
            sp_ins_upd_flash_sales (pvOrganizationId, 
                                    pvRetailLocationId, 
                                    vTransDate, 
                                    pvWrkstnId,
                                    'TendersTakenIn', 
                                    1, 
                                    vTenderAmt, 
                                    vCurrencyId);
        ELSE
            sp_ins_upd_flash_sales (pvOrganizationId, 
                                    pvRetailLocationId, 
                                    vTransDate, 
                                    pvWrkstnId, 
                                    'TendersRefunded', 
                                    1, 
                                    vTenderAmt, 
                                    vCurrencyId);
        END IF;
    END LOOP;
    CLOSE tenderCursor;
  EXCEPTION
    WHEN OTHERS THEN CLOSE tenderCursor;
  END;
  END IF;
  
  -- collect post void info
  IF vTransTypcode = 'POST_VOID' OR vPostVoidFlag = 1 THEN
      vTransCount := -1; /* reversing the count */
      IF vPostVoidFlag = 0 THEN
        vPostVoidFlag := 1;
      
            /* NOTE: From now on the parameter value carries the original post voided
                information rather than the current transaction information in 
                case of post void trans type. This will apply for sales data 
                processing.
            */
            BEGIN
            SELECT voided_org_id, voided_rtl_store_id, voided_wkstn_id, voided_business_date, voided_trans_id 
              INTO pvOrganizationId, pvRetailLocationId, pvWrkstnId, pvBusinessDate, pvTransSeq
              FROM TRN_POST_VOID_TRANS 
              WHERE organization_id = pvOrganizationId
                AND rtl_loc_id = pvRetailLocationId
                AND wkstn_id = pvWrkstnId
                AND business_date = pvBusinessDate
                AND trans_seq = pvTransSeq;
            EXCEPTION
                WHEN no_data_found THEN
                NULL;
            END;

            vCntPostVoid := SQL%ROWCOUNT;

            IF vCntPostVoid = 0 THEN      
              
                raise myerror; -- don't know the original post voided record
            END IF;

      select count(*) into vCntPostVoid from rpt_sale_line
      WHERE organization_id = pvOrganizationId
      AND rtl_loc_id = pvRetailLocationId
      AND wkstn_id = pvWrkstnId
      AND trans_seq = pvTransSeq
      AND business_date = pvBusinessDate
      AND trans_statcode = 'VOID';

      IF vCntPostVoid > 0 THEN
                raise myreturn; -- record already exists
      END IF;
    END IF;
    -- updating for postvoid
     UPDATE rpt_sale_line
       SET trans_statcode='VOID'
       WHERE organization_id = pvOrganizationId
         AND rtl_loc_id = pvRetailLocationId
         AND wkstn_id = pvWrkstnId
         AND business_date = pvBusinessDate
         AND trans_seq = pvTransSeq; 
        
      BEGIN
      SELECT typcode, amt INTO vPaid, vPaidAmt
        FROM TSN_TNDR_CONTROL_TRANS 
        WHERE typcode LIKE 'PAID%'
          AND organization_id = pvOrganizationId
          AND rtl_loc_id = pvRetailLocationId
          AND wkstn_id = pvWrkstnId
          AND trans_seq = pvTransSeq
          AND business_date = pvBusinessDate;
      EXCEPTION WHEN no_data_found THEN
          NULL;
      END;


      IF SQL%FOUND AND vTransStatcode = 'COMPLETE' THEN
        -- it is paid in or paid out
        IF vPaid = 'PAID_IN' OR vPaid = 'PAIDIN' THEN
            vLineEnum := 'paidin';
        ELSE
            vLineEnum := 'paidout';
        END IF;
        vPaidAmt := vPaidAmt * -1 ;

        -- update flash sales                 
        sp_ins_upd_flash_sales (pvOrganizationId, 
                                pvRetailLocationId, 
                                vTransDate,
                                pvWrkstnId, 
                                vLineEnum, 
                                -1, 
                                vPaidAmt, 
                                vCurrencyId);
      END IF;
    
        BEGIN
        SELECT taxtotal INTO vTaxTotal
          FROM TRN_TRANS 
          WHERE organization_id = pvOrganizationId
            AND rtl_loc_id = pvRetailLocationId
            AND wkstn_id = pvWrkstnId
            AND business_date = pvBusinessDate
            AND trans_seq = pvTransSeq;
        EXCEPTION WHEN no_data_found THEN
            NULL;
        END;
        
        vCntRevTrans := SQL%ROWCOUNT;
        
        IF vCntRevTrans = 1 THEN    
            IF ABS(vTaxTotal) > 0 AND vTransStatcode = 'COMPLETE' THEN
                vTaxTotal := vTaxTotal * -1 ;
                sp_ins_upd_flash_sales (pvOrganizationId,
                                        pvRetailLocationId,
                                        vTransDate,
                                        pvWrkstnId,
                                        'TOTALTAX',
                                        -1,
                                        vTaxTotal, 
                                        vCurrencyId);
            END IF;
        END IF;

        -- reverse tenders
    BEGIN
        OPEN postVoidTenderCursor;
        
        LOOP
            FETCH postVoidTenderCursor INTO vTenderAmt, vForeign_amt, vTndrid, vTndrStatcode, vTndridProp;
            EXIT WHEN postVoidTenderCursor%NOTFOUND;
          
            IF vTndrStatcode <> 'Change' THEN
              vTndrCount := -1 ; -- only for original tenders
            ELSE 
              vTndrCount := 0 ;
            END IF;
          
      if vTndridProp IS NOT NULL THEN
         vTndrid := vTndridProp;
      end if;

            -- update flash
            vTenderAmt := vTenderAmt * -1;

            IF vTransStatcode = 'COMPLETE' THEN
                sp_ins_upd_flash_sales (pvOrganizationId, 
                                        pvRetailLocationId, 
                                        vTransDate, 
                                        pvWrkstnId, 
                                        vTndrid, 
                                        vTndrCount, 
                                        vTenderAmt, 
                                        vCurrencyId);
            END IF;
            
            IF vTenderAmt < 0 AND vTransStatcode = 'COMPLETE' THEN
                sp_ins_upd_flash_sales (pvOrganizationId, 
                                        pvRetailLocationId, 
                                        vTransDate, 
                                        pvWrkstnId,
                                        'TendersTakenIn',
                                        -1, 
                                        vTenderAmt, 
                                        vCurrencyId);
            ELSE
                sp_ins_upd_flash_sales (pvOrganizationId, 
                                        pvRetailLocationId, 
                                        vTransDate, 
                                        pvWrkstnId,
                                        'TendersRefunded',
                                        -1, 
                                        vTenderAmt, 
                                        vCurrencyId);
            END IF;
        END LOOP;
        
        CLOSE postVoidTenderCursor;
    EXCEPTION
      WHEN OTHERS THEN CLOSE postVoidTenderCursor;
  END;
  END IF;
  
  -- collect sales data
          

IF vPostVoidFlag = 0 and vTransTypcode <> 'POST_VOID' THEN -- dont do it for rpt sale line
        -- sale item insert
         insert into rpt_sale_line
        (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq,
        quantity, actual_quantity, gross_quantity, unit_price, net_amt, gross_amt, item_id, 
        item_desc, merch_level_1, serial_nbr, return_flag, override_amt, trans_timestamp, trans_date,
        discount_amt, cust_party_id, last_name, first_name, trans_statcode, sale_lineitm_typcode, begin_time_int, exclude_from_net_sales_flag)
        select tsl.organization_id, tsl.rtl_loc_id, tsl.business_date, tsl.wkstn_id, tsl.trans_seq, tsl.rtrans_lineitm_seq,
        tsl.net_quantity, tsl.quantity, tsl.gross_quantity, tsl.unit_price,
        -- For VAT taxed items there are rounding problems by which the usage of the tsl.net_amt could create problems.
        -- So, we are calculating it using the tax amount which could have more decimals and because that it is more accurate
        case when vat_amt is null then tsl.net_amt else tsl.gross_amt-tsl.vat_amt-coalesce(d.discount_amt,0) end,
        tsl.gross_amt, tsl.item_id,
        i.DESCRIPTION, coalesce(tsl.merch_level_1,i.MERCH_LEVEL_1,'DEFAULT'), tsl.serial_nbr, tsl.return_flag, coalesce(o.override_amt,0), vTransTimeStamp, vTransDate,
        coalesce(d.discount_amt,0), tr.cust_party_id, cust.last_name, cust.first_name, vTransStatcode, tsl.sale_lineitm_typcode, vBeginTimeInt, tsl.exclude_from_net_sales_flag
        from trl_sale_lineitm tsl
        inner join trl_rtrans_lineitm r
        on tsl.organization_id=r.organization_id
        and tsl.rtl_loc_id=r.rtl_loc_id
        and tsl.wkstn_id=r.wkstn_id
        and tsl.trans_seq=r.trans_seq
        and tsl.business_date=r.business_date
        and tsl.rtrans_lineitm_seq=r.rtrans_lineitm_seq
        and r.rtrans_lineitm_typcode = 'ITEM'
        left join xom_order_mod xom
            on tsl.organization_id=xom.organization_id
            and tsl.rtl_loc_id=xom.rtl_loc_id
            and tsl.wkstn_id=xom.wkstn_id
            and tsl.trans_seq=xom.trans_seq
            and tsl.business_date=xom.business_date
            and tsl.rtrans_lineitm_seq=xom.rtrans_lineitm_seq
        left join xom_order_line_detail xold
            on xom.organization_id=xold.organization_id
            and xom.order_id=xold.order_id
            and xom.detail_seq=xold.detail_seq
            and xom.detail_line_number=xold.detail_line_number
            left join itm_item i
        on tsl.organization_id=i.ORGANIZATION_ID
        and tsl.item_id=i.ITEM_ID
        left join (select extended_amt override_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
            FROM trl_rtl_price_mod
            WHERE void_flag = 0 and rtl_price_mod_reascode='PRICE_OVERRIDE') o
        on tsl.organization_id = o.organization_id 
            AND tsl.rtl_loc_id = o.rtl_loc_id
            AND tsl.business_date = o.business_date 
            AND tsl.wkstn_id = o.wkstn_id 
            AND tsl.trans_seq = o.trans_seq
            AND tsl.rtrans_lineitm_seq = o.rtrans_lineitm_seq
        left join (select sum(extended_amt) discount_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
            FROM trl_rtl_price_mod
            WHERE void_flag = 0 and rtl_price_mod_reascode in ('LINE_ITEM_DISCOUNT', 'TRANSACTION_DISCOUNT', 'GROUP_DISCOUNT', 'NEW_PRICE_RULE', 'DEAL')
            group by organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq) d
        on tsl.organization_id = d.organization_id 
            AND tsl.rtl_loc_id = d.rtl_loc_id
            AND tsl.business_date = d.business_date 
            AND tsl.wkstn_id = d.wkstn_id 
            AND tsl.trans_seq = d.trans_seq
            AND tsl.rtrans_lineitm_seq = d.rtrans_lineitm_seq
        left join trl_rtrans tr
        on tsl.organization_id = tr.organization_id 
            AND tsl.rtl_loc_id = tr.rtl_loc_id
            AND tsl.business_date = tr.business_date 
            AND tsl.wkstn_id = tr.wkstn_id 
            AND tsl.trans_seq = tr.trans_seq
        left join crm_party cust
        on tsl.organization_id = cust.organization_id 
            AND tr.cust_party_id = cust.party_id
        where tsl.organization_id = pvOrganizationId
        and tsl.rtl_loc_id = pvRetailLocationId
        and tsl.wkstn_id = pvWrkstnId
        and tsl.business_date = pvBusinessDate
        and tsl.trans_seq = pvTransSeq
        and r.void_flag=0
        and ((tsl.SALE_LINEITM_TYPCODE <> 'ORDER'and (xom.detail_type IS NULL OR xold.status_code = 'FULFILLED') )
             or (tsl.SALE_LINEITM_TYPCODE = 'ORDER' and xom.detail_type in ('FEE', 'PAYMENT') ));

END IF;
    
        IF vTransStatcode = 'COMPLETE' THEN -- process only completed transaction for flash sales tables
        BEGIN
       select sum(case vPostVoidFlag when 0 then -1 else 1 end * coalesce(quantity,0)),sum(case vPostVoidFlag when 1 then -1 else 1 end * coalesce(net_amt,0))
        INTO vQuantity,vNetAmount
        from rpt_sale_line rsl
    left join itm_non_phys_item inp on rsl.item_id=inp.item_id and rsl.organization_id=inp.organization_id
        where rsl.organization_id = pvOrganizationId
            and rtl_loc_id = pvRetailLocationId
            and wkstn_id = pvWrkstnId
            and business_date = pvBusinessDate
            and trans_seq= pvTransSeq
            and return_flag=1
      and coalesce(exclude_from_net_sales_flag,0)=0;
        EXCEPTION WHEN no_data_found THEN
          NULL;
        END;
        
            IF ABS(vNetAmount) > 0 OR ABS(vQuantity) > 0 THEN
                -- populate now to flash tables
                -- returns
                sp_ins_upd_flash_sales(pvOrganizationId, 
                                       pvRetailLocationId, 
                                       vTransDate, 
                                       pvWrkstnId, 
                                       'RETURNS', 
                                       vQuantity, 
                                       vNetAmount, 
                                       vCurrencyId);
            END IF;
            
        select sum(case when return_flag=vPostVoidFlag then 1 else -1 end * coalesce(gross_quantity,0)),
        sum(case when return_flag=vPostVoidFlag then 1 else -1 end * coalesce(quantity,0)),
        sum(case vPostVoidFlag when 1 then -1 else 1 end * coalesce(gross_amt,0)),
        sum(case vPostVoidFlag when 1 then -1 else 1 end * coalesce(net_amt,0)),
        sum(case vPostVoidFlag when 1 then 1 else -1 end * coalesce(override_amt,0)),
        sum(case vPostVoidFlag when 1 then 1 else -1 end * coalesce(discount_amt,0))
        into vGrossQuantity,vQuantity,vGrossAmount,vNetAmount,vOverrideAmt,vDiscountAmt
        from rpt_sale_line rsl
    left join itm_non_phys_item inp on rsl.item_id=inp.item_id and rsl.organization_id=inp.organization_id
        where rsl.organization_id = pvOrganizationId
            and rtl_loc_id = pvRetailLocationId
            and wkstn_id = pvWrkstnId
            and business_date = pvBusinessDate
            and trans_seq= pvTransSeq
      and QUANTITY <> 0
      and sale_lineitm_typcode not in ('ONHOLD','WORK_ORDER')
      and coalesce(exclude_from_net_sales_flag,0)=0;
      
      -- For VAT taxed items there are rounding problems by which the usage of the SUM(net_amt) could create problems
      -- So we decided to set it as simple difference between the gross amount and the discount, which results in the expected value for both SALES and VAT without rounding issues
      -- We excluded the possibility to round also the tax because several reasons:
      -- 1) It will be possible that the final result is not accurate if both values have 5 as exceeding decimal
      -- 2) The value of the tax is rounded by specific legal requirements, and must match with what specified on the fiscal receipts
      -- 3) The number of decimals used for the tax amount in the database is less (6) than the one used in the calculator (10); 
      -- anyway, this last one is the most accurate, so we cannot rely on the value on the database which is at line level (rpt_sale_line) and could be affected by several roundings
      vNetAmount := vGrossAmount + vDiscountAmt - vTaxTotal;
      
            -- Gross sales
            IF ABS(vGrossAmount) > 0 THEN
                sp_ins_upd_flash_sales(pvOrganizationId,
                                       pvRetailLocationId,
                                       vTransDate, 
                                       pvWrkstnId, 
                                       'GROSSSALES', 
                                       vGrossQuantity, 
                                       vGrossAmount, 
                                       vCurrencyId);
            END IF;
      
            -- Net Sales update
            IF ABS(vNetAmount) > 0 THEN
                sp_ins_upd_flash_sales(pvOrganizationId,
                                       pvRetailLocationId,
                                       vTransDate, 
                                       pvWrkstnId, 
                                       'NETSALES', 
                                       vQuantity, 
                                       vNetAmount, 
                                       vCurrencyId);
            END IF;
        
            -- Discounts
            IF ABS(vOverrideAmt) > 0 THEN
                sp_ins_upd_flash_sales(pvOrganizationId,
                                       pvRetailLocationId,
                                       vTransDate, 
                                       pvWrkstnId, 
                                       'OVERRIDES', 
                                       vQuantity, 
                                       vOverrideAmt, 
                                       vCurrencyId);
            END IF; 
  
            -- Discounts  
            IF ABS(vDiscountAmt) > 0 THEN 
                sp_ins_upd_flash_sales(pvOrganizationId,
                                       pvRetailLocationId,
                                       vTransDate,
                                       pvWrkstnId,
                                       'DISCOUNTS',
                                       vQuantity, 
                                       vDiscountAmt, 
                                       vCurrencyId);
            END IF;
      
   
        -- Hourly sales updates (add for all the line items in the transaction)
            vTotQuantity := COALESCE(vTotQuantity,0) + vQuantity;
            vTotNetAmt := COALESCE(vTotNetAmt,0) + vNetAmount;
            vTotGrossAmt := COALESCE(vTotGrossAmt,0) + vGrossAmount;
    
  BEGIN
    OPEN saleCursor;
      
    LOOP  
        FETCH saleCursor INTO vItemId, 
                              vSaleLineitmTypcode, 
                              vActualQuantity,
                              vUnitPrice, 
                              vGrossAmount, 
                              vGrossQuantity, 
                              vDepartmentId, 
                              vNetAmount, 
                              vQuantity,
                vReturnFlag;
    
        EXIT WHEN saleCursor%NOTFOUND;
      
            BEGIN
            SELECT non_phys_item_typcode INTO vNonPhysType
              FROM ITM_NON_PHYS_ITEM 
              WHERE item_id = vItemId 
                AND organization_id = pvOrganizationId  ;
            EXCEPTION WHEN no_data_found THEN
                NULL;
            END;
      
            vCntNonPhysItm := SQL%ROWCOUNT;
            
            IF vCntNonPhysItm = 1 THEN  
                -- check for layaway or sp. order payment / deposit
                IF vPostVoidFlag <> vReturnFlag THEN 
                    vNonPhysPrice := vUnitPrice * -1;
                    vNonPhysQuantity := vActualQuantity * -1;
                ELSE
                    vNonPhysPrice := vUnitPrice;
                    vNonPhysQuantity := vActualQuantity;
                END IF;
      
                IF vNonPhysType = 'LAYAWAY_DEPOSIT' THEN 
                    vNonPhys := 'LayawayDeposits';
                ELSIF vNonPhysType = 'LAYAWAY_PAYMENT' THEN
                    vNonPhys := 'LayawayPayments';
                ELSIF vNonPhysType = 'SP_ORDER_DEPOSIT' THEN
                    vNonPhys := 'SpOrderDeposits';
                ELSIF vNonPhysType = 'SP_ORDER_PAYMENT' THEN
                    vNonPhys := 'SpOrderPayments';
             ELSIF vNonPhysType = 'PRESALE_DEPOSIT' THEN
        vNonPhys := 'PresaleDeposits';
          ELSIF vNonPhysType = 'PRESALE_PAYMENT' THEN
        vNonPhys := 'PresalePayments';
                ELSE 
                    vNonPhys := 'NonMerchandise';
                    vNonPhysPrice := vGrossAmount;
                    vNonPhysQuantity := vGrossQuantity;
                END IF; 
                -- update flash sales for non physical payments / deposits
                sp_ins_upd_flash_sales (pvOrganizationId,
                                        pvRetailLocationId,
                                        vTransDate,
                                        pvWrkstnId,
                                        vNonPhys,
                                        vNonPhysQuantity, 
                                        vNonphysPrice, 
                                        vCurrencyId);
            ELSE
                vNonPhys := ''; -- reset 
            END IF;
    
            -- process layaways and special orders (not sales)
            IF vSaleLineitmTypcode = 'LAYAWAY' OR vSaleLineitmTypcode = 'SPECIAL_ORDER' THEN
                IF (NOT (vNonPhys = 'LayawayDeposits' 
                      OR vNonPhys = 'LayawayPayments' 
                      OR vNonPhys = 'SpOrderDeposits' 
                      OR vNonPhys = 'SpOrderPayments'
          OR vNonPhys = 'PresaleDeposits'
          OR vNonPhys = 'PresalePayments')) 
                    AND ((vLineitemStatcode IS NULL) OR (vLineitemStatcode <> 'CANCEL')) THEN
                    
                    vNonPhysSaleType := 'SpOrderItems';
                  
                    IF vSaleLineitmTypcode = 'LAYAWAY' THEN
                        vNonPhysSaleType := 'LayawayItems';
            ELSIF vSaleLineitmTypcode = 'PRESALE' THEN
            vNonPhysSaleType := 'PresaleItems';

                    END IF;
                  
                    -- update flash sales for layaway items
                    vLayawayPrice := vUnitPrice * COALESCE(vActualQuantity,0);
                    sp_ins_upd_flash_sales (pvOrganizationId,
                                            pvRetailLocationId,
                                            vTransDate,
                                            pvWrkstnId,
                                            vNonPhys,
                                            vActualQuantity, 
                                            vLayawayPrice, 
                                            vCurrencyId);
                END IF;
            END IF;
            -- end flash sales update
            -- department sales
            sp_ins_upd_merchlvl1_sales(pvOrganizationId, 
                                  pvRetailLocationId, 
                                  vTransDate, 
                                  pvWrkstnId, 
                                  vDepartmentId, 
                                  vQuantity, 
                                  vNetAmount, 
                                  vGrossAmount, 
                                  vCurrencyId);
    END LOOP;
    CLOSE saleCursor;
  EXCEPTION
    WHEN OTHERS THEN CLOSE saleCursor;
  END;
    END IF; 
  
  
    -- update hourly sales
    Sp_Ins_Upd_Hourly_Sales(pvOrganizationId, 
                            pvRetailLocationId, 
                            vTransDate, 
                            pvWrkstnId, 
                            vTransTimeStamp, 
                            vTotquantity, 
                            vTotNetAmt, 
                            vTotGrossAmt, 
                            vTransCount, 
                            vCurrencyId);
  
    COMMIT;
  
    EXCEPTION
        --WHEN NO_DATA_FOUND THEN
        --    vRowCnt := 0;            
        WHEN myerror THEN
            rollback;
        WHEN myreturn THEN
            commit;
        WHEN others THEN
            DBMS_OUTPUT.PUT_LINE('ERROR NUM: ' || to_char(sqlcode));
            DBMS_OUTPUT.PUT_LINE('ERROR TXT: ' || SQLERRM);
            rollback;
--    END;
END sp_flash;
/

GRANT EXECUTE ON sp_flash TO posusers,dbausers;
 
BEGIN
    dbms_output.put_line('     Step Update sp_flash stored procedure end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Upgrade row modification information to the new size starting...');
END;
/
CREATE OR REPLACE PROCEDURE SP_ALTERALLROWMODIFICATIONINFO

IS
    vsql varchar2(32000);
    CURSOR mycur IS
      SELECT TABLE_NAME, COLUMN_NAME
      FROM all_tab_cols 
      WHERE OWNER = upper('$(DbSchema)')
      AND HIDDEN_COLUMN = 'NO'
      AND COLUMN_NAME IN ('CREATE_USER_ID', 'UPDATE_USER_ID')
      AND CHAR_COL_DECL_LENGTH <> 256
      ORDER BY TABLE_NAME, COLUMN_NAME;
BEGIN
    FOR myval IN mycur
    LOOP
      dbms_output.put_line('--- Modifying ' || myval.TABLE_NAME || '.' || myval.COLUMN_NAME);
      vsql := 'ALTER TABLE ' || myval.TABLE_NAME || ' MODIFY ' || myval.COLUMN_NAME || ' VARCHAR2(256)';
      EXECUTE IMMEDIATE vsql;
    END LOOP;
END;
/

BEGIN
    SP_ALTERALLROWMODIFICATIONINFO;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP PROCEDURE SP_ALTERALLROWMODIFICATIONINFO';
END;
/
BEGIN
    dbms_output.put_line('     Step Upgrade row modification information to the new size end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Update string_value from VARCHAR(MAX) to VARCHAR(4000) - Only for MS SQL Server starting...');
END;
/
-- Leave this file here to workaround a known issue for new database maintenance function 
BEGIN
    dbms_output.put_line('     Step Update string_value from VARCHAR(MAX) to VARCHAR(4000) - Only for MS SQL Server end.');
END;
/




PROMPT '***** Body scripts end *****';


-- Keep at end of the script

PROMPT '**************************************';
PROMPT 'Finalizing UPGRADE release 20.0';
PROMPT '**************************************';
/

-- LEAVE BLANK LINE BELOW
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING RPT_TRL_SALE_LINEITM_VIEW');

CREATE OR REPLACE VIEW rpt_trl_sale_lineitm_view
(ORGANIZATION_ID, RTL_LOC_ID, WKSTN_ID, TRANS_SEQ, RTRANS_LINEITM_SEQ, BUSINESS_DATE, BEGIN_DATETIME, END_DATETIME, TRANS_STATCODE, TRANS_TYPCODE, SESSION_ID, OPERATOR_PARTY_ID, CUST_PARTY_ID, ITEM_ID, DEPARTMENT_ID, QUANTITY, UNIT_PRICE, EXTENDED_AMT, VAT_AMT, RETURN_FLAG, NET_AMT, GROSS_AMT, SERIAL_NBR, SALE_LINEITM_TYPCODE, TAX_GROUP_ID, ORIGINAL_RTL_LOC_ID, ORIGINAL_WKSTN_ID, ORIGINAL_BUSINESS_DATE, ORIGINAL_TRANS_SEQ, ORIGINAL_RTRANS_LINEITM_SEQ, RETURN_REASCODE, RETURN_COMMENT, RETURN_TYPCODE, VOID_FLAG, VOID_LINEITM_REASCODE, BASE_EXTENDED_PRICE, RPT_BASE_UNIT_PRICE, EXCLUDE_FROM_NET_SALES_FLAG) AS
SELECT 
TRN.organization_id,
TRN.rtl_loc_id ,
TRN.wkstn_id ,
TRN.trans_seq ,
TSL.rtrans_lineitm_seq ,
TRN.business_date,
TRN.begin_datetime,
TRN.end_datetime,
TRN.trans_statcode,
TRN.trans_typcode,
TRN.session_id,
TRN.operator_party_id,
TRT.cust_party_id,
TSL.item_id,
TSL.merch_level_1,
TSL.quantity,
TSL.unit_price,
TSL.extended_amt,
TSL.vat_amt,
TSL.return_flag,
TSL.net_amt,
TSL.gross_amt,
TSL.serial_nbr,
TSL.sale_lineitm_typcode,
TSL.tax_group_id,
TSL.original_rtl_loc_id,
TSL.original_wkstn_id,
TSL.original_business_date,
TSL.original_trans_seq,
TSL.original_rtrans_lineitm_seq,
TSL.return_reascode,
TSL.return_comment,
TSL.return_typcode,
TRL.void_flag,
TRL.void_lineitm_reascode,
TSL.base_extended_price,
TSL.rpt_base_unit_price,
TSL.exclude_from_net_sales_flag
FROM  
trn_trans TRN, 
trl_sale_lineitm TSL, 
trl_rtrans_lineitm TRL, 
trl_rtrans TRT
WHERE
TRN.organization_id = TSL.organization_id AND
TRN.rtl_loc_id = TSL.rtl_loc_id AND
TRN.wkstn_id = TSL.wkstn_id AND
TRN.business_date = TSL.business_date AND
TRN.trans_seq = TSL.trans_seq AND
TSL.organization_id = TRL.organization_id AND
TSL.rtl_loc_id = TRL.rtl_loc_id AND
TSL.wkstn_id = TRL.wkstn_id AND
TSL.business_date = TRL.business_date AND
TSL.trans_seq = TRL.trans_seq AND
TSL.rtrans_lineitm_seq = TRL.rtrans_lineitm_seq AND
TSL.organization_id = TRT.organization_id AND
TSL.rtl_loc_id = TRT.rtl_loc_id AND
TSL.wkstn_id = TRT.wkstn_id AND
TSL.business_date = TRT.business_date AND
TSL.trans_seq = TRT.trans_seq AND
TRN.trans_statcode ='COMPLETE'
;
/

GRANT SELECT ON rpt_trl_sale_lineitm_view TO posusers,dbausers
;

--
-- VIEW: Test_Connection 
--
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING Test_Connection');

CREATE OR REPLACE VIEW Test_Connection(result)
AS
SELECT 1  from dual;

GRANT SELECT ON Test_Connection TO posusers,dbausers;



EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING RPT_TRL_STOCK_MOVEMENT_VIEW');

CREATE OR REPLACE VIEW RPT_TRL_STOCK_MOVEMENT_VIEW
AS
SELECT organization_id, rtl_loc_id, business_date, item_id, quantity, adjustment_flag
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
      AND (source_bucket_id='ON_HAND' OR dest_bucket_id='ON_HAND')));
/

GRANT SELECT ON RPT_TRL_STOCK_MOVEMENT_VIEW TO posusers,dbausers
;

-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : DATEADD
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-- 
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION DATEADD');

CREATE OR REPLACE FUNCTION DATEADD (as_DateFMT      varchar2,
                                        ai_interval    integer,
                                        as_Date        timestamp) RETURN TIMESTAMP
AUTHID CURRENT_USER 
IS
    ld_NewDate      timestamp;
    id_Date         timestamp;
   
BEGIN
    
    id_Date := as_Date;
   
    CASE UPPER(as_DateFMT)
        WHEN 'DAY' THEN
            ld_NewDate := id_Date + ai_interval;
        WHEN 'MONTH' THEN
            ld_NewDate := ADD_MONTHS(id_Date, ai_interval);
        WHEN 'YEAR' THEN
            ld_NewDate := ADD_MONTHS(id_Date, (ai_interval * 12));
        else
            ld_NewDate := NULL;
    END CASE;
    
    RETURN ld_NewDate;
END DATEADD;
/

GRANT EXECUTE ON DATEADD TO posusers,dbausers;
 
-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : datepart
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-- 
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION DATEPART');

CREATE OR REPLACE FUNCTION datepart (as_DateFMT     varchar2,
                                        ad_Date         timestamp) RETURN INTEGER
AUTHID CURRENT_USER 
IS
    li_DatePart     integer;
    
BEGIN
    
    
    CASE UPPER(as_DateFMT)
        WHEN 'DD' THEN
            li_DatePart := to_number(to_char(ad_Date, 'DD'));
        WHEN 'DW' THEN
            li_DatePart := to_number(to_char(ad_Date, 'D'));
        WHEN 'DY' THEN
            li_DatePart := to_number(to_char(ad_Date, 'DDD'));
        else
            li_DatePart := NULL;
    END CASE;
    
    RETURN li_DatePart;
END datepart;
/

GRANT EXECUTE ON datepart TO posusers,dbausers;
 
-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : DAY
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-- 
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION DAY');

CREATE OR REPLACE FUNCTION DAY
 RETURN varchar2
AUTHID CURRENT_USER 
IS
BEGIN
    RETURN 'DAY';
END DAY;
/

GRANT EXECUTE ON DAY TO posusers,dbausers;
 
-- 
-- FUNCTION: fn_getsessionid 
--
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION FN_GETSESSIONID');

CREATE OR REPLACE FUNCTION FN_GETSESSIONID (orgId NUMBER, rtlLocId NUMBER, wkstnId NUMBER) RETURN NUMBER 
AUTHID CURRENT_USER 
IS
  v_sessionId NUMBER(10,0);
BEGIN
  SELECT Max(session_id)
    INTO v_sessionId 
    FROM tsn_session_wkstn 
    WHERE organization_id = orgId AND
          rtl_loc_id = rtlLocId AND
          wkstn_id = wkstnId AND
          attached_flag = '1';
 
  RETURN v_sessionId;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
    WHEN OTHERS THEN RETURN 0;
END fn_getSessionId;
/
GRANT EXECUTE ON fn_getsessionid TO posusers,dbausers;
 
-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : GETDATE
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-- 
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION GETDATE');

CREATE OR REPLACE FUNCTION GETDATE 
 RETURN TIMESTAMP
AUTHID CURRENT_USER 
IS
BEGIN
    RETURN SYSDATE;
END GETDATE;
/

GRANT EXECUTE ON GETDATE TO posusers,dbausers;
 

-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : GETUTCDATE
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-- 
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION GETUTCDATE');

CREATE OR REPLACE FUNCTION GETUTCDATE 
 RETURN TIMESTAMP
AUTHID CURRENT_USER 
IS
BEGIN
    RETURN SYS_EXTRACT_UTC(SYSTIMESTAMP);
END GETUTCDATE;
/

GRANT EXECUTE ON GETUTCDATE TO posusers,dbausers;
 

-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : MONTH
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-- 
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION MONTH');

CREATE OR REPLACE FUNCTION MONTH
 RETURN varchar2
AUTHID CURRENT_USER 
IS
BEGIN
    RETURN 'MONTH';
END MONTH;
/

GRANT EXECUTE ON MONTH TO posusers,dbausers;
 
-- 
-- PROCEDURE: SP_INS_UPD_HOURLY_SALES 
--
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE sp_ins_upd_hourly_sales');

CREATE OR REPLACE PROCEDURE     sp_ins_upd_hourly_sales (
argOrganizationId IN NUMBER /*oragnization id*/,
argRtlLocId IN NUMBER /*retail location or store number*/,
argBusinessDate IN DATE /*business date*/,
argWkstnId IN NUMBER /*register*/,
argHour IN TIMESTAMP /*flash sales classification*/,
argQty IN NUMBER /*quantity*/,
argNetAmt IN NUMBER /*net amount*/,
argGrossAmt IN NUMBER /*gross amount*/,
argTransCount IN NUMBER /*transcation count*/,
argCurrencyId IN VARCHAR2
)
AUTHID CURRENT_USER 
IS
vcount int;
BEGIN 
select decode(instr(DBMS_UTILITY.format_call_stack,'SP_FLASH'),0,0,1) into vcount from dual;
 if vcount>0 then
  UPDATE rpt_sales_by_hour
     SET qty = coalesce(qty, 0) + coalesce(argQty, 0),
         trans_count = coalesce(trans_count, 0) + coalesce(argTransCount, 0),
         net_sales = coalesce(net_sales, 0) + coalesce(argNetAmt, 0),
         gross_sales = coalesce(gross_sales, 0) + coalesce(argGrossAmt, 0),
         update_date = SYS_EXTRACT_UTC(SYSTIMESTAMP),
         update_user_id = user
   WHERE organization_id = argOrganizationId
     AND rtl_loc_id = argRtlLocId
     AND wkstn_id = argWkstnId
     AND business_date = argBusinessDate
     AND hour = extract (HOUR FROM argHour);

  IF sql%notfound THEN
    INSERT INTO rpt_sales_by_hour
      (organization_id, rtl_loc_id, wkstn_id, hour, qty, trans_count,
      net_sales, business_date, gross_sales, currency_id, create_date, create_user_id)
    VALUES (argOrganizationId, argRtlLocId, argWkstnId, extract (HOUR FROM argHour), argQty, 
      argTransCount, argNetAmt, argBusinessDate, argGrossAmt, argCurrencyId, SYS_EXTRACT_UTC(SYSTIMESTAMP), user);
  END IF;
 else
  raise_application_error( -20001, 'Cannot be run directly.' );
 end if;
END;
/

GRANT EXECUTE ON SP_INS_UPD_HOURLY_SALES TO posusers,dbausers;


-- 
-- PROCEDURE: SP_INS_UPD_MERCHLVL1_SALES 
--
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE sp_ins_upd_merchlvl1_sales');

CREATE OR REPLACE PROCEDURE     sp_ins_upd_merchlvl1_sales (
argOrganizationId IN NUMBER /*organization id*/,
argRtlLocId IN NUMBER /*retail location or store number*/,
argBusinessDate IN DATE /*business date*/,
argWkstnId IN NUMBER /*register*/,
argDeptId IN VARCHAR2 /*flash sales classification*/,
argQty IN NUMBER /*quantity*/,
argNetAmt IN NUMBER /*net amount*/,
argGrossAmt IN NUMBER /*gross amount*/,
argCurrencyId IN VARCHAR2
)
AUTHID CURRENT_USER 
IS
vcount int;
BEGIN
select decode(instr(DBMS_UTILITY.format_call_stack,'SP_FLASH'),0,0,1) into vcount from dual;
 if vcount>0 then
  UPDATE rpt_merchlvl1_sales
     SET line_count = coalesce(line_count, 0) + argQty,
         line_amt = coalesce(line_amt, 0) + argNetAmt,
         gross_amt = gross_amt + argGrossAmt,
         update_date = SYS_EXTRACT_UTC(SYSTIMESTAMP),
         update_user_id = user
   WHERE organization_id = argOrganizationId
     AND rtl_loc_id = argRtlLocId
     AND wkstn_id = argWkstnId
     AND business_date = argBusinessDate
     AND merch_level_1 = argDeptId;

  IF sql%notfound THEN
    INSERT INTO rpt_merchlvl1_sales (organization_id, rtl_loc_id, wkstn_id, merch_level_1, line_count, 
      line_amt, business_date, gross_amt, currency_id, create_date, create_user_id)
    VALUES (argOrganizationId, argRtlLocId, argWkstnId, argDeptId, argQty, 
      argNetAmt, argBusinessDate, argGrossAmt, argCurrencyId, SYS_EXTRACT_UTC(SYSTIMESTAMP), user);
  END IF;
 else
  raise_application_error( -20001, 'Cannot be run directly.' );
 end if;
END;
/

GRANT EXECUTE ON SP_INS_UPD_MERCHLVL1_SALES TO posusers,dbausers;


-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : SP_REPLACE_ORG_ID
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-- PGH 09/22/10     Added a commit after each table is updated. 
-- BCW 09/18/15     Changed owner to the current schema.
-- BCW 09/24/15     Changed argNewOrgId from varchar2 to number.
-------------------------------------------------------------------------------------------------------------------

EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION sp_replace_org_id');

CREATE OR REPLACE FUNCTION sp_replace_org_id
  (argNewOrgId IN number)
RETURN INTEGER
AUTHID CURRENT_USER 
IS
  v_sqlStmt varchar(500);
  v_tabName varchar(60);
  
  CURSOR rtlcur IS 
    SELECT col.table_name 
      FROM all_tab_columns col, all_tables tab
      WHERE tab.owner = upper('$(DbSchema)') AND 
            col.owner = upper('$(DbSchema)') AND 
            col.table_name = tab.table_name AND 
            col.column_name = 'ORGANIZATION_ID'
      ORDER BY col.table_name;
      
BEGIN

  DBMS_OUTPUT.PUT_LINE ('Starting sp_replace_org_id...');
  
  OPEN rtlcur;
  LOOP
    --DBMS_OUTPUT.PUT_LINE ('Starting Loop');

    FETCH rtlcur INTO v_tabName;
        EXIT WHEN rtlcur%NOTFOUND;
    
    v_sqlStmt := 'update $(DbSchema).'||v_tabName||' set organization_id = '||argNewOrgId;
    dbms_output.put_line (v_sqlstmt);
    
    IF v_sqlStmt IS NOT NULL THEN
      EXECUTE IMMEDIATE v_sqlStmt;
      
    END IF;
    
    COMMIT;
    
  END LOOP;
  CLOSE rtlcur;
  
  DBMS_OUTPUT.PUT_LINE ('Ending sp_replace_org_id...');
  
  RETURN 0;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error:');
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
        DBMS_OUTPUT.PUT_LINE ('Ending sp_replace_org_id...');
        CLOSE rtlcur;
        RETURN -1;
END;
/

GRANT EXECUTE ON SP_REPLACE_ORG_ID TO posusers,dbausers;

 
-------------------------------------------------------------------------------------------------------------
--
-- Procedure         : SP_TRUNCATE_TABLE
-- Description       : truncates data from a table
-- Version           : 16.0
-------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                               --
-------------------------------------------------------------------------------------------------------------
-- WHO              DATE              DESCRIPTION                                                          --
-------------------------------------------------------------------------------------------------------------
-- Nuwan Wijekoon 02/07/2019         Initial Version
-- 
-------------------------------------------------------------------------------------------------------------

EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE SP_TRUNCATE_TABLE');

CREATE OR REPLACE PROCEDURE SP_TRUNCATE_TABLE(argTableName IN VARCHAR2)
AS
vPrepStatement VARCHAR2(4000);
BEGIN
  vPrepStatement := 'TRUNCATE TABLE ' || argTableName;
  EXECUTE IMMEDIATE vPrepStatement;
END;
/

GRANT EXECUTE ON SP_TRUNCATE_TABLE TO posusers;
GRANT EXECUTE ON SP_TRUNCATE_TABLE TO dbausers;
-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : YEAR
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-- 
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION YEAR');

CREATE OR REPLACE FUNCTION YEAR
 RETURN varchar2
AUTHID CURRENT_USER 
IS
BEGIN
    RETURN 'YEAR';
END YEAR;
/

GRANT EXECUTE ON YEAR TO posusers,dbausers;
 
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION fn_NLS_LOWER'); 
CREATE OR REPLACE FUNCTION fn_NLS_LOWER (argString varchar) RETURN VARCHAR 
AUTHID CURRENT_USER 
IS
BEGIN
   
   RETURN NLS_LOWER(argString);
END fn_NLS_LOWER;
/

GRANT EXECUTE ON fn_NLS_LOWER TO posusers,dbausers;
 
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION fn_NLS_UPPER'); 
CREATE OR REPLACE FUNCTION fn_NLS_UPPER (argString varchar) RETURN VARCHAR 
AUTHID CURRENT_USER 
IS
BEGIN
   
   RETURN NLS_UPPER(argString);
END fn_NLS_UPPER;
/

GRANT EXECUTE ON fn_NLS_UPPER TO posusers,dbausers;
 
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION fn_ParseDate'); 
CREATE OR REPLACE FUNCTION fn_ParseDate (argDateString varchar) RETURN DATE 
AUTHID CURRENT_USER 
IS
BEGIN
   
   RETURN to_date(argDateString,'YYYY-MM-DD HH24:MI:SS');
END fn_ParseDate;
/

GRANT EXECUTE ON fn_ParseDate TO posusers,dbausers;

create or replace function
fn_compressedblob2clob(src_blob BLOB) 
return CLOB
is
  dest_clob CLOB;
  raw_blob BLOB;
  dest_offset integer := 1;
  src_offset integer := 1;
  csid integer := NLS_CHARSET_ID('al32utf8');
  lang_context integer := 0;
  warning integer := 0;
begin
  raw_blob := UTL_COMPRESS.LZ_UNCOMPRESS(src_blob);
  DBMS_LOB.CreateTemporary(lob_loc=>dest_clob, CACHE=>true);
  DBMS_LOB.ConvertToClob(dest_clob, raw_blob, length(raw_blob), dest_offset, src_offset, csid, lang_context, warning);
  DBMS_LOB.FreeTemporary(raw_blob);
  return(dest_clob);
end fn_compressedblob2clob;
/
GRANT EXECUTE ON fn_compressedblob2clob TO posusers,dbausers;
create or replace type split_tbl as table of number(10,0);
 /

EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION fn_integerListToTable'); 
 create or replace function fn_integerListToTable
 (
     p_list varchar2,
     p_del varchar2 := ','
 ) return split_tbl pipelined
AUTHID CURRENT_USER 
 is
     l_idx    pls_integer;
     l_list    varchar2(32767):= p_list;
 --AA
--     l_value    varchar2(32767);
     
  begin
     loop
         l_idx :=instr(l_list,p_del);
         if l_idx > 0 then
             pipe row(substr(l_list,1,l_idx-1));
             l_list:= substr(l_list,l_idx+length(p_del));

         else
             pipe row(l_list);
             exit;
         end if;
     end loop;
     return;
 end fn_integerListToTable;
 /

GRANT EXECUTE ON split_tbl TO posusers,dbausers;
GRANT EXECUTE ON fn_integerListToTable TO posusers,dbausers;

 
create or replace type var_tbl as table of varchar2(4000 char);
 /

EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION fn_nodesInHierarchy'); 
CREATE OR REPLACE function fn_nodesInHierarchy 
(
    v_orgId number, 
    v_orgCode VARCHAR2, 
    v_orgValue VARCHAR2
) return  var_tbl
AUTHID CURRENT_USER 
 as
 testtab var_tbl := var_tbl();
BEGIN
FOR rc IN
(select org_code || ':' || org_value as node from
    (SELECT org_code, org_value
    FROM loc_org_hierarchy
    WHERE organization_id = v_orgId
    START WITH org_code =v_orgCode AND org_value = v_orgValue
    CONNECT BY PRIOR parent_code = org_code AND PRIOR parent_value = org_value))
  LOOP
    testtab.EXTEND;
    testtab (testtab.COUNT) := rc.node;
  END LOOP;
  return testtab;
  END fn_nodesInHierarchy;
  /

GRANT EXECUTE ON var_tbl TO posusers,dbausers;
GRANT EXECUTE ON fn_nodesInHierarchy TO posusers,dbausers;

 
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION fn_storesInHierarchy'); 
CREATE OR REPLACE function fn_storesInHierarchy 
(
    v_orgId number, 
    v_orgCode VARCHAR2, 
    v_orgValue VARCHAR2
) return  split_tbl
AUTHID CURRENT_USER 
 as
 testtab split_tbl := split_tbl();
BEGIN
FOR rc IN
(select cast(org_value as number) org_value from
    (SELECT organization_id, org_code, org_value
    FROM loc_org_hierarchy
    WHERE organization_id = v_orgId
START WITH org_code =v_orgCode AND org_value = v_orgValue
CONNECT BY PRIOR org_code = parent_code AND PRIOR org_value = parent_value)
  WHERE org_code = 'STORE')
  LOOP
    testtab.EXTEND;
    testtab (testtab.COUNT) := rc.org_value;
  END LOOP;
  return testtab;
  END fn_storesInHierarchy;
  /

GRANT EXECUTE ON fn_storesInHierarchy TO posusers,dbausers;

 
/* 
 * PROCEDURE: sp_conv_to_unicode 
 */

-- =============================================
-- Author:        Brett C. White
-- Create date: 2/14/12
-- Description:    Converts all char2, varchar2, and clob fields into nchar2, nvarchar2, and nclob.
-- =============================================
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE sp_conv_to_unicode');
CREATE OR REPLACE PROCEDURE sp_conv_to_unicode 
AUTHID CURRENT_USER 
IS
    v_csql varchar2(255);
    v_ttable varchar2(40);
    v_tcolumn varchar2(40);
    v_old varchar2(40);
BEGIN

  DECLARE CURSOR column_list is
    select 'ALTER TABLE ' || COL.table_name || ' MODIFY "' || column_name || '" N' || data_type
    || '(' || cast(data_length as varchar2(4)) || ')'
    from all_tab_columns COL
    inner join all_tables t on t.TABLE_NAME=COL.TABLE_NAME
    where DATA_TYPE in ('VARCHAR2','CHAR2')
  order by COL.table_name;

  BEGIN
  open column_list;
  LOOP
    FETCH column_list INTO v_csql;
    EXIT WHEN column_list%NOTFOUND;

        BEGIN
        EXECUTE IMMEDIATE v_csql;
 --       dbms_output.put_line(v_csql);
            EXCEPTION
            WHEN OTHERS THEN
            dbms_output.put_line(v_csql || ' failed');
        END;
  END LOOP;
  close column_list;
    END;

    DECLARE CURSOR text_list is
   select COL.table_name,col.COLUMN_NAME
  from all_tab_columns COL
  inner join all_tables t on t.TABLE_NAME=COL.TABLE_NAME
  where DATA_TYPE in ('CLOB')
  order by COL.table_name;

  begin
  open text_list;
    LOOP
      FETCH text_list INTO v_ttable,v_tcolumn;
        EXIT WHEN text_list%NOTFOUND;
    
    v_old := 'old_column';
  
    dbms_output.put_line('ALTER TABLE ' || v_ttable || ' RENAME COLUMN ' || v_tcolumn || ' TO ' || v_old);
    EXECUTE IMMEDIATE 'ALTER TABLE ' || v_ttable || ' RENAME COLUMN ' || v_tcolumn || ' TO ' || v_old;
    
    dbms_output.put_line('ALTER TABLE ' || v_ttable || ' ADD ' || v_tcolumn || ' NCLOB');
    EXECUTE IMMEDIATE 'ALTER TABLE ' || v_ttable || ' ADD ' || v_tcolumn || ' NCLOB';
    
    dbms_output.put_line('update ' || v_ttable || ' SET ' || v_tcolumn || ' = ' || v_old);
    EXECUTE IMMEDIATE 'update ' || v_ttable || ' SET ' || v_tcolumn || ' = ' || v_old;

    dbms_output.put_line('ALTER TABLE ' || v_ttable || ' DROP COLUMN ' || v_old);
    EXECUTE IMMEDIATE 'ALTER TABLE ' || v_ttable || ' DROP COLUMN ' || v_old;
  end LOOP;
  close text_list;
  EXCEPTION
    WHEN OTHERS THEN CLOSE text_list;
  end;
  dbms_output.put_line('PLEASE UPDATE THE STORED PROCEDURES MANUALLY!!!');
END;
/

GRANT EXECUTE ON sp_conv_to_unicode TO dbausers;

 
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE sp_fifo_detail');

CREATE OR REPLACE PROCEDURE sp_fifo_detail
   (merch_level_1_param    in varchar2, 
    merch_level_2_param    in varchar2, 
    merch_level_3_param    in varchar2, 
    merch_level_4_param    in varchar2,
    item_id_param          in varchar2,
    style_id_param         in varchar2,
    rtl_loc_id_param       in varchar2, 
    organization_id_param  in int,
    user_name_param        in varchar2,
    stock_val_date_param   in DATE)
AUTHID CURRENT_USER 
 IS

            organization_id         int;
            organization_id_a       int;
            item_id                 VARCHAR2(60);
            item_id_a               VARCHAR2(60);
            description             VARCHAR2(254);
            description_a           VARCHAR2(254);
            style_id                VARCHAR2(60);
            style_id_a              VARCHAR2(254);
            style_desc              VARCHAR2(254);
            style_desc_a            VARCHAR2(254);
            rtl_loc_id              int;
            rtl_loc_id_a            int;
            store_name              VARCHAR2(254);
            store_name_a            VARCHAR2(254);
            invctl_document_id      VARCHAR2(30);
            invctl_document_id_a    VARCHAR2(30);
            invctl_document_nbr     int;
            invctl_document_nbr_a   int;
            create_date_timestamp   DATE;
            create_date_timestamp_a DATE;
            unit_count              DECIMAL(14,4);
            unit_count_a            DECIMAL(14,4);
            current_unit_count      DECIMAL(14,4);
            unit_cost               DECIMAL(17,6);
            unit_cost_a             DECIMAL(17,6);
            unitCount               DECIMAL(14,4);
            unitCount_a             DECIMAL(14,4);

            vcomment                VARCHAR2(254);

            current_item_id         VARCHAR2(60);
            current_rtl_loc_id      int;
            pending_unitCount       DECIMAL(14,4);
            
            vinsert                 number(4,0);
            
  
  CURSOR tableCur IS 
      SELECT MAX(sla.organization_id), MAX(COALESCE(sla.unitcount,0)) + MAX(COALESCE(ts.quantity, 0)) AS quantity, 
                  sla.item_id, MAX(i.description), MAX(style.item_id), MAX(style.description), 
              l.rtl_loc_id, MAX(l.store_name), doc.invctl_document_id, doc.invctl_document_line_nbr,
                  doc.create_date, MAX(COALESCE(doc.unit_count,0)), MAX(COALESCE(doc.unit_cost,0))
      FROM loc_rtl_loc l, (select column_value from table(fn_integerListToTable(rtl_loc_id_param))) fn, 
      (SELECT organization_id, item_id, COALESCE(SUM(unitcount),0) AS unitcount 
        FROM inv_stock_ledger_acct, (select column_value from table(fn_integerListToTable(rtl_loc_id_param))) fn
        WHERE fn.column_value = rtl_loc_id 
                AND bucket_id = 'ON_HAND'
        GROUP BY organization_id, item_id) sla
        LEFT OUTER JOIN
            (SELECT itm_mov.organization_id, itm_mov.rtl_loc_id, itm_mov.item_id, 
                  SUM(COALESCE(quantity,0) * CASE WHEN adjustment_flag = 1 THEN 1 ELSE -1 END) AS quantity
           FROM rpt_trl_stock_movement_view itm_mov
           WHERE to_char(business_date) > to_char(stock_val_date_param)
           GROUP BY itm_mov.organization_id, itm_mov.rtl_loc_id, itm_mov.item_id) ts
           ON sla.organization_id = ts.organization_id
              AND sla.item_id = ts.item_id
            LEFT OUTER JOIN (
                  SELECT id.organization_id, idl.inventory_item_id, idl.rtl_loc_id , id.invctl_document_id, 
                        idl.invctl_document_line_nbr, idl.create_date, COALESCE(idl.unit_count,0) AS unit_count, COALESCE(idl.unit_cost,0) AS unit_cost
                  FROM inv_invctl_document_lineitm idl, (select column_value from table(fn_integerListToTable(rtl_loc_id_param))) fn, inv_invctl_document id
                  WHERE idl.organization_id = id.organization_id AND idl.rtl_loc_id = id.rtl_loc_id AND 
                        idl.document_typcode = id.document_typcode AND idl.invctl_document_id = id.invctl_document_id AND 
                        idl.unit_count IS NOT NULL AND idl.unit_cost IS NOT NULL AND idl.create_date IS NOT NULL AND
                        id.document_subtypcode = 'ASN'
                        AND id.status_code IN ('CLOSED', 'OPEN', 'IN_PROCESS')
                        AND to_date(idl.create_date,'MM/DD/YYYY') <= to_date(stock_val_date_param,'MM/DD/YYYY')
                        AND fn.column_value = idl.rtl_loc_id 
                        AND idl.organization_id = organization_id_param
            ) doc
            ON sla.organization_id = doc.organization_id AND 
               sla.item_id = doc.inventory_item_id
            INNER JOIN itm_item i
            ON sla.item_id = i.item_id AND
               sla.organization_id = i.organization_id
            LEFT OUTER JOIN itm_item style
            ON i.parent_item_id = style.item_id AND
               i.organization_id = style.organization_id
      WHERE merch_level_1_param in (i.merch_level_1,'%') AND merch_level_2_param in (i.merch_level_2,'%') AND 
            merch_level_3_param IN (i.merch_level_3,'%') AND merch_level_4_param IN (i.merch_level_4,'%') AND
            item_id_param IN (i.item_id,'%') AND style_id_param IN (i.parent_item_id,'%') AND
            sla.organization_id = l.organization_id AND 
            fn.column_value = l.rtl_loc_id AND 
            doc.rtl_loc_id = l.rtl_loc_id AND 
            COALESCE(sla.unitcount,0) + COALESCE(ts.quantity, 0) > 0
      GROUP BY style.item_id, sla.item_id, doc.invctl_document_id, l.rtl_loc_id, doc.invctl_document_line_nbr, doc.create_date
      ORDER BY sla.item_id,doc.create_date DESC;

BEGIN      
  EXECUTE IMMEDIATE 'DELETE FROM rpt_fifo_detail WHERE user_name = ''' || user_name_param || '''';
    vcomment := '';
    current_item_id := '';
    pending_unitCount := 0;
    vinsert := 0;
    OPEN tableCur;
    FETCH tableCur INTO organization_id, unitcount, item_id, description, style_id, style_desc, rtl_loc_id, store_name, invctl_document_id, invctl_document_nbr, create_date_timestamp, unit_count, unit_cost;
    LOOP
    EXIT WHEN tableCur%NOTFOUND;
        IF current_item_id <> item_id THEN
            current_item_id := item_id;
            pending_unitCount := unitcount;
        END IF;
     IF pending_unitCount > 0 Then
              IF pending_unitCount < unit_count Then
                  current_unit_count := pending_unitCount;
                  pending_unitCount := 0;
              ELSE
                  current_unit_count := unit_count ;
                  pending_unitCount := pending_unitCount - unit_count;
              END IF;
              vinsert := 1;
        ELSIF pending_unitCount < 0 Then
                 vinsert := 1;
        ELSE 
            vinsert := 0;
        END IF;

              organization_id_a := organization_id;
              unitcount_a := unitcount;
              item_id_a := item_id;
              description_a := description;
              style_id_a := style_id;
              style_desc_a := style_desc;
              rtl_loc_id_a := rtl_loc_id;
              store_name_a := store_name;
              invctl_document_id_a := invctl_document_id;
              invctl_document_nbr_a := invctl_document_nbr;
              create_date_timestamp_a := create_date_timestamp;
              unit_count_a := unit_count;
              unit_cost_a := unit_cost;

        FETCH tableCur INTO organization_id, unitcount, item_id, description, style_id, style_desc, rtl_loc_id, store_name, invctl_document_id, invctl_document_nbr, create_date_timestamp, unit_count, unit_cost;
     IF (pending_unitCount >= 0 OR tableCur%NOTFOUND  OR item_id <> item_id_a) AND vinsert = 1 then
             vcomment := '';
              IF (item_id_a <> item_id AND pending_unitCount > 0) OR tableCur%NOTFOUND then
                  IF pending_unitCount > 0 Then
                        vcomment := '_rptLackDocStockVal';
                  END IF;
              END IF;

      IF pending_unitCount < 0 Then
         invctl_document_id_a := '_rptNoAvailDocStockVal';
         unit_cost_a := null;
         unit_count_a := null;
         current_unit_count := null;
         create_date_timestamp_a := null;
         vcomment := '_rptLackDocStockVal';
      END IF;

              INSERT INTO rpt_fifo_detail (organization_id, rtl_loc_id, item_id, invctl_doc_id, user_name, invctl_doc_create_date, description, store_name, 
                     unit_count, current_unit_count, unit_cost, unit_count_a, current_cost, "comment", pending_count, style_id, style_desc, invctl_doc_line_nbr)
              VALUES(organization_id_a, rtl_loc_id_a, item_id_a, invctl_document_id_a, user_name_param, create_date_timestamp_a, description_a, store_name_a,
           unit_count_a, current_unit_count, unit_cost_a, unitcount_a, current_unit_count * unit_cost_a, vcomment, pending_unitCount, style_id_a, style_desc_a, invctl_document_nbr_a);
           END IF;
    END LOOP;
    CLOSE tableCur;
  EXCEPTION
    WHEN OTHERS THEN CLOSE tableCur;
END sp_fifo_detail;
/


GRANT EXECUTE ON sp_fifo_detail TO posusers,dbausers;
-- 
-- PROCEDURE: sp_fifo_summary 
--
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING procedure SP_FIFO_SUMMARY');

CREATE OR REPLACE PROCEDURE sp_fifo_summary
   (merch_level_1_param     in varchar2, 
    merch_level_2_param     in varchar2, 
    merch_level_3_param     in varchar2, 
    merch_level_4_param     in varchar2,
    item_id_param           in varchar2,
    style_id_param          in varchar2,
    rtl_loc_id_param        in varchar2, 
    organization_id_param   in int,
    user_name_param         in varchar2,
    stock_val_date_param    in DATE)
AUTHID CURRENT_USER 
 IS

            organization_id         int;
            item_id                 VARCHAR2(60);
            description             VARCHAR2(254);
            style_id                VARCHAR2(60);
            style_desc              VARCHAR2(254);
            rtl_loc_id              int;
            store_name              VARCHAR2(254);
            unit_count              DECIMAL(14,4);
            unit_cost               DECIMAL(17,6);
            vcomment                VARCHAR2(254);
  
  CURSOR tableCur IS 
      SELECT MAX(sla.organization_id), MAX(COALESCE(sla.unitcount,0)) + MAX(COALESCE(ts.quantity, 0)) AS quantity, sla.item_id, MAX(i.description), style.item_id, MAX(style.description), sla.rtl_loc_id, MAX(l.store_name),
      MAX(COALESCE(fifo_detail.unit_cost,0)), MAX(fifo_detail."comment")
      FROM loc_rtl_loc l, (select column_value from table(fn_integerListToTable(rtl_loc_id_param))) fn, inv_stock_ledger_acct sla
            LEFT OUTER JOIN
            (SELECT itm_mov.organization_id, itm_mov.rtl_loc_id, itm_mov.item_id, 
                    SUM(COALESCE(quantity,0) * CASE WHEN adjustment_flag = 1 THEN 1 ELSE -1 END) AS quantity
             FROM rpt_trl_stock_movement_view itm_mov
             WHERE to_char(business_date) > to_char(stock_val_date_param) 
             GROUP BY itm_mov.organization_id, itm_mov.rtl_loc_id, itm_mov.item_id) ts
             ON sla.organization_id = ts.organization_id
                AND sla.rtl_loc_id = ts.rtl_loc_id
                AND sla.item_id = ts.item_id
            LEFT OUTER JOIN (
                  SELECT organization_id, item_id, SUM(current_cost)/SUM(current_unit_count) as unit_cost, MAX("comment") as "comment"
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
             WHERE merch_level_1_param in (i.merch_level_1,'%') AND merch_level_2_param in (i.merch_level_2,'%') AND 
                 merch_level_3_param IN (i.merch_level_3,'%') AND merch_level_4_param IN (i.merch_level_4,'%') AND
                 item_id_param IN (i.item_id,'%') AND style_id_param IN (i.parent_item_id,'%') AND
            fn.column_value = sla.rtl_loc_id AND
            sla.organization_id = l.organization_id AND 
            sla.rtl_loc_id = l.rtl_loc_id AND
            sla.bucket_id = 'ON_HAND' AND
            COALESCE(sla.unitcount,0) + COALESCE(ts.quantity, 0) <> 0
      GROUP BY sla.rtl_loc_id, style.item_id, sla.item_id
      ORDER BY sla.rtl_loc_id, sla.item_id DESC;

BEGIN      
    sp_fifo_detail (merch_level_1_param, merch_level_2_param, merch_level_3_param, merch_level_4_param, item_id_param, style_id_param, rtl_loc_id_param, organization_id_param, user_name_param, stock_val_date_param);
    EXECUTE IMMEDIATE 'DELETE FROM rpt_fifo WHERE user_name = ''' || user_name_param || '''';
    OPEN tableCur;
    LOOP
    FETCH tableCur INTO organization_id, unit_count, item_id, description, style_id, style_desc, rtl_loc_id, store_name, unit_cost, vcomment;
    EXIT WHEN tableCur%NOTFOUND;
      IF unit_cost=0 then
        unit_count :=0;
      END IF;
       INSERT INTO rpt_fifo (organization_id, rtl_loc_id, store_name, item_id, user_name, description,  
           style_id, style_desc, unit_count, unit_cost, "comment")
       VALUES(organization_id, rtl_loc_id, store_name, item_id, user_name_param, description, 
           style_id, style_desc, unit_count, unit_cost, vcomment); 
    END LOOP;
    CLOSE tableCur;
    EXCEPTION
        WHEN OTHERS THEN CLOSE tableCur;
END sp_fifo_summary;
/

GRANT EXECUTE ON sp_fifo_summary TO posusers,dbausers;
 
 

-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : sp_ins_upd_flash_sales
-- Description       : Loads data into the Report tables which are then used by the flash reports.
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....      Initial Version
-- 
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE sp_ins_upd_flash_sales');

CREATE OR REPLACE PROCEDURE sp_ins_upd_flash_sales (
argOrganizationId   IN NUMBER   /*organization id*/,
argRtlLocId         IN NUMBER   /*retail location or store number*/,
argBusinessDate     IN DATE     /*business date*/,
argWkstnId          IN NUMBER   /*register*/,
argLineEnum         IN VARCHAR2 /*flash sales classification*/,
argQty              IN NUMBER   /*quantity*/,
argNetAmt           IN NUMBER   /*net amount*/,
argCurrencyId       IN VARCHAR2
)
AUTHID CURRENT_USER 
IS
vcount int;
BEGIN
select decode(instr(DBMS_UTILITY.format_call_stack,'SP_FLASH'),0,0,1) into vcount from dual;
 if vcount>0 then
  UPDATE rpt_flash_sales
     SET line_count = COALESCE(line_count, 0) + argQty,
         line_amt = COALESCE(line_amt, 0) + argNetAmt,
         update_date = SYS_EXTRACT_UTC(SYSTIMESTAMP),
         update_user_id = USER
   WHERE organization_id = argOrganizationId
     AND rtl_loc_id = argRtlLocId
     AND wkstn_id = argWkstnId
     AND business_date = argBusinessDate
     AND line_enum = argLineEnum;

  IF SQL%NOTFOUND THEN
    INSERT INTO rpt_flash_sales (organization_id,
                                 rtl_loc_id,
                                 wkstn_id, 
                                 line_enum, 
                                 line_count,
                                 line_amt, 
                                 foreign_amt, 
                                 currency_id, 
                                 business_date, 
                                 create_date, 
                                 create_user_id)
    VALUES (argOrganizationId, 
            argRtlLocId, 
            argWkstnId, 
            argLineEnum, 
            argQty, 
            argNetAmt, 
            0, 
            argCurrencyId, 
            argBusinessDate, 
            SYS_EXTRACT_UTC(SYSTIMESTAMP), 
            USER);
  END IF;
 else
  raise_application_error( -20001, 'Cannot be run directly.' );
 end if;
END;
/

GRANT EXECUTE ON sp_ins_upd_flash_sales TO posusers,dbausers;


EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION sp_next_sequence_value');
CREATE OR REPLACE FUNCTION sp_next_sequence_value (
  argOrganizationId      number,
  argRetailLocationId    number,
  argWorkstationId       number,
  argSequenceId          varchar2,
  argSequenceMode        varchar2,
  argIncrement           number,
  argIncrementalValue    number,
  argMaximumValue        number,
  argInitialValue        number)
return number
AUTHID CURRENT_USER 
IS
    vCurrentSequence number(10,0);
    vNextSequence number(10,0);
  BEGIN 
  LOCK TABLE com_sequence IN EXCLUSIVE MODE;
    
    SELECT t.sequence_nbr INTO vCurrentSequence
        FROM com_sequence t 
        WHERE t.organization_id = argOrganizationId
        AND t.rtl_loc_id = argRetailLocationId
        AND t.wkstn_id = argWorkstationId
        AND t.sequence_id = argSequenceId
        AND t.sequence_mode = argSequenceMode;
        
      vNextSequence := vCurrentSequence + argIncrementalValue;
      IF(vNextSequence > argMaximumValue)  then
        vNextSequence := argInitialValue + argIncrementalValue;
      end if;  
        -- handle initial value -1
      IF (argIncrement = '1')  then
        UPDATE com_sequence
        SET sequence_nbr = vNextSequence
        WHERE organization_id = argOrganizationId
        AND rtl_loc_id = argRetailLocationId
        AND wkstn_id = argWorkstationId
        AND sequence_id = argSequenceId
        AND sequence_mode = argSequenceMode;
      END if;
      return vNextSequence;
    exception
      when NO_DATA_FOUND 
      then 
      begin
      IF (argIncrement = '1')  then
        vNextSequence := argInitialValue + argIncrementalValue;
      ELSE
        vNextSequence := argInitialValue;
      END if;   
      INSERT INTO com_sequence (organization_id, rtl_loc_id, wkstn_id, sequence_id, sequence_mode, sequence_nbr) 
      VALUES (argOrganizationId, argRetailLocationId, argWorkstationId, argSequenceId, argSequenceMode, vNextSequence);
      return vNextSequence;
      end;
END sp_next_sequence_value;
/

GRANT EXECUTE ON sp_next_sequence_value TO posusers,dbausers;


EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE sp_set_sequence_value');
CREATE OR REPLACE PROCEDURE sp_set_sequence_value(
  argOrganizationId      number,
  argRetailLocationId    number,
  argWorkstationId       number,
  argSequenceId          varchar2,
  argSequenceMode        varchar2,
  argSequenceValue       number)
AUTHID CURRENT_USER 
IS
BEGIN
  LOCK TABLE com_sequence IN EXCLUSIVE MODE;
  
    UPDATE com_sequence 
        SET sequence_nbr = argSequenceValue
        WHERE organization_id = argOrganizationId
        AND rtl_loc_id = argRetailLocationId
        AND wkstn_id = argWorkstationId
        AND sequence_id = argSequenceId    
        And sequence_mode = argSequenceMode;
END sp_set_sequence_value;
/

GRANT EXECUTE ON sp_set_sequence_value TO posusers,dbausers;

EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE sp_tables_inmemory');
CREATE OR REPLACE PROCEDURE sp_tables_inmemory 
    (venable varchar2) -- Yes = enables in-memory in all tables.  No = disables in-memory in all tables.
AUTHID CURRENT_USER 
AS
vcount int;
CURSOR mycur IS 
  select table_name,owner from all_tables
  where owner=upper('$(DbSchema)')
  order by table_name asc;

BEGIN
    FOR myval IN mycur
    LOOP
    IF substr(upper(venable),1,1) in ('1','T','Y','E') or upper(venable)='ON' THEN
      EXECUTE IMMEDIATE 'alter table ' || myval.owner || '.' || myval.table_name || ' inmemory MEMCOMPRESS FOR QUERY HIGH';
    ELSE
      EXECUTE IMMEDIATE 'alter table ' || myval.owner || '.' || myval.table_name || ' no inmemory';
    END IF;
    END LOOP;
    IF substr(upper(venable),1,1) in ('1','T','Y','E') or upper(venable)='ON' THEN
            dbms_output.put_line('In-Memory option has been enabled on all tables.
Please run the following line to enable the In-Memory option on all new tables.
ALTER TABLESPACE &dbDataTableSpace. DEFAULT INMEMORY MEMCOMPRESS FOR QUERY HIGH;');
    ELSE
        dbms_output.put_line('In-Memory option has been disabled on all tables.
Please run the following line to disable the In-Memory option on all new tables.
ALTER TABLESPACE &dbDataTableSpace. DEFAULT NO INMEMORY;');
    END IF;
END;
/

GRANT EXECUTE ON sp_tables_inmemory TO dbausers;

-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : SP_WRITE_DBMS_OUTPUT_TO_FILE
-- Description       : 
-- Version           : 19.0
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... .....         Initial Version
-------------------------------------------------------------------------------------------------------------------

EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE sp_write_dbms_output_to_file');

create or replace PROCEDURE sp_write_dbms_output_to_file(logname varchar) AS
   l_line VARCHAR2(255);
   l_done NUMBER;
   l_file utl_file.file_type;
   ext NUMBER;
BEGIN
   ext := INSTR(logname,'.', 1);
   if ext = 0 then
    l_file := utl_file.fopen('EXP_DIR', logname || '.log', 'A');
   else
    l_file := utl_file.fopen('EXP_DIR', logname, 'A');
   end if;
   LOOP
      dbms_output.get_line(l_line, l_done);
      EXIT WHEN l_done = 1;
      utl_file.put_line(l_file, substr(to_char(systimestamp,'YYYY-MM-DD HH24:MI:SS,FF'),1,23) || ' ' || l_line);
   END LOOP;
   utl_file.fflush(l_file);
   utl_file.fclose(l_file);
END sp_write_dbms_output_to_file;
/

GRANT EXECUTE ON sp_write_dbms_output_to_file TO posusers,dbausers;

 
-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : SP_EXPORT_DATABASE
-- Description       : This procedure is called on the local database to export all of the XStore objects.
-- Version           : 19.0
--
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... ..........         Initial Version
-- PGH 11/04/10     Converted to a function, so a return code can be sent back to Data Server.
-- BCW 09/11/15     Added reuse file to ADD_FILE.  This ability was added in 11g.
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION SP_EXPORT_DATABASE');

CREATE OR REPLACE FUNCTION SP_EXPORT_DATABASE 
(  
    argExportPath          varchar2,                   -- Import Directory Name
    argBackupDataFile      varchar2,                   -- Dump File Name
    argOutputFile          varchar2,                   -- Log File Name
    argSourceOwner         varchar2                    -- Source Owner User Name
)
RETURN INTEGER
IS

-- Varaibles for the Datapump section
h1                      NUMBER;         -- Data Pump job handle
job_state               VARCHAR2(30);   -- To keep track of job state
ind                     NUMBER;         -- loop index
le                      ku$_LogEntry;   -- WIP and error messages
js                      ku$_JobStatus;  -- job status from get_status
jd                      ku$_JobDesc;    -- job description from get_status
sts                     ku$_Status;     -- status object returned by
rowcnt                  NUMBER; 

BEGIN
    --Enable Server Output
    DBMS_OUTPUT.ENABLE (500000);
    DBMS_OUTPUT.PUT_LINE (user || ' is starting SP_EXPORT_DATABASE.');
    sp_write_dbms_output_to_file('SP_EXPORT_DATABASE');

    --
    -- Checks to see if the Data Pump work table exists and drops it.
    --
    select count(*)
        into rowcnt
        from all_tables
        where table_name = 'XSTORE_EXPORT';
          
    IF rowcnt > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE XSTORE_EXPORT';
    END IF;

    --
    -- Create a schema level export for the DTV objects
    --
    h1 := DBMS_DATAPUMP.OPEN('EXPORT', 'SCHEMA', NULL, 'XSTORE_EXPORT', 'LATEST');
    DBMS_DATAPUMP.METADATA_FILTER(h1, 'SCHEMA_EXPR', 'IN ('''|| argSourceOwner ||''')');

    DBMS_DATAPUMP.METADATA_FILTER(h1,'NAME_EXPR','!=''SP_IMPORT_DATABASE''', 'FUNCTION');
    DBMS_DATAPUMP.METADATA_FILTER(h1,'NAME_EXPR','!=''SP_WRITE_DBMS_OUTPUT_TO_FILE''', 'PROCEDURE');
    DBMS_DATAPUMP.METADATA_FILTER(h1, 'EXCLUDE_PATH_EXPR', 'IN (''STATISTICS'')');
    DBMS_DATAPUMP.SET_PARAMETER(h1, 'METRICS', 1);

    --
    -- Adds the data and log files
    --
    DBMS_DATAPUMP.ADD_FILE(h1, argBackupDataFile, argExportPath, NULL, DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE, 1);
    DBMS_DATAPUMP.ADD_FILE(h1, argOutputFile, argExportPath, NULL, DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE, 1);
    
    --
    -- Start the job. An exception will be generated if something is not set up
    -- properly.
    --
    DBMS_DATAPUMP.START_JOB(h1);

    --
    -- Waits until the job as completed
    --
    DBMS_DATAPUMP.WAIT_FOR_JOB (h1, job_state);

    dbms_output.put_line('Job has completed');
    dbms_output.put_line('Final job state = ' || job_state);

    dbms_datapump.detach(h1);
    
    DBMS_OUTPUT.PUT_LINE ('Ending SP_EXPORT_DATABASE...');
    sp_write_dbms_output_to_file('SP_EXPORT_DATABASE');
    DBMS_OUTPUT.DISABLE ();
    RETURN 0;
    
EXCEPTION
    WHEN OTHERS THEN
    BEGIN
        dbms_datapump.get_status(h1, 
                                    dbms_datapump.ku$_status_job_error, 
                                    -1, 
                                    job_state, 
                                    sts);
        js := sts.job_status;
        le := sts.error;
        IF le IS NOT NULL THEN
          ind := le.FIRST;
          WHILE ind IS NOT NULL LOOP
            dbms_output.put_line(le(ind).LogText);
            ind := le.NEXT(ind);
          END LOOP;
        END IF;
    
        DBMS_DATAPUMP.STOP_JOB (h1, -1, 0, 0);
        dbms_datapump.detach(h1);

        DBMS_OUTPUT.PUT_LINE ('Ending SP_EXPORT_DATABASE...');
        sp_write_dbms_output_to_file('SP_EXPORT_DATABASE');
        DBMS_OUTPUT.DISABLE ();
       return -1;
    END;
END;
/

GRANT EXECUTE ON SP_EXPORT_DATABASE TO dbausers;


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
-- ... .....        Initial Version
-- PGH  02/23/10    Removed the currencyid paramerer, then joining the loc_rtl_loc table to get the default
--                  currencyid for the location.  If the default is not set, defaulting to 'USD'. 
-- BCW  06/21/12    Updated per Emily Tan's instructions.
-- BCW  12/06/13    Replaced the sale cursor by writing the transaction line item directly into the rpt_sale_line table.
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE SP_FLASH');

CREATE OR REPLACE PROCEDURE sp_flash 
  (argOrganizationId    IN NUMBER, 
   argRetailLocationId  IN NUMBER, 
   argBusinessDate      IN DATE, 
   argWrkstnId          IN NUMBER, 
   argTransSeq          IN NUMBER) 
AUTHID CURRENT_USER 
IS

myerror exception;
myreturn exception;

-- Arguments
pvOrganizationId        NUMBER(10);
pvRetailLocationId      NUMBER(10); 
pvBusinessDate          DATE;
pvWrkstnId              NUMBER(20,0);
pvTransSeq              NUMBER(20,0);

-- Quantities
vActualQuantity         NUMBER (11,2);
vGrossQuantity          NUMBER (11,2);
vQuantity               NUMBER (11,2);
vTotQuantity            NUMBER (11,2);

-- Amounts
vNetAmount              NUMBER (17,6);
vGrossAmount            NUMBER (17,6);
vTotGrossAmt            NUMBER (17,6);
vTotNetAmt              NUMBER (17,6);
vDiscountAmt            NUMBER (17,6);
vOverrideAmt            NUMBER (17,6);
vPaidAmt                NUMBER (17,6);
vTenderAmt              NUMBER (17,6);
vForeign_amt            NUMBER (17,6);
vLayawayPrice           NUMBER(17,6);
vUnitPrice              NUMBER (17,6);

-- Non Physical Items
vNonPhys                VARCHAR2(30 char);
vNonPhysSaleType        VARCHAR2(30 char);
vNonPhysType            VARCHAR2(30 char);
vNonPhysPrice           NUMBER (17,6);
vNonPhysQuantity        NUMBER (11,2);

-- Status codes
vTransStatcode          VARCHAR2(30 char);
vTransTypcode           VARCHAR2(30 char);
vSaleLineItmTypcode     VARCHAR2(30 char);
vTndrStatcode           VARCHAR2(60 char);
vLineitemStatcode       VARCHAR2(30 char);

-- others
vTransTimeStamp         TIMESTAMP;
vTransDate              TIMESTAMP;
vTransCount             NUMBER(10);
vTndrCount              NUMBER(10);
vPostVoidFlag           NUMBER(1);
vReturnFlag             NUMBER(1);
vTaxTotal               NUMBER (17,6);
vPaid                   VARCHAR2(30 char);
vLineEnum               VARCHAR2(150 char);
vTndrId                 VARCHAR2(60 char);
vItemId                 VARCHAR2(60 char);
vRtransLineItmSeq       NUMBER(10);
vDepartmentId           VARCHAR2(90 char);
vTndridProp             VARCHAR2(60 char);
vCurrencyId             VARCHAR2(3 char);
vTndrTypCode            VARCHAR2(30 char);

vSerialNbr              VARCHAR2(60 char);
vPriceModAmt            NUMBER(17,6);
vPriceModReascode       VARCHAR2(60 char);
vNonPhysExcludeFlag     NUMBER(1);
vCustPartyId            VARCHAR2(60 char);
vCustLastName           VARCHAR2(90 char);
vCustFirstName          VARCHAR2(90 char);
vItemDesc               VARCHAR2(254 char);
vBeginTimeInt           NUMBER(10);

-- counts
vRowCnt                 NUMBER(10);
vCntTrans               NUMBER(10);
vCntTndrCtl             NUMBER(10);
vCntPostVoid            NUMBER(10);
vCntRevTrans            NUMBER(10);
vCntNonPhysItm          NUMBER(10);
vCntNonPhys             NUMBER(10);
vCntCust                NUMBER(10);
vCntItem                NUMBER(10);
vCntParty               NUMBER(10);

-- cursors

CURSOR tenderCursor IS 
    SELECT t.amt, t.foreign_amt, t.tndr_id, t.tndr_statcode, tr.string_value, tnd.tndr_typcode 
        FROM TTR_TNDR_LINEITM t 
        inner join TRL_RTRANS_LINEITM r ON t.organization_id=r.organization_id
                                       AND t.rtl_loc_id=r.rtl_loc_id
                                       AND t.wkstn_id=r.wkstn_id
                                       AND t.trans_seq=r.trans_seq
                                       AND t.business_date=r.business_date
                                       AND t.rtrans_lineitm_seq=r.rtrans_lineitm_seq
        inner join TND_TNDR tnd ON t.organization_id=tnd.organization_id
                                       AND t.tndr_id=tnd.tndr_id                                   
    left outer join trl_rtrans_lineitm_p tr on tr.organization_id=r.organization_id
                    and tr.rtl_loc_id=r.rtl_loc_id
                    and tr.wkstn_id=r.wkstn_id
                    and tr.trans_seq=r.trans_seq
                    and tr.business_date=r.business_date
                    and tr.rtrans_lineitm_seq=r.rtrans_lineitm_seq
                    and lower(property_code) = 'tender_id'
        WHERE t.organization_id = pvOrganizationId
          AND t.rtl_loc_id = pvRetailLocationId
          AND t.wkstn_id = pvWrkstnId
          AND t.trans_seq = pvTransSeq
          AND t.business_date = pvBusinessDate
          AND r.void_flag = 0
          AND t.tndr_id <> 'ACCOUNT_CREDIT';

CURSOR postVoidTenderCursor IS 
    SELECT t.amt, t.foreign_amt, t.tndr_id, t.tndr_statcode, tr.string_value 
        FROM TTR_TNDR_LINEITM t 
        inner join TRL_RTRANS_LINEITM r ON t.organization_id=r.organization_id
                                       AND t.rtl_loc_id=r.rtl_loc_id
                                       AND t.wkstn_id=r.wkstn_id
                                       AND t.trans_seq=r.trans_seq
                                       AND t.business_date=r.business_date
                                       AND t.rtrans_lineitm_seq=r.rtrans_lineitm_seq
    left outer join trl_rtrans_lineitm_p tr on tr.organization_id=r.organization_id
                    and tr.rtl_loc_id=r.rtl_loc_id
                    and tr.wkstn_id=r.wkstn_id
                    and tr.trans_seq=r.trans_seq
                    and tr.business_date=r.business_date
                    and tr.rtrans_lineitm_seq=r.rtrans_lineitm_seq
                    and lower(property_code) = 'tender_id'
        WHERE t.organization_id = pvOrganizationId
          AND t.rtl_loc_id = pvRetailLocationId
          AND t.wkstn_id = pvWrkstnId
          AND t.trans_seq = pvTransSeq
          AND t.business_date = pvBusinessDate
          AND r.void_flag = 0
      AND t.tndr_id <> 'ACCOUNT_CREDIT';

CURSOR saleCursor IS
       select rsl.item_id,
       sale_lineitm_typcode,
       actual_quantity,
       unit_price,
       case vPostVoidFlag when 1 then -1 else 1 end * coalesce(gross_amt,0),
       case when return_flag=vPostVoidFlag then 1 else -1 end * coalesce(gross_quantity,0),
       merch_level_1,
       case vPostVoidFlag when 1 then -1 else 1 end * coalesce(net_amt,0),
       case when return_flag=vPostVoidFlag then 1 else -1 end * coalesce(quantity,0),
     return_flag 
       from rpt_sale_line rsl
     left join itm_non_phys_item inp on rsl.item_id=inp.item_id and rsl.organization_id=inp.organization_id
       WHERE rsl.organization_id = pvOrganizationId
          AND rtl_loc_id = pvRetailLocationId
          AND wkstn_id = pvWrkstnId
          AND business_date = pvBusinessDate
          AND trans_seq = pvTransSeq
      and QUANTITY <> 0
      and sale_lineitm_typcode not in ('ONHOLD','WORK_ORDER')
      and coalesce(exclude_from_net_sales_flag,0)=0;

-- Declarations end 

BEGIN
    -- initializations of args
    pvOrganizationId      := argOrganizationId;
    pvRetailLocationId    := argRetailLocationId;
    pvWrkstnId            := argWrkstnId;
    pvBusinessDate        := argBusinessDate;
    pvTransSeq            := argTransSeq;

    BEGIN
    SELECT tt.trans_statcode,
           tt.trans_typcode, 
           tt.begin_datetime, 
           tt.trans_date,
           tt.taxtotal, 
           tt.post_void_flag, 
           tt.begin_time_int,
           coalesce(t.currency_id, rl.currency_id)
        INTO vTransStatcode, 
             vTransTypcode, 
             vTransTimeStamp, 
             vTransDate,
             vTaxTotal, 
             vPostVoidFlag, 
             vBeginTimeInt,
             vCurrencyID
        FROM TRN_TRANS tt  
            LEFT JOIN loc_rtl_loc rl on tt.organization_id = rl.organization_id and tt.rtl_loc_id = rl.rtl_loc_id
      LEFT JOIN (select max(currency_id) currency_id,ttl.organization_id,ttl.rtl_loc_id,ttl.wkstn_id,ttl.business_date,ttl.trans_seq
      from ttr_tndr_lineitm ttl
      inner join tnd_tndr tnd on ttl.organization_id=tnd.organization_id and ttl.tndr_id=tnd.tndr_id
      group by ttl.organization_id,ttl.rtl_loc_id,ttl.wkstn_id,ttl.business_date,ttl.trans_seq) t ON
      tt.organization_id = t.organization_id
          AND tt.rtl_loc_id = t.rtl_loc_id
          AND tt.wkstn_id = t.wkstn_id
          AND tt.business_date = t.business_date
          AND tt.trans_seq = t.trans_seq
        WHERE tt.organization_id = pvOrganizationId
          AND tt.rtl_loc_id = pvRetailLocationId
          AND tt.wkstn_id = pvWrkstnId
          AND tt.business_date = pvBusinessDate
          AND tt.trans_seq = pvTransSeq;
    EXCEPTION
        WHEN no_data_found THEN
        NULL;
    END;
    
    vCntTrans := SQL%ROWCOUNT;
    
    IF vCntTrans = 1 THEN 
    
    -- so update the column on trn trans
        UPDATE TRN_TRANS SET flash_sales_flag = 1
            WHERE organization_id = pvOrganizationId
            AND rtl_loc_id = pvRetailLocationId
            AND wkstn_id = pvWrkstnId
            AND trans_seq = pvTransSeq
            AND business_date = pvBusinessDate;
    ELSE
        -- /* Invalid transaction */
        raise myerror;
        
    END IF;

    vTransCount := 1; -- /* initializing the transaction count */

  select count(*) into vCntTrans from rpt_sale_line
    WHERE organization_id = pvOrganizationId
    AND rtl_loc_id = pvRetailLocationId
    AND wkstn_id = pvWrkstnId
    AND trans_seq = pvTransSeq
    AND business_date = pvBusinessDate;

  IF vCntTrans = 0 AND vPostVoidFlag = 1 THEN
    insert into rpt_sale_line
    (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq,
    quantity, actual_quantity, gross_quantity, unit_price, net_amt, gross_amt, item_id, 
    item_desc, merch_level_1, serial_nbr, return_flag, override_amt, trans_timestamp, trans_date,
    discount_amt, cust_party_id, last_name, first_name, trans_statcode, sale_lineitm_typcode, begin_time_int, exclude_from_net_sales_flag)
    select tsl.organization_id, tsl.rtl_loc_id, tsl.business_date, tsl.wkstn_id, tsl.trans_seq, tsl.rtrans_lineitm_seq,
    tsl.net_quantity, tsl.quantity, tsl.gross_quantity, tsl.unit_price,
    -- For VAT taxed items there are rounding problems by which the usage of the tsl.net_amt could create problems.
    -- So, we are calculating it using the tax amount which could have more decimals and because that it is more accurate
    case when vat_amt is null then tsl.net_amt else tsl.gross_amt-tsl.vat_amt-coalesce(d.discount_amt,0) end, 
    tsl.gross_amt, tsl.item_id,
    i.DESCRIPTION, coalesce(tsl.merch_level_1,i.MERCH_LEVEL_1,'DEFAULT'), tsl.serial_nbr, tsl.return_flag, coalesce(o.override_amt,0), vTransTimeStamp, vTransDate,
    coalesce(d.discount_amt,0), tr.cust_party_id, cust.last_name, cust.first_name, 'VOID', tsl.sale_lineitm_typcode, vBeginTimeInt, tsl.exclude_from_net_sales_flag
    from trl_sale_lineitm tsl
    inner join trl_rtrans_lineitm r
    on tsl.organization_id=r.organization_id
    and tsl.rtl_loc_id=r.rtl_loc_id
    and tsl.wkstn_id=r.wkstn_id
    and tsl.trans_seq=r.trans_seq
    and tsl.business_date=r.business_date
    and tsl.rtrans_lineitm_seq=r.rtrans_lineitm_seq
    and r.rtrans_lineitm_typcode = 'ITEM'
    left join xom_order_mod xom
    on tsl.organization_id=xom.organization_id
    and tsl.rtl_loc_id=xom.rtl_loc_id
    and tsl.wkstn_id=xom.wkstn_id
    and tsl.trans_seq=xom.trans_seq
    and tsl.business_date=xom.business_date
    and tsl.rtrans_lineitm_seq=xom.rtrans_lineitm_seq
    left join xom_order_line_detail xold
    on xom.organization_id=xold.organization_id
    and xom.order_id=xold.order_id
    and xom.detail_seq=xold.detail_seq
    and xom.detail_line_number=xold.detail_line_number
    left join itm_item i
    on tsl.organization_id=i.ORGANIZATION_ID
    and tsl.item_id=i.ITEM_ID
    left join (select extended_amt override_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
      FROM trl_rtl_price_mod
      WHERE void_flag = 0 and rtl_price_mod_reascode='PRICE_OVERRIDE') o
    on tsl.organization_id = o.organization_id 
      AND tsl.rtl_loc_id = o.rtl_loc_id
      AND tsl.business_date = o.business_date 
      AND tsl.wkstn_id = o.wkstn_id 
      AND tsl.trans_seq = o.trans_seq
      AND tsl.rtrans_lineitm_seq = o.rtrans_lineitm_seq
    left join (select sum(extended_amt) discount_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
      FROM trl_rtl_price_mod
      WHERE void_flag = 0 and rtl_price_mod_reascode in ('LINE_ITEM_DISCOUNT', 'TRANSACTION_DISCOUNT', 'GROUP_DISCOUNT', 'NEW_PRICE_RULE', 'DEAL')
      group by organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq) d
    on tsl.organization_id = d.organization_id 
      AND tsl.rtl_loc_id = d.rtl_loc_id
      AND tsl.business_date = d.business_date 
      AND tsl.wkstn_id = d.wkstn_id 
      AND tsl.trans_seq = d.trans_seq
      AND tsl.rtrans_lineitm_seq = d.rtrans_lineitm_seq
    left join trl_rtrans tr
    on tsl.organization_id = tr.organization_id 
      AND tsl.rtl_loc_id = tr.rtl_loc_id
      AND tsl.business_date = tr.business_date 
      AND tsl.wkstn_id = tr.wkstn_id 
      AND tsl.trans_seq = tr.trans_seq
    left join crm_party cust
    on tsl.organization_id = cust.organization_id 
      AND tr.cust_party_id = cust.party_id
    where tsl.organization_id = pvOrganizationId
    and tsl.rtl_loc_id = pvRetailLocationId
    and tsl.wkstn_id = pvWrkstnId
    and tsl.business_date = pvBusinessDate
    and tsl.trans_seq = pvTransSeq
    and r.void_flag=0
    and ((tsl.SALE_LINEITM_TYPCODE <> 'ORDER'and (xom.detail_type IS NULL OR xold.status_code = 'FULFILLED') )
    or (tsl.SALE_LINEITM_TYPCODE = 'ORDER' and xom.detail_type in ('FEE', 'PAYMENT') ));
    raise myreturn;
  END IF;

    -- collect transaction data
    IF ABS(vTaxTotal) > 0 AND vTransTypcode <> 'POST_VOID' AND vPostVoidFlag = 0 AND vTransStatcode = 'COMPLETE' THEN
      
        sp_ins_upd_flash_sales (pvOrganizationId, 
                                pvRetailLocationId, 
                                vTransDate,
                                pvWrkstnId, 
                                'TOTALTAX', 
                                1, 
                                vTaxTotal, 
                                vCurrencyId);
      
    END IF;

    IF vTransTypcode = 'TENDER_CONTROL' AND vPostVoidFlag = 0 THEN    -- process for paid in paid out 
    
        BEGIN
        SELECT  typcode, amt INTO vPaid, vPaidAmt 
            FROM TSN_TNDR_CONTROL_TRANS 
            WHERE typcode LIKE 'PAID%'
              AND organization_id = pvOrganizationId
              AND rtl_loc_id = pvRetailLocationId
              AND wkstn_id = pvWrkstnId
              AND trans_seq = pvTransSeq
              AND business_date = pvBusinessDate;
           EXCEPTION
        WHEN no_data_found THEN
            NULL;
        END;


        vCntTndrCtl := SQL%ROWCOUNT;
    
        IF vCntTndrCtl = 1 THEN   
            
                IF vTransStatcode = 'COMPLETE' THEN
                        -- it is paid in or paid out
                    IF vPaid = 'PAID_IN' OR vPaid = 'PAIDIN' THEN
                        vLineEnum := 'paidin';
                    ELSE
                        vLineEnum := 'paidout';
                    END IF; 
                        -- update flash sales                 
                        sp_ins_upd_flash_sales (pvOrganizationId, 
                                               pvRetailLocationId, 
                                               vTransDate,
                                               pvWrkstnId, 
                                               vLineEnum, 
                                               1, 
                                               vPaidAmt, 
                                               vCurrencyId);
                END IF;
        END IF;
    END IF;
  
  -- collect tenders  data
  IF vPostVoidFlag = 0 AND vTransTypcode <> 'POST_VOID' THEN
  BEGIN
    OPEN tenderCursor;
    LOOP
        FETCH tenderCursor INTO vTenderAmt, vForeign_amt, vTndrid, vTndrStatcode, vTndridProp, vTndrTypCode; 
        EXIT WHEN tenderCursor%NOTFOUND;
  
        IF vTndrTypCode='VOUCHER' OR vTndrStatcode <> 'Change' THEN
            vTndrCount := 1;-- only for original tenders
        ELSE 
            vTndrCount := 0;
        END IF;

        if vTndridProp IS NOT NULL THEN
           vTndrid := vTndridProp;
    end if;

       IF vLineEnum = 'paidout' THEN
            vTenderAmt := vTenderAmt * -1;
            vForeign_amt := vForeign_amt * -1;
        END IF;

        -- update flash
        IF vTransStatcode = 'COMPLETE' THEN
            sp_ins_upd_flash_sales (pvOrganizationId, 
                                    pvRetailLocationId, 
                                    vTransDate, 
                                    pvWrkstnId, 
                                    vTndrid, 
                                    vTndrCount, 
                                    vTenderAmt, 
                                    vCurrencyId);
        END IF;

        IF vTenderAmt > 0 AND vTransStatcode = 'COMPLETE' THEN
            sp_ins_upd_flash_sales (pvOrganizationId, 
                                    pvRetailLocationId, 
                                    vTransDate, 
                                    pvWrkstnId,
                                    'TendersTakenIn', 
                                    1, 
                                    vTenderAmt, 
                                    vCurrencyId);
        ELSE
            sp_ins_upd_flash_sales (pvOrganizationId, 
                                    pvRetailLocationId, 
                                    vTransDate, 
                                    pvWrkstnId, 
                                    'TendersRefunded', 
                                    1, 
                                    vTenderAmt, 
                                    vCurrencyId);
        END IF;
    END LOOP;
    CLOSE tenderCursor;
  EXCEPTION
    WHEN OTHERS THEN CLOSE tenderCursor;
  END;
  END IF;
  
  -- collect post void info
  IF vTransTypcode = 'POST_VOID' OR vPostVoidFlag = 1 THEN
      vTransCount := -1; /* reversing the count */
      IF vPostVoidFlag = 0 THEN
        vPostVoidFlag := 1;
      
            /* NOTE: From now on the parameter value carries the original post voided
                information rather than the current transaction information in 
                case of post void trans type. This will apply for sales data 
                processing.
            */
            BEGIN
            SELECT voided_org_id, voided_rtl_store_id, voided_wkstn_id, voided_business_date, voided_trans_id 
              INTO pvOrganizationId, pvRetailLocationId, pvWrkstnId, pvBusinessDate, pvTransSeq
              FROM TRN_POST_VOID_TRANS 
              WHERE organization_id = pvOrganizationId
                AND rtl_loc_id = pvRetailLocationId
                AND wkstn_id = pvWrkstnId
                AND business_date = pvBusinessDate
                AND trans_seq = pvTransSeq;
            EXCEPTION
                WHEN no_data_found THEN
                NULL;
            END;

            vCntPostVoid := SQL%ROWCOUNT;

            IF vCntPostVoid = 0 THEN      
              
                raise myerror; -- don't know the original post voided record
            END IF;

      select count(*) into vCntPostVoid from rpt_sale_line
      WHERE organization_id = pvOrganizationId
      AND rtl_loc_id = pvRetailLocationId
      AND wkstn_id = pvWrkstnId
      AND trans_seq = pvTransSeq
      AND business_date = pvBusinessDate
      AND trans_statcode = 'VOID';

      IF vCntPostVoid > 0 THEN
                raise myreturn; -- record already exists
      END IF;
    END IF;
    -- updating for postvoid
     UPDATE rpt_sale_line
       SET trans_statcode='VOID'
       WHERE organization_id = pvOrganizationId
         AND rtl_loc_id = pvRetailLocationId
         AND wkstn_id = pvWrkstnId
         AND business_date = pvBusinessDate
         AND trans_seq = pvTransSeq; 
        
      BEGIN
      SELECT typcode, amt INTO vPaid, vPaidAmt
        FROM TSN_TNDR_CONTROL_TRANS 
        WHERE typcode LIKE 'PAID%'
          AND organization_id = pvOrganizationId
          AND rtl_loc_id = pvRetailLocationId
          AND wkstn_id = pvWrkstnId
          AND trans_seq = pvTransSeq
          AND business_date = pvBusinessDate;
      EXCEPTION WHEN no_data_found THEN
          NULL;
      END;


      IF SQL%FOUND AND vTransStatcode = 'COMPLETE' THEN
        -- it is paid in or paid out
        IF vPaid = 'PAID_IN' OR vPaid = 'PAIDIN' THEN
            vLineEnum := 'paidin';
        ELSE
            vLineEnum := 'paidout';
        END IF;
        vPaidAmt := vPaidAmt * -1 ;

        -- update flash sales                 
        sp_ins_upd_flash_sales (pvOrganizationId, 
                                pvRetailLocationId, 
                                vTransDate,
                                pvWrkstnId, 
                                vLineEnum, 
                                -1, 
                                vPaidAmt, 
                                vCurrencyId);
      END IF;
    
        BEGIN
        SELECT taxtotal INTO vTaxTotal
          FROM TRN_TRANS 
          WHERE organization_id = pvOrganizationId
            AND rtl_loc_id = pvRetailLocationId
            AND wkstn_id = pvWrkstnId
            AND business_date = pvBusinessDate
            AND trans_seq = pvTransSeq;
        EXCEPTION WHEN no_data_found THEN
            NULL;
        END;
        
        vCntRevTrans := SQL%ROWCOUNT;
        
        IF vCntRevTrans = 1 THEN    
            IF ABS(vTaxTotal) > 0 AND vTransStatcode = 'COMPLETE' THEN
                vTaxTotal := vTaxTotal * -1 ;
                sp_ins_upd_flash_sales (pvOrganizationId,
                                        pvRetailLocationId,
                                        vTransDate,
                                        pvWrkstnId,
                                        'TOTALTAX',
                                        -1,
                                        vTaxTotal, 
                                        vCurrencyId);
            END IF;
        END IF;

        -- reverse tenders
    BEGIN
        OPEN postVoidTenderCursor;
        
        LOOP
            FETCH postVoidTenderCursor INTO vTenderAmt, vForeign_amt, vTndrid, vTndrStatcode, vTndridProp;
            EXIT WHEN postVoidTenderCursor%NOTFOUND;
          
            IF vTndrStatcode <> 'Change' THEN
              vTndrCount := -1 ; -- only for original tenders
            ELSE 
              vTndrCount := 0 ;
            END IF;
          
      if vTndridProp IS NOT NULL THEN
         vTndrid := vTndridProp;
      end if;

            -- update flash
            vTenderAmt := vTenderAmt * -1;

            IF vTransStatcode = 'COMPLETE' THEN
                sp_ins_upd_flash_sales (pvOrganizationId, 
                                        pvRetailLocationId, 
                                        vTransDate, 
                                        pvWrkstnId, 
                                        vTndrid, 
                                        vTndrCount, 
                                        vTenderAmt, 
                                        vCurrencyId);
            END IF;
            
            IF vTenderAmt < 0 AND vTransStatcode = 'COMPLETE' THEN
                sp_ins_upd_flash_sales (pvOrganizationId, 
                                        pvRetailLocationId, 
                                        vTransDate, 
                                        pvWrkstnId,
                                        'TendersTakenIn',
                                        -1, 
                                        vTenderAmt, 
                                        vCurrencyId);
            ELSE
                sp_ins_upd_flash_sales (pvOrganizationId, 
                                        pvRetailLocationId, 
                                        vTransDate, 
                                        pvWrkstnId,
                                        'TendersRefunded',
                                        -1, 
                                        vTenderAmt, 
                                        vCurrencyId);
            END IF;
        END LOOP;
        
        CLOSE postVoidTenderCursor;
    EXCEPTION
      WHEN OTHERS THEN CLOSE postVoidTenderCursor;
  END;
  END IF;
  
  -- collect sales data
          

IF vPostVoidFlag = 0 and vTransTypcode <> 'POST_VOID' THEN -- dont do it for rpt sale line
        -- sale item insert
         insert into rpt_sale_line
        (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, rtrans_lineitm_seq,
        quantity, actual_quantity, gross_quantity, unit_price, net_amt, gross_amt, item_id, 
        item_desc, merch_level_1, serial_nbr, return_flag, override_amt, trans_timestamp, trans_date,
        discount_amt, cust_party_id, last_name, first_name, trans_statcode, sale_lineitm_typcode, begin_time_int, exclude_from_net_sales_flag)
        select tsl.organization_id, tsl.rtl_loc_id, tsl.business_date, tsl.wkstn_id, tsl.trans_seq, tsl.rtrans_lineitm_seq,
        tsl.net_quantity, tsl.quantity, tsl.gross_quantity, tsl.unit_price,
        -- For VAT taxed items there are rounding problems by which the usage of the tsl.net_amt could create problems.
        -- So, we are calculating it using the tax amount which could have more decimals and because that it is more accurate
        case when vat_amt is null then tsl.net_amt else tsl.gross_amt-tsl.vat_amt-coalesce(d.discount_amt,0) end,
        tsl.gross_amt, tsl.item_id,
        i.DESCRIPTION, coalesce(tsl.merch_level_1,i.MERCH_LEVEL_1,'DEFAULT'), tsl.serial_nbr, tsl.return_flag, coalesce(o.override_amt,0), vTransTimeStamp, vTransDate,
        coalesce(d.discount_amt,0), tr.cust_party_id, cust.last_name, cust.first_name, vTransStatcode, tsl.sale_lineitm_typcode, vBeginTimeInt, tsl.exclude_from_net_sales_flag
        from trl_sale_lineitm tsl
        inner join trl_rtrans_lineitm r
        on tsl.organization_id=r.organization_id
        and tsl.rtl_loc_id=r.rtl_loc_id
        and tsl.wkstn_id=r.wkstn_id
        and tsl.trans_seq=r.trans_seq
        and tsl.business_date=r.business_date
        and tsl.rtrans_lineitm_seq=r.rtrans_lineitm_seq
        and r.rtrans_lineitm_typcode = 'ITEM'
        left join xom_order_mod xom
            on tsl.organization_id=xom.organization_id
            and tsl.rtl_loc_id=xom.rtl_loc_id
            and tsl.wkstn_id=xom.wkstn_id
            and tsl.trans_seq=xom.trans_seq
            and tsl.business_date=xom.business_date
            and tsl.rtrans_lineitm_seq=xom.rtrans_lineitm_seq
        left join xom_order_line_detail xold
            on xom.organization_id=xold.organization_id
            and xom.order_id=xold.order_id
            and xom.detail_seq=xold.detail_seq
            and xom.detail_line_number=xold.detail_line_number
            left join itm_item i
        on tsl.organization_id=i.ORGANIZATION_ID
        and tsl.item_id=i.ITEM_ID
        left join (select extended_amt override_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
            FROM trl_rtl_price_mod
            WHERE void_flag = 0 and rtl_price_mod_reascode='PRICE_OVERRIDE') o
        on tsl.organization_id = o.organization_id 
            AND tsl.rtl_loc_id = o.rtl_loc_id
            AND tsl.business_date = o.business_date 
            AND tsl.wkstn_id = o.wkstn_id 
            AND tsl.trans_seq = o.trans_seq
            AND tsl.rtrans_lineitm_seq = o.rtrans_lineitm_seq
        left join (select sum(extended_amt) discount_amt,organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq
            FROM trl_rtl_price_mod
            WHERE void_flag = 0 and rtl_price_mod_reascode in ('LINE_ITEM_DISCOUNT', 'TRANSACTION_DISCOUNT', 'GROUP_DISCOUNT', 'NEW_PRICE_RULE', 'DEAL')
            group by organization_id,rtl_loc_id,business_date,wkstn_id,trans_seq,rtrans_lineitm_seq) d
        on tsl.organization_id = d.organization_id 
            AND tsl.rtl_loc_id = d.rtl_loc_id
            AND tsl.business_date = d.business_date 
            AND tsl.wkstn_id = d.wkstn_id 
            AND tsl.trans_seq = d.trans_seq
            AND tsl.rtrans_lineitm_seq = d.rtrans_lineitm_seq
        left join trl_rtrans tr
        on tsl.organization_id = tr.organization_id 
            AND tsl.rtl_loc_id = tr.rtl_loc_id
            AND tsl.business_date = tr.business_date 
            AND tsl.wkstn_id = tr.wkstn_id 
            AND tsl.trans_seq = tr.trans_seq
        left join crm_party cust
        on tsl.organization_id = cust.organization_id 
            AND tr.cust_party_id = cust.party_id
        where tsl.organization_id = pvOrganizationId
        and tsl.rtl_loc_id = pvRetailLocationId
        and tsl.wkstn_id = pvWrkstnId
        and tsl.business_date = pvBusinessDate
        and tsl.trans_seq = pvTransSeq
        and r.void_flag=0
        and ((tsl.SALE_LINEITM_TYPCODE <> 'ORDER'and (xom.detail_type IS NULL OR xold.status_code = 'FULFILLED') )
             or (tsl.SALE_LINEITM_TYPCODE = 'ORDER' and xom.detail_type in ('FEE', 'PAYMENT') ));

END IF;
    
        IF vTransStatcode = 'COMPLETE' THEN -- process only completed transaction for flash sales tables
        BEGIN
       select sum(case vPostVoidFlag when 0 then -1 else 1 end * coalesce(quantity,0)),sum(case vPostVoidFlag when 1 then -1 else 1 end * coalesce(net_amt,0))
        INTO vQuantity,vNetAmount
        from rpt_sale_line rsl
    left join itm_non_phys_item inp on rsl.item_id=inp.item_id and rsl.organization_id=inp.organization_id
        where rsl.organization_id = pvOrganizationId
            and rtl_loc_id = pvRetailLocationId
            and wkstn_id = pvWrkstnId
            and business_date = pvBusinessDate
            and trans_seq= pvTransSeq
            and return_flag=1
      and coalesce(exclude_from_net_sales_flag,0)=0;
        EXCEPTION WHEN no_data_found THEN
          NULL;
        END;
        
            IF ABS(vNetAmount) > 0 OR ABS(vQuantity) > 0 THEN
                -- populate now to flash tables
                -- returns
                sp_ins_upd_flash_sales(pvOrganizationId, 
                                       pvRetailLocationId, 
                                       vTransDate, 
                                       pvWrkstnId, 
                                       'RETURNS', 
                                       vQuantity, 
                                       vNetAmount, 
                                       vCurrencyId);
            END IF;
            
        select sum(case when return_flag=vPostVoidFlag then 1 else -1 end * coalesce(gross_quantity,0)),
        sum(case when return_flag=vPostVoidFlag then 1 else -1 end * coalesce(quantity,0)),
        sum(case vPostVoidFlag when 1 then -1 else 1 end * coalesce(gross_amt,0)),
        sum(case vPostVoidFlag when 1 then -1 else 1 end * coalesce(net_amt,0)),
        sum(case vPostVoidFlag when 1 then 1 else -1 end * coalesce(override_amt,0)),
        sum(case vPostVoidFlag when 1 then 1 else -1 end * coalesce(discount_amt,0))
        into vGrossQuantity,vQuantity,vGrossAmount,vNetAmount,vOverrideAmt,vDiscountAmt
        from rpt_sale_line rsl
    left join itm_non_phys_item inp on rsl.item_id=inp.item_id and rsl.organization_id=inp.organization_id
        where rsl.organization_id = pvOrganizationId
            and rtl_loc_id = pvRetailLocationId
            and wkstn_id = pvWrkstnId
            and business_date = pvBusinessDate
            and trans_seq= pvTransSeq
      and QUANTITY <> 0
      and sale_lineitm_typcode not in ('ONHOLD','WORK_ORDER')
      and coalesce(exclude_from_net_sales_flag,0)=0;
      
      -- For VAT taxed items there are rounding problems by which the usage of the SUM(net_amt) could create problems
      -- So we decided to set it as simple difference between the gross amount and the discount, which results in the expected value for both SALES and VAT without rounding issues
      -- We excluded the possibility to round also the tax because several reasons:
      -- 1) It will be possible that the final result is not accurate if both values have 5 as exceeding decimal
      -- 2) The value of the tax is rounded by specific legal requirements, and must match with what specified on the fiscal receipts
      -- 3) The number of decimals used for the tax amount in the database is less (6) than the one used in the calculator (10); 
      -- anyway, this last one is the most accurate, so we cannot rely on the value on the database which is at line level (rpt_sale_line) and could be affected by several roundings
      vNetAmount := vGrossAmount + vDiscountAmt - vTaxTotal;
      
            -- Gross sales
            IF ABS(vGrossAmount) > 0 THEN
                sp_ins_upd_flash_sales(pvOrganizationId,
                                       pvRetailLocationId,
                                       vTransDate, 
                                       pvWrkstnId, 
                                       'GROSSSALES', 
                                       vGrossQuantity, 
                                       vGrossAmount, 
                                       vCurrencyId);
            END IF;
      
            -- Net Sales update
            IF ABS(vNetAmount) > 0 THEN
                sp_ins_upd_flash_sales(pvOrganizationId,
                                       pvRetailLocationId,
                                       vTransDate, 
                                       pvWrkstnId, 
                                       'NETSALES', 
                                       vQuantity, 
                                       vNetAmount, 
                                       vCurrencyId);
            END IF;
        
            -- Discounts
            IF ABS(vOverrideAmt) > 0 THEN
                sp_ins_upd_flash_sales(pvOrganizationId,
                                       pvRetailLocationId,
                                       vTransDate, 
                                       pvWrkstnId, 
                                       'OVERRIDES', 
                                       vQuantity, 
                                       vOverrideAmt, 
                                       vCurrencyId);
            END IF; 
  
            -- Discounts  
            IF ABS(vDiscountAmt) > 0 THEN 
                sp_ins_upd_flash_sales(pvOrganizationId,
                                       pvRetailLocationId,
                                       vTransDate,
                                       pvWrkstnId,
                                       'DISCOUNTS',
                                       vQuantity, 
                                       vDiscountAmt, 
                                       vCurrencyId);
            END IF;
      
   
        -- Hourly sales updates (add for all the line items in the transaction)
            vTotQuantity := COALESCE(vTotQuantity,0) + vQuantity;
            vTotNetAmt := COALESCE(vTotNetAmt,0) + vNetAmount;
            vTotGrossAmt := COALESCE(vTotGrossAmt,0) + vGrossAmount;
    
  BEGIN
    OPEN saleCursor;
      
    LOOP  
        FETCH saleCursor INTO vItemId, 
                              vSaleLineitmTypcode, 
                              vActualQuantity,
                              vUnitPrice, 
                              vGrossAmount, 
                              vGrossQuantity, 
                              vDepartmentId, 
                              vNetAmount, 
                              vQuantity,
                vReturnFlag;
    
        EXIT WHEN saleCursor%NOTFOUND;
      
            BEGIN
            SELECT non_phys_item_typcode INTO vNonPhysType
              FROM ITM_NON_PHYS_ITEM 
              WHERE item_id = vItemId 
                AND organization_id = pvOrganizationId  ;
            EXCEPTION WHEN no_data_found THEN
                NULL;
            END;
      
            vCntNonPhysItm := SQL%ROWCOUNT;
            
            IF vCntNonPhysItm = 1 THEN  
                -- check for layaway or sp. order payment / deposit
                IF vPostVoidFlag <> vReturnFlag THEN 
                    vNonPhysPrice := vUnitPrice * -1;
                    vNonPhysQuantity := vActualQuantity * -1;
                ELSE
                    vNonPhysPrice := vUnitPrice;
                    vNonPhysQuantity := vActualQuantity;
                END IF;
      
                IF vNonPhysType = 'LAYAWAY_DEPOSIT' THEN 
                    vNonPhys := 'LayawayDeposits';
                ELSIF vNonPhysType = 'LAYAWAY_PAYMENT' THEN
                    vNonPhys := 'LayawayPayments';
                ELSIF vNonPhysType = 'SP_ORDER_DEPOSIT' THEN
                    vNonPhys := 'SpOrderDeposits';
                ELSIF vNonPhysType = 'SP_ORDER_PAYMENT' THEN
                    vNonPhys := 'SpOrderPayments';
             ELSIF vNonPhysType = 'PRESALE_DEPOSIT' THEN
        vNonPhys := 'PresaleDeposits';
          ELSIF vNonPhysType = 'PRESALE_PAYMENT' THEN
        vNonPhys := 'PresalePayments';
                ELSE 
                    vNonPhys := 'NonMerchandise';
                    vNonPhysPrice := vGrossAmount;
                    vNonPhysQuantity := vGrossQuantity;
                END IF; 
                -- update flash sales for non physical payments / deposits
                sp_ins_upd_flash_sales (pvOrganizationId,
                                        pvRetailLocationId,
                                        vTransDate,
                                        pvWrkstnId,
                                        vNonPhys,
                                        vNonPhysQuantity, 
                                        vNonphysPrice, 
                                        vCurrencyId);
            ELSE
                vNonPhys := ''; -- reset 
            END IF;
    
            -- process layaways and special orders (not sales)
            IF vSaleLineitmTypcode = 'LAYAWAY' OR vSaleLineitmTypcode = 'SPECIAL_ORDER' THEN
                IF (NOT (vNonPhys = 'LayawayDeposits' 
                      OR vNonPhys = 'LayawayPayments' 
                      OR vNonPhys = 'SpOrderDeposits' 
                      OR vNonPhys = 'SpOrderPayments'
          OR vNonPhys = 'PresaleDeposits'
          OR vNonPhys = 'PresalePayments')) 
                    AND ((vLineitemStatcode IS NULL) OR (vLineitemStatcode <> 'CANCEL')) THEN
                    
                    vNonPhysSaleType := 'SpOrderItems';
                  
                    IF vSaleLineitmTypcode = 'LAYAWAY' THEN
                        vNonPhysSaleType := 'LayawayItems';
            ELSIF vSaleLineitmTypcode = 'PRESALE' THEN
            vNonPhysSaleType := 'PresaleItems';

                    END IF;
                  
                    -- update flash sales for layaway items
                    vLayawayPrice := vUnitPrice * COALESCE(vActualQuantity,0);
                    sp_ins_upd_flash_sales (pvOrganizationId,
                                            pvRetailLocationId,
                                            vTransDate,
                                            pvWrkstnId,
                                            vNonPhys,
                                            vActualQuantity, 
                                            vLayawayPrice, 
                                            vCurrencyId);
                END IF;
            END IF;
            -- end flash sales update
            -- department sales
            sp_ins_upd_merchlvl1_sales(pvOrganizationId, 
                                  pvRetailLocationId, 
                                  vTransDate, 
                                  pvWrkstnId, 
                                  vDepartmentId, 
                                  vQuantity, 
                                  vNetAmount, 
                                  vGrossAmount, 
                                  vCurrencyId);
    END LOOP;
    CLOSE saleCursor;
  EXCEPTION
    WHEN OTHERS THEN CLOSE saleCursor;
  END;
    END IF; 
  
  
    -- update hourly sales
    Sp_Ins_Upd_Hourly_Sales(pvOrganizationId, 
                            pvRetailLocationId, 
                            vTransDate, 
                            pvWrkstnId, 
                            vTransTimeStamp, 
                            vTotquantity, 
                            vTotNetAmt, 
                            vTotGrossAmt, 
                            vTransCount, 
                            vCurrencyId);
  
    COMMIT;
  
    EXCEPTION
        --WHEN NO_DATA_FOUND THEN
        --    vRowCnt := 0;            
        WHEN myerror THEN
            rollback;
        WHEN myreturn THEN
            commit;
        WHEN others THEN
            DBMS_OUTPUT.PUT_LINE('ERROR NUM: ' || to_char(sqlcode));
            DBMS_OUTPUT.PUT_LINE('ERROR TXT: ' || SQLERRM);
            rollback;
--    END;
END sp_flash;
/

GRANT EXECUTE ON sp_flash TO posusers,dbausers;
 
-------------------------------------------------------------------------------------------------------------------
--
-- Procedure         : SP_IMPORT_DATABASE
-- Description       : This procedure is called on the local database to import all of the XStore objects onto a
--                      secondary register or for the local training databases.  It procedure will drop all of the 
--                      procedures, triggers, views, sequences and functions owned by the target owner.  If this a 
--                      production database the public synonyms are also dropped.
-- Version           : 19.0
--
-------------------------------------------------------------------------------------------------------------------
--                            CHANGE HISTORY                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- WHO DATE      DESCRIPTION                                                                                     --
-------------------------------------------------------------------------------------------------------------------
-- ... ..........         Initial Version
-- PGH 03/17/2010   Added the two parameters and logic to drop public synonyms
-- PGH 03/26/2010   Rewritten the procedure to execute the datadump import via SQL calls instead of the command
--                  line utility.  The procedures now does pre, import and post steps.
-- PGH 08/30/2010   Add a line to ignore the ctl_replication_queue, because there are two copies of this table and
--                  the synoym should not be owned by DTV.
-- BCW 09/08/2015   Changed the public synonyms to user synonyms.
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING FUNCTION SP_IMPORT_DATABASE');

CREATE OR REPLACE FUNCTION SP_IMPORT_DATABASE 
(  
    argImportPath              varchar2,                   -- Import Directory Name
    argProd                    varchar2,                   -- Import Type: PRODUCTION / TRAINING
    argBackupDataFile          varchar2,                   -- Dump File Name
    argOutputFile              varchar2,                   -- Log File Name
    argSourceOwner             varchar2,                   -- Source Owner User Name
    argTargetOwner             varchar2,                   -- Target Owner User Name
    argSourceTablespace        varchar2,                   -- Source Data Tablespace Name
    argTargetTablespace        varchar2,                   -- Target Data Tablespace Name
    argSourceIndexTablespace   varchar2,                   -- Source Index Tablespace Name
    argTargetIndexTablespace   varchar2                    -- Target Index Tablespace Name
)
RETURN INTEGER
IS

sqlStmt                 VARCHAR2(512);
ls_object_type          VARCHAR2(30);
ls_object_name          VARCHAR2(128);
err_count               NUMBER := 0;
status_message          VARCHAR2(30);

-- Varaibles for the Datapump section
h1                      NUMBER;         -- Data Pump job handle
job_state               VARCHAR2(30);   -- To keep track of job state
ind                     NUMBER;         -- loop index
le                      ku$_LogEntry;   -- WIP and error messages
js                      ku$_JobStatus;  -- job status from get_status
jd                      ku$_JobDesc;    -- job description from get_status
sts                     ku$_Status;     -- status object returned by 
rowcnt                  NUMBER;


CURSOR OBJECT_LIST (v_owner  VARCHAR2) IS
SELECT object_type, object_name
  FROM all_objects
  WHERE object_type IN ('PROCEDURE', 'TRIGGER', 'VIEW', 'SEQUENCE', 'FUNCTION', 'TABLE', 'TYPE')
    AND object_name != 'SP_IMPORT_DATABASE'
    AND object_name != 'SP_WRITE_DBMS_OUTPUT_TO_FILE'
    AND object_name != 'CTL_REPLICATION_QUEUE'
    AND owner = v_owner;

BEGIN

    -- Enable Server Output
    DBMS_OUTPUT.ENABLE (500000);
    DBMS_OUTPUT.PUT_LINE (user || ' is starting SP_IMPORT_DATABASE.');
    sp_write_dbms_output_to_file('SP_IMPORT_DATABASE');
    
    --
    -- Checks to see if the Data Pump work table exists and drops it.
    --
    select count(*)
        into rowcnt
        from all_tables
        where owner = upper('$(DbSchema)')
          and table_name = 'XSTORE_IMPORT';
          
    IF rowcnt > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE XSTORE_IMPORT';
    END IF;

    -- 
    -- Validate the first parameter is either 'PRODUCTION' OR 'TRAINING', if not raise an error
    --
    IF argProd != 'PRODUCTION' AND argProd != 'TRAINING' THEN
        dbms_output.put_line ('Parameter: argProd - Must be PRODUCTION OR TRAINING');
        Raise_application_error(-20001 , 'Parameter: argProd - Must be PRODUCTION OR TRAINING');
    END IF;

    --
    -- Drops all of the user's objects
    --
    BEGIN
    OPEN OBJECT_LIST (argTargetOwner);
      
    LOOP 
      BEGIN
        FETCH OBJECT_LIST INTO ls_object_type, ls_object_name;
        EXIT WHEN OBJECT_LIST%NOTFOUND;
        
        -- Do not drop the tables, they will be dropped by datapump.
        IF ls_object_type != 'TABLE' THEN
            IF ls_object_type = 'SEQUENCE' AND ls_object_name LIKE '%ISEQ$$%' THEN
              dbms_output.put_line ('FOUND A SYSTEM GENERATED SEQ ' || ls_object_name ||' WILL NOT DROP IT.');
            ELSE
              sqlstmt := 'DROP '|| ls_object_type ||' '|| argTargetOwner || '.' || ls_object_name;
              dbms_output.put_line (sqlstmt);
            END IF;
            IF sqlStmt IS NOT NULL THEN
                  EXECUTE IMMEDIATE sqlStmt;
            END IF;
        END IF;
      EXCEPTION
         WHEN OTHERS THEN
         BEGIN
         DBMS_OUTPUT.PUT_LINE('Error: '|| SQLERRM);
         sp_write_dbms_output_to_file('SP_IMPORT_DATABASE');
         err_count := err_count + 1;
         END;
      END;  
    END LOOP;
    CLOSE OBJECT_LIST;
    sp_write_dbms_output_to_file('SP_IMPORT_DATABASE');
    EXCEPTION
         WHEN OTHERS THEN
         BEGIN
         CLOSE OBJECT_LIST;
         DBMS_OUTPUT.PUT_LINE('Error: '|| SQLERRM);
         sp_write_dbms_output_to_file('SP_IMPORT_DATABASE');
         err_count := err_count + 1;
         END;
    END;  

    --
    -- Import the schema objects using Datapump DBMS package
    -- This is a code block to handel exceptions from Datapump
    --

    BEGIN
            --
        -- Performs a schema level import for the Xstore objects
        --
        h1 := DBMS_DATAPUMP.OPEN('IMPORT','SCHEMA',NULL,'XSTORE_IMPORT','LATEST');
        DBMS_DATAPUMP.METADATA_FILTER(h1, 'SCHEMA_EXPR', 'IN ('''|| argSourceOwner || ''')');

        --
        -- Adds the data and log files
        --
        DBMS_DATAPUMP.ADD_FILE(h1, argBackupDataFile, argImportPath, NULL, DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE);
        DBMS_DATAPUMP.ADD_FILE(h1, argOutputFile, argImportPath, NULL, DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);
        
        --
        -- Parameters for the import
        --  1) Do not create user
        --  2) Drop table if they exists
        --  3) Collect metrics as time taken to process object(s)
        --  4) Exclude procedure SP_PREP_FOR_IMPORT
        --  5) If Training, exclude grants
        --  6) Remap Schema
        --  7) Remap Tablespace
        --  8) Inhibit the assignment of the exported OID,a new OID will be assigned.
        --
        --DBMS_DATAPUMP.SET_PARAMETER(h1, 'USER_METADATA', 0);
        DBMS_DATAPUMP.SET_PARAMETER(h1, 'TABLE_EXISTS_ACTION', 'REPLACE');
        DBMS_DATAPUMP.SET_PARAMETER(h1, 'METRICS', 1);
        DBMS_DATAPUMP.METADATA_REMAP(h1, 'REMAP_SCHEMA', argSourceOwner, argTargetOwner);
        DBMS_DATAPUMP.METADATA_FILTER(h1,'NAME_EXPR','!=''SP_IMPORT_DATABASE''', 'FUNCTION');
        DBMS_DATAPUMP.METADATA_FILTER(h1,'NAME_EXPR','!=''SP_WRITE_DBMS_OUTPUT_TO_FILE''', 'PROCEDURE');
        DBMS_DATAPUMP.METADATA_FILTER(h1,'NAME_EXPR','!=''$(DbUser)''', 'USER');
        DBMS_DATAPUMP.METADATA_FILTER(h1,'NAME_EXPR','!=''TRAINING''', 'USER');
        DBMS_DATAPUMP.METADATA_TRANSFORM(h1,'OID',0, 'TYPE');
        IF upper(argProd) = 'TRAINING' THEN
            DBMS_DATAPUMP.METADATA_FILTER(h1, 'EXCLUDE_PATH_EXPR', 'like''%GRANT%''');
        END IF;
        
        DBMS_DATAPUMP.METADATA_REMAP(h1, 'REMAP_TABLESPACE', argSourceTablespace, argTargetTablespace); 
        DBMS_DATAPUMP.METADATA_REMAP(h1, 'REMAP_TABLESPACE', argSourceIndexTablespace, argTargetIndexTablespace); 

        --
        -- Start the job. An exception will be generated if something is not set up
        -- properly.
        --
        dbms_output.put_line('Starting datapump job');
        DBMS_DATAPUMP.START_JOB(h1);

        --
        -- Waits until the job as completed
        --
        DBMS_DATAPUMP.WAIT_FOR_JOB (h1, job_state);

        dbms_output.put_line('Job has completed');
        dbms_output.put_line('Final job state = ' || job_state);

        dbms_datapump.detach(h1);
      sp_write_dbms_output_to_file('SP_IMPORT_DATABASE');
      BEGIN
        sqlstmt := 'PURGE RECYCLEBIN';
        EXECUTE IMMEDIATE sqlstmt;
        DBMS_OUTPUT.PUT_LINE(sqlstmt || ' executed');
        sp_write_dbms_output_to_file('SP_IMPORT_DATABASE');
      END;
    EXCEPTION
        WHEN OTHERS THEN
        BEGIN
            dbms_datapump.get_status(h1, 
                                        dbms_datapump.ku$_status_job_error, 
                                        -1, 
                                        job_state, 
                                        sts);
            js := sts.job_status;
            le := sts.error;
            IF le IS NOT NULL THEN
              ind := le.FIRST;
              WHILE ind IS NOT NULL LOOP
                dbms_output.put_line(le(ind).LogText);
                ind := le.NEXT(ind);
              END LOOP;
            END IF;
            
            DBMS_DATAPUMP.STOP_JOB (h1, -1, 0, 0);
            dbms_datapump.detach(h1);
        sp_write_dbms_output_to_file('SP_IMPORT_DATABASE');
          DBMS_OUTPUT.DISABLE ();
            --Raise_application_error(-20002 , 'Datapump: Data Import Failed');
            return -1;
        END;
    END;  
    
    status_message :=
      CASE err_count
         WHEN 0 THEN 'successfully.'
         ELSE 'with ' || err_count || ' errors.'
      end;
    DBMS_OUTPUT.PUT_LINE (user || ' has executed SP_IMPORT_DATABASE '|| status_message);
    sp_write_dbms_output_to_file('SP_IMPORT_DATABASE');
 
    DBMS_OUTPUT.DISABLE ();

    return 0;
EXCEPTION
    WHEN OTHERS THEN
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        err_count := err_count + 1;
        DBMS_OUTPUT.PUT_LINE (user || ' has executed SP_IMPORT_DATABASE with ' || err_count || ' errors.');
        sp_write_dbms_output_to_file('SP_IMPORT_DATABASE');
        DBMS_OUTPUT.DISABLE ();
        RETURN -1;
    END;
END;
/

GRANT EXECUTE ON SP_IMPORT_DATABASE TO dbausers;


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
-- PGH 11/03/18   Changed the v_business_date paramter from timestamp(6) to date.
-- 
-------------------------------------------------------------------------------------------------------------------
EXEC DBMS_OUTPUT.PUT_LINE('--- CREATING PROCEDURE SP_REPORT');

CREATE OR REPLACE PROCEDURE SP_REPORT (
  job_id      in number default 0,
  firstLoc_id   in number default 0,
  lastLoc_id    in number default 999999999,
  start_date    in DATE default to_date('01/01/1900','mm/dd/yyyy'),
  end_date    in DATE default to_date('12/31/9999','mm/dd/yyyy'),
  batch_count   in number default 9999999999,
  nologging   in number default 0)
AUTHID CURRENT_USER 
IS

  v_organization_id  NUMBER(10);
  v_rtl_loc_id NUMBER(10);
  v_wkstn_id NUMBER(20);
  v_business_date date;       -- Changed the parameter from timestamp(6) to date.
  v_trans_seq NUMBER(10);
  v_starttime DATE;
  v_sql VARCHAR2(4000);

  CURSOR trans IS
   SELECT trn.organization_id, 
          trn.rtl_loc_id, 
          trn.business_date, 
          trn.wkstn_id, 
          trn.trans_seq
   FROM trn_trans trn

   LEFT JOIN tsn_tndr_control_trans tndr
    ON trn.organization_id = tndr.organization_id
    AND trn.rtl_loc_id     = tndr.rtl_loc_id
    AND trn.business_date  = tndr.business_date
    AND trn.wkstn_id       = tndr.wkstn_id
    AND trn.trans_seq      = tndr.trans_seq
    AND trn.flash_sales_flag = 0

   WHERE trn.flash_sales_flag = 0
   AND trn.trans_typcode in ('RETAIL_SALE','POST_VOID','TENDER_CONTROL')
   AND trn.trans_statcode not like 'CANCEL%'
   AND trn.rtl_loc_id between firstLoc_id AND lastLoc_id
   AND trn.business_date between start_date AND end_date
   AND (tndr.typcode IS NULL OR tndr.typcode IN ('PAID_IN', 'PAID_OUT'))
   AND rownum<=batch_count
  ORDER BY trn.business_date, trn.rtl_loc_id, trn.begin_datetime;

BEGIN
    select sysdate into v_starttime from dual;
    if nologging=0 then
       insert into log_sp_report (job_id,loc_id,business_date,job_start,completed,expected)
      select job_id, trn.rtl_loc_id, trn.business_date, v_starttime, 0, COUNT(*)
      FROM trn_trans trn
      
      LEFT JOIN tsn_tndr_control_trans tndr
        ON trn.organization_id = tndr.organization_id
        AND trn.rtl_loc_id     = tndr.rtl_loc_id
        AND trn.business_date  = tndr.business_date
        AND trn.wkstn_id       = tndr.wkstn_id
        AND trn.trans_seq      = tndr.trans_seq
        AND trn.flash_sales_flag = 0
      
      WHERE trn.flash_sales_flag = 0
      AND trn.trans_typcode in ('RETAIL_SALE','POST_VOID','TENDER_CONTROL')
      AND trn.trans_statcode not like 'CANCEL%'
      AND trn.rtl_loc_id between firstLoc_id AND lastLoc_id
      AND trn.business_date between start_date AND end_date
      AND (tndr.typcode IS NULL OR tndr.typcode IN ('PAID_IN', 'PAID_OUT'))
      AND rownum<=batch_count
      group by trn.rtl_loc_id, trn.business_date;
    end if;
    
    OPEN trans;
  
        LOOP
            FETCH trans INTO v_organization_id, 
                             v_rtl_loc_id, 
                             v_business_date, 
                             v_wkstn_id,
                             v_trans_seq;
       
            EXIT WHEN trans%NOTFOUND;

        if nologging=0 then
        update log_sp_report set start_dt = SYSDATE where loc_id = v_rtl_loc_id and business_date=v_business_date and job_start=v_starttime and job_id=job_id and start_dt is null;
      end if;

           sp_flash (v_organization_id, 
                      v_rtl_loc_id, 
                      v_business_date, 
                      v_wkstn_id,
                      v_trans_seq); 

        if nologging=0 then
        update log_sp_report set completed = completed + 1,end_dt = SYSDATE where loc_id = v_rtl_loc_id and business_date=v_business_date and job_start=v_starttime and job_id=job_id;
      end if;
        END LOOP;
    CLOSE trans;
  if nologging=0 then
    update log_sp_report set job_end = SYSDATE where job_start=v_starttime and job_id=job_id;
  end if;
  EXCEPTION
    WHEN OTHERS THEN CLOSE trans;
END SP_REPORT;
/

GRANT EXECUTE ON SP_REPORT TO posusers,dbausers;

-- 
-- TRIGGER: TRG_UPDATE_RETURN 
--

CREATE OR REPLACE TRIGGER TRG_UPDATE_RETURN
AFTER INSERT
ON trl_returned_item_journal
REFERENCING OLD AS OLD NEW AS NEW
FOR EACH ROW
DECLARE
  v_found_trans SMALLINT;
  v_found_lineitm SMALLINT;
BEGIN
  SELECT COUNT(*) INTO v_found_trans 
      FROM trn_trans 
      WHERE organization_id = :NEW.organization_id
      AND rtl_loc_id = :NEW.rtl_loc_id
      AND wkstn_id = :NEW.wkstn_id
      AND business_date = :NEW.business_date
      AND trans_seq = :NEW.trans_seq;
  IF v_found_trans > 0 THEN
     SELECT COUNT(*) INTO v_found_lineitm FROM trl_returned_item_count ric WHERE 
           organization_id = :NEW.organization_id AND
           rtl_loc_id = :NEW.rtl_loc_id AND
           wkstn_id = :NEW.wkstn_id AND
           business_date = :NEW.business_date AND
           trans_seq = :NEW.trans_seq AND
           rtrans_lineitm_seq = :NEW.rtrans_lineitm_seq;
    IF v_found_lineitm < 1 THEN
      INSERT INTO trl_returned_item_count
        (organization_id, rtl_loc_id, wkstn_id, business_date, trans_seq,
        rtrans_lineitm_seq, returned_count)
  VALUES(:NEW.organization_id,:NEW.rtl_loc_id,
        :NEW.wkstn_id,:NEW.business_date,:NEW.trans_seq,
        :NEW.rtrans_lineitm_seq,:NEW.returned_count);
    ELSE
      UPDATE trl_returned_item_count 
        SET
          returned_count = returned_count + :NEW.returned_count
        WHERE
          organization_id = :NEW.organization_id AND
          rtl_loc_id = :NEW.rtl_loc_id AND
          wkstn_id = :NEW.wkstn_id AND
          business_date = :NEW.business_date AND
          trans_seq = :NEW.trans_seq AND
          rtrans_lineitm_seq = :NEW.rtrans_lineitm_seq;
    END IF;
  END IF;
END;
/

SET SERVEROUTPUT ON SIZE 10000


-- ***************************************************************************
-- This script will apply after all schema artifacts have been upgraded to a given version.  It is
-- generally useful for performing conversions between legacy and modern representations of affected
-- data sets.
--
-- Source version:  18.0.x
-- Target version:  19.0.0
-- DB platform:     Oracle 12c
-- ***************************************************************************

UNDEFINE dbDataTableSpace;
UNDEFINE dbIndexTableSpace;

-- LEAVE BLANK LINE BELOW

INSERT INTO ctl_version_history (
    organization_id, base_schema_version, customer_schema_version, base_schema_date, 
    create_user_id, create_date, update_user_id, update_date)
VALUES (
    $(OrgID), '20.0.0.0.566', '0.0.0 - 0.0', SYSDATE, 
    'Oracle', SYSDATE, 'Oracle', SYSDATE);

COMMIT;
declare
vcnt int;
begin
	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='CREATE ANY TRIGGER';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE CREATE ANY TRIGGER FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='CREATE PUBLIC SYNONYM';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE CREATE PUBLIC SYNONYM FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='CREATE ANY VIEW';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE CREATE ANY VIEW FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='CREATE ANY DIRECTORY';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE CREATE ANY DIRECTORY FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='CREATE ANY SEQUENCE';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE CREATE ANY SEQUENCE FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='CREATE ANY PROCEDURE';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE CREATE ANY PROCEDURE FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='CREATE ANY TABLE';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE CREATE ANY TABLE FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='CREATE ANY JOB';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE CREATE ANY JOB FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='DROP ANY TRIGGER';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE DROP ANY TRIGGER FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='DROP PUBLIC SYNONYM';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE DROP PUBLIC SYNONYM FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='DROP ANY VIEW';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE DROP ANY VIEW FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='DROP ANY DIRECTORY';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE DROP ANY DIRECTORY FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='DROP ANY SEQUENCE';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE DROP ANY SEQUENCE FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='DROP ANY PROCEDURE';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE DROP ANY PROCEDURE FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='DROP ANY TABLE';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE DROP ANY TABLE FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_ROLE_PRIVS where GRANTEE=upper('$(DbSchema)') and GRANTED_ROLE='EXP_FULL_DATABASE';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE EXP_FULL_DATABASE FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='SELECT ANY DICTIONARY';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE SELECT ANY DICTIONARY FROM $(DbSchema)';
	end if;


	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='CREATE ANY SYNONYM';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'REVOKE CREATE ANY SYNONYM FROM $(DbSchema)';
	end if;

	select count(*) into vcnt from DBA_SYS_PRIVS where GRANTEE=upper('$(DbSchema)') and PRIVILEGE='GRANT ANY PRIVILEGE';

	if vcnt>0 then
		EXECUTE IMMEDIATE 'GRANT CREATE TRIGGER TO $(DbSchema)';
		EXECUTE IMMEDIATE 'GRANT CREATE VIEW TO $(DbSchema)';
		EXECUTE IMMEDIATE 'GRANT CREATE SEQUENCE TO $(DbSchema)';
		EXECUTE IMMEDIATE 'GRANT CREATE PROCEDURE TO $(DbSchema)';
		EXECUTE IMMEDIATE 'GRANT CREATE TABLE TO $(DbSchema)';
		EXECUTE IMMEDIATE 'GRANT CREATE TYPE TO $(DbSchema)';
		EXECUTE IMMEDIATE 'GRANT CREATE JOB TO $(DbSchema)';
		EXECUTE IMMEDIATE 'GRANT CREATE SYNONYM TO $(DbUser)';
		EXECUTE IMMEDIATE 'GRANT UNLIMITED TABLESPACE TO $(DbUser)';
		EXECUTE IMMEDIATE 'GRANT UNLIMITED TABLESPACE TO $(DbBackup)';

		EXECUTE IMMEDIATE 'REVOKE GRANT ANY PRIVILEGE FROM $(DbSchema)';
	end if;
end;
/

SPOOL OFF;
