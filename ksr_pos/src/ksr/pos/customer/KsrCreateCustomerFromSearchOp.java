//$Id$
package ksr.pos.customer;

import java.util.*;

import javax.inject.Inject;

import ksr.pos.KsrConstants;
import ksr.ui.swing.text.KsrValidationResultsStyler;

import dtv.data2.access.DataFactory;
import dtv.i18n.OutputContextType;
import dtv.pos.common.ConfigurationMgr;
import dtv.pos.common.ValueKeys;
import dtv.pos.customer.CreateCustomerOp;
import dtv.pos.customer.CustomerMaintenanceModel;
import dtv.pos.framework.ui.prompt.*;
import dtv.pos.iframework.event.IXstEvent;
import dtv.pos.iframework.op.IOpResponse;
import dtv.pos.iframework.validation.IValidationResultList;
import dtv.xst.dao.crm.*;
import dtv.xst.dao.crm.impl.PartyPropertyModel;

/**
 * 
 *
 * Spec Name/#:
 * Developer: Aaditya Singh
 * Reviewed By:
 * Issue # (if any):
 * Comments: Custom class for CreateCustomerFromSearchOp to persist 
 * values of new fields in customer capture screen
 * 
 */
public class KsrCreateCustomerFromSearchOp extends CreateCustomerOp {

  @Inject
  private IPromptFactory promptFactory;
  
  @Override
  protected IOpResponse handleAbortChanges(IXstEvent argEvent) {
      return this.HELPER.silentErrorResponse();
  }

  @Override
  protected IOpResponse handleDisplayAgain() {
      CustomerMaintenanceModel custModel = this.getModel();
      IPartyLocaleInformation addressInformation = this
              .getScopedValue(ValueKeys.ADDRESS_SEARCH_RESULT);
      if (addressInformation != null) {
          custModel.setAddress1(addressInformation.getAddress1());
          custModel.setAddress2(addressInformation.getAddress2());
          custModel.setAddress3(addressInformation.getAddress3());
          custModel.setAddress4(addressInformation.getAddress4());
          custModel.setApartment("");
          custModel.setCity(addressInformation.getCity());
          custModel.setPostalCode(addressInformation.getPostalCode());
          custModel.setState(addressInformation.getState());
          custModel.setCounty(addressInformation.getCounty());
          custModel.setNeighborhood(addressInformation.getNeighborhood());
      }

      this.clearScopedValue(ValueKeys.ADDRESS_SEARCH_RESULT);
      return super.handleDisplayAgain();
  }

  @Override
  protected IOpResponse handleSaveComplete(IXstEvent argEvent) {
      IOpResponse response = super.handleSaveComplete(argEvent);
      this.setScopedValue(ValueKeys.SHIP_TO_PARTY, this.getScopedValue(ValueKeys.SELECTED_CUSTOMER));
      return response;
  }

  @Override
  protected IOpResponse handleFormResponse(IXstEvent argEvent) {
    
    CustomerMaintenanceModel custModel=this.getModel();
    List<PartyPropertyModel> models = this.getModelsToPersist(custModel);
    DataFactory.makePersistent(models);
    
    return super.handleFormResponse(argEvent);
  }
  
  @Override
  protected IOpResponse getFormValidityResponse(CustomerMaintenanceModel argModel) {
    IValidationResultList results = this.validateForm(this.getModel());
    if (results.isValid()) {
      return null;
    } else {
      this.setOpState(this.VALIDATION_ERROR);
      String promptKey = this.getFormValidationFailedPromptKey();
      IPrompt prompt = this.promptFactory.getPrompt(promptKey);
      String problemHeader = prompt.getMessage().toString(OutputContextType.VIEW);
      KsrValidationResultsStyler styler = new KsrValidationResultsStyler(problemHeader, results.getInvalidResults());
      PromptOverrideProperties overrides = new PromptOverrideProperties();
      overrides.setPromptStyler(styler);
      return this.HELPER.getPromptResponse(promptKey, overrides, false);
    }
  }
  
  
  private List<PartyPropertyModel> getModelsToPersist(CustomerMaintenanceModel custModel){

    IParty customer = this.getScopedValue(ValueKeys.SELECTED_CUSTOMER);
    List<PartyPropertyModel> models = new ArrayList<>();

    List<String> propertyCodes= Arrays.asList(KsrConstants.CUST_ID_NUMBER_CODE,KsrConstants.CUST_ID_TYPE_CODE,KsrConstants.ISSUING_AGENCY_CODE,KsrConstants.ID_COUNTRY_CODE,KsrConstants.ID_EXPIRATION_DATE_CODE,KsrConstants.REL_TO_PATIENT_CODE);
    List<String> fieldNames= Arrays.asList(KsrConstants.CUSTOMER_ID_NUMBER,KsrConstants.CUSTOMER_ID_TYPE,KsrConstants.ISSUING_AGENCY,KsrConstants.ID_COUNTRY,KsrConstants.ID_EXPIRATION_DATE,KsrConstants.RELATIONSHIP_TO_PATIENT);
    int i=0;
    for(String propertyCode: propertyCodes){
      PartyPropertyId id= new PartyPropertyId();
      id.setOrganizationId(ConfigurationMgr.getOrganizationId());
      id.setPartyId(customer.getPartyId());
      id.setPropertyCode(propertyCode);
      PartyPropertyModel model=DataFactory.getObjectByIdNoThrow(id);
      if(model==null)
        model=(PartyPropertyModel) DataFactory.createObject(id,IPartyProperty.class);
      model.setType(KsrConstants.TYPE_STRING);
      Object fieldValue = custModel.getValue(fieldNames.get(i));
      model.setStringValue(fieldValue.toString());
      models.add(model);
      i++;
    }
    return models;

  }
  
}
