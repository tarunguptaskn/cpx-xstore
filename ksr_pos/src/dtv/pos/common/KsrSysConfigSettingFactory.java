//$Id$
package dtv.pos.common;

import com.micros.xstore.config.ISingleElementConfigMgr;
import com.micros.xstore.config.settings.SettingType;
import com.micros.xstore.config.settings.SysConfig;

import ksr.pos.common.KsrConfigurationMgr;

/**
 * DESCRIPTION GOES HERE<br>
 * <br>
 * Copyright (c) 2004, 2021, Oracle and/or its affiliates. All rights reserved.
 *
 * @author JitendraTalla
 * @created 14-Sep-2021
 * @version $Revision$
 */
public class KsrSysConfigSettingFactory
    extends
    SysConfigSettingFactory {

  public KsrSysConfigSettingFactory(ISingleElementConfigMgr<SysConfig, SettingType> argConfigMgr) {
    super(argConfigMgr);
  }

  @Override
  void initializeConfigurationMgr() {
    super.initializeConfigurationMgr();
    KsrConfigurationMgr.setConfigSettingFactory(this);

  }

}
