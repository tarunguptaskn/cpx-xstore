SET SERVEROUTPUT ON SIZE 100000

SPOOL hybridize.log;

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
-- DB platform:     Oracle 12c
-- ***************************************************************************
PROMPT '**************************************';
PROMPT '*****        HYBRIDIZING         *****';
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
    dbms_output.put_line('     Step Create the trigger RECEIPT_DATA_COPY_CFDI starting...');
END;
/
BEGIN
  IF NOT SP_TABLE_EXISTS ('trn_receipt_data') THEN
    dbms_output.put_line('Trigger RECEIPT_DATA_COPY_CFDI not created because the table trn_receipt_data is missing');
  ELSE
  EXECUTE IMMEDIATE 'CREATE OR REPLACE TRIGGER RECEIPT_DATA_COPY_CFDI
  AFTER INSERT ON trn_receipt_data FOR EACH ROW
  BEGIN
    IF :NEW.receipt_id  = ''CFDI_XML'' THEN
      INSERT INTO trn_trans_attachment (organization_id, rtl_loc_id, business_date, wkstn_id, trans_seq, attachment_type, attachment_data, create_date, create_user_id)
      VALUES (:new.organization_id, :new.rtl_loc_id, :new.business_date, :new.wkstn_id, :new.trans_seq, ''MX_INVOICE'', :new.receipt_data, :new.create_date, ''SYSTEM'');
    END IF;
  END;';
    dbms_output.put_line('Trigger RECEIPT_DATA_COPY_CFDI created');
  END IF;
END;
/
BEGIN
    dbms_output.put_line('     Step Create the trigger RECEIPT_DATA_COPY_CFDI end.');
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
    dbms_output.put_line('     Step Add Column: DTX[FrRcptDuplicate] Column[[Field=documentType]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('cfra_rcpt_dup','document_type') THEN
       dbms_output.put_line('      Column cfra_rcpt_dup.document_type already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE cfra_rcpt_dup ADD document_type VARCHAR2(30 char)';
    dbms_output.put_line('     Column cfra_rcpt_dup.document_type created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[FrRcptDuplicate] Column[[Field=documentType]] end.');
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
    dbms_output.put_line('     Step Add Table: DTX[FrInvoiceDuplicate] starting...');
END;
/
BEGIN
  IF SP_TABLE_EXISTS ('CFRA_INVOICE_DUP') THEN
       dbms_output.put_line('      Table cfra_invoice_dup already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE TABLE cfra_invoice_dup(
organization_id NUMBER(10, 0) NOT NULL,
rtl_loc_id NUMBER(10, 0) NOT NULL,
wkstn_id NUMBER(10, 0) NOT NULL,
reprint_id VARCHAR2(30 char) NOT NULL,
doc_number VARCHAR2(30 char) NOT NULL,
reprint_number NUMBER(10, 0),
operator_code VARCHAR2(30 char),
business_date TIMESTAMP(6),
reprint_date TIMESTAMP(6),
document_type VARCHAR2(32 char) NOT NULL,
inv_rtl_loc_id NUMBER(10, 0),
inv_wkstn_id NUMBER(19, 0),
inv_business_year NUMBER(4, 0),
inv_sequence_id VARCHAR2(255 char),
inv_sequence_nbr NUMBER(19, 0),
postponement_flag NUMBER(1, 0) DEFAULT 0,
signature VARCHAR2(1024 char),
signature_source VARCHAR2(1024 char),
signature_version NUMBER(6, 0),
create_user_id VARCHAR2(256 char),
create_date TIMESTAMP(6),
update_user_id VARCHAR2(256 char),
update_date TIMESTAMP(6),
record_state VARCHAR2(30 char), 
CONSTRAINT pk_cfra_invoice_dup PRIMARY KEY (organization_id, rtl_loc_id, wkstn_id, reprint_id, doc_number) USING INDEX TABLESPACE &dbIndexTableSpace.
)
TABLESPACE &dbDataTableSpace.
';
        dbms_output.put_line('      Table cfra_invoice_dup created');
    EXECUTE IMMEDIATE 'GRANT SELECT,INSERT,UPDATE,DELETE ON cfra_invoice_dup TO POSUSERS,DBAUSERS';
  END IF;
END;
/

BEGIN
  IF SP_TABLE_EXISTS ('CFRA_INVOICE_DUP_P') THEN
       dbms_output.put_line('      Table CFRA_INVOICE_DUP_P already exists');
  ELSE
    CREATE_PROPERTY_TABLE('cfra_invoice_dup');
    dbms_output.put_line('     Table cfra_invoice_dup_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Table: DTX[FrInvoiceDuplicate] end.');
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



BEGIN
    dbms_output.put_line('     Step Trigger for Incoming Mexican pending invoice conversion created starting...');
END;
/
BEGIN
  EXECUTE IMMEDIATE 'CREATE OR REPLACE TRIGGER CIVC_INVOICE_MX_PENDING
  AFTER INSERT ON civc_invoice
  BEGIN
      UPDATE civc_invoice
      SET sequence_id = CONCAT(''PENDING_'', civc_invoice.sequence_id), invoice_type = CONCAT(''PENDING_GLOBAL_'', civc_invoice.invoice_type)
      WHERE CONCAT(CONCAT(civc_invoice.organization_id, ''::''), civc_invoice.rtl_loc_id) IN (SELECT CONCAT(CONCAT(organization_id, ''::''), rtl_loc_id) 
                                                                                      FROM loc_rtl_loc 
                                                                                      WHERE loc_rtl_loc.country = ''MX'')
      AND civc_invoice.ext_invoice_id IS NULL
      AND civc_invoice.sequence_id NOT LIKE ''PENDING%'';
  END;';
  dbms_output.put_line('Trigger CIVC_INVOICE_MX_PENDING created');
END;
/

BEGIN
  EXECUTE IMMEDIATE 'CREATE OR REPLACE TRIGGER CIVC_INVOICE_XREF_MX_PENDING
  AFTER INSERT ON civc_invoice_xref
  BEGIN
      UPDATE civc_invoice_xref
      SET sequence_id = CONCAT(''PENDING_'', sequence_id)
      WHERE CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(organization_id, ''::''), rtl_loc_id), ''::''), wkstn_id), ''::''), business_year), ''::''), CONCAT(''PENDING_'', sequence_id)), ''::''), sequence_nbr)
            IN (SELECT CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(organization_id, ''::''), rtl_loc_id), ''::''), wkstn_id), ''::''), business_year), ''::''), sequence_id), ''::''), sequence_nbr)
                                                                      FROM civc_invoice 
                                                                      WHERE sequence_id LIKE ''PENDING%'')
      AND sequence_id NOT LIKE ''PENDING%'';
  END;';
  dbms_output.put_line('Trigger CIVC_INVOICE_MX_PENDING created');
END;
/
BEGIN
    dbms_output.put_line('     Step Trigger for Incoming Mexican pending invoice conversion created end.');
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



BEGIN
    dbms_output.put_line('     Step Add Table: DTX[PtAts] starting...');
END;
/
BEGIN
  IF SP_TABLE_EXISTS ('CPOR_ATS') THEN
       dbms_output.put_line('      Table cpor_ats already exists');
  ELSE
    EXECUTE IMMEDIATE 'CREATE TABLE cpor_ats(
organization_id NUMBER(10, 0) NOT NULL,
rtl_loc_id NUMBER(10, 0) NOT NULL,
wkstn_id NUMBER(19, 0) NOT NULL,
sequence_id VARCHAR2(255 char) NOT NULL,
series VARCHAR2(1 char) NOT NULL,
year NUMBER(19, 0) NOT NULL,
ats VARCHAR2(70 char),
create_user_id VARCHAR2(256 char),
create_date TIMESTAMP(6),
update_user_id VARCHAR2(256 char),
update_date TIMESTAMP(6),
record_state VARCHAR2(30 char), 
CONSTRAINT pk_cpor_ats PRIMARY KEY (organization_id, rtl_loc_id, wkstn_id, sequence_id, series, year) USING INDEX TABLESPACE &dbIndexTableSpace.
)
TABLESPACE &dbDataTableSpace.
';
        dbms_output.put_line('      Table cpor_ats created');
    EXECUTE IMMEDIATE 'GRANT SELECT,INSERT,UPDATE,DELETE ON cpor_ats TO POSUSERS,DBAUSERS';
  END IF;
END;
/

BEGIN
  IF SP_TABLE_EXISTS ('CPOR_ATS_P') THEN
       dbms_output.put_line('      Table CPOR_ATS_P already exists');
  ELSE
    CREATE_PROPERTY_TABLE('cpor_ats');
    dbms_output.put_line('     Table cpor_ats_P created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Table: DTX[PtAts] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Fixing a missing DBMS_OUTPUT.ENABLE starting...');
END;
/
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

  DBMS_OUTPUT.ENABLE (500000);
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

 
BEGIN
    dbms_output.put_line('     Step Fixing a missing DBMS_OUTPUT.ENABLE end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[WorkstationConfigData] Column[[Field=linkColumn]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('loc_wkstn_config_data','link_column') THEN
       dbms_output.put_line('      Column loc_wkstn_config_data.link_column already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_wkstn_config_data ADD link_column VARCHAR2(30 char)';
    dbms_output.put_line('     Column loc_wkstn_config_data.link_column created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[WorkstationConfigData] Column[[Field=linkColumn]] end.');
END;
/



BEGIN
    dbms_output.put_line('     Step Add Column: DTX[LegalEntity] Column[[Field=establishmentCode, Field=registrationCity]] starting...');
END;
/
BEGIN
  IF SP_COLUMN_EXISTS ('loc_legal_entity','establishment_code') THEN
       dbms_output.put_line('      Column loc_legal_entity.establishment_code already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_legal_entity ADD establishment_code VARCHAR2(30 char)';
    dbms_output.put_line('     Column loc_legal_entity.establishment_code created');
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ('loc_legal_entity','registration_city') THEN
       dbms_output.put_line('      Column loc_legal_entity.registration_city already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE loc_legal_entity ADD registration_city VARCHAR2(254 char)';
    dbms_output.put_line('     Column loc_legal_entity.registration_city created');
  END IF;
END;
/

BEGIN
    dbms_output.put_line('     Step Add Column: DTX[LegalEntity] Column[[Field=establishmentCode, Field=registrationCity]] end.');
END;
/




PROMPT '***** Body scripts end *****';


-- Keep at end of the script

PROMPT '***************************************************************************';
PROMPT 'Database now hybridized to support clients running against the following versions:';
PROMPT '     19.0.*';
PROMPT '     20.0.0';
PROMPT 'Please run the corresponding un-hybridize script against this database once all';
PROMPT 'clients on earlier supported versions have been updated to the latest supported release.';
PROMPT '***************************************************************************';
/
