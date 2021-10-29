//$Id$
package ksr.pos.pretender;

import java.math.BigDecimal;
import java.util.List;

import ksr.pos.KsrConstants;

import dtv.data2.access.DataFactory;
import dtv.pos.common.OpChainKey;
import dtv.pos.common.TransactionType;
import dtv.pos.framework.op.Operation;
import dtv.pos.iframework.event.IXstEvent;
import dtv.pos.iframework.op.IOpResponse;
import dtv.xst.dao.itm.ItemPropertyId;
import dtv.xst.dao.itm.impl.ItemPropertyModel;
import dtv.xst.dao.trl.*;
import dtv.xst.dao.trl.impl.SaleReturnLineItemModel; 
/**
Spec Name/#:Identify PSE item and Capture Customer Information
Developer:akshat jain
Reviewed By:
Issue # (if any):
Comments:
 * @author akshat jain
 * @created 09-Sep-2021
 * @version $Revision$
 */
/**
Spec Name/#:Identify PSE item and Capture Customer Information
Developer:akshat jain
Reviewed By:
Issue # (if any):
Comments:
 * @author akshat jain
 * @created 09-Sep-2021
 * @version $Revision$
 */
/*********************************************************************************************************
 * Description:
 * Created By: akshat jain
 * 
 * Created Date: 09-Sep-2021
 * 
 *  History:
 *  
 *  Vers              Date              By                       Spec                    Description
 * $Revision$       09-Sep-2021       akshat jain                                     Identify PSE item and 
 *                                                                                 Capture Customer Information        
*********************************************************************************************************/

 
public class KsrPreTenderPseItemCheckOp extends Operation {

  @Override
  public boolean isOperationApplicable() {
    IRetailTransaction transaction = this.getTransaction(); 
    List<IRetailTransactionLineItem> itms = transaction.getSaleLineItems(); //Items in Tender
    
   if(transaction.getCustomerParty()==null) {
    for(IRetailTransactionLineItem itm:itms){ 
        if(itm instanceof ISaleReturnLineItem && !itm.getVoid()) {
        ItemPropertyId id = new ItemPropertyId(); 
        id.setOrganizationId(itm.getOrganizationId());
        id.setItemId(((SaleReturnLineItemModel) itm).getItemId()); 
        id.setPropertyCode(KsrConstants.ITEM_PSE_PROPERTY_CODE); 
        ItemPropertyModel model= DataFactory.getObjectByIdNoThrow(id); //Fetching properties corresponding to selected Item   
        if(model!=null && model.getDecimalValue().equals(BigDecimal.valueOf(1))) //Checking if the Item is PSE Item
           return true;         
        }
      }
    return false;
  }
   else
      return false ;
  }

  @Override
  public IOpResponse handleOpExec(IXstEvent argArg0) {
    return this.HELPER.getCompleteStackChainResponse(OpChainKey.valueOf("CUST_ASSOCIATION"));
  } 
  
  protected IRetailTransaction getTransaction() {
    return this._transactionScope.getTransaction(TransactionType.RETAIL_SALE);
   }
}

