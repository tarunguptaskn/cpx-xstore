//$Id$
package ksr.pos.customer;


import dtv.pos.customer.*;
import dtv.pos.iframework.ILocationFactory;
import javax.inject.Inject;

import ksr.pos.KsrConstants;

/**
 * 
 *
 * Spec Name/#:
 * Developer: Aaditya Singh
 * Reviewed By:
 * Issue # (if any):
 * Comments: Class to set the default value of state
 * to where the register is installed
 * 
 */


public class KsrCustomerSearchOp extends CustomerSearchOp {
  
  @Inject
  private ILocationFactory locationFactory;

  @Override
  protected CustomerSearchModel createModel() {
    
    CustomerSearchModel model=new CustomerSearchModel();
    
    // getting the state value from retail location id and setting it as default
    
    model.setValue(KsrConstants.STATE, this.locationFactory.getStoreById(this._stationState.getRetailLocationId()).getState());
    return model;
  }
  
  
}
