//$Id$
package ksr.pos.web;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import ksr.pos.json.pojo.KsrControlItemCheckPojo;

import dtv.i18n.FormattableFactory;
import dtv.pos.framework.op.Operation;
import dtv.pos.iframework.event.IXstEvent;
import dtv.pos.iframework.op.IOpResponse;
import dtv.xst.dao.crm.IParty;
import dtv.xst.dao.trl.IRetailTransaction;
import dtv.xst.dao.trl.ISaleReturnLineItem;
import dtv.xst.dao.trn.IPosTransaction;

public class KsrPseControlledItemsOp
    extends
    Operation {

  /*  @Inject
  private KsrRequestHandler ksrRequestHandler;*/

  @Override
  public IOpResponse handleOpExec(IXstEvent argArg0) {

    IPosTransaction transaction = _transactionScope.getTransaction();
    IRetailTransaction retailTrans = (IRetailTransaction) transaction;
    IParty party = retailTrans.getCustomerParty();

    KsrControlItemCheckPojo controlItemCheckPojo = new KsrControlItemCheckPojo();
    KsrPseItemCheckRequestHandler ksrRequestHandler = new KsrPseItemCheckRequestHandler();

    controlItemCheckPojo.setCustFirstName(party.getFirstName());

    List<ISaleReturnLineItem> saleLineItems = transaction.getLineItems(ISaleReturnLineItem.class);

    List<String> itemList1 = new ArrayList<String>();

    for (ISaleReturnLineItem saleItem : saleLineItems) {
      int i = 0;
      if (!saleLineItems.get(i).getVoid()) {
        String itemId = saleItem.getItemId();
        itemList1.add(itemId);
      }
      i++ ;
    }

    List<String> itemList = saleLineItems.stream().filter(item -> !item.getVoid())
        .map(ISaleReturnLineItem::getItemId).collect(Collectors.toList());
    System.out.println(itemList1);

    //  List<String> itemList = saleLineItems.stream().map(item -> item.getItemId()).collect(Collectors.toList());

    controlItemCheckPojo.setControlItemList(itemList);

    controlItemCheckPojo.setLastname("last");
    controlItemCheckPojo.setMailId("h@mail.com");
    controlItemCheckPojo.setPhoneNumber("931874897");

    // String responce = ksrRequestHandler.handleRequest(controlItemCheckPojo);

    String responce = ksrRequestHandler.buildPostRequestPseItemCheck(controlItemCheckPojo);

    if ("decline".equals(responce)) {
      /* return this.HELPER.getPromptResponse("promptkey",
          FormattableFactory.getInstance().getTranslatable("pseitem"));*/
      return this.HELPER.getErrorResponse(FormattableFactory.getInstance().getTranslatable("pseitem"));
    }
    else if ("Approved".equals(responce)) {
      return this.HELPER.completeResponse();
    }

    else {
      return this.HELPER.completeResponse();
    }
  }

}
