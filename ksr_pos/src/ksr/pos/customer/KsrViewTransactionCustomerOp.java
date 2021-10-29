//$Id$
package ksr.pos.customer;

import dtv.pos.common.TransactionType;
import dtv.pos.common.ValueKeys;
import dtv.xst.dao.trl.IRetailTransaction;

/**
 * 
 *
 * Spec Name/#:
 * Developer: Aaditya Singh
 * Reviewed By:
 * Issue # (if any):
 * Comments: Class to handle the new model
 * related changes
 * 
 */
public class KsrViewTransactionCustomerOp extends KsrEditCustomerOp {

  @Override
  public boolean isOperationApplicable() {
    return true;
  }
  
  @Override
  protected KsrCustomerMaintenanceModel createModel() {
    IRetailTransaction trans = this._transactionScope.getTransaction(TransactionType.RETAIL_SALE);
    this.setScopedValue(ValueKeys.SELECTED_CUSTOMER, trans.getCustomerParty());
    return super.createModel();
  }
  
}
