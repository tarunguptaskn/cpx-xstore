//$Id$
package ksr.pos.customer;

import dtv.data2.access.IDataModel;
import dtv.logbuilder.ILogBuilder;
import dtv.pos.common.ConfigurationMgr;
import dtv.pos.common.ValueKeys;
import dtv.pos.customer.*;
import dtv.pos.framework.form.EditModelKey;
import dtv.pos.framework.form.EditModelMapper;
import dtv.pos.framework.form.FormConstants;
import dtv.pos.iframework.action.IXstActionKey;
import dtv.pos.iframework.action.IXstDataAction;
import dtv.pos.iframework.event.IXstEvent;
import dtv.pos.iframework.op.IOpResponse;
import dtv.pos.iframework.op.IOpState;
import dtv.util.config.ConfigUtils;
import dtv.xst.crm.impl.cust.persist.req.PartyCreateLogModel;
import dtv.xst.crm.impl.registry.RegistryDataModel;
import dtv.xst.dao.crm.IParty;
import dtv.xst.dao.crm.IPartyLocaleInformation;
import dtv.xst.dao.crm.PartyId;
import java.util.ArrayList;
import java.util.List;
import javax.inject.Inject;

/**
 * DESCRIPTION GOES HERE<br>
 * <br>
 * Copyright (c) 2004, 2021, Oracle and/or its affiliates. All rights reserved.
 *
 * @author Aaditya
 * @created Sep 14, 2021
 * @version $Revision$
 */
public class KsrCreateCustomerOp extends AbstractEditCustomerOp<KsrCustomerMaintenanceModel> {
  
  @Inject
  private ILogBuilder _logBuilder;
  @Inject
  private ICustomerUIHelper _customerUIHelper;
  private boolean _editable = true;
  private boolean allowAddCustToTran_ = false;

  @Override
  public void setParameter(String argName, String argValue) {
      if ("AddCustomerToTran".equalsIgnoreCase(argName)) {
          this.allowAddCustToTran_ = ConfigUtils.toBoolean(argValue);
      } else {
          super.setParameter(argName, argValue);
      }

  }

  @Override
  protected KsrCustomerMaintenanceModel createModel() {
      IParty party = this.getScopedValue(ValueKeys.SELECTED_CUSTOMER);
      if (party.getPrimaryLocaleInformation() == null) {
          IPartyLocaleInformation locale = this._customerHelper.getLocaleInfo(party);
          party.addPartyLocaleInformation(locale);
      }

      IDataModel[] objects = new IDataModel[]{party, party.getPrimaryLocaleInformation()};
      CustomerMaintenanceModel model1 = (CustomerMaintenanceModel) EditModelMapper.getInstance()
              .mapDao(EditModelKey.valueOf("CUSTOMER"), objects, true);
      KsrCustomerMaintenanceModel model= new KsrCustomerMaintenanceModel(model1.getDaos(), model1.getMappingConfig(), true);
      model.setAllowAddToTran(this.allowAddCustToTran_);
      this.setScopedValue(ValueKeys.ADDRESS_LOOKUP_COUNTRY, model.getCountry());
      if (ConfigurationMgr.isCustomerWishListEnabled()) {
          List<RegistryDataModel> wishLists = new ArrayList();
          this.setScopedValue(ValueKeys.WISH_LISTS, wishLists);
          model.setWishLists(wishLists);
      }
      return model;
  }

  @Override
  protected IOpResponse handleAbortChanges(IXstEvent argEvent) {
      this.setScopedValue(ValueKeys.SELECTED_CUSTOMER, this.getScopedValue(ValueKeys.PREVIOUS_CUSTOMER));
      this.clearScopedValue(ValueKeys.PREVIOUS_CUSTOMER);
      return this.HELPER.completeResponse();
  }

  @Override
  protected IOpResponse handleBeforeDataAction(IXstEvent argEvent) {
      return super.handleBeforeDataAction(argEvent);
  }

  @Override
  protected IOpResponse handleDataAction(IXstDataAction argAction) {
      IXstActionKey actionKey = argAction.getActionKey();
      if (FormConstants.EDIT == actionKey) {
          this._editable = true;
          return this.handleDisplayAgain();
      } else {
          return FormConstants.EXIT == actionKey
                  ? this.HELPER.getBackupResponse()
                  : super.handleDataAction(argAction);
      }
  }

  @Override
  protected IOpResponse handleDisplayAgain() {
      KsrCustomerMaintenanceModel cm = (KsrCustomerMaintenanceModel) this.getModel();
      IPartyLocaleInformation addressInformation = this
              .getScopedValue(ValueKeys.ADDRESS_SEARCH_RESULT);
      if (addressInformation != null) {
          cm.setAddress1(addressInformation.getAddress1());
          cm.setAddress2(addressInformation.getAddress2());
          cm.setAddress3(addressInformation.getAddress3());
          cm.setAddress4(addressInformation.getAddress4());
          cm.setApartment("");
          cm.setCity(addressInformation.getCity());
          cm.setPostalCode(addressInformation.getPostalCode());
          cm.setState(addressInformation.getState());
          cm.setCounty(addressInformation.getCounty());
          cm.setNeighborhood(addressInformation.getNeighborhood());
          this.clearScopedValue(ValueKeys.ADDRESS_SEARCH_RESULT);
      }

      IParty curParty = this.getScopedValue(ValueKeys.SELECTED_CUSTOMER);
      if (cm != null && curParty != null && cm.getCustomer().getPartyId() != curParty.getPartyId()) {
          this.setOpState((IOpState) null);
          return this.HELPER.incompleteResponse();
      } else {
          return super.handleDisplayAgain();
      }
  }

  @Override
  protected IOpResponse handleInitialState() {
      super.handleInitialState();
      return this.HELPER.getShowFormResponse(this.getFormKey(), this.getModel(), this.getActionGroupKey(),
              this.isEditable(), this.getInitialEditTab(true));
  }

  @Override
  protected void handleLogCustomerParty(IParty argCustomer) {
      if (argCustomer != null) {
          this._logBuilder.saveLogEntry(new PartyCreateLogModel(argCustomer));
      }

  }

  @Override
  protected IOpResponse handleSaveComplete(IXstEvent argEvent) {
      String userId = this._stationState.getSystemUser().getOperatorParty().getEmployeeId();
      IParty oldParty = this.getScopedValue(ValueKeys.SELECTED_CUSTOMER);
      IParty newParty = this._customerHelper.searchPartyById((PartyId) oldParty.getObjectId(),
              (long) this._stationState.getRetailLocationId(), userId);
      if (newParty != null) {
          this.setScopedValue(ValueKeys.SELECTED_CUSTOMER, newParty);
      }

      this._editable = false;
      if (ConfigurationMgr.returnToCustomerSearchAfterSave()) {
          return this.HELPER.completeResponse();
      } else {
          this._customerUIHelper.updateCustInfoDisplayMessage(newParty);
          return this.handleDisplayAgain();
      }
  }

  @Override
  protected boolean isEditable() {
      return this._editable;
  }
  
}
