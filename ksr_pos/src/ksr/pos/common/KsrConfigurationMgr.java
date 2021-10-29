// Copyright (c) 2017, Oracle and/or its affiliates. All rights reserved.
// $Id$
package ksr.pos.common;

import java.math.BigDecimal;
import java.util.*;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import dtv.pos.common.*;
import dtv.util.StringUtils;

/**
 * BRB Custom Configuration Manager<br>
 * <br>
 * Copyright (c) 2016, Oracle and/or its affiliates. All rights reserved.
 *
 * @author mminoliti
 * @created 13 mag 2016
 * @version $Revision: 1303506 $
 */
public class KsrConfigurationMgr
    extends
    ConfigurationMgr {

  protected static KsrSysConfigSettingFactory _settingsFactory;
  private static final Logger logger = LogManager.getLogger(KsrConfigurationMgr.class);

  public static int getInt(String argKeys, int argDefault) {
    Integer intValue = null;
    try {
      intValue = Integer.valueOf(getGenericSetting(argKeys));
    }
    catch (NumberFormatException e) {
      logger.warn("Invalid integer value specified for key[{}]. Using default value [{}]", argKeys,
          argDefault);
    }

    return intValue != null ? intValue : argDefault;
  }

  public static long getLong(String argKeys, long argDefault) {
    Long longValue = null;
    try {
      longValue = Long.valueOf(getGenericSetting(argKeys));
    }
    catch (NumberFormatException e) {
      logger.warn("Invalid long value specified for key[{}]. Using default value [{}]", argKeys, argDefault);
    }

    return longValue != null ? longValue : argDefault;
  }

  public static BigDecimal getBigDecimal(String argKeys) {
    BigDecimal value = null;
    try {
      value = new BigDecimal(getGenericSetting(argKeys));
    }
    catch (NumberFormatException e) {
      logger.warn("Invalid decimal value specified for key[{}]. Default to zero.", argKeys);
    }

    return value != null ? value : BigDecimal.ZERO;
  }

  private static List<String> getStringList(String argKeys) {
    String stringValue = getGenericSetting(argKeys);
    if (!StringUtils.isEmpty(stringValue)) {
      String[] values = stringValue.split(",");
      return Arrays.asList(values);
    }

    return Collections.emptyList();
  }

  //properties for LDAP--START
  public static String getLdapUsername() {
    return getGenericSetting("KsrConfig---LDAPConfig---SecurityUsername");
  }

  public static String getLdapPassword() {
    return getGenericSetting("KsrConfig---LDAPConfig---SecurityPassword");
  }

  public static String getLdapProviderUrl() {
    return getGenericSetting("KsrConfig---LDAPConfig---ProviderUrl");
  }

  public static String getLdapAuthType() {
    return getGenericSetting("KsrConfig---LDAPConfig---AuthType");
  }

  public static boolean isLdapEnabled() {
    return Boolean.valueOf(getGenericSetting("KsrConfig---LDAPConfig---Enable"));
  }
  //properties for LDAP--END

  public static int getWebMethodConnectionTimeOut() {
    return Integer.valueOf(getGenericSetting("KsrConfig---PseWeb---WMConnectionTimeOut"));
  }
  
  public static String getWebConnectionURL() {
    return getGenericSetting("KsrConfig---PseWeb---WMConnectionURL");
  }
  
  public static void setConfigSettingFactory(SysConfigSettingFactory argFactory) {
    _settingsFactory = (KsrSysConfigSettingFactory) argFactory;
  }

}
