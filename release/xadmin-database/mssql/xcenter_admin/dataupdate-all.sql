
-- Base Configuration Features
DELETE FROM cfg_base_feature;
GO

INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('cust/loyalty', 'Loyalty', null, 10, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('cust/loyalty/award', 'Loyalty Awards', 'cust/loyalty', 10, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('relate', 'Customer Engagement', null, 20, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('cust/registry', 'Gift Registry', 'relate', 10, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('idcs/relate', 'Use IDCS (Identity Cloud Service) for Authorization', 'relate', 20, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('order:locate', 'Order Broker (Cloud)', null, 30, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('idcs/locate', 'Use IDCS (Identity Cloud Service) for Authorization', 'order:locate', 10, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('crosschannelreturn:serenade', 'Order Management System', null, 40, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('idcs/serenade', 'Use IDCS (Identity Cloud Service) for Authorization', 'crosschannelreturn:serenade', 10, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('sim:sim/$FORM_FACTOR$', 'Enterprise Inventory Cloud Service', null, 50, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('idcs/sim', 'Use IDCS (Identity Cloud Service) for Authorization', 'sim:sim/$FORM_FACTOR$', 10, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('rxm:rxm/$FORM_FACTOR$', 'Retail Extension Module (RXM)', null, 60, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('avs:qas', 'Experian Address Verification', null, 70, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('xcommerce', 'Xcommerce', null, 80, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('opera', 'Opera Guest Services', null, 90, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('dtv/sql/mssql', 'Microsoft SQL Server Support', null, 110, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('authprocessor/eftlink', 'EFTLink Authorizations', null, 120, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('authprocessor/eftlink/giftcard', 'EFTLink Gift Cards', 'authprocessor/eftlink', 10, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('24x7', '24 x 7 Support (No Store Closing)', null, 130, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('buttonmatrix', 'Item Selection Grid', null, 150, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('dailyreport', 'Financial Daily Report', null, 160, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('invoice', 'Invoice', null, 170, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('invoice/globalblue', 'Global Blue Tax Fee (cannot be combined with Planet Tax Free)', 'invoice', 10, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('invoice/fintrax', 'Planet Tax Fee (cannot be combined with Global Blue Tax Free)', 'invoice', 20, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('xbri', 'XBRi Sales Productivity', null, 180, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('luxuryreceipt', 'Luxury receipts', null, 190, getDate(), 'BASEDATA');
INSERT INTO cfg_base_feature (feature_id, description, depends_on_feature_id, sort_order, create_date, create_user_id) VALUES ('vouchers', 'Taxed vouchers', null, 200, getDate(), 'BASEDATA');
GO


-- CFG_PRIVILEGE
DELETE FROM cfg_privilege WHERE category IN ('Menu', 'Support', 'AdminSecurity', 'Administration', 'Configurator','Customization', 'DataManager', 'DeploymentManager', 'Reports', 'Home Page') AND  privilege_id NOT IN ('ADMN_BROADCASTERS','ADMN_INTEGRATIONS');
GO

DELETE FROM cfg_role_privilege WHERE privilege_id = 'CFG_DELETE_STORE_CONFIGS';
GO


INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Home Page', 'BASIC_ACCESS', 'Home Page', 'Home Page', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Support', 'SPT_VIEW_SUPPORT_DASHBOARD', 'Alert Console', 'Alert Console', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Support', 'SPT_SUPPORT_SETTINGS', 'Alert Settings', 'Alert Settings', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Support', 'SPT_POSLOG_BUILDER', 'POSLog Publisher', 'PosLog Publisher', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Support', 'SPT_VERSIONINFO_DASHBOARD', 'Deployed Xstore Versions', 'Deployed Xstore Versions', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'SPT_EJOURNAL', 'Electronic Journal', 'Electronic Journal', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Support', 'SPT_REPL_VIEWER', 'Replication Status', 'Replication Status', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Support', 'SPT_TEMP_STORES', 'Popup Stores', 'Popup Stores', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_ADD_EDIT_USERS', 'Users and Security Access', 'Users and Security Access', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_USER_ROLES', 'User Roles', 'User Roles', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_AVAILABLE_LOCALES', 'Available Locales', 'Available Locales', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_STORE_AUTH_MANAGER', 'Store Authorization Manager', 'Store Authorization Manager', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_STORE_ENROLL', 'Store Enrollment', 'Store Enrollment', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_XOFFICE_CS_STORE_ENROLL', 'Xoffice Cloud Store Enrollment', 'Xoffice Cloud Store Enrollment', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'XADMIN_SETTINGS', 'Xadmin Settings', 'Xadmin Settings', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_ACCOUNT_RESET', 'Lock/Reset Account', 'Lock/Reset Account', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'XADMIN_USERS', 'Xadmin Users', 'Xadmin Users', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'SYSTEM_MANAGER', 'System Manager', 'System Manager', getDate(), 'BASEDATA');

INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_ORGANIZATIONS', 'Organizations', 'Organizations', getDate(), 'BASEDATA');

INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_CUSTOMIZATIONS', 'Customizations', 'Customizations', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Customization', 'EXPORT_CUSTOMIZATIONS', 'Export Customizations', 'Export Customizations', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Customization', 'DELETE_CUSTOMIZATIONS', 'Delete Customizations', 'Delete Customizations', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Customization', 'UPLOAD_CUSTOMIZATIONS', 'Upload Customizations', 'Upload Customizations', getDate(), 'BASEDATA');

INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_CREDENTIALS_STORAGE', 'Credentials Storage', 'Credentials Storage', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Administration', 'ADMN_JOB_MANAGEMENT', 'Job Management', 'Job Management', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_CODE', 'Code Value', 'Code Value', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_SYSCONFIG', 'System Config', 'System Config', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_DISCOUNTS', 'Discounts', 'Discounts', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_MENUS', 'Menus', 'Menus', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_MENU_CONFIG', 'Menu Configuration', 'Menu Configuration', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_TAB_CONFIG', 'Tab Configuration', 'Tab Configuration', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_REASON_CODE', 'Reason Codes', 'Reason Codes', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_RECEIPT_CONFIG', 'Receipts', 'Receipts', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_PROFILE_CONFIGURATION', 'Configurator', 'Configurator', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_PROFILE_GROUPS', 'Profile Maintenance', 'Profile Maintenance', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_PROFILE_MANAGEMENT', 'Profile Management', 'Profile Management', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_PERSONALITY_MAINTENANCE', 'Personality Maintenance', 'Personality Maintenance', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_LANDSCAPE_MAINTENANCE', 'Landscape Maintenance', 'Landscape Maintenance', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_STORE_PERSONALITIES', 'Store Personality Maintenance', 'Store Personality Maintenance', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_GLOBAL_CONFIGURATION', 'Global Configurations', 'Global Configurations', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_CONFIGURATION_OVERRIDES', 'Configuration Overrides', 'Configuration Overrides', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_SCHEDULE_DEPLOYMENT', 'Schedule Deployment', 'Schedule Deployment', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_STORE_SPECIFIC_OVERRIDES', 'Store Specific Overrides', 'Store Specific Overrides', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_COPY_STORE_CONFIGS', 'Copy Store Configurations', 'Copy Store Configurations', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_DELETE_PROFILE_CHANGES', 'Delete Profile Element Configurations', 'Delete Profile Element Configurations', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_SECURITY_GROUP', 'Security Groups', 'Security Group', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_SECURITY_PERMISSION', 'Security', 'Security', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_SECURITY_PRIVILEGE', 'Security Privileges', 'Security Privilege', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_TENDER', 'Tender Maintenance', 'Tender Maintenance', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_TENDER_OPTIONS', 'Tender Options Maintenance', 'Tender Options Maintenance', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_TENDER_USER_SETTINGS', 'Tender Security Settings', 'Tender Security Settings', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_TENDER_OPTION', 'Tenders', 'Tenders', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Configurator', 'CFG_CUSTDISPLAYS', 'Customer Displays', 'Customer Displays', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_CURRENCY_EXCHANGE', 'Currency Exchange', 'Currency Exchange', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_EMPLOYEE', 'Employee', 'Employee', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_EMPLOYEE_MESSAGE', 'Store Messages', 'Store Messages', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_EMPLOYEE_TASK', 'Employee Tasks', 'Employee Tasks', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_ITEM', 'Items', 'Items', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_ITEM_PRICING', 'Item Pricing', 'Item Pricing', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_ORGANIZATION_HIERARCHY', 'Organization Hierarchy', 'Organization Hierarchy', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_ORG_HIERARCHY_LEVELS', 'Organization Hierarchy Levels', 'Organization Hierarchy Levels', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_ORG_HIERARCHY_MAINTENANCE', 'Organization Hierarchy Maintenance', 'Organization Hierarchy Maintenance', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_STORE_COLLECTIONS', 'Store Collections', 'Store Collections', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_STORES', 'Stores', 'Stores', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_TAX_AUTHORITY', 'Tax Authority', 'Tax Authority', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_TAX_GROUP', 'Tax Group', 'Tax Group', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_TAX_LOCATION', 'Tax Location', 'Tax Location', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_VENDOR', 'Vendor', 'Vendor', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_LEGAL_ENTITY', 'Legal Entity', 'Legal Entity', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_EDIT_SESSION', 'Data Manager', 'Data Manager', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_COMMUNICATIONS', 'Store Communications', 'Store Communications', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_MERCH_ITEMS', 'Merchandise Items', 'Merchandise Items', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_NON_MERCH_ITEMS', 'Non Merchandise Items', 'Non Merchandise Items', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_ITEM_MESSAGE_MAINTENANCE', 'Item Message Maintenance', 'Item Message Maintenance', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_ITEM_MATRIX', 'Item Matrix Manager', 'Item Matrix Manager', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_MERCH_HIERARCHY', 'Merchandise Hierarchy', 'Merchandise Hierarchy', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_RESTRICTION_MAINT', 'Item Restrictions', 'Item Restrictions', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_RESTRICTION_TYPE_MAINT', 'Item Restriction Types', 'Item Restriction Types', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_TAXES', 'Taxes', 'Taxes', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_TAX_ELEMENTS', 'Tax Elements', 'Tax Elements', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_TAX_RATES', 'Tax Rates', 'Tax Rates', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_TAX_BRACKET', 'Tax Brackets', 'Tax Brackets', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_ATTACHED_ITEMS', 'Attached Items', 'Attached Items', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_MASS_TRANSFER', 'Data Publisher', 'Data Publisher', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DataManager', 'CFG_OCDS_DATA_REFRESH', 'Ocds Data Refresh', 'Ocds Data Refresh', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'SPT_FILE_UPLOAD', 'File Upload', 'File Upload', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'UPLOAD_FILE_TO_DEPLOY', 'Upload File to Deploy', 'Upload File to Deploy', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'SPT_DEPLOYMENT_VIEWER', 'View Deployments', 'View Deployments', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'FILE_DEPLOY', 'File Deploy', 'File Deploy', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'CANCEL_DEPLOYMENT', 'Cancel Deployment', 'Cancel Deployment', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'VIEW_ONLY_DEPLOYMENT_PLAN', 'View Deployment Plans', 'View Deployment Plans', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'EDIT_DEPLOYMENT_PLAN', 'Create/Edit Deployment Plans', 'Create/Edit Deployment Plans', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'UNAPPROVE_DEPLOYMENT_WAVE', 'Unapprove Deployment Wave', 'Unapprove Deployment Wave', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'APPROVE_DEPLOYMENT_WAVE', 'Approve Deployment Wave', 'Approve Deployment Wave', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'SCHEDULE_DEPLOYMENT_PLAN', 'Schedule Planned Deployment', 'Schedule Planned Deployment', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'SCHEDULE_SINGLE_TARGET', 'Schedule Single Deployment', 'Schedule Single Deployment', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('DeploymentManager', 'PURGE_DEPLOYMENT_FILES', 'Purge Deployment Files', 'Purge Deployment Files', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_GENERAL_ACCESS', 'View Reports', 'View Reports', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_BEST_SELLERS', 'Best Sellers Report', 'Best Sellers Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_CCA_ACTIVITY_SUMMARY', 'Customer Account Activity Summary Report', 'Customer Account Activity Summary Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_COUNTRYPACK.STAMP_TAX_RPT', 'Stamp Tax Report', 'Stamp Tax Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_CREDIT_CARD', 'Credit Card Report', 'Credit Card Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_CUSTOMER_LIST', 'Customer List Report', 'Customer List Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_DAILY_SALES_CASH', 'Daily Sales and Cash Report', 'Daily Sales and Cash Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_DAILY_SALES', 'Daily Sales Report', 'Daily Sales Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_DAILY_SALES_TOTAL', 'Daily Sales Total Report', 'Daily Sales Total Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_EMPLOYEE_PERFORMANCE', 'Employee Performance Report', 'Employee Performance Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_FLASH_SALES', 'Flash Sales Report', 'Flash Sales Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_GIFT_CERTIFICATE', 'Gift Certificate Report', 'Gift Certificate Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_ITEM_LIST', 'Item List Report', 'Item List Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_EMP_TASKS', 'Employee Tasks Report', 'Employee Tasks Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_JOURNAL', 'Journal Report', 'Journal Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_LAYAWAY_ACCT_ACTIVITY', 'Layaway Account Activity Report', 'Layaway Account Activity Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_LAYAWAY_AGING', 'Layaway Aging Report', 'Layaway Aging Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_LINE_VOID', 'Line Void Report', 'Line Void Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_NO_SALE', 'No Sale Report', 'No Sale Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_POST_VOID', 'Post Void Report', 'Post Void Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_PRICE_CHANGE', 'Price Change Report', 'Price Change Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_PRICE_OVERRIDE', 'Price Override Report', 'Price Override Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_RECEIVING_EXCEPTION', 'Receiving Exception Report', 'Receiving Exception Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_RETURNED_MERCHANDISE', 'Returned Merchandise Report', 'Returned Merchandise Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_INVENTORY_STOCK_COST', 'Inventory Stock Cost Report', 'Inventory Stock Cost Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_RECEIVING_REPORT', 'Receiving Report', 'Receiving Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_SALES_DEPT_EMPLOYEE', 'Sales By Department and Employee Report', 'Sales By Department and Employee Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_SALES_DEPARTMENT', 'Sales By Department Report', 'Sales By Department Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_SALES_HOUR_ANALYSIS', 'Sales By Hour Analysis Report', 'Sales By Hour Analysis Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_SALES_HOUR', 'Sales By Hour Report', 'Sales By Hour Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_SHIPPING_EXCEPTION', 'Shipping Exception Report', 'Shipping Exception Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_SPECIAL_ORDERS', 'Special Orders Report', 'Special Orders Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_STORE_LOCATIONS', 'Store Locations Report', 'Store Locations Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_SUSPENDED_TRANS', 'Suspended Transaction Summary Report', 'Suspended Transaction Summary Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_TAX_EXEMPTION', 'Tax Exemption Report', 'Tax Exemption Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_TRANS_CANCEL', 'Transaction Cancel Detail Report', 'Transaction Cancel Detail Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_DASHBOARD', 'Dashboard Report For Sales', 'Dashboard Report For Sales', getDate(), 'BASEDATA');
--INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_WORST_SELLERS_ITEM', 'Worst Sellers By Item Report', 'Worst Sellers By Item Report', getDate(), 'BASEDATA');
--INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_WORST_SELLERS_STYLE', 'Worst Sellers By Style Report', 'Worst Sellers By Style Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_STOCK_VALUATION', 'Stock Valuation Reports', 'Stock Valuation Reports', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_STOCK_ROLLUP', 'Roll-up Stock Valuation Report', 'Roll-up Stock Valuation Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Reports', 'RPT_AIRSIDE_CSV', 'Airport Authority Report', 'Airport Authority Report', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Home Page', 'HOME_PAGE_CONFIG', 'Home Page Config Management Panel', 'Home Page Config Management Panel', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Home Page', 'HOME_PAGE_DATA', 'Home Page Data Management Panel', 'Home Page Data Management Panel', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Home Page', 'HOME_PAGE_DEPLOY', 'Home Page Deployment Panel', 'Home Page Deployment Panel', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Home Page', 'HOME_PAGE_SUPPORT', 'Home Page Support Panel', 'Home Page Support Panel', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Home Page', 'HOME_PAGE_REPORTS', 'Home Page Reports Panel', 'Home Page Reports Panel', getDate(), 'BASEDATA');
INSERT INTO cfg_privilege (category, privilege_id, privilege_desc, short_desc, create_date, create_user_id) VALUES ('Home Page', 'HOME_PAGE_SYSTEM', 'Home Page System Panel', 'Home Page System Panel', getDate(), 'BASEDATA');
GO


-- **************************************************** --
-- * Manual referential-integrity cleanup: keep the   * --
-- * cfg_role_privilege table consistent with the     * --
-- * actual list of privileges from cfg_privilege.    * --
-- * Always do this AFTER cfg_privileges are          * --
-- * (re)created!                                     * --
-- * Exempt the existing role prvileges that are      * --
-- * cloud specific administrtator privileges.        * --
-- **************************************************** --
DELETE FROM cfg_role_privilege WHERE privilege_id NOT IN (SELECT privilege_id FROM cfg_privilege) AND privilege_id NOT IN ('ADMN_BROADCASTERS','ADMN_INTEGRATIONS');
GO



-- CFG_MENU_CONFIG
DELETE FROM cfg_menu_config WHERE category = 'REDIRECT_MENU_ACTION';
GO


INSERT INTO cfg_menu_config (category, menu_name, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REDIRECT_MENU_ACTION', 'CHANGE_PASSWORD', 10, 1, getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REDIRECT_MENU_ACTION', 'INDEX', 10, 1, getDate(), 'BASEDATA');
GO



-- TOP LEVEL MENUS
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and (parent_menu_name IS NULL OR parent_menu_name = 'ROOT');
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, menu_small_icon, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'ELECTRONIC_JOURNAL', 'ROOT', 'ELECTRONIC_JOURNAL', '_menuJournal', 10, 1, '/xadmin/images/newlaf/menu-electronic-journal.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, menu_small_icon, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'REPORTS_MENU', 'ROOT', null, '_reports', 20, 1, '/xadmin/images/newlaf/menu-reports.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, menu_small_icon, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'CONFIGURATOR_MENU', 'ROOT', 'CONFIGURATOR', '_enterConfigurator', 30, 1, '/xadmin/images/newlaf/menu-config.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, menu_small_icon, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'DATA_MANAGER_MENU', 'ROOT', 'DATA', '_enterDataManager', 40, 1, '/xadmin/images/newlaf/menu-data.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, menu_small_icon, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'DEPLOY_MANAGER_MENU', 'ROOT', 'DEPLOY', '_enterDeployManager', 50, 1, '/xadmin/images/newlaf/menu-deployment.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, menu_small_icon, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'SUPPORT_MENU', 'ROOT', 'SUPPORT', '_xstoreInformationSupport', 60, 1, '/xadmin/images/newlaf/menu-support.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, menu_small_icon, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'XCENTER_ADMIN_MENU', 'ROOT', 'ADMIN', '_systemToolPanelTitle', 70, 1, '/xadmin/images/newlaf/menu-settings.png', getDate(), 'BASEDATA');
GO



-- ELECTRONIC JOURNAL MENU
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'ELECTRONIC_JOURNAL';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'EJ_SEARCH', 'ELECTRONIC_JOURNAL', 'ELECTRONIC_JOURNAL', '_menuEj', 20, 1, 'SPT_EJOURNAL', getDate(), 'BASEDATA');
GO



-- CONFIGURATION MANAGER MENU
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'CONFIGURATOR_MENU';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'CONFIGURATOR2', 'CONFIGURATOR_MENU', '_configurator', 10, 1, 'CFG_PROFILE_CONFIGURATION', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'PROFILE_MANAGEMENT', 'CONFIGURATOR_MENU', '_profileManagement', 30, 1, 'CFG_PROFILE_MANAGEMENT', getDate(), 'BASEDATA');
GO



-- CONFIGURATOR FEATURES
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'CODE';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'CODE', 'CONFIGURATOR2_FEATURE', 'ALL,PERSONALITY', '_codeConfig', 10, 1, 'CFG_CODE', '/xadmin/images/configurator/code.png', '_codeConfigDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' AND menu_name = 'DISCOUNT';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'DISCOUNT', 'CONFIGURATOR2_FEATURE', 'ALL,PERSONALITY', '_discountConfig', 20, 1, 'CFG_DISCOUNTS', '/xadmin/images/configurator/discount.png', '_discountConfigDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' AND menu_name in ('MENU_CONFIG','MENU');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'MENU', 'CONFIGURATOR2_FEATURE', 'ALL,ALL', '_menuConfig', 30, 1, 'CFG_MENUS', '/xadmin/images/configurator/menu1.png', '_menuConfigDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' AND menu_name in ('REASONCODE_CONFIG','REASONCODE');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'REASONCODE', 'CONFIGURATOR2_FEATURE', 'ALL,PERSONALITY', '_reasonCodeConfig', 40, 1, 'CFG_REASON_CODE', '/xadmin/images/configurator/reasoncode.png', '_reasonCodeDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' AND menu_name in ('RECEIPT_CONFIG','RECEIPT');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'RECEIPT', 'CONFIGURATOR2_FEATURE', 'ALL,PERSONALITY', '_receiptConfig', 50, 1, 'CFG_RECEIPT_CONFIG', '/xadmin/images/configurator/receipt-64.png', '_receiptConfigDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'SECURITY';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'SECURITY', 'CONFIGURATOR2_FEATURE', 'MASTER,PERSONALITY', '_securityConfig', 60, 1, 'CFG_SECURITY_PERMISSION', '/xadmin/images/configurator/security.png', '_securityConfigDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' AND menu_name = 'SYSCONFIG';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'SYSCONFIG', 'CONFIGURATOR2_FEATURE', 'ALL,ALL', '_systemConfig', 70, 1, 'CFG_SYSCONFIG', '/xadmin/images/configurator/systemconfig.png', '_systemConfigDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' AND menu_name in ('TENDER_CONFIG', 'TENDER');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'TENDER', 'CONFIGURATOR2_FEATURE', 'ALL,PERSONALITY', '_tenderConfig', 80, 1, 'CFG_TENDER_OPTION', '/xadmin/images/configurator/tender.png', '_tenderConfigDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' AND menu_name = 'CUSTDISPLAY';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'CUSTDISPLAY', 'CONFIGURATOR2_FEATURE', 'ALL,PERSONALITY', '_custDisplayConfig', 90, 1, 'CFG_CUSTDISPLAYS', '/xadmin/images/configurator/custdisplay.png', '_custDisplayConfigDesc', getDate(), 'BASEDATA');
GO



-- DATA MANAGER MENU
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'DATA_MANAGER_MENU';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'DATA_MANAGER', 'DATA_MANAGER_MENU', '_dataManager', 5, 1, 'CFG_EDIT_SESSION', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'ORG_HIERARCHY';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'ORG_HIERARCHY', 'DATA_MANAGER_MENU', '_orgHierarchy', 10, 1, 'CFG_ORGANIZATION_HIERARCHY', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'YEAREND_PROCESS';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'YEAREND_PROCESS', 'DATA_MANAGER_MENU', '_yearEndRollUpMenuTitle', 20, 1, 'RPT_STOCK_ROLLUP', getDate(), 'BASEDATA');
GO


-- "New" DATA MANAGER FEATURES
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'COMMUNICATIONS';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'COMMUNICATIONS', 'DATA_MANAGER2_FEATURE', 'COMMUNICATIONS', '_communicationsConfigFeatureTitle', 10, 1, 'CFG_COMMUNICATIONS', '/xadmin/images/datamanager/CommIcon_64x64.png', '_communicationsMaintDesc', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'CURRENCY_EXCHANGE';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'CURRENCY_EXCHANGE', 'DATA_MANAGER2_FEATURE', 'CURRENCY_EXCHANGE', '_currencyExchangeConfigFeatureTitle', 20, 1, 'CFG_CURRENCY_EXCHANGE', '/xadmin/images/datamanager/CurrencyExchange6464.png', '_currencyExchangeMaintDesc', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'EMPLOYEE';
GO

INSERT INTO cfg_menu_config(category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'EMPLOYEE', 'DATA_MANAGER2_FEATURE', 'EMPLOYEE', '_employeeConfig', 30, 1, 'CFG_EMPLOYEE', '/xadmin/images/datamanager/employees6464.png', '_employeeMaintDesc', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'ITEM';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'ITEM', 'DATA_MANAGER2_FEATURE', 'ITEM', '_itemConfigFeatureTitle', 40, 1, 'CFG_ITEM', '/xadmin/images/datamanager/items6464.png', '_itemMaintDesc', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'STORES';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'STORES', 'DATA_MANAGER2_FEATURE', 'STORES', '_retailLocationConfig', 50, 1, 'CFG_STORES', '/xadmin/images/datamanager/Stores6464.png', '_storesMaintDesc', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'TAXES';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'TAXES', 'DATA_MANAGER2_FEATURE', 'TAXES', '_taxesConfigFeatureTitle', 60, 1, 'CFG_TAXES', '/xadmin/images/datamanager/Taxes6464.png', '_taxesMaintDesc', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'VENDOR';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'VENDOR', 'DATA_MANAGER2_FEATURE', 'VENDOR', '_vendorConfigFeatureTitle', 70, 1, 'CFG_VENDOR', '/xadmin/images/datamanager/VendorIcon6464.png', '_vendorMaintDesc', getDate(), 'BASEDATA');
  
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'LEGAL_ENTITY';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'LEGAL_ENTITY', 'DATA_MANAGER2_FEATURE', 'LEGAL_ENTITY', '_legalEntityConfig', 80, 1, 'CFG_LEGAL_ENTITY', '/xadmin/images/datamanager/LegalEntities6464.png', '_legalEntityMaintDesc', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'OCDS_RETAIL_LOCATION';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'OCDS_RETAIL_LOCATION', 'DATA_MANAGER3_FEATURE', 'OCDS_RETAIL_LOCATION', '_ocdsRetailLocationFeatureTitle', 10, 1, 'CFG_OCDS_DATA_REFRESH', '/xadmin/images/datamanager/Stores6464.png', '_ocdsRetailLocationMainDesc', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'OCDS_ITEM';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'OCDS_ITEM', 'DATA_MANAGER3_FEATURE', 'OCDS_ITEM', '_ocdsItemConfigFeatureTitle', 20, 1, 'CFG_OCDS_DATA_REFRESH', '/xadmin/images/datamanager/items6464.png', '_ocdsItemMaintDesc', getDate(), 'BASEDATA');


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'OCDS_TAXES';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'OCDS_TAXES', 'DATA_MANAGER3_FEATURE', 'OCDS_TAXES', '_ocdsTaxesConfigFeatureTitle', 30, 1, 'CFG_OCDS_DATA_REFRESH', '/xadmin/images/datamanager/Taxes6464.png', '_ocdsTaxesMaintDesc', getDate(), 'BASEDATA');

  
-- "Old" DATA MANAGER FEATURES
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'DATA_MANAGER_FEATURE';
GO



-- DATA MANAGER SECURITY SUB MENUS
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'SECURITY_CONFIG';
GO



-- DATA MANAGER TAX SUB MENUS
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'TAX_CONFIG';
GO



-- DATA MANAGER TENDER SUB MENUS
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'TENDER_CONFIG';
GO



-- DEPLOYMENT MENU
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'DEPLOY_MANAGER_MENU';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'FILE_UPLOAD', 'DEPLOY_MANAGER_MENU', '_fileupload', 10, 1, 'SPT_FILE_UPLOAD', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'DEPLOYMENT_VIEWER', 'DEPLOY_MANAGER_MENU', '_deploymentViewerMenu', 20, 1, 'SPT_DEPLOYMENT_VIEWER', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'VIEW_ONLY_DEPLOYMENT_PLAN', 'DEPLOY_MANAGER_MENU', '_deploymentPlanMenu', 30, 1, 'VIEW_ONLY_DEPLOYMENT_PLAN', getDate(), 'BASEDATA');


-- SUPPORT MENU
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'SUPPORT_MENU';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'SUPPORT_DASHBOARD', 'SUPPORT_MENU', '_supportDashboard', 10, 1, 'SPT_VIEW_SUPPORT_DASHBOARD', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'SUPPORT_DASHBOARD_SETTINGS', 'SUPPORT_MENU', '_supportDashboardSettings', 20, 1, 'SPT_SUPPORT_SETTINGS', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'VERSION_INFO', 'SUPPORT_MENU', '_versioninfo', 30, 1, 'SPT_VERSIONINFO_DASHBOARD', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'POSLOG_BUILDER', 'SUPPORT_MENU', '_posLogPublisherMenu', 40, 1, 'SPT_POSLOG_BUILDER', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'REPL_VIEWER', 'SUPPORT_MENU', '_replViewerMenu', 50, 1, 'SPT_REPL_VIEWER', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'TEMP_STORES', 'SUPPORT_MENU', '_tempStoresMenu', 50, 1, 'SPT_TEMP_STORES', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'PROFILE_CONFIG';
GO


-- SYSTEM UTILS MENU
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'XCENTER_ADMIN_MENU';
GO


-- The option for the new administration landing page
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'ADMINISTRATION';
GO


-- The individual administration menu options
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'XADMIN_SETTINGS';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'XADMIN_SETTINGS', 'XCENTER_ADMIN_MENU', '_adminConfigFeatureShortTitle', 10, 1, 'XADMIN_SETTINGS', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'XADMIN_USERS';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'XADMIN_USERS', 'XCENTER_ADMIN_MENU', '_adminUserFeatureShortTitle', 20, 1, 'XADMIN_USERS', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'AVAILABLE_LOCALE';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'AVAILABLE_LOCALE', 'XCENTER_ADMIN_MENU', '_availableLocaleFeatureTitle', 30, 1, 'ADMN_AVAILABLE_LOCALES', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'STORE_AUTH_MANAGER';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'STORE_AUTH_MANAGER', 'XCENTER_ADMIN_MENU', '_storeAuthFeatureTitle', 40, 1, 'ADMN_STORE_AUTH_MANAGER', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'STORE_AUTH_ENROLLMENT';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'STORE_AUTH_ENROLLMENT', 'STORE_AUTH_FEATURE', 'STORE_AUTH_ENROLLMENT', '_storeAuthEnrollmentFeatureTitle', 10, 1, 'ADMN_STORE_ENROLL', '/xadmin/images/administration/storeAuthEnroll.png', '_storeAuthEnrollmentDesc', getDate(), 'BASEDATA');

DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'USER_GUIDE';
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'SYSTEM_MANAGER';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'SYSTEM_MANAGER', 'XCENTER_ADMIN_MENU', '_systemManagerTitle', 40, 1, 'SYSTEM_MANAGER', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'VERSION';
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'CREDENTIALS_STORAGE';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'CREDENTIALS_STORAGE', 'SYSTEM_MANAGER2_FEATURE', 'CREDENTIALS_STORAGE', '_credsStorageFeatureTitle', 10, 1, 'ADMN_CREDENTIALS_STORAGE', '/xadmin/images/sysmanager/credentialsStorage.png', '_credsStorageMaintDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'JOB_MANAGEMENT';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'JOB_MANAGEMENT', 'SYSTEM_MANAGER2_FEATURE', 'JOB_MANAGEMENT', '_jobManagementFeatureTitle', 30, 1, 'ADMN_JOB_MANAGEMENT', '/xadmin/images/sysmanager/jobs.png', '_jobManagementMaintDesc', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'ORGANIZATIONS';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'ORGANIZATIONS', 'SYSTEM_MANAGER2_FEATURE', 'ORGANIZATIONS', '_organizationsFeatureTitle', 20, 1, 'ADMN_ORGANIZATIONS', '/xadmin/images/sysmanager/organizations.png', '_organizationsMaintDesc', getDate(), 'BASEDATA');
GO



DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'CUSTOMIZATIONS';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, security_privilege, menu_small_icon, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'CUSTOMIZATIONS', 'SYSTEM_MANAGER2_FEATURE', 'CUSTOMIZATIONS', '_customizationsFeatureTitle', 30, 1, 'ADMN_CUSTOMIZATIONS', '/xadmin/images/sysmanager/customizations.png', '_customizationsMaintDesc', getDate(), 'BASEDATA');
GO


-- REPORT MENU
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and parent_menu_name = 'REPORTS_MENU';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'REPORT_VIEWER', 'REPORTS_MENU', '_startReports', 30, 1, 'RPT_GENERAL_ACCESS', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'REPORT_VIEWER|FLASH_SALES_REPORT', 'REPORTS_MENU', '_rptFlashSalesReportTitle', 20, '@{reportLoadAction.execute(''FLASH_SALES_REPORT'')}', 1, 'RPT_FLASH_SALES', '_rptDescFlashSales', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('MAIN_MENU', 'REPORT_VIEWER|DASHBOARD_XADMIN', 'REPORTS_MENU', '_rptDashboardXadminReportTitle', 10, '@{reportLoadAction.execute(''DASHBOARD_XADMIN'')}', 1, 'RPT_DASHBOARD', '_rptDescDashboardXadmin', getDate(), 'BASEDATA');
GO


-- Report groups that are accessed from within the report viewer
-- Old place of storing in-feature report options
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and config_type = 'REPORTS';
GO

-- New place of storing in-feature report options
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name = 'ROOT';
-- Delete this menu first since it moved from its original location (Misc Reports) to here
DELETE FROM cfg_menu_config WHERE category = 'MAIN_MENU' and menu_name = 'STOCK_VALUATION_GROUP';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'FLASH_SALES_GROUP', 'ROOT', 'REPORTS', '_menutextFlashSalesReports', 10, 1, getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'DASHBOARD_XADMIN', 'ROOT', 'REPORTS', '_rptDashboardXadminMenu', 0, '@{reportLoadAction.execute(''DASHBOARD_XADMIN'')}', 1, 'RPT_DASHBOARD', '_rptDescXadminDashboard', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'SALES_GROUP', 'ROOT', 'REPORTS', '_menuTextSalesReport', 20, 1, getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'TRANSACTION_AUDIT_GROUP', 'ROOT', 'REPORTS', '_menuTextTransAuditReport', 30, 1, getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'INVENTORY_GROUP', 'ROOT', 'REPORTS', '_menuTextInventoryException', 40, 1, getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'SCHEDULE_GROUP', 'ROOT', 'REPORTS', '_menutextEmpSchedRep', 50, 1, getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'LAYAWAY_GROUP', 'ROOT', 'REPORTS', '_menutextLayawayReports', 60, 1, getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'MISC_GROUP', 'ROOT', 'REPORTS', '_menutextMiscReports', 70, 1, getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'STOCK_VALUATION_GROUP', 'ROOT', 'REPORTS', '_rptStockValReport', 80, 1, getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'AIRSIDE_GROUP', 'ROOT', 'REPORTS', '_rptAirsideReports', 90, 1, getDate(), 'BASEDATA');
GO



-- FLASH SALES REPORT MENU
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name = 'FLASH_SALES_GROUP';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'FLASH_SALES_REPORT', 'FLASH_SALES_GROUP', 'REPORTS', '_rptFlashSalesReportMenu', 10, '@{reportLoadAction.execute(''FLASH_SALES_REPORT'')}', 1, 'RPT_FLASH_SALES', '_rptDescFlashSales', getDate(), 'BASEDATA');
GO



-- SALES REPORT MENU
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name IN ('SALES_GROUP', 'SALES_REPORTS');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'DAILY_SALES_CASH_REPORT', 'SALES_GROUP', 'REPORTS', '_rptDailySalesCashReportTitleMenu', 10, '@{reportLoadAction.execute(''DAILY_SALES_CASH_REPORT'')}', 1, 'RPT_DAILY_SALES_CASH', '_rptDescDailySalesCash', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'SALES_BY_HOUR_REPORT', 'SALES_GROUP', 'REPORTS', '_rptSalesByHourReportSalesByHour', 20, '@{reportLoadAction.execute(''SALES_BY_HOUR_REPORT'')}', 1, 'RPT_SALES_HOUR', '_rptDescSalesHour', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'SALES_BY_HOUR_ANALYSIS_REPORT', 'SALES_GROUP', 'REPORTS', '_rptSaleByHourAnalysisTitleMenu', 30, '@{reportLoadAction.execute(''SALES_BY_HOUR_ANALYSIS_REPORT'')}', 1, 'RPT_SALES_HOUR_ANALYSIS', '_rptDescSalesHourAnalysis', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'SALES_BY_MERCHLVL1_REPORT', 'SALES_GROUP', 'REPORTS', '_rptSaleByMerchLevel1TitleMenu', 40, '@{reportLoadAction.execute(''SALES_BY_MERCHLVL1_REPORT'')}', 1, 'RPT_SALES_DEPARTMENT', '_rptDescSalesDept', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'RETURN_MERCHANDISE_REPORT', 'SALES_GROUP', 'REPORTS', '_rptReturnMerchandiseReportMenu', 60, '@{reportLoadAction.execute(''RETURN_MERCHANDISE_REPORT'')}', 1, 'RPT_RETURNED_MERCHANDISE', '_rptDescReturnMerchLog', getDate(), 'BASEDATA');
--INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
--  VALUES ('REPORT_VIEWER_MENU', 'SALES_BY_EMPLOYEE', 'SALES_GROUP', 'REPORTS', '_rptSalesByEmployeeReportTitleMenu', 70, '@{reportLoadAction.execute(''SALES_BY_EMPLOYEE'')}', 1, 'RPT_DAILY_SALES', '_rptDescSalesEmployee', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'BEST_SELLERS_REPORT', 'SALES_GROUP', 'REPORTS', '_rptBestSellersMenu', 80, '@{reportLoadAction.execute(''BEST_SELLERS_BY_STYLE_REPORT'')}', 1, 'RPT_BEST_SELLERS', '_rptDescBestSellers', getDate(), 'BASEDATA');
--INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
--  VALUES ('REPORT_VIEWER_MENU', 'WORST_SELLERS_BY_STYLE_REPORT', 'SALES_GROUP', 'REPORTS', '_rptWorstSellersByStyleTitle', 100, '@{reportLoadAction.execute(''WORST_SELLERS_BY_STYLE_REPORT'')}', 1, 'RPT_WORST_SELLERS_STYLE', '_rptDescWorstSellersStyle', getDate(), 'BASEDATA');
--INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
--  VALUES ('REPORT_VIEWER_MENU', 'WORST_SELLERS_BY_ITEM_REPORT', 'SALES_GROUP', 'REPORTS', '_rptWorstSellersByItemTitle', 110, '@{reportLoadAction.execute(''WORST_SELLERS_BY_ITEM_REPORT'')}', 1, 'RPT_WORST_SELLERS_ITEM', '_rptDescWorstSellersItem', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'CREDIT_CARD_REPORT', 'SALES_GROUP', 'REPORTS', '_rptCreditCardTitleMenu', 120, '@{reportLoadAction.execute(''CREDIT_CARD_REPORT'')}', 1, 'RPT_CREDIT_CARD', '_rptDescCreditCard', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'DAILY_SALES_REPORT', 'SALES_GROUP', 'REPORTS', '_rptDailySalesReportTitleMenu', 130, '@{reportLoadAction.execute(''DAILY_SALES_REPORT'')}', 1, 'RPT_DAILY_SALES_TOTAL', '_rptDescDailySalesTotal', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'COUNTRYPACK.STAMP_TAX_REPORT', 'SALES_GROUP', 'REPORTS', '_countrypack.jp.rptStampTaxReportTitle', 130, '@{reportLoadAction.execute(''COUNTRYPACK.STAMP_TAX_REPORT'')}', 1, 'RPT_COUNTRYPACK.STAMP_TAX_RPT', '_countrypack.jp.rptDescStampTaxReport', getDate(), 'BASEDATA');
GO


DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name = 'TRANSACTION_AUDIT_GROUP';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'NO_SALE_REPORT', 'TRANSACTION_AUDIT_GROUP', 'REPORTS', '_rptNoSaleTitleMenu', 10, '@{reportLoadAction.execute(''NO_SALE_REPORT'')}', 1, 'RPT_NO_SALE', '_rptDescNoSale', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'PRICE_OVERRIDE_REPORT', 'TRANSACTION_AUDIT_GROUP', 'REPORTS', '_rptPriceOverrideTitleMenu', 20, '@{reportLoadAction.execute(''PRICE_OVERRIDE_REPORT'')}', 1, 'RPT_PRICE_OVERRIDE', '_rptDescPriceOverride', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'LINE_VOID_REPORT', 'TRANSACTION_AUDIT_GROUP', 'REPORTS', '_rptLineVoidTitleMenu', 30, '@{reportLoadAction.execute(''LINE_VOID_REPORT'')}', 1, 'RPT_LINE_VOID', '_rptDescLineVoid', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'POST_VOID_TRANSACTION_REPORT', 'TRANSACTION_AUDIT_GROUP', 'REPORTS', '_rptPostVoidTransactionMenu', 40, '@{reportLoadAction.execute(''POST_VOID_REPORT'')}', 1, 'RPT_POST_VOID', '_rptDescPostVoid', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'SUSPENDED_TRANSACTION_REPORT', 'TRANSACTION_AUDIT_GROUP', 'REPORTS', '_rptSuspendedTransactionReportTitleMenu', 50, '@{reportLoadAction.execute(''SUSPENDED_TRANSACTION_REPORT'')}', 1, 'RPT_SUSPENDED_TRANS', '_rptDescSuspendedTransSummary', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'CANCELLED_TRANSACTION_REPORT', 'TRANSACTION_AUDIT_GROUP', 'REPORTS', '_rptCancelledTransactionTitleMenu', 60, '@{reportLoadAction.execute(''CANCELLED_TRANSACTION_REPORT'')}', 1, 'RPT_TRANS_CANCEL', '_rptDescTransactionVoidSummary', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'GIFT_CERTIFICATE_REPORT', 'TRANSACTION_AUDIT_GROUP', 'REPORTS', '_rptGiftCertificateTitleMenu', 70, '@{reportLoadAction.execute(''GIFT_CERTIFICATE_REPORT'')}', 1, 'RPT_GIFT_CERTIFICATE', '_rptDescGiftCertificate', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'TAX_EXEMPTION_REPORT', 'TRANSACTION_AUDIT_GROUP', 'REPORTS', '_rptTaxExemptionReportTitleMenu', 80, '@{reportLoadAction.execute(''TAX_EXEMPTION_REPORT'')}', 1, 'RPT_TAX_EXEMPTION', '_rptDescTaxExemption', getDate(), 'BASEDATA');
GO



-- INVENTORY REPORT MENU
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name IN ('INVENTORY_GROUP', 'INVENTORY_EXCEPTION');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'INVENTORY_SHIPPING_EXCEPTION_REPORT', 'INVENTORY_GROUP', 'REPORTS', '_rptInventoryExceptionShipTitle', 10, '@{reportLoadAction.execute(''INVENTORY_SHIPPING_EXCEPTION_REPORT'')}', 1, 'RPT_SHIPPING_EXCEPTION', '_rptDescInventoryShip', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'INVENTORY_RECEIVING_EXCEPTION_REPORT', 'INVENTORY_GROUP', 'REPORTS', '_rptInventoryExceptionRecTitle', 20, '@{reportLoadAction.execute(''INVENTORY_RECEIVING_EXCEPTION_REPORT'')}', 1, 'RPT_RECEIVING_EXCEPTION', '_rptDescInventoryRecv', getDate(), 'BASEDATA');
--INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
--  VALUES ('REPORT_VIEWER_MENU', 'RESTOCK_REPORT', 'INVENTORY_GROUP', 'REPORTS', '_rpReStockReportTitleMenu', 30, '@{reportLoadAction.execute("RESTOCK_REPORT")}', '_rptDescRestock', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'INVENTORY_STOCK_COST_REPORT', 'INVENTORY_GROUP', 'REPORTS', '_rptInventoryStockCostTitleMenu', 40, '@{reportLoadAction.execute(''INVENTORY_STOCK_COST_REPORT'')}', 1, 'RPT_INVENTORY_STOCK_COST', '_rptDescInventoryStockCost', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'RECEIVING_REPORT', 'INVENTORY_GROUP', 'REPORTS', '_rptReceivingReportTitle', 50, '@{reportLoadAction.execute(''RECEIVING_REPORT'')}', 1, 'RPT_RECEIVING_REPORT', '_rptDescReceiving', getDate(), 'BASEDATA');
GO



-- EMPLOYEE REPORT MENU
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name IN ('SCHEDULE_GROUP', 'SCHEDULE_REPORTS');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
VALUES ('REPORT_VIEWER_MENU', 'EMPLOYEE_PERFORMANCE_REPORT', 'SCHEDULE_GROUP', 'REPORTS', '_menutextRepEmpPerf', 10, '@{reportLoadAction.execute(''EMPLOYEE_PERFORMANCE_REPORT'')}', 1, 'RPT_EMPLOYEE_PERFORMANCE', '_rptDescEmployeePerformance', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'SCHEDULE_DETAIL_REPORT', 'SCHEDULE_GROUP', 'REPORTS', '_menutextRepSchedDet', 20, '@{reportLoadAction.execute("SCHEDULE_DETAIL_REPORT")}', 0, '_rptDescEmpScheduleDetail', getDate(), 'BASEDATA');
GO



-- LAYAWAY REPORT MENU
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name IN ('LAYAWAY_GROUP', 'LAYAWAY_REPORTS');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'LAYAWAY_AGING_REPORT', 'LAYAWAY_GROUP', 'REPORTS', '_rptLayawayAgingMenu', 10, '@{reportLoadAction.execute(''LAYAWAY_AGING_REPORT'')}', 1, 'RPT_LAYAWAY_AGING', '_rptLayawayAgingTitle', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)  
  VALUES ('REPORT_VIEWER_MENU', 'LAYAWAY_ACCOUNT_ACTIVITY_REPORT', 'LAYAWAY_GROUP', 'REPORTS', '_rptLayawayAccountActivityMenu', 30, '@{reportLoadAction.execute(''LAYAWAY_ACCOUNT_ACTIVITY_REPORT'')}', 1, 'RPT_LAYAWAY_ACCT_ACTIVITY', '_rptLayawayAccountActivityTitle', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'CONFIGURABLE_CUST_ACCT_ACTIVITY_SUMMARY_REPORT', 'LAYAWAY_GROUP', 'REPORTS', '_menutextConfigurableCustAccountActivtySummaryReport', 10, '@{reportLoadAction.execute("CONFIGURABLE_CUST_ACCT_ACTIVITY_SUMMARY_REPORT")}', 1, 'RPT_CCA_ACTIVITY_SUMMARY', '_rptDescCcaActivitySummary', getDate(), 'BASEDATA');
GO



-- MISC REPORT MENU
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name IN ('MISC_GROUP', 'MISC_REPORTS');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'JOURNAL_ROLL_REPORT', 'MISC_GROUP', 'REPORTS', '_rptJournalRollReport', 10, '@{reportLoadAction.execute(''JOURNAL_ROLL_REPORT'')}', 1, 'RPT_JOURNAL', '_rptDescJournalRoll', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'STORE_LOCATIONS_REPORT', 'MISC_GROUP', 'REPORTS', '_rptStoreLocationsReport', 20, '@{reportLoadAction.execute(''STORE_LOCATIONS_REPORT'')}', 1, 'RPT_STORE_LOCATIONS', '_rptDescStoreLocations', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'CUSTOMER_LIST_REPORT', 'MISC_GROUP', 'REPORTS', '_menutextCustList', 30, '@{reportLoadAction.execute(''CUSTOMER_LIST_REPORT'')}', 1, 'RPT_CUSTOMER_LIST', '_rptDescCustomerList', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'SPECIAL_ORDERS_REPORT', 'MISC_GROUP', 'REPORTS', '_menutextSpecialOrdersReports', 40, '@{reportLoadAction.execute(''SPECIAL_ORDERS_REPORTS'')}', 1, 'RPT_SPECIAL_ORDERS', '_rptDescSpecialOrders', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'PRICE_CHANGE_REPORT', 'MISC_GROUP', 'REPORTS', '_menutextPriceChangeReport', 50, '@{reportLoadAction.execute(''PRICE_CHANGE_REPORT'')}', 1, 'RPT_PRICE_CHANGE', '_rptDescPriceChange', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
 VALUES ('REPORT_VIEWER_MENU', 'ITEM_LIST_REPORT', 'MISC_GROUP', 'REPORTS', '_rptItemListTitle', 70, '@{reportLoadAction.execute(''ITEM_LIST_REPORT'')}', 1, 'RPT_ITEM_LIST', '_rptDescItemList', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'EMPLOYEE_TASKS_REPORT', 'MISC_GROUP', 'REPORTS', '_rptEmployeeTasksReport', 80, '@{reportLoadAction.execute(''EMPLOYEE_TASKS_REPORT'')}', 1, 'RPT_EMP_TASKS', '_rptDescEmployeeTasks', getDate(), 'BASEDATA');
GO


-- STOCK VALUATION REPORTS
-- WAC Reports
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name IN ('WAC_REPORTS_GROUP', 'WAC_REPORTS');
GO

-- PWAC Reports
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name IN ('PWAC_REPORTS_GROUP', 'PWAC_REPORTS');
GO

-- FIFO Reports
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name IN ('FIFO_REPORTS_GROUP', 'FIFO_REPORTS');
GO


DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name IN ('STOCK_VALUATION_GROUP', 'STOCK_VALUATION_REPORT');
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'WAC_STOCK_VALUATION_REPORT', 'STOCK_VALUATION_GROUP', 'REPORTS', '_rptWacStockValReportTitleMenu', 10, '@{reportLoadAction.execute(''WAC_STOCK_VALUATION_REPORT'')}', 1, 'RPT_STOCK_VALUATION', '_rptDescWacStockValuation', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'WAC_DETAIL_STOCK_VALUATION_REPORT', 'STOCK_VALUATION_GROUP', 'REPORTS', '_rptWacDetailReportTitleMenu', 20, '@{reportLoadAction.execute(''WAC_DETAIL_STOCK_VALUATION_REPORT'')}', 1, 'RPT_STOCK_VALUATION', '_rptDescWacStockValuationDetail', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'PWAC_STOCK_VALUATION_REPORT', 'STOCK_VALUATION_GROUP', 'REPORTS', '_rptPwacStockValReportTitleMenu', 30, '@{reportLoadAction.execute(''PWAC_STOCK_VALUATION_REPORT'')}', 1, 'RPT_STOCK_VALUATION', '_rptDescPwacStockValuation', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'PWAC_DETAIL_STOCK_VALUATION_REPORT', 'STOCK_VALUATION_GROUP', 'REPORTS', '_rptPwacDetailReportTitleMenu', 40, '@{reportLoadAction.execute(''PWAC_DETAIL_STOCK_VALUATION_REPORT'')}', 1, 'RPT_STOCK_VALUATION', '_rptDescPwacStockValuationDetail', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'FIFO_STOCK_VALUATION_REPORT', 'STOCK_VALUATION_GROUP', 'REPORTS', '_rptFifoStockValReportTitleMenu', 50, '@{reportLoadAction.execute(''FIFO_STOCK_VALUATION_REPORT'')}', 0, 'RPT_STOCK_VALUATION', '_rptDescFifoSummary', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'FIFO_DETAIL_STOCK_VALUATION_REPORT', 'STOCK_VALUATION_GROUP', 'REPORTS', '_rptFifoDetailReportTitleMenu', 60, '@{reportLoadAction.execute(''FIFO_DETAIL_STOCK_VALUATION_REPORT'')}', 0, 'RPT_STOCK_VALUATION', '_rptDescFifoDetail', getDate(), 'BASEDATA');
GO


-- Airside Reports
DELETE FROM cfg_menu_config WHERE category = 'REPORT_VIEWER_MENU' and parent_menu_name = 'AIRSIDE_GROUP';
GO

INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, config_type, title, sort_order, action_expression, active_flag, security_privilege, description, create_date, create_user_id)
  VALUES ('REPORT_VIEWER_MENU', 'AIRSIDE_CSV_REPORT', 'AIRSIDE_GROUP', 'REPORTS', '_rptAirsideCsvReportTitle', 10, '@{reportLoadAction.execute(''AIRSIDE_CSV_REPORT'')}', 1, 'RPT_AIRSIDE_CSV', '_rptDescAirsideCsv', getDate(), 'BASEDATA');
GO


-- **********************************************************************************************************
-- Home Page Menu options
-- **********************************************************************************************************
-- Home page menu
DELETE FROM cfg_menu_config WHERE category = 'HOME_PAGE_MENU' and parent_menu_name = 'ROOT';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, menu_small_icon, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'CONFIG_OPTIONS', 'ROOT', '_homePageOptionTitleConfig', 10, 1, 'HOME_PAGE_CONFIG', '/xadmin/images/newlaf/icon-config-db.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, menu_small_icon, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'DATA_OPTIONS', 'ROOT', '_enterDataManager', 20, 1, 'HOME_PAGE_DATA', '/xadmin/images/newlaf/icon-data-db.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, menu_small_icon, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'DEPLOY_OPTIONS', 'ROOT', '_homePageOptionTitleDeploy', 30, 1, 'HOME_PAGE_DEPLOY', '/xadmin/images/newlaf/icon-deploy-db.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, menu_small_icon, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'SUPPORT_OPTIONS', 'ROOT', '_xstoreInformationSupport', 40, 1, 'HOME_PAGE_SUPPORT', '/xadmin/images/newlaf/icon-support-db.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, menu_small_icon, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'REPORT_OPTIONS', 'ROOT', '_reports', 50, 1, 'HOME_PAGE_REPORTS', '/xadmin/images/newlaf/icon-reports-db.png', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, menu_small_icon, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'SYSTEM_OPTIONS', 'ROOT', '_homePageOptionTitleSystem', 60, 1, 'HOME_PAGE_SYSTEM', '/xadmin/images/newlaf/icon-system-db.png', getDate(), 'BASEDATA');
GO


-- Config options home menu
DELETE FROM cfg_menu_config WHERE category = 'HOME_PAGE_MENU' and parent_menu_name = 'CONFIG_OPTIONS';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'CONFIGURATOR2', 'CONFIG_OPTIONS', '_configurator', 10, 1,'CFG_PROFILE_CONFIGURATION', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'PROFILE_MANAGEMENT', 'CONFIG_OPTIONS', '_profileManagement', 20, 1, 'CFG_PROFILE_MANAGEMENT', getDate(), 'BASEDATA');
GO


-- Data options home menu
DELETE FROM cfg_menu_config WHERE category = 'HOME_PAGE_MENU' and parent_menu_name = 'DATA_OPTIONS';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'DATA_MANAGER', 'DATA_OPTIONS', '_dataManager', 10, 1, 'CFG_EDIT_SESSION', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'ORG_HIERARCHY', 'DATA_OPTIONS', '_orgHierarchy', 20, 1, 'CFG_ORGANIZATION_HIERARCHY', getDate(), 'BASEDATA');
GO


-- Deployment options home menu
DELETE FROM cfg_menu_config WHERE category = 'HOME_PAGE_MENU' and parent_menu_name = 'DEPLOY_OPTIONS';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'FILE_UPLOAD', 'DEPLOY_OPTIONS', '_fileupload', 10, 1, 'SPT_FILE_UPLOAD', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'DEPLOYMENT_VIEWER', 'DEPLOY_OPTIONS', '_deploymentViewerMenu', 20, 1, 'SPT_DEPLOYMENT_VIEWER', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'VIEW_ONLY_DEPLOYMENT_PLAN', 'DEPLOY_OPTIONS', '_deploymentPlanMenu', 30, 1, 'VIEW_ONLY_DEPLOYMENT_PLAN', getDate(), 'BASEDATA');
GO


-- Support options home menu
DELETE FROM cfg_menu_config WHERE category = 'HOME_PAGE_MENU' and parent_menu_name = 'SUPPORT_OPTIONS';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'SUPPORT_DASHBOARD', 'SUPPORT_OPTIONS', '_supportDashboard', 10, 1, 'SPT_VIEW_SUPPORT_DASHBOARD', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'VERSION_INFO', 'SUPPORT_OPTIONS', '_versioninfo', 20, 1, 'SPT_VERSIONINFO_DASHBOARD', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'POSLOG_BUILDER', 'SUPPORT_OPTIONS', '_posLogPublisherMenu', 30, 1, 'SPT_POSLOG_BUILDER', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'REPL_VIEWER', 'SUPPORT_OPTIONS', '_replViewerMenu', 40, 1, 'SPT_REPL_VIEWER', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'TEMP_STORES', 'SUPPORT_OPTIONS', '_tempStoresMenu', 40, 1, 'SPT_TEMP_STORES', getDate(), 'BASEDATA');
GO


-- Report options home menu
DELETE FROM cfg_menu_config WHERE category = 'HOME_PAGE_MENU' and parent_menu_name = 'REPORT_OPTIONS';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'EJ_SEARCH', 'REPORT_OPTIONS', '_menuEj', 10, 1, 'SPT_EJOURNAL', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'REPORT_VIEWER|DASHBOARD_XADMIN', 'REPORT_OPTIONS', '_rptDashboardXadminReportTitle', 20, 1, 'RPT_DASHBOARD', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'REPORT_VIEWER|FLASH_SALES_REPORT', 'REPORT_OPTIONS', '_rptFlashSalesReportTitle', 30, 1, 'RPT_FLASH_SALES', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'REPORT_VIEWER|DAILY_SALES_CASH_REPORT', 'REPORT_OPTIONS', '_rptDailySalesCashReportTitle', 40, 1, 'RPT_DAILY_SALES_CASH', getDate(), 'BASEDATA');
GO


-- System options home menu
DELETE FROM cfg_menu_config WHERE category = 'HOME_PAGE_MENU' and parent_menu_name = 'SYSTEM_OPTIONS';
GO


INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'XADMIN_SETTINGS', 'SYSTEM_OPTIONS', '_adminConfigFeatureShortTitle', 10, 1, 'XADMIN_SETTINGS', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'XADMIN_USERS', 'SYSTEM_OPTIONS', '_adminUserFeatureShortTitle', 20, 1, 'XADMIN_USERS', getDate(), 'BASEDATA');
INSERT INTO cfg_menu_config (category, menu_name, parent_menu_name, title, sort_order, active_flag, security_privilege, create_date, create_user_id)
  VALUES ('HOME_PAGE_MENU', 'SYSTEM_MANAGER', 'SYSTEM_OPTIONS', '_systemManagerTitle', 30, 1, 'SYSTEM_MANAGER', getDate(), 'BASEDATA');
GO

-- **********************************************************************************************************
-- (End) Home Page Menu options
-- **********************************************************************************************************



-- CFG_CODE_VALUE
DELETE FROM cfg_code_value WHERE category = 'VISIBILITY_RULE';
GO


DELETE FROM cfg_code_value WHERE category = 'SYSTEM_CONFIG';
GO


IF NOT EXISTS (SELECT 1 FROM cfg_code_value WHERE category = 'AVAILABLE_LOCALE' AND sub_category = 'DEFAULT')
BEGIN

INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('AVAILABLE_LOCALE', 'DEFAULT', 'en_US', 'DEFAULT', 'US English', 10, getDate(), 'BASEDATA');
END

GO


IF NOT EXISTS (SELECT 1 FROM cfg_code_value WHERE category = 'CONFIG_PATH' AND sub_category = 'DEFAULT')
BEGIN

INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('CONFIG_PATH', 'DEFAULT', '/version1', 'DEFAULT', 'cust', 10, getDate(), 'BASEDATA');
END

GO


DELETE FROM cfg_code_value WHERE category = 'CONFIG_PATH_GROUP' AND sub_category = 'DEFAULT';
GO



-- Configuration settings
DELETE FROM cfg_code_value WHERE category = 'ConfiguratorConfig' AND sub_category = 'DEFAULT';
GO

-- Config settings now live in the cfg_system_setting table

-- Deployment configurations
DELETE FROM cfg_code_value WHERE category = 'ConfiguratorConfig' AND sub_category = 'DEPLOYMENT';
GO

-- Deployment Config settings now live in the cfg_system_setting table

-- SECURITY SETTINGS
-- Password validation rules
DELETE FROM cfg_code_value WHERE category = 'ConfiguratorConfig' AND sub_category = 'Password';
GO

-- Config settings now live in the cfg_system_setting table

-- Xadmin Configuration - User accounts
DELETE FROM cfg_code_value WHERE category = 'ConfiguratorConfig' AND sub_category = 'ACCOUNT';
GO

-- Config settings now live in the cfg_system_setting table

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'CODE_CATEGORY';
GO

-- Code categories are defined in the cfg_code_category table


DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'AUTH_METHOD_CODE';
GO

INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_AMERICAN_EXPRESS', 'DEFAULT', '_AJB_AMERICAN_EXPRESS', 10, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_CHECK', 'DEFAULT', '_AJB_CHECK', 20, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_DEBIT', 'DEFAULT', '_AJB_DEBIT', 30, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_DINERS_CLUB', 'DEFAULT', '_AJB_DINERS_CLUB', 40, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_DISCOVER', 'DEFAULT', '_AJB_DISCOVER', 50, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_GIFT_CARD', 'DEFAULT', '_AJB_GIFT_CARD', 60, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_JCB', 'DEFAULT', '_AJB_JCB', 70, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_MASTERCARD', 'DEFAULT', '_AJB_MASTERCARD', 80, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_PRIVATE_CREDIT', 'DEFAULT', '_AJB_PRIVATE_CREDIT', 100, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'AJB_VISA', 'DEFAULT', '_AJB_VISA', 110, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'EFT_LINK_CREDIT', 'DEFAULT', '_EFT_LINK_CREDIT', 120, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'EFT_LINK_CREDIT_CNP', 'DEFAULT', '_EFT_LINK_CREDIT_CNP', 130, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'EFT_LINK_CHECK', 'DEFAULT', '_EFT_LINK_CHECK', 140, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'EFTLINK_GIFT_CARD', 'DEFAULT', '_EFTLINK_GIFT_CARD', 150, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'MANUAL', 'DEFAULT', '_MANUAL', 160, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'OPERA_ROOM_CHARGE', 'DEFAULT', '_OPERA_ROOM_CHARGE', 170, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'TENDER_RETAIL_CREDIT', 'DEFAULT', '_TENDER_RETAIL_CREDIT', 180, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'TENDER_RETAIL_DEBIT', 'DEFAULT', '_TENDER_RETAIL_DEBIT', 190, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_AMEX_AMEX', 'DEFAULT', '_XPAY_AMEX_AMEX', 200, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_CHECK_CERTEGY', 'DEFAULT', '_XPAY_CHECK_CERTEGY', 210, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_GIFT_CARD_PAYMENTECH', 'DEFAULT', '_XPAY_GIFT_CARD_PAYMENTECH', 220, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_GIFT_CARD_RELATE', 'DEFAULT', '_XPAY_GIFT_CARD_RELATE', 230, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_POINTS_CARD', 'DEFAULT', '_XPAY_POINTS_CARD', 240, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_AMEX_FDMS', 'DEFAULT', '_XPAY_AMEX_FDMS', 250, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DEBIT_FDMS', 'DEFAULT', '_XPAY_DEBIT_FDMS', 260, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DINERS_CLUB_FDMS', 'DEFAULT', '_XPAY_DINERS_CLUB_FDMS', 270, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DISCOVER_FDMS', 'DEFAULT', '_XPAY_DISCOVER_FDMS', 280, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_JCB_FDMS', 'DEFAULT', '_XPAY_JCB_FDMS', 290, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_MASTERCARD_FDMS', 'DEFAULT', '_XPAY_MASTERCARD_FDMS', 300, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_PRIVATE_LABEL_FDMS', 'DEFAULT', '_XPAY_PRIVATE_LABEL_FDMS', 310, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_VISA_FDMS', 'DEFAULT', '_XPAY_VISA_FDMS', 320, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_AMEX_MERCHANTLINK', 'DEFAULT', '_XPAY_AMEX_MERCHANTLINK', 330, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DEBIT_MERCHANTLINK', 'DEFAULT', '_XPAY_DEBIT_MERCHANTLINK', 340, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DINERS_CLUB_MERCHANTLINK', 'DEFAULT', '_XPAY_DINERS_CLUB_MERCHANTLINK', 350, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DISCOVER_MERCHANTLINK', 'DEFAULT', '_XPAY_DISCOVER_MERCHANTLINK', 360, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_JCB_MERCHANTLINK', 'DEFAULT', '_XPAY_JCB_MERCHANTLINK', 370, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_MASTERCARD_MERCHANTLINK', 'DEFAULT', '_XPAY_MASTERCARD_MERCHANTLINK', 380, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_PRIVATELABEL_MERCHANTLINK', 'DEFAULT', '_XPAY_PRIVATELABEL_MERCHANTLINK', 390, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_VISA_MERCHANTLINK', 'DEFAULT', '_XPAY_VISA_MERCHANTLINK', 400, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_AMEX_MWHSE', 'DEFAULT', '_XPAY_AMEX_MWHSE', 410, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DEBIT_MWHSE', 'DEFAULT', '_XPAY_DEBIT_MWHSE', 420, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DINERS_CLUB_MWHSE', 'DEFAULT', '_XPAY_DINERS_CLUB_MWHSE', 430, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DISCOVER_MWHSE', 'DEFAULT', '_XPAY_DISCOVER_MWHSE', 440, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_JCB_MWHSE', 'DEFAULT', '_XPAY_JCB_MWHSE', 450, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_MASTERCARD_MWHSE', 'DEFAULT', '_XPAY_MASTERCARD_MWHSE', 460, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_VISA_MWHSE', 'DEFAULT', '_XPAY_VISA_MWHSE', 470, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_AMEX_PAYMENTECH', 'DEFAULT', '_XPAY_AMEX_PAYMENTECH', 480, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DEBIT_PAYMENTECH', 'DEFAULT', '_XPAY_DEBIT_PAYMENTECH', 490, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DINERS_CLUB_PAYMENTECH', 'DEFAULT', '_XPAY_DINERS_CLUB_PAYMENTECH', 500, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_DISCOVER_PAYMENTECH', 'DEFAULT', '_XPAY_DISCOVER_PAYMENTECH', 510, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_JCB_PAYMENTECH', 'DEFAULT', '_XPAY_JCB_PAYMENTECH', 520, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_MASTERCARD_PAYMENTECH', 'DEFAULT', '_XPAY_MASTERCARD_PAYMENTECH', 530, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_PRIVATE_LABEL_PAYMENTECH', 'DEFAULT', '_XPAY_PRIVATE_LABEL_PAYMENTECH', 540, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_VISA_PAYMENTECH', 'DEFAULT', '_XPAY_VISA_PAYMENTECH', 550, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'XPAY_GIFT_CARD_FDMS', 'DEFAULT', '_XPAY_GIFT_CARD_FDMS', 610, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('DATA', 'AUTH_METHOD_CODE', 'GIFT_CARD_RELATE', 'DEFAULT', '_GIFT_CARD_RELATE', 620, getDate(), 'BASEDATA');
  
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Discount---applicationMethod';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Discount---calculationMethod';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Discount---eligibilityType';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Discount---taxibilityCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Employee---employeeStatusCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Employee---employeeTypeCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Item---itemLevelCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Item---itemTypeCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'PRICE_TYPES';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'REASON_CODE_TYPE';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'RECEIPT_TEXT';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Security---noAccessSettingsCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Security---secondPromptSettingsCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Tax---roundingRequireCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Tax---taxApplicationTypes';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Tax---taxBreakPointTypes';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Tender---authMethodCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Tender---currencyId';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Tender---custIdReqCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Tender---reportingGroup';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Tender---unitCountCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'TenderAvailability---availabilityCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'TenderUserSettings---entryMethodCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'TenderUserSettings---usageCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Vendor---vendorStatusCode';
GO

DELETE FROM cfg_code_value WHERE category = 'DATA' AND config_name = 'Vendor---vendorTypeCode';
GO

DELETE FROM cfg_code_value WHERE category = 'MenuConfig' AND config_name = 'KEY_STROKES';
GO

INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F2', 'DEFAULT', 'F2', 10, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F3', 'DEFAULT', 'F3', 20, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F4', 'DEFAULT', 'F4', 30, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F5', 'DEFAULT', 'F5', 40, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F6', 'DEFAULT', 'F6', 50, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F7', 'DEFAULT', 'F7', 60, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F8', 'DEFAULT', 'F8', 70, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F9', 'DEFAULT', 'F9', 80, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F10', 'DEFAULT', 'F10', 90, getDate(), 'BASEDATA');
INSERT INTO cfg_code_value (category, config_name, code, sub_category, description, sort_order, create_date, create_user_id)
  VALUES ('MenuConfig', 'KEY_STROKES', 'F11', 'DEFAULT', 'F11', 100, getDate(), 'BASEDATA');
GO

DELETE FROM cfg_code_value WHERE category = 'ORG_HIERARCHY_LEVEL';
GO

DELETE FROM cfg_code_value WHERE category = 'RcptConfig';
GO

DELETE FROM cfg_code_value WHERE category = 'ConfiguratorConfig' and config_name in ('StagingHostName','StagingHostPort','StagingHostBaseURL', 'StagingHostUsername', 'StagingHostPassword');
GO



-- ************************************************************ --
-- * Change some enum status codes for some deployment tables * --
-- ************************************************************ --
UPDATE dpl_deployment_target SET files_downloaded_status='UNREPORTED' where files_downloaded_status='PENDING';
UPDATE dpl_deployment_target SET files_applied_status='UNREPORTED' where files_applied_status='PENDING';
UPDATE dpl_deployment_file_status SET downloaded_status='UNREPORTED' where downloaded_status='PENDING';
UPDATE dpl_deployment_file_status SET applied_status='UNREPORTED' where applied_status='PENDING';
GO


-- ************************************************************ --
-- * Default the deployment name to N/A if its NULL * --
-- ************************************************************ --
UPDATE dpl_deployment SET deployment_name='N/A' where deployment_name is null;
GO


-- ************************************************************ --
-- * set this field to COMPLETE for 5.5.0 customers               --
-- * In the document guide, customer should complete the existing --
-- * deployments  before doing the upgrade                        --
-- ************************************************************   --
 UPDATE dpl_deployment SET deploy_status = 'NOT_APPLICABLE' where deploy_status is null;
 GO


 -- ************************************************************   --
-- * set this field to NOT_APPLICABLE for 5.5.0 customers          --
-- ************************************************************   --
 UPDATE dpl_deployment SET deployment_type = 'NOT_APPLICABLE' where deployment_type is null;
 GO


-- ************************************************************ --
-- * Default the plan_id to -1 if its NULL * --
-- * this means all previous deployment are considered single * --
-- * wave deployment since plan is introduced only for 6.0    * --
-- ************************************************************ --
 UPDATE dpl_deployment SET plan_id = -1 where plan_id is null;
 GO


 -- ************************************************************ --
-- * Default the plan_name to Single Wave if its NULL * --
-- * this means all previous deployments(5.5) are considered   * --
-- * single wave deployment since plan is introduced only for 6.0--
-- ************************************************************  --
 UPDATE dpl_deployment SET plan_name = 'Single Wave' where plan_name is null;
 GO


-- ************************************************************ --
-- * Default the purge_status to UNREPORTED if its NULL         --
-- * this means all previous deployment fiels (5.5) by default  --
-- * are not purged                                             --
-- ************************************************************ --
 UPDATE dpl_deployment SET purge_status = 'UNREPORTED' where purge_status is null;
 GO


-- ************************************************************ --
-- * Default the purge_status to UNREPORTED if its NULL         --
-- * this means all previous deployment files (5.5) by default  --
-- * are not purged                                             --
-- ************************************************************ --
 UPDATE dpl_deployment_file SET purge_status = 'UNREPORTED' where purge_status is null;
 GO

 -- ************************************************************ --
-- * Default the is_all_remaining_store to 0 if its NULL         --
-- * We will not face this issue when upgrading from 5.5 to 6.o  --
-- * for any client since "dpl_deployment_plan_wave" is already  --
-- * new table but we need this update for QA lab "xstxcenter"   --
-- ************************************************************ --
 UPDATE dpl_deployment_plan_wave SET is_all_remaining_store = 0 where is_all_remaining_store is null;
 GO



-- Remove the org node from the configurator object id.
UPDATE cfg_desc_translation_map SET change_id=REPLACE(change_id,'::null::null','') where change_id like '%::null::null';
UPDATE cfg_msg_translation_map SET change_id=REPLACE(change_id,'::null::null','') where change_id like '%::null::null';
UPDATE cfg_receipt_text_change SET change_id=REPLACE(change_id,'::null::null','') where change_id like '%::null::null';
UPDATE cfg_reason_code_change SET change_id=REPLACE(change_id,'::null::null','') where change_id like '%::null::null';
UPDATE cfg_dsc_valid_item_type_change SET change_id=REPLACE(change_id,'::null::null','') where change_id like '%::null::null';
UPDATE cfg_dsc_group_mapping_change SET change_id=REPLACE(change_id,'::null::null','') where change_id like '%::null::null';
UPDATE cfg_discount_change SET change_id=REPLACE(change_id,'::null::null','') where change_id like '%::null::null';
UPDATE cfg_profile_element_changes SET change_subtype=REPLACE(change_subtype,'::null::null','') where change_subtype like '%::null::null';
GO



-- New settings data
-- Configuration settings
IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'AutoFileTransferDirectory')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('AutoFileTransferDirectory', 'file:/filetransfer/auto/org${organizationId}/', 'com.micros_retail.configurator.filetransfer.autoSchedulerIntervalChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'AutoFileTransferSchedulerInterval')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('AutoFileTransferSchedulerInterval', '15', 'com.micros_retail.configurator.filetransfer.autoSchedulerIntervalChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'FileUploadDirectory')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('FileUploadDirectory', 'file:/fileuploads/org${organizationId}/', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DeviceConsideredMissingInXMinutes')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DeviceConsideredMissingInXMinutes', '61', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'IgnoreMissingDeviceAfterXHours')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('IgnoreMissingDeviceAfterXHours', '72', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'ScanForMissingDevicesEveryXMinutes')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('ScanForMissingDevicesEveryXMinutes', '15', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'BusinessDateStartTime')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('BusinessDateStartTime', '5', 'com.micros_retail.xcenter.support.observer.businessDateStartTimeChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'PosLogPublisherRemoteFileDirectory')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('PosLogPublisherRemoteFileDirectory', 'file:/poslog/org${organizationId}/', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableStoreSpecificOverrides')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableStoreSpecificOverrides', 'false', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableDeleteStoreConfigurations')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableDeleteStoreConfigurations', 'false', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DeploymentConfigTimeout')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DeploymentConfigTimeout', '5', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DeploymentConfigRetries')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DeploymentConfigRetries', '10', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DeploymentConfigRetryInterval')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DeploymentConfigRetryInterval', '10', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableDataManagerAutoDeployment')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableDataManagerAutoDeployment', 'false', 'com.micros_retail.xadmin.datamanager.server.dataManagerDeploymentChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DataManagerAutoDeploymentStartTime')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DataManagerAutoDeploymentStartTime', '21:00', 'com.micros_retail.xadmin.datamanager.server.dataManagerDeploymentChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'MaxDeploymentResult')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('MaxDeploymentResult', '100', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'MaxPOSLogResult')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('MaxPOSLogResult', '100', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforeLaunchDate')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforeLaunchDate', '3', 'com.micros_retail.xadmin.daysBeforeLaunchDateChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DeploymentAutoEmailInterval')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DeploymentAutoEmailInterval', '60', 'com.micros_retail.xadmin.deploymentAutoEmailIntervalChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'NewUserPasswordCreation')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('NewUserPasswordCreation', 'MANUAL', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableLDAP')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableLDAP', 'false', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'LDAP_URL')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('LDAP_URL', '', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'LDAP_DefaultDomain')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('LDAP_DefaultDomain', '', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'POSLogPublishSearchMaxResult')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('POSLogPublishSearchMaxResult', '1000', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DeleteFifoDataAfterRptGen')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DeleteFifoDataAfterRptGen', 'true', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'UseTillAccountabilityDefault')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('UseTillAccountabilityDefault', 'false', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DefaultDepositBankName')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DefaultDepositBankName', 'Deposit Bank', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DefaultDepositBankAcctNbr')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DefaultDepositBankAcctNbr', '1234567890', null, 'BASEDATA', getDate());
END

-- Purge Configuration settings
IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableDataPurge')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableDataPurge', 'false', 'com.micros_retail.configurator.purge.enableDataPurgeChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DataPurgeStartTime')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DataPurgeStartTime', '23:00', 'com.micros_retail.configurator.purge.dataPurgeStartTimeChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeTransactions')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeTransactions', '365', 'com.micros_retail.configurator.purge.daysBeforePurgeTransactionsChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgePosLogs')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgePosLogs', '90', 'com.micros_retail.configurator.purge.daysBeforePurgePosLogsChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeCustomers')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeCustomers', '-1', 'com.micros_retail.configurator.purge.daysBeforePurgeCustomersChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeInvoices')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeInvoices', '365', 'com.micros_retail.configurator.purge.daysBeforePurgeInvoicesChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeReports')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeReports', '365', 'com.micros_retail.configurator.purge.daysBeforePurgeReportsChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeEventLogs')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeEventLogs', '30', 'com.micros_retail.configurator.purge.daysBeforePurgeEventLogsChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgePayroll')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgePayroll', '-1', 'com.micros_retail.configurator.purge.daysBeforePurgePayrollChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeCycle')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeCycle', '365', 'com.micros_retail.configurator.purge.daysBeforePurgeCycleChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeInventory')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeInventory', '365', 'com.micros_retail.configurator.purge.daysBeforePurgeInventoryChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeItems')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeItems', '-1', 'com.micros_retail.configurator.purge.daysBeforePurgeItemsChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeDeals')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeDeals', '-1', 'com.micros_retail.configurator.purge.daysBeforePurgeDealsChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeTax')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeTax', '365', 'com.micros_retail.configurator.purge.daysBeforePurgeTaxChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeTender')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeTender', '-1', 'com.micros_retail.configurator.purge.daysBeforePurgeTenderChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeOrders')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeOrders', '365', 'com.micros_retail.configurator.purge.daysBeforePurgeOrdersChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeEmail')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeEmail', '30', 'com.micros_retail.configurator.purge.daysBeforePurgeEmailChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeFlightInfo')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeFlightInfo', '30', 'com.micros_retail.configurator.purge.daysBeforePurgeFlightInfoChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforeDeleteAutoFileTransferArchives')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforeDeleteAutoFileTransferArchives', '30', 'com.micros_retail.configurator.purge.daysBeforeDeleteAutoFileTransferArchives', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforeDeleteCompletedDeployments')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforeDeleteCompletedDeployments', '365', 'com.micros_retail.configurator.purge.daysBeforeDeleteCompletedDeployments', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforeDeleteFileUploads')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforeDeleteFileUploads', '90', 'com.micros_retail.configurator.purge.daysBeforeDeleteFileUploads', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforeDeleteRepublishedPosLogFiles')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforeDeleteRepublishedPosLogFiles', '30', 'com.micros_retail.configurator.purge.daysBeforeDeleteRepublishedPosLogFiles', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforeDeletePosPollFiles')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforeDeletePosPollFiles', '30', 'com.micros_retail.configurator.purge.daysBeforeDeletePosPollFiles', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeTempStoreRequest')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DaysBeforePurgeTempStoreRequest', '365', 'com.micros_retail.configurator.purge.daysBeforePurgeTempStoreRequestChanged', 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'BrDaysBackSpedExport')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('BrDaysBackSpedExport', '5', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DaysBeforePurgeCountryFRArchives')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event)
  VALUES ('DaysBeforePurgeCountryFRArchives', '-1', 'com.micros_retail.configurator.purge.daysBeforePurgeCountryFRArchives');
END


UPDATE cfg_system_setting SET config_value = '-1', update_date = getDate(), update_user_id = 'BASEDATA' WHERE update_date is null and config_id = 'DaysBeforePurgeCustomers';
UPDATE cfg_system_setting SET config_value = '-1', update_date = getDate(), update_user_id = 'BASEDATA' WHERE update_date is null and config_id = 'DaysBeforePurgePayroll';
UPDATE cfg_system_setting SET config_value = '-1', update_date = getDate(), update_user_id = 'BASEDATA' WHERE update_date is null and config_id = 'DaysBeforePurgeItems';
UPDATE cfg_system_setting SET config_value = '-1', update_date = getDate(), update_user_id = 'BASEDATA' WHERE update_date is null and config_id = 'DaysBeforePurgeDeals';
UPDATE cfg_system_setting SET config_value = '-1', update_date = getDate(), update_user_id = 'BASEDATA' WHERE update_date is null and config_id = 'DaysBeforePurgeTender';
GO


DELETE FROM cfg_system_setting WHERE config_id = 'OCDSEnabled' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSOrgChainMapping' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSScheduledJobInterval' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSOnDemandJobInterval' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSRetainJobHistoryDays' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSOffset' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSRequestLimit' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSRetailLocationTillAccountability' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSRetailLocationLocale' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSNontaxableItemTaxGroupId' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSIncludeFutureDateVatCode' AND NOT EXISTS (SELECT integration_system FROM cfg_integration WHERE integration_system = 'OCDS');
DELETE FROM cfg_system_setting where config_id = 'OCDSVATRoundingCode';
DELETE FROM cfg_system_setting where config_id = 'OCDSVATRoundingDigits';
DELETE FROM cfg_system_setting where config_id = 'OCDSVATRoundingAtTransLevel';
GO


-- User/Password settings
IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'PasswordHistoryLength')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('PasswordHistoryLength', '12', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'PasswordMaximumConsecutiveChars')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('PasswordMaximumConsecutiveChars', '2', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'PasswordMinimumCapitalLetters')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('PasswordMinimumCapitalLetters', '1', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'PasswordMinimumDigits')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('PasswordMinimumDigits', '1', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'PasswordMinimumLength')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('PasswordMinimumLength', '8', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'PasswordMinimumSpecialChars')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('PasswordMinimumSpecialChars', '1', null, 'BASEDATA', getDate());
END

--sort_order of all password related entries may need to be adjusted
IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'PasswordExpirationDays')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('PasswordExpirationDays', '90', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'LockUserAccountAfterRetries')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('LockUserAccountAfterRetries', '3', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'UserIdMinimumLength')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('UserIdMinimumLength', '6', null, 'BASEDATA', getDate());
END

GO

-- Report settings
IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableReportOutputFormat_PDF')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableReportOutputFormat_PDF', 'true', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableReportOutputFormat_HTML')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableReportOutputFormat_HTML', 'true', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableReportOutputFormat_XLS')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableReportOutputFormat_XLS', 'true', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableReportOutputFormat_XLSX')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableReportOutputFormat_XLSX', 'true', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableReportOutputFormat_PPTX')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableReportOutputFormat_PPTX', 'true', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableReportOutputFormat_RTF')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableReportOutputFormat_RTF', 'true', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'EnableReportOutputFormat_DOCX')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('EnableReportOutputFormat_DOCX', 'true', null, 'BASEDATA', getDate());
END

IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DefaultReportOutputFormat')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DefaultReportOutputFormat', 'PDF', null, 'BASEDATA', getDate());
END

GO


-- Country Code Setting for the organization
IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DefaultCountryCode')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DefaultCountryCode', 'US', null, 'BASEDATA', getDate());
END

GO


-- Currency Code Setting for the organization
IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DefaultCurrencyCode')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DefaultCurrencyCode', 'USD', null, 'BASEDATA', getDate());
END

GO


-- Locale Code Setting for the organization
IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'DefaultLocaleCode')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('DefaultLocaleCode', 'en_US', null, 'BASEDATA', getDate());
END

GO


-- Temporary Stores
IF NOT EXISTS (SELECT 1 FROM cfg_system_setting where config_id = 'TempStoreEmployeeMessageDuration')
BEGIN

INSERT INTO cfg_system_setting (config_id, config_value, modified_event, create_user_id, create_date)
  VALUES ('TempStoreEmployeeMessageDuration', '7', null, 'BASEDATA', getDate());
END

GO


-- Tab property configuration
DELETE FROM cfg_tab_property;
GO


INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('MESSAGE_AREA', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('ASSOCIATE_TASKS', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('SALES_GOAL', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('EMPLOYEE_MESSAGES', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('NUMERIC_KEYPAD', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('TRANSACTION_COUPONS', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('ACTIVITY_STREAM', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('ORDER_WORKLIST', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('WEATHER_FORECAST', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('EMPLOYEE_SCHEDULE', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('QUICK_LAUNCH', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('QUICK_ITEMS', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('URL_NAVIGATOR', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('URL_NAVIGATOR', 'tab', 'TextBox', 'complexValue', '_tabUrlLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('ASSOCIATED_ITEMS', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
INSERT INTO cfg_tab_property(tab_id, property_id, display_component, value_type, label, create_date, create_user_id)
  VALUES('CUSTOMER_INFO', 'tabTitle', 'TextBox', 'value', '_tabTitleLabel', getDate(), 'BASEDATA');
GO


-- Replace the old style representation of SystemConfig.xml changes with the newer SysConfig.xml representation
UPDATE cfg_profile_element_changes SET change_subtype = 'SysConfig.xml' WHERE change_subtype = 'SystemConfig.xml';
GO

UPDATE cfg_profile_element_changes SET changes = REPLACE(changes, 'Store---SystemConfig---', '') WHERE change_type = 'SYSCFG';
GO

UPDATE cfg_profile_element_changes SET changes = REPLACE(changes, 'Store---RegisterConfig---', '') WHERE change_type = 'SYSCFG';
GO


-- **************************************************** --
-- * Always keep Default User Creation at end of file * --
-- **************************************************** --
-- DEFAULT USER
IF NOT EXISTS (SELECT 1 FROM cfg_user where USER_NAME='1')
BEGIN

  INSERT INTO cfg_user (user_name, first_name, last_name, locale, create_date, create_user_id) VALUES ('1', 'Default', 'User', 'en_US', getDate(), 'BASEDATA');
  INSERT INTO cfg_user_password (user_name, password, effective_date, create_date, create_user_id) VALUES ('1', 'tZxnvxlqR1gZHkL3ZnDOug==', getDate(), getDate(), 'BASEDATA');
END

GO


-- ************************************************************ --
-- * Default the config_version to 0 if it is NULL.             --
-- * This means that all previous translation changes are not   --
-- * managed therefore cannot be monitored by the config        --
-- * versioning feature of Xadmin.                              --
-- ************************************************************ --
 UPDATE cfg_desc_translation_map SET s_config_version = 0 where s_config_version is null;
 UPDATE cfg_msg_translation_map SET s_config_version = 0 where s_config_version is null;
 UPDATE cfg_desc_translation_map SET t_config_version = 0 where t_config_version is null;
 UPDATE cfg_msg_translation_map SET t_config_version = 0 where t_config_version is null;
 UPDATE dpl_deployment SET config_version = 0 where config_version is null;
 UPDATE cfg_profile_element_changes SET inactive_flag = 0 where inactive_flag is null;
 UPDATE cfg_resource SET config_version = 0 where config_version is null;
 GO

 
 --Removing OCDS jobs and triggers from quartz table
DELETE FROM QRTZ_TRIGGERS WHERE TRIGGER_NAME = 'onDemandOcdsDataChangesTrigger';
DELETE FROM QRTZ_TRIGGERS WHERE TRIGGER_NAME = 'scheduledOcdsDataChangesTrigger';
DELETE FROM QRTZ_SIMPLE_TRIGGERS WHERE TRIGGER_NAME = 'onDemandOcdsDataChangesTrigger';
DELETE FROM QRTZ_SIMPLE_TRIGGERS WHERE TRIGGER_NAME = 'scheduledOcdsDataChangesTrigger';
DELETE FROM QRTZ_JOB_DETAILS WHERE JOB_NAME = 'onDemandOcdsDataChangesJob';
DELETE FROM QRTZ_JOB_DETAILS WHERE JOB_NAME = 'scheduledOcdsDataChangesJob';
GO


--Customer Reports - If there are custom reports but no CUSTOM_REPORTS_GROUP menu then insert one
IF NOT EXISTS (SELECT 1  FROM cfg_menu_config where menu_name = 'CUSTOM_REPORTS_GROUP')
BEGIN

  IF NOT EXISTS (SELECT 1  FROM cfg_menu_config where parent_menu_name = 'CUSTOM_REPORTS_GROUP')
BEGIN

    INSERT INTO cfg_menu_config 
    (category, menu_name, parent_menu_name, config_type, title, sort_order, active_flag) VALUES
    ('REPORT_VIEWER_MENU', 'CUSTOM_REPORTS_GROUP', 'ROOT', 'REPORTS', '_customizationsReportsTitle', 1, 1);
  END

END

GO
