//$Id$
package ksr.pos.customer;

import java.util.*;
import java.util.function.Function;
import java.util.function.Predicate;

import javax.inject.Inject;

import ksr.pos.KsrConstants;

import dtv.data2.access.IDataModel;
import dtv.pos.common.ConfigurationMgr;
import dtv.pos.customer.*;
import dtv.pos.framework.form.*;
import dtv.pos.framework.location.*;
import dtv.pos.iframework.ILocationFactory;
import dtv.pos.iframework.form.*;
import dtv.pos.iframework.form.config.*;
import dtv.pos.iframework.security.ISecuredObjectID;
import dtv.pos.iframework.security.SecuredObjectID;
import dtv.util.address.*;
import dtv.xst.dao.com.CodeLocator;
import dtv.xst.dao.com.ICodeValue;

/**

 *
 * Spec Name/#:
 * Developer: Aaditya Singh
 * Reviewed By:
 * Issue # (if any):
 * Comments: Custom model class to add new fields in the
 * customer capture screen
 * 
 */
public class KsrCustomerMaintenanceModel extends CustomerMaintenanceModel { 
  
  private final IValueWrapperFactory codeWrapperFactory= ValueWrapperFactory.makeWrapperFactory(CodeEnumValueWrapper.class);
  
  private String custIdNumber;
  private String custIdType;
  private  String issuingAgency;
  private String custIdCountry;
  private Date idExpirationDate;
  private String relToPatient;
  
  final StateWrapperFactory stateFactory;
  
  @Inject
  private ILocationFactory locationFactory;
  
  @SuppressWarnings("unchecked")
  public KsrCustomerMaintenanceModel(IDataModel[] argParam1, IDaoEditMappingConfig argParam2,
      Boolean argParam3) {
    super(argParam1, argParam2, argParam3);
    
    final IDataEditFieldListConfig partylocaleOtherFields = Arrays.stream(this.mappingConfig_.getDataDefs()).filter(x -> x.getMappingId().equals("PARTY_LOCALE")).findFirst().map(x -> x.getOtherFields()).orElse(null);

    
    List<? extends ICodeValue> custIdTypeList = CodeLocator.getCodeValues(ConfigurationMgr.getOrganizationId(), KsrConstants.CREDIT_PRIMARY_ID_CODE);
    List<? extends ICodeValue> relToPatientList = CodeLocator.getCodeValues(ConfigurationMgr.getOrganizationId(), KsrConstants.REL_TO_PATIENT_CODE);
    
    
    Collection<IRegion> regions = StoreLocationHelper.getInstance().getRegions();
    List<ICountry> countries = new ArrayList<>();
    Iterator<IRegion> iterator = regions.iterator();
   

    while(iterator.hasNext()) {
       IRegion region = iterator.next();
       countries.addAll(Arrays.asList(region.getCountries()));
    }
    
    String country=this.locationFactory.getStoreById(this._stationState.getRetailLocationId()).getCountry();
    
    IValueWrapperFactory countryWrapperFactory = this.getFieldDef("country").getValueWrapper();
    
    
    this.addField(KsrConstants.CUSTOMER_ID_NUMBER,String.class);
    this.addField(KsrConstants.ID_EXPIRATION_DATE,Date.class);
    
    this.addField(EditModelField.makeFieldDefUnsafe(this, KsrConstants.CUSTOMER_ID_TYPE, String.class, 2, null, null, custIdTypeList, null, codeWrapperFactory, null));
    this.addField(EditModelField.makeFieldDefUnsafe(this, KsrConstants.RELATIONSHIP_TO_PATIENT, String.class, 2, null, null, relToPatientList, null, codeWrapperFactory, null));
    this.addField(EditModelField.makeFieldDefUnsafe(this, KsrConstants.ID_COUNTRY, String.class, 2, null, null, countries, null, countryWrapperFactory, this.getSecuredObjId(partylocaleOtherFields, "country")));
    this.setValue(KsrConstants.ID_COUNTRY, this.locationFactory.getStoreById(this._stationState.getRetailLocationId()).getCountry());
    
    stateFactory = new StateWrapperFactory(country);
    this.addField(EditModelField.makeFieldDef(this, KsrConstants.ISSUING_AGENCY, String.class, 2, null, null, (List<String>) null, null, null, null));    

    initializeFieldState();
  }
  
  private ISecuredObjectID getSecuredObjId(final IDataEditFieldListConfig argConfig, final String argFieldname){
    return (argConfig != null) ? argConfig.getFieldConfig(argFieldname).getSecuredObject() : SecuredObjectID.CUSTOMER_CONTACT_INFO;
  }

  
  public String getCustIdNumber() {
    return custIdNumber;
  }

  
  public void setCustIdNumber(String argCustIdNumber) {
    custIdNumber = argCustIdNumber;
  }

  
  public String getCustIdType() {
    return custIdType;
  }

  
  public void setCustIdType(String argCustIdType) {
    custIdType = argCustIdType;
  }

  
  public String getIssuingAgency() {
    return issuingAgency;
  }

  
  public void setIssuingAgency(String argIssuingAgency) {
    issuingAgency = argIssuingAgency;
  }

  
  public String getCustIdCountry() {
    return custIdCountry;
  }

  
  @SuppressWarnings("unchecked")
  public void setCustIdCountry(String argCustIdCountry) {
    custIdCountry = argCustIdCountry;
    
    StateCache state = (StateCache) AddressService.getInternalInstance().getFieldCache(KsrConstants.DEFAULT_REGEX, KsrConstants.STATE);
    getFieldDef(KsrConstants.ISSUING_AGENCY).setEnumeratedPossibleValues(Arrays.asList(state.getStateArrayForCountry(argCustIdCountry)));
    getFieldDef(KsrConstants.STATE).setEnumeratedPossibleValues(Arrays.asList(state.getStateArrayForCountry(argCustIdCountry)));
  }

  
  public Date getIdExpirationDate() {
    return idExpirationDate;
  }

  
  public void setIdExpirationDate(Date argIdExpirationDate) {
    idExpirationDate = argIdExpirationDate;
  }

 
  public String getRelToPatient() {
    return relToPatient;
  }

 
  public void setRelToPatient(String argRelToPatient) {
    relToPatient = argRelToPatient;
  }
  
}
