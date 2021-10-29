//$Id$
package ksr.ui.swing.text;

import org.apache.log4j.LogManager;
import org.apache.log4j.Logger;

import dtv.i18n.*;
import dtv.pos.iframework.validation.IValidationResult;
import dtv.ui.UIResourceManager;
import dtv.ui.swing.text.DefaultStyler;
import dtv.util.CompositeObject;
import dtv.util.StringUtils;
import dtv.util.NumberUtils;

/**
 * 
 *
 * Spec Name/#:
 * Developer: Aaditya Singh
 * Reviewed By:
 * Issue # (if any):
 * Comments: Class to increase the rows showed
 * in validation prompt
 * 
 */
public class KsrValidationResultsStyler extends DefaultStyler {
  
  private static final String HEADER_PREFIX = UIResourceManager.getInstance().getString("_formatHeader");
  private static final String DETAIL_PREFIX = UIResourceManager.getInstance().getString("_formatDetail");
  private static final int MAX_VALIDATIONS_TO_SHOW = 8;
  private final IValidationResult[] validationResults;
  private String problemDetails;
  private static final Logger _logger = LogManager.getLogger(KsrValidationResultsStyler.class);

  public KsrValidationResultsStyler(String argProblemHeader, IValidationResult[] argValidationResults) {
    super((CompositeObject.TwoPiece<String, String>[]) new CompositeObject.TwoPiece[0]);
    this.validationResults = argValidationResults;
    int extraErrors = argValidationResults.length - MAX_VALIDATIONS_TO_SHOW;
    String problemDetails = "";
    for (int index = 0; index < ((Integer) NumberUtils.leastNonNull(
            (Comparable[]) new Integer[]{argValidationResults.length, MAX_VALIDATIONS_TO_SHOW}))
                    .intValue(); index++) {
        IValidationResult result = argValidationResults[index];
        String problemDetail = DETAIL_PREFIX + result.getMessage();
        problemDetails = StringUtils.appendLine(problemDetails, problemDetail);
    }
    if (extraErrors > 0) {
        String extraErrorsMsgKey = (extraErrors == 1)
                ? "_formValidationAdditionalMessage"
                : "_formValidationAdditionalMessages";
        IFormattable extraErrorArg = FormattableFactory.getInstance().getLiteral(Integer.valueOf(extraErrors));
        IFormattable extraErrorMsg = FormattableFactory.getInstance().getTranslatable(extraErrorsMsgKey,
            extraErrorArg);
        String extraDetail = DETAIL_PREFIX + extraErrorMsg.toString();
        problemDetails = StringUtils.appendLine(problemDetails, extraDetail);
    }
    this.problemDetails = problemDetails;
    CompositeObject.TwoPiece<String, String> headerStyle = CompositeObject.make(HEADER_PREFIX + argProblemHeader,
            "header");
    CompositeObject.TwoPiece<String, String> detailStyle = CompositeObject.make(problemDetails, "detail");
    this._styleData.add(headerStyle);
    this._styleData.add(detailStyle);
  }

  public String getProblemDetails() {
    return this.problemDetails;
  }

  public IValidationResult[] getValidationResults() {
    return this.validationResults;
  }

}
