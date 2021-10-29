package ksr.pos.validators;

import java.io.File;
import java.io.StringReader;
import java.nio.charset.Charset;
import java.util.Properties;
import java.util.regex.Pattern;


import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import ksr.pos.KsrConstants;

import dtv.pos.framework.form.validators.IEditModelFieldValidator;
import dtv.pos.iframework.form.IEditModel;
import dtv.pos.iframework.form.IEditModelField;
import dtv.pos.iframework.validation.IValidationResult;
import dtv.pos.iframework.validation.SimpleValidationResult;

/**
 * 
 *
 * Spec Name/#:
 * Developer: Aaditya Singh
 * Reviewed By:
 * Issue # (if any):
 * Comments: Class for regex validation of the fields
 * in customer capture screen
 * 
 */
public class KsrCustMaintFieldValidator
implements
IEditModelFieldValidator<Object> {

  private static final Logger logger_ = LogManager.getLogger(KsrCustMaintFieldValidator.class);
  private File regexPropFile;

  @Override
  public IValidationResult validateField(IEditModel argEditModel, IEditModelField<Object> argField) {
    IValidationResult result = SimpleValidationResult.getPassed();
    if (!argField.isReadOnly() && argField.isAvailable()) {
      Object fieldValue = argEditModel.getValue(argField.getFieldKey());

      logger_.error(String.format("Regex Validation for: %s " , argField.getFieldKey()));
      boolean valid = (fieldValue == null) ? true : isValid(argField.getFieldKey(), fieldValue.toString());
      result = valid ? SimpleValidationResult.getPassed() : SimpleValidationResult.getFailed("_invalid"+argField.getFieldKey());
    }
    return result;
  }

  public boolean isValid(String fieldKey, CharSequence argText) {
    regexPropFile = new File(KsrConstants.REGEX_VALIDATION_FILE);
    Pattern pattern = Pattern.compile(getRegEx(fieldKey));
    try {
      if (argText == null) {
        return pattern.matcher("").matches();
      }
      else {
        return pattern.matcher(argText).matches();
      }
    }
    catch (Exception ex) {
      logger_.error(KsrConstants.CAUGHT_EXCEPTION, ex);
    }
    return true;
  }

  protected String getRegEx(final String argKey) {
    String regex = null;
    Properties props = new Properties();
    StringReader r = null;
    try {
      r = new StringReader(
          org.apache.commons.io.FileUtils.readFileToString(regexPropFile,Charset.defaultCharset()).replace("\\", "\\\\"));
      props.load(r);
      regex = props.getProperty(argKey);
      if (regex == null) {
        regex = props.getProperty(KsrConstants.DEFAULT_REGEX);
        return regex;
      }
      return regex;
    }
    catch (Exception ex) {
      logger_.error(KsrConstants.CAUGHT_EXCEPTION, ex);
      return regex;
    }
    finally {
      try {
        if (r != null) {
          r.close();
        }
      }
      catch (Exception e) {
        logger_.error(KsrConstants.CAUGHT_EXCEPTION, e);
      }
    }
  }
}
