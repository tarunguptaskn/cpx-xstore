//$Id$
package ksr.pos.customer;

import java.math.BigDecimal;
import java.text.SimpleDateFormat;
import java.util.*;

import javax.inject.Inject;
import javax.inject.Provider;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import ksr.pos.KsrConstants;
import oracle.retail.xstore.itm.custitem.CustomerItem;

import dtv.data2.access.*;
import dtv.data2.access.impl.IDataModelImpl;
import dtv.data2x.IDataServices;
import dtv.data2x.impl.req.NoRecordsFoundException;
import dtv.event.eventor.DefaultEventor;
import dtv.hardware.types.InputType;
import dtv.logbuilder.ILogBuilder;
import dtv.pos.common.*;
import dtv.pos.customer.*;
import dtv.pos.employee.IEmployeeHelper;
import dtv.pos.framework.event.FormSwipeTouchEvent;
import dtv.pos.framework.form.*;
import dtv.pos.framework.op.OpState;
import dtv.pos.framework.security.SecurityUtil;
import dtv.pos.framework.ui.model.InfoTabHelper;
import dtv.pos.iframework.action.*;
import dtv.pos.iframework.event.IXstEvent;
import dtv.pos.iframework.event.IXstEventType;
import dtv.pos.iframework.op.IOpResponse;
import dtv.pos.iframework.op.IOpState;
import dtv.pos.iframework.ui.model.IMessage;
import dtv.pos.iframework.visibilityrules.IAccessLevel;
import dtv.pos.order.OrderHelper;
import dtv.pos.order.OrderMgr;
import dtv.pos.pricing.PricingHelper;
import dtv.pos.register.ItemLocator;
import dtv.pos.register.infomessage.InfoMessage;
import dtv.pos.register.sale.SaleItemHelper;
import dtv.pos.tasks.TaskHelper;
import dtv.service.ServiceException;
import dtv.util.config.ConfigUtils;
import dtv.xst.crm.impl.cust.persist.req.PartyUpdateLogModel;
import dtv.xst.crm.impl.registry.RegistryDataModel;
import dtv.xst.crm.impl.task.TaskQueryResult;
import dtv.xst.dao.crm.IParty;
import dtv.xst.dao.crm.IPartyLocaleInformation;
import dtv.xst.dao.hrs.IEmployee;
import dtv.xst.dao.itm.IItem;
import dtv.xst.dao.xom.IOrder;

/**
 * 
 *
 * Spec Name/#:
 * Developer: Aaditya Singh
 * Reviewed By:
 * Issue # (if any):
 * Comments: Class to show the new values persisted
 * in the table into the new fields in customer capture
 * screen
 * 
 */
public class KsrEditCustomerOp extends AbstractEditCustomerOp<KsrCustomerMaintenanceModel> {

  private static final Logger _logger = LogManager.getLogger(KsrEditCustomerOp.class);

  private final IOpState noItemsFound = new OpState(KsrConstants.NO_ITEMS_FOUND);

  private boolean allowAddCustToTran = false;

  private boolean editable = false;

  @Inject
  protected Provider<IDataServices> dataServices;

  @Inject
  private InfoTabHelper infoTabHelper;

  @Inject
  private TaskHelper taskHelper;

  @Inject
  private IEmployeeHelper employeeHelper;

  @Inject
  private SecurityUtil securityUtil;

  @Inject
  private ILogBuilder logBuilder;

  @Inject
  protected SaleItemHelper saleItemHelper;

  @Inject
  private ICustomerUIHelper customerUIHelper;

  @Inject
  private PricingHelper pricingHelper;

  @Inject
  private OrderMgr orderMgr;

  @Inject
  private OrderHelper orderHelper;
  
  final IQueryKey<IQueryResult> query=new QueryKey<>("GET_CUST_DETAILS", IQueryResult.class);
  
  @Override
  protected IOpResponse handleInitialState() {
    IOpState opState = this.getOpState();

    IOpResponse res = super.handleInitialState();
    if (opState == null) {
      return res;
    }
    else {
      String currentTab = this.getCurrentTab();
      super.handleDisplayAgain();
      FormTabKey requestedTabKey = currentTab != null ? FormTabKey.forName(currentTab) : null;

      return this.HELPER.getChangeFormResponse(this.getFormKey(), getModel(), this.getActionGroupKey(),
          isEditable(), requestedTabKey);
    }
  }
  
  @Override
  public IXstEventType[] getObservedEvents() {
    List<IXstEventType> events = new ArrayList<>(Arrays.asList(EVENTS));
    IParty customer = getScopedValue(ValueKeys.SELECTED_CUSTOMER);
    if (this._customerHelper.hasCustomerWriteAccess(customer))
      events.add(InputType.INPUT_ITEM);
    events.add(InputType.FORM_SWIPE_TOUCH_EVENT_TYPE);
    return events.<IXstEventType>toArray(new IXstEventType[events.size()]);
  }

  @Override
  public boolean isOperationApplicable() {
    return (getScopedValue(ValueKeys.SELECTED_CUSTOMER) != null);
  }

  @Override
  public void setParameter(String argName, String argValue) {
    if ("AddCustomerToTran".equalsIgnoreCase(argName)) {
      this.allowAddCustToTran = ConfigUtils.toBoolean(argValue).booleanValue();
    } else {
      super.setParameter(argName, argValue);
    }
  }

  protected void cleanPartyModel() {
    IParty party = getScopedValue(ValueKeys.SELECTED_CUSTOMER);
    if (party != null)
      this.dataServices.get().makeClean((IDataModel) party, true);
  }

  @Override
  protected KsrCustomerMaintenanceModel createModel() {
    IParty party = getScopedValue(ValueKeys.SELECTED_CUSTOMER);
    if (party.getPrimaryLocaleInformation() == null) {
      IPartyLocaleInformation locale = this._customerHelper.getLocaleInfo(party);
      party.addPartyLocaleInformation(locale);
    }
    IDataModel[] objects = {party, party.getPrimaryLocaleInformation()};
    CustomerMaintenanceModel model1 = (CustomerMaintenanceModel) EditModelMapper.getInstance()
        .mapDao(EditModelKey.valueOf("CUSTOMER"), objects, false);
    KsrCustomerMaintenanceModel model= new KsrCustomerMaintenanceModel(model1.getDaos(), model1.getMappingConfig(), false);
    model.setAllowAddToTran(this.allowAddCustToTran);
    model.setDataSource(((IDataModelImpl) party).getDAO().getOriginDataSource());
    if (model.hasInvalidFields()) {
      List<IMessage> message = InfoMessage.make("_customerInvalidFieldsTitle", "_customerInvalidFieldsMessage",
          ConfigurationMgr.getInstructionalMsgIcon());
      this._modeProvider.get().getStationModel().getMessageModel().addMessage(message);
    }
    setSelectedCountry(party.getPrimaryLocaleInformation().getCountry());
    
    model=this.setAdditionalProperties(model, party);
    
    model.setAllowAddToTran(this.allowAddCustToTran);
    model.getCustAccountListModel().showForm(party);
    if (ConfigurationMgr.isCustomerWishListEnabled()) {
      String str = this._stationState.getSystemUser().getOperatorParty().getEmployeeId();
      List<RegistryDataModel> wishLists = new ArrayList<>();
      try {
        wishLists = this._customerHelper.getWishLists(party, this._stationState.getRetailLocationId(), str);
        List<CustomerItem> wishListItems = new ArrayList<>();
        if (!wishLists.isEmpty()) {
          for (RegistryDataModel wishListRegistry : wishLists) {
            for (CustomerItem regItem : wishListRegistry.getItems()) {
              regItem.setItemType(CustomerItem.ItemType.WISH_LIST_ITEM);
              regItem.setQuantity(BigDecimal.ONE);
              BigDecimal itemPrice = this.pricingHelper.getCurrentItemPrice(regItem.getItem(), false)
                  .getPrice();
              regItem.setPrice(itemPrice);
            }
          }
          setScopedValue(ValueKeys.CURRENT_WISH_LIST, wishLists.get(0));
          wishListItems = wishLists.get(0).getItems();
          model.setCustWishListTitle(wishLists.get(0).getEventName(), 1,
              wishLists.size());
        }
        model.setWishListItems(wishListItems);
      } catch (ServiceException ex) {
        model.setWishListUnretrievable(true);
      }
      setScopedValue(ValueKeys.WISH_LISTS, wishLists);
      model.setWishLists(wishLists);
    }
    try {
      List<CustomerItem> items = this.saleItemHelper.getCustomerDigitalCartItems(party, this._stationState.getRetailLocationId());
      setScopedValue(ValueKeys.DIGITAL_CART_ITEMS, items);
      model.setDigitalCartItems(items);
    } catch (NoRecordsFoundException noRecordsFoundException) {
      _logger.error("CAUGHT EXCEPTION:", noRecordsFoundException);
    } catch (ServiceException ex) {
      model.setDigitalCartUnretrievable(true);
    }
    IAccessLevel access = this.securityUtil.getAccessLevel("VIEW_ALL_TASKS",
        this._stationState.getSystemUser().getGroupMembership());
    IEmployee emp = null;
    String userId = this._stationState.getSystemUser().getOperatorParty().getEmployeeId();
    if (!access.isGranted()) {
      emp = this.employeeHelper.getEmployeeById(userId);
      setScopedValue(ValueKeys.SELECTED_EMPLOYEE, emp);
    }
    try {
      List<? extends TaskQueryResult> tasks = this.taskHelper.retrieveCustomerTasks(emp, party,
          this._stationState.getRetailLocationId(), userId);
      
      model.setTasks(tasks);
    } catch (NoRecordsFoundException ex) {
      _logger.error(String.format("No tasks found for customer [ %s ]", party.getPartyId()));
    } catch (Exception ex) {
      _logger.error("CAUGHT EXCEPTION:", ex);
    }
    return model;
  }

  @Override
  protected IOpResponse handleAbortChanges(IXstEvent argEvent) {
    KsrCustomerMaintenanceModel custModel = getModel();
    custModel.revertChanges();
    this.editable = false;
    IParty party = getScopedValue(ValueKeys.SELECTED_CUSTOMER);
    setSelectedCountry(party.getPrimaryLocaleInformation().getCountry());
    custModel=this.setAdditionalProperties(custModel, party);
    String currentTab = getCurrentTab();
    if (CUSTOMER_WISH_LIST.toString().equals(currentTab)) {
      custModel.loadCustWishList();
      return this.HELPER.getChangeFormResponse(getFormKey(), custModel, getActionGroupKey(), true);
    }
    FormTabKey requestedTabKey = (currentTab != null) ? FormTabKey.forName(currentTab) : null;
    return this.HELPER.getChangeFormResponse(getFormKey(), custModel, getActionGroupKey(), false,
        requestedTabKey);
  }

  @Override
  protected IOpResponse handleBeforeDataAction(IXstEvent argEvent) {
    if (argEvent instanceof dtv.hardware.events.ItemScanEvent) {
      if (getOpState() == this.noItemsFound)
        return this.HELPER.getPromptResponse(KsrConstants.INVALID_INPUT);
      if (!isEditable()) {
        if (CUSTOMER_WISH_LIST.toString().equals(getCurrentTab())) {
          String itemId = argEvent.getStringData();
          IItem currentItem = ItemLocator.getLocator().lookupItem(itemId);
          if (currentItem == null) {
            setOpState(this.noItemsFound);
            return this.HELPER.getPromptResponse(KsrConstants.SCANNED_ITEMS_NOT_FOUND);
          }
          setScopedValue(ValueKeys.CURRENT_ITEM, currentItem);
          return this.HELPER.getWaitStackChainResponse(OpChainKey.valueOf("ADD_WISH_LIST_ITEM_FROM_SCAN"));
        }
        return this.HELPER.incompleteResponse();
      }
      return this.HELPER.incompleteResponse();
    }
    if (argEvent instanceof FormSwipeTouchEvent) {
      if (((FormSwipeTouchEvent) argEvent).getSwipedDirection() == 3 && !isEditable()) {
        setEditable(true);
        return this.HELPER.getChangeFormResponse(getFormKey(), getModel(), getActionGroupKey(), true);
      }
      return this.HELPER.incompleteResponse();
    }
    if (getOpState() == this.noItemsFound) {
      setOpState(this.AFTER_REQUEST);
      return handleDisplayAgain();
    }
    return super.handleBeforeDataAction(argEvent);
  }

  @Override
  protected IOpResponse handleDataAction(IXstDataAction argAction) {
    IXstActionKey actionKey = argAction.getActionKey();
    if (FormConstants.EDIT == actionKey) {
      setEditable(true);
      return this.HELPER.getChangeFormResponse(getFormKey(), getModel(), getActionGroupKey(), true,
          getInitialEditTab(false));
    }
    if (FormConstants.EXIT == actionKey) {
      clearScopedValue(ValueKeys.WISH_LISTS);
      return this.HELPER.getBackupResponse();
    }
    return super.handleDataAction(argAction);
  }

  @Override
  protected IOpResponse handleDisplayAgain() {
    KsrCustomerMaintenanceModel cm = getModel();
    IPartyLocaleInformation addressInformation = getScopedValue(
        ValueKeys.ADDRESS_SEARCH_RESULT);
    if (addressInformation != null) {
      setEditable(true);
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
      clearScopedValue(ValueKeys.ADDRESS_SEARCH_RESULT);
    }
    IParty curParty = getScopedValue(ValueKeys.SELECTED_CUSTOMER);
    if (cm != null && curParty != null && !cm.getCustomer().equals(curParty)) {
      setOpState(null);
      return this.HELPER.incompleteResponse();
    }
    return super.handleDisplayAgain();
  }

  @Override
  protected void handleLogCustomerParty(IParty argCustomer) {
    if (argCustomer != null)
      this.logBuilder.saveLogEntry(new PartyUpdateLogModel(argCustomer));
  }

  @Override
  protected IOpResponse handleSaveComplete(IXstEvent argEvent) {
    IParty customer = getScopedValue(ValueKeys.SELECTED_CUSTOMER);
    this.editable = false;
    DefaultEventor defaultEventor = new DefaultEventor(CustomerUtil.CUSTOMER_PARTY_UPDATED_EVENT_DESCRIPTOR);
    defaultEventor.post(CustomerUtil.CUSTOMER_PARTY_UPDATED, getModel().getCustomer());
    this.infoTabHelper.setTabUpdated("CUSTOMER_INFO");
    if (ConfigurationMgr.returnToCustomerSearchAfterSave())
      return this.HELPER.completeResponse();
    getModel().commitChanges();
    this.customerUIHelper.updateCustInfoDisplayMessage(customer);
    IOrder order = this.orderMgr.getCurrentOrder();
    if (order != null) {
      order.setCustomer(this.orderHelper.getCustomerModifier(customer, order));
      if (this.orderMgr.getDeliveryInfo() != null)
        this.orderMgr.setDeliveryInfo(order.getCustomer());
    }
    return this.HELPER.getChangeFormResponse(getFormKey(), getModel(), getActionGroupKey(), false);
  }

  protected boolean isAllowAddCustToTran() {
    return this.allowAddCustToTran;
  }

  @Override
  protected boolean isEditable() {
    return this.editable;
  }

  protected void setEditable(boolean argEditable) {
    this.editable = argEditable;
  }
  
  private KsrCustomerMaintenanceModel setAdditionalProperties(KsrCustomerMaintenanceModel model, IParty party) {
    
    HashMap<String,Object> map=new HashMap<>();
    map.put("argPartyId", party.getPartyId());
    map.put("argOrganizationId", ConfigurationMgr.getOrganizationId());
    List<IQueryResult> custDetails=DataFactory.getObjectByQueryNoThrow(query, map);
    
    for(IQueryResult res: custDetails)
    {
      if(((String) res.get(KsrConstants.PROPERTY_CODE)).equalsIgnoreCase(KsrConstants.ID_EXPIRATION_DATE_CODE)) {
          try {
            Date date= new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.S").parse((String) res.get(KsrConstants.STRING_VALUE));
            model.setValue(this.getFieldKey((String) res.get(KsrConstants.PROPERTY_CODE)), date);
            continue;
          }
          catch (Exception ex) {
            _logger.error("CAUGHT EXCEPTION:", ex);
          }
      }
      model.setValue(this.getFieldKey((String) res.get(KsrConstants.PROPERTY_CODE)), res.get(KsrConstants.STRING_VALUE));
    }
 
    return model;
  }

  private String getFieldKey(String propertyCode) {
    
    if(propertyCode.equalsIgnoreCase(KsrConstants.CUST_ID_NUMBER_CODE))
      return KsrConstants.CUSTOMER_ID_NUMBER;
    else if(propertyCode.equalsIgnoreCase(KsrConstants.CUST_ID_TYPE_CODE))
      return KsrConstants.CUSTOMER_ID_TYPE;
    else if(propertyCode.equalsIgnoreCase(KsrConstants.ID_COUNTRY_CODE))
      return KsrConstants.ID_COUNTRY;
    else if(propertyCode.equalsIgnoreCase(KsrConstants.ID_EXPIRATION_DATE_CODE))
      return KsrConstants.ID_EXPIRATION_DATE;
    else if(propertyCode.equalsIgnoreCase(KsrConstants.REL_TO_PATIENT_CODE))
      return KsrConstants.RELATIONSHIP_TO_PATIENT;
    else 
      return KsrConstants.ISSUING_AGENCY;
  }
}