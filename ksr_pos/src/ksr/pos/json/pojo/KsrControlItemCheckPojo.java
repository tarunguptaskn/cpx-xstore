
package ksr.pos.json.pojo;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonProperty;

public class KsrControlItemCheckPojo {

  
  @JsonProperty("controlitems")
  private List<String> controlItemList;
  @JsonProperty("firstname")
  private String custFirstName;
  @JsonProperty("lastname")
  private String lastname;
  @JsonProperty("mailid")
  private String mailId;
  @JsonProperty("phonenumber")
  private String phoneNumber;
  /**
   * Returns 
   * @return 
   */
  public List<String> getControlItemList() {
    return controlItemList;
  }
  /**
   * Specifies
   * @param argControlItemList 
   */
  public void setControlItemList(List<String> argControlItemList) {
    controlItemList = argControlItemList;
  }
  /**
   * Returns 
   * @return 
   */
  public String getCustFirstName() {
    return custFirstName;
  }
  /**
   * Specifies
   * @param argCustFirstName 
   */
  public void setCustFirstName(String argCustFirstName) {
    custFirstName = argCustFirstName;
  }
  /**
   * Returns 
   * @return 
   */
  public String getLastname() {
    return lastname;
  }
  /**
   * Specifies
   * @param argLastname 
   */
  public void setLastname(String argLastname) {
    lastname = argLastname;
  }
  /**
   * Returns 
   * @return 
   */
  public String getMailId() {
    return mailId;
  }
  /**
   * Specifies
   * @param argMailId 
   */
  public void setMailId(String argMailId) {
    mailId = argMailId;
  }
  /**
   * Returns 
   * @return 
   */
  public String getPhoneNumber() {
    return phoneNumber;
  }
  /**
   * Specifies
   * @param argPhoneNumber 
   */
  public void setPhoneNumber(String argPhoneNumber) {
    phoneNumber = argPhoneNumber;
  }
  
  
  
  
  
}
