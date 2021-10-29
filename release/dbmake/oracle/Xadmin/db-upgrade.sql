SET SERVEROUTPUT ON SIZE 20000

SPOOL dbupdate.log;

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
-- DB platform:     Oracle 12c
-- ***************************************************************************
-- ***************************************************************************
-- ***************************************************************************
-- 19.0.x -> 20.0.0
-- ***************************************************************************
-- ***************************************************************************

BEGIN dbms_output.put_line('--- CREATING sp_column_exists --- '); END;
/
CREATE OR REPLACE function sp_column_exists (
 table_name     varchar2,
 column_name    varchar2
) return boolean is

 v_count integer;
 v_exists boolean;
 curSchema VARCHAR2(128);

begin

select sys_context( 'userenv', 'current_schema' ) into curSchema from dual;
select decode(count(*),0,0,1) into v_count
    from all_tab_columns
    where owner = upper(curSchema)
      and table_name = upper(sp_column_exists.table_name)
      and column_name = upper(sp_column_exists.column_name);

 if v_count = 1 then
   v_exists := true;
 else
   v_exists := false;
 end if;

 return v_exists;

end sp_column_exists;
/

BEGIN dbms_output.put_line('--- CREATING sp_table_exists --- '); END;
/
CREATE OR REPLACE function sp_table_exists (
  table_name varchar2
) return boolean is

  v_count integer;
  v_exists boolean;
  curSchema VARCHAR2(128);
begin

  select sys_context( 'userenv', 'current_schema' ) into curSchema from dual;
  select decode(count(*),0,0,1) into v_count
    from all_tables
    where owner = upper(curSchema)
      and table_name = upper(sp_table_exists.table_name);

  if v_count = 1 then
    v_exists := true;
  else
    v_exists := false;
  end if;

  return v_exists;

end sp_table_exists;
/

BEGIN dbms_output.put_line('--- CREATING sp_constraint_exists --- '); END;
/
CREATE OR REPLACE function sp_constraint_exists (
 table_name     varchar2,
 constraint_name    varchar2
) return boolean is

 v_count integer;
 v_exists boolean;
 curSchema VARCHAR2(128);

begin

select sys_context( 'userenv', 'current_schema' ) into curSchema from dual;
select decode(count(*),0,0,1) into v_count
    from all_constraints
    where owner = upper(curSchema)
      and table_name = upper(sp_constraint_exists.table_name)
      and constraint_name = upper(sp_constraint_exists.constraint_name);

 if v_count = 1 then
   v_exists := true;
 else
   v_exists := false;
 end if;

 return v_exists;

end sp_constraint_exists;
/

BEGIN dbms_output.put_line('--- CREATING sp_column_size --- '); END;
/
CREATE OR REPLACE FUNCTION sp_column_size (
 table_name     VARCHAR2,
 column_name    VARCHAR2,
 column_size    INTEGER
)
RETURN BOOLEAN IS
 v_count INTEGER;
 v_exists BOOLEAN;
 curSchema VARCHAR2(128);

BEGIN
  SELECT sys_context( 'userenv', 'current_schema' ) INTO curSchema FROM DUAL;
  SELECT decode(count(*),0,0,1) INTO v_count
    FROM all_tab_columns
    WHERE owner = upper(curSchema)
      AND table_name = upper(sp_column_size.table_name)
      AND column_name = upper(sp_column_size.column_name)
      AND char_length = sp_column_size.column_size;

  IF v_count = 1 THEN
    v_exists := true;
  ELSE
    v_exists := false;
  END IF;

  RETURN v_exists;

END sp_column_size;
/


--[RXPS-37101, RXPS-42003] START

-- 
-- TABLE: CFG_INTEGRATION
--
BEGIN
    IF SP_TABLE_EXISTS ('cfg_integration') THEN
           dbms_output.put_line('      cfg_integration already exists'); 
      
        IF SP_COLUMN_EXISTS ( 'cfg_integration','organization_id') THEN
            dbms_output.put_line('     cfg_integration.organization_id already exists');
        ELSE
             IF SP_CONSTRAINT_EXISTS ('cfg_integration','pk_cfg_integration') THEN
               dbms_output.put_line('     cfg_integration.pk_cfg_integration constraint does not exists');
               EXECUTE IMMEDIATE 'ALTER TABLE cfg_integration DROP CONSTRAINT pk_cfg_integration';
               dbms_output.put_line('     cfg_integration.pk_cfg_integration constraint REMOVED');
             ELSE
               dbms_output.put_line('     cfg_integration.pk_cfg_integration constraint does not exist');
             END IF;
            
             EXECUTE IMMEDIATE 'ALTER TABLE cfg_integration ADD organization_id NUMBER(10, 0) NULL';
             dbms_output.put_line('     cfg_integration.organization_id column created');
            
             FOR i IN (
              SELECT code FROM cfg_code_value c WHERE c.category = 'OrganizationId'
              ) LOOP
              dbms_output.put_line('    inserting existing integration data for organization '||i.code);          
              EXECUTE IMMEDIATE 'INSERT INTO CFG_INTEGRATION (organization_id,integration_system,implementation_type,integration_type,status,pause_integration_flag,auth_mode,CREATE_DATE,CREATE_USER_ID,UPDATE_DATE,UPDATE_USER_ID) SELECT '||i.code||', integration_system,implementation_type,integration_type,status,pause_integration_flag,auth_mode,CREATE_DATE,CREATE_USER_ID,UPDATE_DATE,UPDATE_USER_ID from cfg_integration where organization_id is null'; 
              END LOOP;
            
            dbms_output.put_line('    integration data for all the organizations inserted');
            EXECUTE IMMEDIATE 'DELETE FROM cfg_integration where organization_id IS NULL';
            dbms_output.put_line('    null organization rows are deleted');         
            
                
            EXECUTE IMMEDIATE 'ALTER TABLE cfg_integration MODIFY organization_id NUMBER(10, 0) NOT NULL';
            dbms_output.put_line('     cfg_integration.organization_id modified to add NOT NULL constraint');
            
            EXECUTE IMMEDIATE 'ALTER TABLE cfg_integration ADD CONSTRAINT pk_cfg_integration PRIMARY KEY(organization_id, integration_system, integration_type, implementation_type)';
            dbms_output.put_line('     cfg_integration.pk_cfg_integration constraint with org ID created');
            
        END IF;
  ELSE
    EXECUTE IMMEDIATE 'CREATE TABLE cfg_integration(
    organization_id       NUMBER(10, 0)     NOT NULL,
    integration_system    VARCHAR2(25 CHAR) NOT NULL,
    implementation_type   VARCHAR2(25 CHAR) NOT NULL,
    integration_type      VARCHAR2(25 CHAR) NOT NULL,
    status                VARCHAR2(25 CHAR) DEFAULT ''PENDING'' NOT NULL,
    pause_integration_flag NUMBER(1, 0) DEFAULT 0, 
    auth_mode             VARCHAR2(25 CHAR),
    create_date           TIMESTAMP(6),
    create_user_id        VARCHAR2(256 CHAR),
    update_date           TIMESTAMP(6),
    update_user_id        VARCHAR2(256 CHAR),
    CONSTRAINT pk_cfg_integration PRIMARY KEY (organization_id, integration_system, integration_type, implementation_type))';
        dbms_output.put_line('      cfg_integration created');

        EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON cfg_integration TO POSUSERS';
            DBMS_OUTPUT.PUT_LINE('      Grant completed.');
        EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON cfg_integration TO DBAUSERS';
            DBMS_OUTPUT.PUT_LINE('      Grant completed.');
  END IF;
END;
/

-- 
-- TABLE: CFG_INTEGRATION_P
--
BEGIN
    IF SP_TABLE_EXISTS ('cfg_integration_p') THEN
           dbms_output.put_line('      cfg_integration_p already exists'); 
      
        IF SP_COLUMN_EXISTS ( 'cfg_integration_p','organization_id') THEN
            dbms_output.put_line('     cfg_integration_p.organization_id already exists');
        ELSE
             IF SP_CONSTRAINT_EXISTS ('cfg_integration_p','pk_cfg_integration_p') THEN 
               EXECUTE IMMEDIATE 'ALTER TABLE cfg_integration_p DROP CONSTRAINT pk_cfg_integration_p';
               dbms_output.put_line('     cfg_integration_p.pk_cfg_integration_p constraint REMOVED');
             ELSE
               dbms_output.put_line('     cfg_integration_p.pk_cfg_integration_p constraint does not exist');
             END IF;
            
             EXECUTE IMMEDIATE 'ALTER TABLE cfg_integration_p ADD organization_id NUMBER(10, 0) NULL';
             dbms_output.put_line('     cfg_integration_p.organization_id created');
             dbms_output.put_line('     Re-aligning the parent-child relationship between cfg_integration and cfg_integration_p');
             EXECUTE IMMEDIATE 'UPDATE cfg_integration_p SET integration_system = integration_type, implementation_type = integration_system, integration_type = implementation_type WHERE integration_system NOT IN (''ORCE'',''OROB'',''OCDS'')';
             FOR i IN (
              SELECT code FROM cfg_code_value c WHERE c.category = 'OrganizationId'
              ) LOOP
              dbms_output.put_line('    inserting existing integration data for organization '||i.code);          
              EXECUTE IMMEDIATE 'INSERT INTO CFG_INTEGRATION_P (organization_id,INTEGRATION_SYSTEM,IMPLEMENTATION_TYPE,INTEGRATION_TYPE,PROPERTY_CODE,TYPE,STRING_VALUE,DATE_VALUE,DECIMAL_VALUE,CREATE_DATE,CREATE_USER_ID,UPDATE_DATE,UPDATE_USER_ID) SELECT '||i.code||', INTEGRATION_SYSTEM,IMPLEMENTATION_TYPE,INTEGRATION_TYPE,PROPERTY_CODE,TYPE,STRING_VALUE,DATE_VALUE,DECIMAL_VALUE,CREATE_DATE,CREATE_USER_ID,UPDATE_DATE,UPDATE_USER_ID FROM cfg_integration_p WHERE organization_id IS NULL'; 
              END LOOP;
            
            dbms_output.put_line('    integration data for all the organizations inserted');
            EXECUTE IMMEDIATE 'DELETE FROM cfg_integration_p where organization_id IS NULL';
            dbms_output.put_line('    null organization rows are deleted');         
            
                
            EXECUTE IMMEDIATE 'ALTER TABLE cfg_integration_p MODIFY organization_id NUMBER(10, 0) NOT NULL';
            dbms_output.put_line('     cfg_integration.organization_id modified to add NOT NULL constraint');
            
            EXECUTE IMMEDIATE 'ALTER TABLE cfg_integration_p ADD CONSTRAINT pk_cfg_integration_p PRIMARY KEY(organization_id, integration_system, integration_type, implementation_type, property_code)';
            dbms_output.put_line('     cfg_integration_p.pk_cfg_integration_p constraint with org ID created');
            
        END IF;
  ELSE
    EXECUTE IMMEDIATE 'CREATE TABLE cfg_integration_p (
    organization_id         NUMBER(10, 0)      NOT NULL,
    integration_system      VARCHAR2(25 CHAR)  NOT NULL,
    implementation_type     VARCHAR2(25 CHAR)  NOT NULL,
    integration_type        VARCHAR2(25 CHAR)  NOT NULL,
    property_code           VARCHAR2(30 CHAR)  NOT NULL,
    type                    VARCHAR2(30 CHAR),   
    string_value            VARCHAR2(4000 CHAR),
    date_value              TIMESTAMP(6),       
    decimal_value           NUMBER(17,6),
    create_date             TIMESTAMP(6),
    create_user_id          VARCHAR2(256 CHAR),
    update_date             TIMESTAMP(6),
    update_user_id          VARCHAR2(256 CHAR),  
    CONSTRAINT pk_cfg_integration_p PRIMARY KEY (organization_id, integration_system, integration_type, implementation_type, property_code))'
;
        dbms_output.put_line('      cfg_integration_p created');

        EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON cfg_integration_p TO POSUSERS';
            DBMS_OUTPUT.PUT_LINE('      Grant completed.');
        EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON cfg_integration_p TO DBAUSERS';
            DBMS_OUTPUT.PUT_LINE('      Grant completed.');
  END IF;
END;
/
--[RXPS-37101, RXPS-42003] END

--[RXPS-42822] START
BEGIN
    IF SP_COLUMN_EXISTS ( 'dtx_field','sort_order') THEN
        dbms_output.put_line('     dtx_field.sort_order already exists');
    ELSE
        EXECUTE IMMEDIATE 'ALTER TABLE dtx_field ADD sort_order NUMBER(10, 0)';
        dbms_output.put_line('     dtx_field.sort_order created');
    END IF;
END;
/

BEGIN
    IF SP_COLUMN_EXISTS ( 'dtx_relationship','use_parent_pm') THEN
        EXECUTE IMMEDIATE 'ALTER TABLE dtx_relationship DROP COLUMN use_parent_pm';
        dbms_output.put_line('     dtx_relationship.use_parent_pm dropped');
    ELSE
        dbms_output.put_line('     dtx_relationship.use_parent_pm already dropped');
    END IF;
END;
/
--[RXPS-42822] END

--[RXPS-43299] START
DECLARE
  v_count integer;

BEGIN

  -- Add new privileges for Store Enrollment
  EXECUTE IMMEDIATE 'DELETE FROM cfg_privilege where privilege_id in (''ADMN_STORE_AUTH_MANAGER'',''ADMN_STORE_ENROLL'')';
  EXECUTE IMMEDIATE 'INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc) VALUES (''Administration'', ''ADMN_STORE_AUTH_MANAGER'', ''Store Authorization Manager'', ''Store Authorization Manager'')';
  EXECUTE IMMEDIATE 'INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc) VALUES (''Administration'', ''ADMN_STORE_ENROLL'', ''Store Enrollment'', ''Store Enrollment'')';

  -- Add new Xoffice Cloud Service Enrollment privilege if CLOUD_MIGRATION privilege exists. CLOUD_MIGRATION was for on-premise only
  SELECT count(*) INTO v_count  FROM cfg_privilege WHERE privilege_id = 'CLOUD_MIGRATION';
   IF v_count > 0 THEN
     dbms_output.put_line('     CLOUD_MIGRATION privilege exists');
     EXECUTE IMMEDIATE 'DELETE FROM cfg_privilege WHERE privilege_id = ''ADMN_XOFFICE_CS_STORE_ENROLL''';
     EXECUTE IMMEDIATE 'INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc) VALUES (''Administration'', ''ADMN_XOFFICE_CS_STORE_ENROLL'', ''Xoffice Cloud Store Enrollment'', ''Xoffice Cloud Store Enrollment'')';
   END IF;

  -- Assign Xoffice Cloud Store Enrollment privileges to any role having 'CLOUD_MIGRATION'
  EXECUTE IMMEDIATE 'INSERT INTO cfg_role_privilege (organization_id, role_id, privilege_id) SELECT organization_id, role_id, ''ADMN_STORE_AUTH_MANAGER'' FROM cfg_role_privilege WHERE privilege_id = ''CLOUD_MIGRATION''';
  EXECUTE IMMEDIATE 'INSERT INTO cfg_role_privilege (organization_id, role_id, privilege_id) SELECT organization_id, role_id, ''ADMN_STORE_ENROLL'' FROM cfg_role_privilege WHERE privilege_id = ''CLOUD_MIGRATION''';
  EXECUTE IMMEDIATE 'INSERT INTO cfg_role_privilege (organization_id, role_id, privilege_id) SELECT organization_id, role_id, ''ADMN_XOFFICE_CS_STORE_ENROLL'' FROM cfg_role_privilege WHERE privilege_id = ''CLOUD_MIGRATION''';

  -- Remove all references to obsolete CLOUD_MIGRATION privilege
  EXECUTE IMMEDIATE 'DELETE FROM cfg_privilege WHERE privilege_id = ''CLOUD_MIGRATION''';
  EXECUTE IMMEDIATE 'DELETE FROM cfg_role_privilege WHERE privilege_id = ''CLOUD_MIGRATION''';

END;
/
--[RXPS-43299] END

--[RXPS-43327]
BEGIN

  UPDATE CFG_USER set USER_NAME=UPPER(USER_NAME);
  UPDATE CFG_USER_NODE set USER_NAME=UPPER(USER_NAME);
  UPDATE CFG_USER_ORG_ROLE set USER_NAME=UPPER(USER_NAME);
  UPDATE CFG_USER_PASSWORD set USER_NAME=UPPER(USER_NAME);
  UPDATE DPL_DEPLOYMENT_EMAIL set USER_NAME=UPPER(USER_NAME);
  UPDATE DPL_DEPLOYMENT_PLAN_EMAILS set USER_NAME=UPPER(USER_NAME);

END;
/
--[/RXPS-43327]

-- [RXPS-42344] START
BEGIN
    IF SP_COLUMN_EXISTS ('dat_legal_entity_change','tax_office_code') THEN   
      dbms_output.put_line('dat_legal_entity_change.tax_office_code already exists');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD tax_office_code varchar2(30 char) NULL';
      dbms_output.put_line('dat_legal_entity_change.tax_office_code CREATED');
    END IF;
END;
/
-- [RXPS-42344] END

-- [RXPS-44815]
BEGIN
  IF SP_COLUMN_EXISTS ( 'dat_legal_entity_change','statistical_code') THEN
    dbms_output.put_line('     dat_legal_entity_change..statistical_code already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD statistical_code VARCHAR2(30 char)';
    dbms_output.put_line('     dat_legal_entity_change..statistical_code created');
  END IF;
END;
/
-- [RXPS-44815] END

-- [RXPS-51583]
UPDATE cfg_customization
   SET NAME = CONCAT('version1/', NAME) 
 WHERE NAME NOT LIKE 'version1/%'
   AND CUSTOMIZATION_TYPE 
    IN ('ACTION_CONFIG', 'MENU_CONFIG', 'PM_TYPE_MAPPING_CONFIG', 
        'SYSTEM_CONFIG', 'SYSTEM_CONFIG_METADATA','TRANSLATIONS');
/
-- [/RXPS-51583]


-- [RXPS-47686]
BEGIN
  IF SP_COLUMN_EXISTS ( 'dpl_deployment','staging_progress') THEN
    dbms_output.put_line('     dpl_deployment..staging_progress already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE dpl_deployment ADD staging_progress NUMBER(3, 0) DEFAULT 0';
    dbms_output.put_line('     dpl_deployment..staging_progress created');
  END IF;
END;
/
-- [RXPS-47686] END

-- RXPS-48532 - START 
ALTER TABLE CFG_TENDER_OPTIONS_CHANGE MODIFY FISCAL_TNDR_ID VARCHAR2(60 char);
/
-- RXPS-48532 - END

-- [RXPS-47081] 
BEGIN
    IF SP_COLUMN_EXISTS ( 'dtx_def','table_name') THEN
        EXECUTE IMMEDIATE 'ALTER TABLE dtx_def MODIFY table_name VARCHAR2(128 char)';
        dbms_output.put_line('     dtx_def.table_name modified');
    ELSE
        dbms_output.put_line('     dtx_def.table_name does not exist');
    END IF;
END;
/
-- [RXPS-47081] - END

-- [RXPS-49184] START
BEGIN
    IF SP_COLUMN_EXISTS ('ocds_subtask_details','path') THEN   
      dbms_output.put_line('ocds_subtask_details.path already exists');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE ocds_subtask_details ADD path varchar2(120 char)';
      dbms_output.put_line('ocds_subtask_details.path CREATED');
    END IF;
END;
/
-- [PS-49184] END

-- [RXPS-44418] START
BEGIN
  IF SP_COLUMN_EXISTS ( 'dat_exchange_rate_change','print_as_inverted') THEN
    dbms_output.put_line('     dat_exchange_rate_change.print_as_inverted already exists');
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE dat_exchange_rate_change ADD print_as_inverted NUMBER(1, 0) DEFAULT 0';
    dbms_output.put_line('     dat_exchange_rate_change.print_as_inverted created');
  END IF;
END;
/
-- [RXPS-44418] END

--[RXPS-49182] START
BEGIN
  IF SP_COLUMN_EXISTS ( 'ocds_subtask_details','active') THEN
    dbms_output.put_line('creating cfg_integration_p records for OCDS enable subtask properties');
    FOR i IN (SELECT organization_id, subtask_id FROM OCDS_SUBTASK_DETAILS)
    LOOP
        dbms_output.put_line('     inserting ENABLE_'|| i.subtask_id || '[orgId=' || i.organization_id || ']' );
        EXECUTE IMMEDIATE 'INSERT INTO cfg_integration_p (organization_id, integration_system, implementation_type, integration_type, property_code, type, decimal_value, create_date, create_user_id, update_date, update_user_id)
        SELECT organization_id, integration_system, implementation_type, integration_type, ''ENABLE_'' || i.subtask_id, ''BOOLEAN'', NVL((SELECT active FROM OCDS_SUBTASK_DETAILS s where s.organization_id = c.organization_id AND s.subtask_id = i.subtask_id), 0) as decimal_value,create_date, create_user_id, update_date, update_user_id
        FROM cfg_integration c 
        WHERE c.integration_system = ''OCDS'' AND  c.organization_id = i.organization_id AND (SELECT decimal_value FROM cfg_integration_p p WHERE p.organization_id = i.organization_id AND p.integration_system = c.integration_system AND p.implementation_type = c.implementation_type AND p.integration_type = c.integration_type AND p.property_code = (''ENABLE_'' || i.subtask_id)) IS NULL';
    END LOOP;
  END IF;
END;
/

BEGIN
  IF SP_COLUMN_EXISTS ( 'ocds_subtask_details','active') THEN
      EXECUTE IMMEDIATE 'ALTER TABLE ocds_subtask_details DROP COLUMN active';
      dbms_output.put_line('     ocds_subtask_details.active dropped');
  ELSE
      dbms_output.put_line('     ocds_subtask_details.active already dropped');
  END IF;

END;
/
-- [RXPS-49182] - END

-- [RXPS-49862] START
BEGIN
    IF SP_COLUMN_EXISTS ('dat_legal_entity_change','legal_form') THEN   
      dbms_output.put_line('dat_legal_entity_change.legal_form already added');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD legal_form varchar2(60 char) NULL';
      dbms_output.put_line('dat_legal_entity_change.legal_form CREATED');
    END IF;
END;
/

BEGIN
    IF SP_COLUMN_EXISTS ('dat_legal_entity_change','social_capital') THEN   
      dbms_output.put_line('dat_legal_entity_change.social_capital already added');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD social_capital varchar2(60 char) NULL';
      dbms_output.put_line('dat_legal_entity_change.social_capital CREATED');
    END IF;
END;
/

BEGIN
    IF SP_COLUMN_EXISTS ('dat_legal_entity_change','companies_register_number') THEN   
      dbms_output.put_line('dat_legal_entity_change.companies_register_number already added');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD companies_register_number varchar2(30 char) NULL';
      dbms_output.put_line('dat_legal_entity_change.companies_register_number CREATED');
    END IF;
END;
/

BEGIN
    IF SP_COLUMN_EXISTS ('dat_legal_entity_change','fax_number') THEN
      dbms_output.put_line('dat_legal_entity_change.fax_number already added');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD fax_number varchar2(32 char) NULL';
      dbms_output.put_line('dat_legal_entity_change.fax_number CREATED');
    END IF;
END;
/

BEGIN
    IF SP_COLUMN_EXISTS ('dat_legal_entity_change','phone_number') THEN
      dbms_output.put_line('dat_legal_entity_change.phone_number already added');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD phone_number varchar2(32 char) NULL';
      dbms_output.put_line('dat_legal_entity_change.phone_number CREATED');
    END IF;
END;
/

BEGIN
    IF SP_COLUMN_EXISTS ('dat_legal_entity_change','web_site') THEN
      dbms_output.put_line('dat_legal_entity_change.web_site already added');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD web_site varchar2(254 char) NULL';
      dbms_output.put_line('dat_legal_entity_change.web_site CREATED');
    END IF;
END;
/
-- [RXPS-49862] END

-- [RXPS-53350] START

BEGIN
    IF NOT SP_COLUMN_EXISTS ('ocds_on_demand','create_user_id') THEN
      dbms_output.put_line('ocds_on_demand.create_user_id does not exist');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE ocds_on_demand MODIFY create_user_id varchar2(256 char)';
      dbms_output.put_line('ocds_on_demand.create_user_id CREATED');
    END IF;
END;
/

BEGIN
    IF NOT SP_COLUMN_EXISTS ('ocds_on_demand','update_user_id') THEN
      dbms_output.put_line('ocds_on_demand.update_user_id does not exist');
    ELSE
      EXECUTE IMMEDIATE 'ALTER TABLE ocds_on_demand MODIFY update_user_id varchar2(256 char)';
      dbms_output.put_line('ocds_on_demand.update_user_id CREATED');
    END IF;
END;
/

-- [RXPS-53350] END

-- [RXPS-53422] START

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_ALERT_SEVERITY_THRESHOLD','CREATE_DATE') THEN
  dbms_output.put_line('CFG_ALERT_SEVERITY_THRESHOLD.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_ALERT_SEVERITY_THRESHOLD MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_ALERT_SEVERITY_THRESHOLD.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_ALERT_SEVERITY_THRESHOLD','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_ALERT_SEVERITY_THRESHOLD.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_ALERT_SEVERITY_THRESHOLD MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_ALERT_SEVERITY_THRESHOLD.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_BASE_FEATURE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_BASE_FEATURE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_BASE_FEATURE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_BASE_FEATURE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_BASE_FEATURE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_BASE_FEATURE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_BASE_FEATURE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_BASE_FEATURE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_BROADCASTER','CREATE_DATE') THEN
  dbms_output.put_line('CFG_BROADCASTER.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_BROADCASTER MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_BROADCASTER.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_BROADCASTER','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_BROADCASTER.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_BROADCASTER MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_BROADCASTER.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CODE_CATEGORY','CREATE_DATE') THEN
  dbms_output.put_line('CFG_CODE_CATEGORY.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CODE_CATEGORY MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CODE_CATEGORY.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CODE_CATEGORY','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_CODE_CATEGORY.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CODE_CATEGORY MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CODE_CATEGORY.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CODE_VALUE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_CODE_VALUE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CODE_VALUE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CODE_VALUE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CODE_VALUE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_CODE_VALUE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CODE_VALUE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CODE_VALUE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CODE_VALUE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_CODE_VALUE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CODE_VALUE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CODE_VALUE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CODE_VALUE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_CODE_VALUE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CODE_VALUE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CODE_VALUE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CRITICAL_ALERT_EMAIL','CREATE_DATE') THEN
  dbms_output.put_line('CFG_CRITICAL_ALERT_EMAIL.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CRITICAL_ALERT_EMAIL MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CRITICAL_ALERT_EMAIL.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CRITICAL_ALERT_EMAIL','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_CRITICAL_ALERT_EMAIL.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CRITICAL_ALERT_EMAIL MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CRITICAL_ALERT_EMAIL.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CUSTOMIZATION','CREATE_DATE') THEN
  dbms_output.put_line('CFG_CUSTOMIZATION.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CUSTOMIZATION MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CUSTOMIZATION.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_CUSTOMIZATION','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_CUSTOMIZATION.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_CUSTOMIZATION MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_CUSTOMIZATION.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_DESCRIPTION_TRANSLATION','CREATE_DATE') THEN
  dbms_output.put_line('CFG_DESCRIPTION_TRANSLATION.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_DESCRIPTION_TRANSLATION MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_DESCRIPTION_TRANSLATION.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_DESCRIPTION_TRANSLATION','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_DESCRIPTION_TRANSLATION.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_DESCRIPTION_TRANSLATION MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_DESCRIPTION_TRANSLATION.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_DISCOUNT_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_DISCOUNT_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_DISCOUNT_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_DISCOUNT_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_DISCOUNT_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_DISCOUNT_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_DISCOUNT_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_DISCOUNT_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_DSC_GROUP_MAPPING_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_DSC_GROUP_MAPPING_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_DSC_GROUP_MAPPING_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_DSC_GROUP_MAPPING_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_DSC_GROUP_MAPPING_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_DSC_GROUP_MAPPING_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_DSC_GROUP_MAPPING_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_DSC_GROUP_MAPPING_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_DSC_VALID_ITEM_TYPE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_DSC_VALID_ITEM_TYPE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_DSC_VALID_ITEM_TYPE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_DSC_VALID_ITEM_TYPE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_DSC_VALID_ITEM_TYPE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_DSC_VALID_ITEM_TYPE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_DSC_VALID_ITEM_TYPE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_DSC_VALID_ITEM_TYPE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_INTEGRATION','CREATE_DATE') THEN
  dbms_output.put_line('CFG_INTEGRATION.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_INTEGRATION MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_INTEGRATION.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_INTEGRATION','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_INTEGRATION.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_INTEGRATION MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_INTEGRATION.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_INTEGRATION_P','CREATE_DATE') THEN
  dbms_output.put_line('CFG_INTEGRATION_P.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_INTEGRATION_P MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_INTEGRATION_P.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_INTEGRATION_P','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_INTEGRATION_P.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_INTEGRATION_P MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_INTEGRATION_P.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_LANDSCAPE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_LANDSCAPE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_LANDSCAPE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_LANDSCAPE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_LANDSCAPE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_LANDSCAPE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_LANDSCAPE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_LANDSCAPE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_LANDSCAPE_GROUP','CREATE_DATE') THEN
  dbms_output.put_line('CFG_LANDSCAPE_GROUP.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_LANDSCAPE_GROUP MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_LANDSCAPE_GROUP.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_LANDSCAPE_GROUP','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_LANDSCAPE_GROUP.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_LANDSCAPE_GROUP MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_LANDSCAPE_GROUP.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_LANDSCAPE_RANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_LANDSCAPE_RANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_LANDSCAPE_RANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_LANDSCAPE_RANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_LANDSCAPE_RANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_LANDSCAPE_RANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_LANDSCAPE_RANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_LANDSCAPE_RANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_MENU_CONFIG','CREATE_DATE') THEN
  dbms_output.put_line('CFG_MENU_CONFIG.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_MENU_CONFIG MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_MENU_CONFIG.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_MENU_CONFIG','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_MENU_CONFIG.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_MENU_CONFIG MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_MENU_CONFIG.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_MESSAGE_TRANSLATION','CREATE_DATE') THEN
  dbms_output.put_line('CFG_MESSAGE_TRANSLATION.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_MESSAGE_TRANSLATION MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_MESSAGE_TRANSLATION.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_MESSAGE_TRANSLATION','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_MESSAGE_TRANSLATION.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_MESSAGE_TRANSLATION MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_MESSAGE_TRANSLATION.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_ORG_HIERARCHY_LEVEL','CREATE_DATE') THEN
  dbms_output.put_line('CFG_ORG_HIERARCHY_LEVEL.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_ORG_HIERARCHY_LEVEL MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_ORG_HIERARCHY_LEVEL.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_ORG_HIERARCHY_LEVEL','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_ORG_HIERARCHY_LEVEL.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_ORG_HIERARCHY_LEVEL MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_ORG_HIERARCHY_LEVEL.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PERSONALITY','CREATE_DATE') THEN
  dbms_output.put_line('CFG_PERSONALITY.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PERSONALITY MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PERSONALITY.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PERSONALITY','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_PERSONALITY.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PERSONALITY MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PERSONALITY.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PERSONALITY_BASE_FEATURE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_PERSONALITY_BASE_FEATURE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PERSONALITY_BASE_FEATURE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PERSONALITY_BASE_FEATURE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PERSONALITY_BASE_FEATURE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_PERSONALITY_BASE_FEATURE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PERSONALITY_BASE_FEATURE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PERSONALITY_BASE_FEATURE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PERSONALITY_ELEMENT','CREATE_DATE') THEN
  dbms_output.put_line('CFG_PERSONALITY_ELEMENT.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PERSONALITY_ELEMENT MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PERSONALITY_ELEMENT.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PERSONALITY_ELEMENT','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_PERSONALITY_ELEMENT.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PERSONALITY_ELEMENT MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PERSONALITY_ELEMENT.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PRIVILEGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_PRIVILEGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PRIVILEGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PRIVILEGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PRIVILEGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_PRIVILEGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PRIVILEGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PRIVILEGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PROFILE_ELEMENT','CREATE_DATE') THEN
  dbms_output.put_line('CFG_PROFILE_ELEMENT.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PROFILE_ELEMENT MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PROFILE_ELEMENT.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PROFILE_ELEMENT','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_PROFILE_ELEMENT.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PROFILE_ELEMENT MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PROFILE_ELEMENT.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PROFILE_ELEMENT_CHANGES','CREATE_DATE') THEN
  dbms_output.put_line('CFG_PROFILE_ELEMENT_CHANGES.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PROFILE_ELEMENT_CHANGES MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PROFILE_ELEMENT_CHANGES.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PROFILE_ELEMENT_CHANGES','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_PROFILE_ELEMENT_CHANGES.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PROFILE_ELEMENT_CHANGES MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PROFILE_ELEMENT_CHANGES.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PROFILE_ELEMENT_VERSION','CREATE_DATE') THEN
  dbms_output.put_line('CFG_PROFILE_ELEMENT_VERSION.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PROFILE_ELEMENT_VERSION MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PROFILE_ELEMENT_VERSION.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PROFILE_ELEMENT_VERSION','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_PROFILE_ELEMENT_VERSION.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PROFILE_ELEMENT_VERSION MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PROFILE_ELEMENT_VERSION.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PROFILE_GROUP','CREATE_DATE') THEN
  dbms_output.put_line('CFG_PROFILE_GROUP.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PROFILE_GROUP MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PROFILE_GROUP.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_PROFILE_GROUP','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_PROFILE_GROUP.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_PROFILE_GROUP MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_PROFILE_GROUP.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_REASON_CODE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_REASON_CODE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_REASON_CODE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_REASON_CODE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_REASON_CODE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_REASON_CODE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_REASON_CODE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_REASON_CODE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_REASON_CODE_P_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_REASON_CODE_P_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_REASON_CODE_P_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_REASON_CODE_P_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_REASON_CODE_P_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_REASON_CODE_P_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_REASON_CODE_P_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_REASON_CODE_P_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_REASON_CODE_TYPE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_REASON_CODE_TYPE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_REASON_CODE_TYPE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_REASON_CODE_TYPE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_REASON_CODE_TYPE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_REASON_CODE_TYPE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_REASON_CODE_TYPE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_REASON_CODE_TYPE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_RECEIPT_TEXT_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_RECEIPT_TEXT_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_RECEIPT_TEXT_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_RECEIPT_TEXT_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_RECEIPT_TEXT_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_RECEIPT_TEXT_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_RECEIPT_TEXT_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_RECEIPT_TEXT_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_RESOURCE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_RESOURCE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_RESOURCE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_RESOURCE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_RESOURCE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_RESOURCE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_RESOURCE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_RESOURCE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_ROLE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_ROLE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_ROLE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_ROLE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_ROLE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_ROLE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_ROLE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_ROLE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_ROLE_PRIVILEGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_ROLE_PRIVILEGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_ROLE_PRIVILEGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_ROLE_PRIVILEGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_ROLE_PRIVILEGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_ROLE_PRIVILEGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_ROLE_PRIVILEGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_ROLE_PRIVILEGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SEC_GROUP_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_SEC_GROUP_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SEC_GROUP_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SEC_GROUP_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SEC_GROUP_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_SEC_GROUP_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SEC_GROUP_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SEC_GROUP_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SEC_PRIVILEGE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_SEC_PRIVILEGE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SEC_PRIVILEGE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SEC_PRIVILEGE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SEC_PRIVILEGE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_SEC_PRIVILEGE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SEC_PRIVILEGE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SEC_PRIVILEGE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SEQUENCE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_SEQUENCE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SEQUENCE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SEQUENCE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SEQUENCE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_SEQUENCE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SEQUENCE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SEQUENCE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SEQUENCE_PART','CREATE_DATE') THEN
  dbms_output.put_line('CFG_SEQUENCE_PART.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SEQUENCE_PART MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SEQUENCE_PART.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SEQUENCE_PART','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_SEQUENCE_PART.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SEQUENCE_PART MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SEQUENCE_PART.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_STORE_PERSONALITY','CREATE_DATE') THEN
  dbms_output.put_line('CFG_STORE_PERSONALITY.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_STORE_PERSONALITY MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_STORE_PERSONALITY.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_STORE_PERSONALITY','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_STORE_PERSONALITY.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_STORE_PERSONALITY MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_STORE_PERSONALITY.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SYSTEM_SETTING','CREATE_DATE') THEN
  dbms_output.put_line('CFG_SYSTEM_SETTING.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SYSTEM_SETTING MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SYSTEM_SETTING.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_SYSTEM_SETTING','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_SYSTEM_SETTING.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_SYSTEM_SETTING MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_SYSTEM_SETTING.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TAB_PROPERTY','CREATE_DATE') THEN
  dbms_output.put_line('CFG_TAB_PROPERTY.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TAB_PROPERTY MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TAB_PROPERTY.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TAB_PROPERTY','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_TAB_PROPERTY.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TAB_PROPERTY MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TAB_PROPERTY.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_AVAILABILITY_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_AVAILABILITY_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_AVAILABILITY_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_AVAILABILITY_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_AVAILABILITY_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_AVAILABILITY_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_AVAILABILITY_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_AVAILABILITY_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_DENOMINATION_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_DENOMINATION_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_DENOMINATION_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_DENOMINATION_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_DENOMINATION_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_DENOMINATION_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_DENOMINATION_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_DENOMINATION_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_OPTIONS_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_OPTIONS_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_OPTIONS_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_OPTIONS_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_OPTIONS_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_OPTIONS_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_OPTIONS_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_OPTIONS_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_SETTINGS_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_SETTINGS_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_SETTINGS_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_SETTINGS_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_SETTINGS_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_SETTINGS_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_SETTINGS_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_SETTINGS_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_TYPE_CATEGORY','CREATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_TYPE_CATEGORY.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_TYPE_CATEGORY MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_TYPE_CATEGORY.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_TENDER_TYPE_CATEGORY','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_TENDER_TYPE_CATEGORY.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_TENDER_TYPE_CATEGORY MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_TENDER_TYPE_CATEGORY.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_UPLOAD_RECORD','CREATE_DATE') THEN
  dbms_output.put_line('CFG_UPLOAD_RECORD.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_UPLOAD_RECORD MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_UPLOAD_RECORD.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_UPLOAD_RECORD','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_UPLOAD_RECORD.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_UPLOAD_RECORD MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_UPLOAD_RECORD.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_UPLOAD_RECORD_HASH','CREATE_DATE') THEN
  dbms_output.put_line('CFG_UPLOAD_RECORD_HASH.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_UPLOAD_RECORD_HASH MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_UPLOAD_RECORD_HASH.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_UPLOAD_RECORD_HASH','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_UPLOAD_RECORD_HASH.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_UPLOAD_RECORD_HASH MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_UPLOAD_RECORD_HASH.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_USER','CREATE_DATE') THEN
  dbms_output.put_line('CFG_USER.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_USER MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_USER.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_USER','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_USER.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_USER MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_USER.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_USER_NODE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_USER_NODE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_USER_NODE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_USER_NODE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_USER_NODE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_USER_NODE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_USER_NODE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_USER_NODE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_USER_ORG_ROLE','CREATE_DATE') THEN
  dbms_output.put_line('CFG_USER_ORG_ROLE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_USER_ORG_ROLE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_USER_ORG_ROLE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_USER_ORG_ROLE','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_USER_ORG_ROLE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_USER_ORG_ROLE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_USER_ORG_ROLE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_USER_PASSWORD','CREATE_DATE') THEN
  dbms_output.put_line('CFG_USER_PASSWORD.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_USER_PASSWORD MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_USER_PASSWORD.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_USER_PASSWORD','EFFECTIVE_DATE') THEN
  dbms_output.put_line('CFG_USER_PASSWORD.EFFECTIVE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_USER_PASSWORD MODIFY EFFECTIVE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_USER_PASSWORD.EFFECTIVE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('CFG_USER_PASSWORD','UPDATE_DATE') THEN
  dbms_output.put_line('CFG_USER_PASSWORD.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE CFG_USER_PASSWORD MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('CFG_USER_PASSWORD.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ADDRESS_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_ADDRESS_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ADDRESS_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ADDRESS_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ADDRESS_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_ADDRESS_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ADDRESS_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ADDRESS_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ATTACHED_ITEM_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_ATTACHED_ITEM_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ATTACHED_ITEM_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ATTACHED_ITEM_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ATTACHED_ITEM_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_ATTACHED_ITEM_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ATTACHED_ITEM_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ATTACHED_ITEM_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_DATAMANAGER_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_DATAMANAGER_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_DATAMANAGER_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_DATAMANAGER_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_DATAMANAGER_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_DATAMANAGER_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_DATAMANAGER_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_DATAMANAGER_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EMP_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_EMP_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EMP_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EMP_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EMP_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_EMP_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EMP_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EMP_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EMP_CUST_GROUP_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_EMP_CUST_GROUP_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EMP_CUST_GROUP_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EMP_CUST_GROUP_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EMP_CUST_GROUP_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_EMP_CUST_GROUP_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EMP_CUST_GROUP_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EMP_CUST_GROUP_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EMP_STORE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_EMP_STORE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EMP_STORE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EMP_STORE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EMP_STORE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_EMP_STORE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EMP_STORE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EMP_STORE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EMP_TASK_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_EMP_TASK_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EMP_TASK_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EMP_TASK_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EMP_TASK_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_EMP_TASK_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EMP_TASK_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EMP_TASK_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EXCHANGE_RATE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_EXCHANGE_RATE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EXCHANGE_RATE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EXCHANGE_RATE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_EXCHANGE_RATE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_EXCHANGE_RATE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_EXCHANGE_RATE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_EXCHANGE_RATE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ITEM_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_ITEM_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ITEM_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ITEM_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ITEM_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_ITEM_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ITEM_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ITEM_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ITEM_OPTIONS_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_ITEM_OPTIONS_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ITEM_OPTIONS_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ITEM_OPTIONS_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ITEM_OPTIONS_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_ITEM_OPTIONS_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ITEM_OPTIONS_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ITEM_OPTIONS_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ITEM_PRICE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_ITEM_PRICE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ITEM_PRICE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ITEM_PRICE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ITEM_PRICE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_ITEM_PRICE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ITEM_PRICE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ITEM_PRICE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ITEM_UPC_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_ITEM_UPC_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ITEM_UPC_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ITEM_UPC_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_ITEM_UPC_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_ITEM_UPC_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_ITEM_UPC_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_ITEM_UPC_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_LEGAL_ENTITY_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_LEGAL_ENTITY_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_LEGAL_ENTITY_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_LEGAL_ENTITY_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_LEGAL_ENTITY_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_LEGAL_ENTITY_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_LEGAL_ENTITY_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_LEGAL_ENTITY_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_MATRIX_SORT_ORDER_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_MATRIX_SORT_ORDER_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_MATRIX_SORT_ORDER_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_MATRIX_SORT_ORDER_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_MATRIX_SORT_ORDER_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_MATRIX_SORT_ORDER_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_MATRIX_SORT_ORDER_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_MATRIX_SORT_ORDER_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_MERCH_HIERARCHY_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_MERCH_HIERARCHY_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_MERCH_HIERARCHY_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_MERCH_HIERARCHY_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_MERCH_HIERARCHY_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_MERCH_HIERARCHY_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_MERCH_HIERARCHY_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_MERCH_HIERARCHY_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_NON_PHYS_ITEM_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_NON_PHYS_ITEM_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_NON_PHYS_ITEM_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_NON_PHYS_ITEM_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_NON_PHYS_ITEM_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_NON_PHYS_ITEM_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_NON_PHYS_ITEM_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_NON_PHYS_ITEM_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_RETAIL_LOCATION_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_RETAIL_LOCATION_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_RETAIL_LOCATION_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_RETAIL_LOCATION_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_RETAIL_LOCATION_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_RETAIL_LOCATION_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_RETAIL_LOCATION_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_RETAIL_LOCATION_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_RETAIL_LOC_WKSTN_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_RETAIL_LOC_WKSTN_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_RETAIL_LOC_WKSTN_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_RETAIL_LOC_WKSTN_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_RETAIL_LOC_WKSTN_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_RETAIL_LOC_WKSTN_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_RETAIL_LOC_WKSTN_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_RETAIL_LOC_WKSTN_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_STORE_MESSAGE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_STORE_MESSAGE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_STORE_MESSAGE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_STORE_MESSAGE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_STORE_MESSAGE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_STORE_MESSAGE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_STORE_MESSAGE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_STORE_MESSAGE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_AUTHORITY_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_AUTHORITY_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_AUTHORITY_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_AUTHORITY_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_AUTHORITY_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_AUTHORITY_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_AUTHORITY_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_AUTHORITY_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_BRACKET_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_BRACKET_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_BRACKET_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_BRACKET_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_BRACKET_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_BRACKET_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_BRACKET_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_BRACKET_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_BRACKET_DTL_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_BRACKET_DTL_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_BRACKET_DTL_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_BRACKET_DTL_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_BRACKET_DTL_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_BRACKET_DTL_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_BRACKET_DTL_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_BRACKET_DTL_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_GROUP_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_GROUP_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_GROUP_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_GROUP_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_GROUP_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_GROUP_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_GROUP_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_GROUP_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_GROUP_RULE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_GROUP_RULE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_GROUP_RULE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_GROUP_RULE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_GROUP_RULE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_GROUP_RULE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_GROUP_RULE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_GROUP_RULE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_LOCATION_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_LOCATION_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_LOCATION_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_LOCATION_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_LOCATION_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_LOCATION_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_LOCATION_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_LOCATION_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_RATE_OVERRIDE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_RATE_OVERRIDE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_RATE_OVERRIDE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_RATE_OVERRIDE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_RATE_OVERRIDE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_RATE_OVERRIDE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_RATE_OVERRIDE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_RATE_OVERRIDE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_RATE_RULE_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_RATE_RULE_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_RATE_RULE_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_RATE_RULE_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TAX_RATE_RULE_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TAX_RATE_RULE_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TAX_RATE_RULE_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TAX_RATE_RULE_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TENDER_REP_FLOAT_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TENDER_REP_FLOAT_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TENDER_REP_FLOAT_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TENDER_REP_FLOAT_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TENDER_REP_FLOAT_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TENDER_REP_FLOAT_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TENDER_REP_FLOAT_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TENDER_REP_FLOAT_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TENDER_REPOSITORY_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_TENDER_REPOSITORY_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TENDER_REPOSITORY_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TENDER_REPOSITORY_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_TENDER_REPOSITORY_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_TENDER_REPOSITORY_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_TENDER_REPOSITORY_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_TENDER_REPOSITORY_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_VENDOR_CHANGE','CREATE_DATE') THEN
  dbms_output.put_line('DAT_VENDOR_CHANGE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_VENDOR_CHANGE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_VENDOR_CHANGE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DAT_VENDOR_CHANGE','UPDATE_DATE') THEN
  dbms_output.put_line('DAT_VENDOR_CHANGE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DAT_VENDOR_CHANGE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DAT_VENDOR_CHANGE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_EMAIL','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_EMAIL.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_EMAIL MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_EMAIL.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_EMAIL','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_EMAIL.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_EMAIL MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_EMAIL.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_FILE','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_FILE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_FILE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_FILE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_FILE','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_FILE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_FILE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_FILE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_FILE_STATUS','APPLIED_TIMESTAMP') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_FILE_STATUS.APPLIED_TIMESTAMP does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_FILE_STATUS MODIFY APPLIED_TIMESTAMP TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_FILE_STATUS.APPLIED_TIMESTAMP CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_FILE_STATUS','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_FILE_STATUS.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_FILE_STATUS MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_FILE_STATUS.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_FILE_STATUS','DOWNLOADED_TIMESTAMP') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_FILE_STATUS.DOWNLOADED_TIMESTAMP does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_FILE_STATUS MODIFY DOWNLOADED_TIMESTAMP TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_FILE_STATUS.DOWNLOADED_TIMESTAMP CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_FILE_STATUS','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_FILE_STATUS.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_FILE_STATUS MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_FILE_STATUS.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_PLAN','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_PLAN MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_PLAN','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_PLAN MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_PLAN_EMAILS','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_EMAILS.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_PLAN_EMAILS MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_EMAILS.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_PLAN_EMAILS','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_EMAILS.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_PLAN_EMAILS MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_EMAILS.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_PLAN_WAVE','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_WAVE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_PLAN_WAVE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_WAVE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_PLAN_WAVE','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_WAVE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_PLAN_WAVE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_WAVE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_PLAN_WAVETARGET','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_WAVETARGET.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_PLAN_WAVETARGET MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_WAVETARGET.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_PLAN_WAVETARGET','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_WAVETARGET.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_PLAN_WAVETARGET MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_PLAN_WAVETARGET.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_TARGET','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_TARGET.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_TARGET MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_TARGET.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_TARGET','MANIFEST_DOWNLOADED_TIMESTAMP') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_TARGET.MANIFEST_DOWNLOADED_TIMESTAMP does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_TARGET MODIFY MANIFEST_DOWNLOADED_TIMESTAMP TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_TARGET.MANIFEST_DOWNLOADED_TIMESTAMP CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_TARGET','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_TARGET.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_TARGET MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_TARGET.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_WAVE','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_WAVE.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_WAVE MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_WAVE.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_WAVE','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_WAVE.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_WAVE MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_WAVE.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_WAVE_APPROVALS','CREATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_WAVE_APPROVALS.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_WAVE_APPROVALS MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_WAVE_APPROVALS.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DPL_DEPLOYMENT_WAVE_APPROVALS','UPDATE_DATE') THEN
  dbms_output.put_line('DPL_DEPLOYMENT_WAVE_APPROVALS.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DPL_DEPLOYMENT_WAVE_APPROVALS MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DPL_DEPLOYMENT_WAVE_APPROVALS.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DTX_DEF','CREATE_DATE') THEN
  dbms_output.put_line('DTX_DEF.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DTX_DEF MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DTX_DEF.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DTX_DEF','UPDATE_DATE') THEN
  dbms_output.put_line('DTX_DEF.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DTX_DEF MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DTX_DEF.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DTX_FIELD','CREATE_DATE') THEN
  dbms_output.put_line('DTX_FIELD.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DTX_FIELD MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DTX_FIELD.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DTX_FIELD','UPDATE_DATE') THEN
  dbms_output.put_line('DTX_FIELD.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DTX_FIELD MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DTX_FIELD.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DTX_RELATIONSHIP','CREATE_DATE') THEN
  dbms_output.put_line('DTX_RELATIONSHIP.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DTX_RELATIONSHIP MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DTX_RELATIONSHIP.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DTX_RELATIONSHIP','UPDATE_DATE') THEN
  dbms_output.put_line('DTX_RELATIONSHIP.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DTX_RELATIONSHIP MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DTX_RELATIONSHIP.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DTX_RELATIONSHIP_FIELD','CREATE_DATE') THEN
  dbms_output.put_line('DTX_RELATIONSHIP_FIELD.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DTX_RELATIONSHIP_FIELD MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DTX_RELATIONSHIP_FIELD.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('DTX_RELATIONSHIP_FIELD','UPDATE_DATE') THEN
  dbms_output.put_line('DTX_RELATIONSHIP_FIELD.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE DTX_RELATIONSHIP_FIELD MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('DTX_RELATIONSHIP_FIELD.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('LOC_RTL_LOC_COLLECTION','CREATE_DATE') THEN
  dbms_output.put_line('LOC_RTL_LOC_COLLECTION.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE LOC_RTL_LOC_COLLECTION MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('LOC_RTL_LOC_COLLECTION.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('LOC_RTL_LOC_COLLECTION','UPDATE_DATE') THEN
  dbms_output.put_line('LOC_RTL_LOC_COLLECTION.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE LOC_RTL_LOC_COLLECTION MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('LOC_RTL_LOC_COLLECTION.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('LOC_RTL_LOC_COLLECTION_ELEMENT','CREATE_DATE') THEN
  dbms_output.put_line('LOC_RTL_LOC_COLLECTION_ELEMENT.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE LOC_RTL_LOC_COLLECTION_ELEMENT MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('LOC_RTL_LOC_COLLECTION_ELEMENT.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('LOC_RTL_LOC_COLLECTION_ELEMENT','UPDATE_DATE') THEN
  dbms_output.put_line('LOC_RTL_LOC_COLLECTION_ELEMENT.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE LOC_RTL_LOC_COLLECTION_ELEMENT MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('LOC_RTL_LOC_COLLECTION_ELEMENT.UPDATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('RPT_STOCK_ROLLUP','CREATE_DATE') THEN
  dbms_output.put_line('RPT_STOCK_ROLLUP.CREATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE RPT_STOCK_ROLLUP MODIFY CREATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('RPT_STOCK_ROLLUP.CREATE_DATE CREATED');
END IF;
END;
/

BEGIN
IF NOT SP_COLUMN_EXISTS ('RPT_STOCK_ROLLUP','UPDATE_DATE') THEN
  dbms_output.put_line('RPT_STOCK_ROLLUP.UPDATE_DATE does not exist');
Else
  EXECUTE IMMEDIATE 'ALTER TABLE RPT_STOCK_ROLLUP MODIFY UPDATE_DATE TIMESTAMP(6)';
  dbms_output.put_line('RPT_STOCK_ROLLUP.UPDATE_DATE CREATED');
END IF;
END;
/

-- [RXPS-53422] END

--[RXPS-54991] START 

BEGIN
    IF SP_COLUMN_EXISTS ('dat_legal_entity_change','establishment_code') THEN
        dbms_output.put_line('     dat_legal_entity_change.establishment_code already exists');
    ELSE
        EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD establishment_code VARCHAR2(30 char) NULL';
        dbms_output.put_line('     dat_legal_entity_change.establishment_code created');
    END IF;
END;
/

BEGIN
    IF SP_COLUMN_EXISTS ('dat_legal_entity_change','registration_city') THEN
        dbms_output.put_line('     dat_legal_entity_change.registration_city already exists');
    ELSE
        EXECUTE IMMEDIATE 'ALTER TABLE dat_legal_entity_change ADD registration_city VARCHAR2(254 char) NULL';
        dbms_output.put_line('     dat_legal_entity_change.registration_city created');
    END IF;
END;
/

-- [RXPS-54991] END

commit;
--SPOOL OFF;
-- LEAVE BLANK LINE BELOW
