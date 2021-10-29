//$Id$
package ksr.pos.disclaimer;

import dtv.pos.framework.form.BasicEditModel;
import dtv.pos.framework.op.Operation;
import dtv.pos.iframework.event.IXstEvent;
import dtv.pos.iframework.op.IOpResponse;

/**
 * This class is responsible for displaying login disclaimer text on the login screen.
 *
 * @author Ashutosh
 * @created 13-Sep-2021
 * @version $Revision$
 */
public class KsrDisclaimerInfoOp extends Operation {

private static final long serialVersionUID = 1L;
private static final String formKey = "DISCLAIMER_INFO";

/** {@inheritDoc} */
@Override
public IOpResponse handleOpExec(IXstEvent argArg0) {
  BasicEditModel model = new BasicEditModel();
  return this.HELPER.getCompleteShowFormResponse(formKey, model);
  }
}
