
package ksr.pos.web;

import java.net.URI;
import java.net.http.*;
import java.time.Duration;

import javax.ws.rs.core.Response;

import ksr.pos.common.KsrConfigurationMgr;
import ksr.pos.json.pojo.KsrControlItemCheckPojo;

public class KsrPseItemCheckRequestHandler {

  /* @Inject
  private KsrWebMethodHelper _ksrWebmethodHelper;*/

  private KsrWebMethodHelper _ksrWebmethodHelper = null;
  Response clientResponse = null;



  public String buildPostRequestPseItemCheck(KsrControlItemCheckPojo argRequest) {

    _ksrWebmethodHelper = new KsrWebMethodHelper();
    String inputJson = _ksrWebmethodHelper.getStringFromJson(argRequest);

    HttpClient httpClient = HttpClient.newBuilder().version(HttpClient.Version.HTTP_2)
        .connectTimeout(Duration.ofSeconds(KsrConfigurationMgr.getWebMethodConnectionTimeOut())).build();

    HttpRequest request = HttpRequest.newBuilder().timeout(Duration.ofSeconds(30))
        .POST(HttpRequest.BodyPublishers.ofString(inputJson))
        .uri(URI.create(KsrConfigurationMgr.getWebConnectionURL()))
        .header(KsrWebmethodConstant.CONTENT_TYPE, "application/json").build();

    HttpResponse<String> response = null;
    try {
      response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

      // print status code
      System.out.println(response.statusCode());

      // print response body
      return response.body();
    }
    catch (Exception ex) {
      ex.printStackTrace();

      /*   adminLoggerDb_.error("Exception Caught during webmethod call: ", ex);
      adminLoggerLog_.error("Exception Caught during webmethod call: ", ex);*/
    }

    return "";
  }

  @SuppressWarnings("unused")
  private String generateUrl(String argUrl) {
    StringBuilder sb = new StringBuilder(argUrl);
    /*sb.append("?").append("region=").append(_elcWebUtility.getRegion()).append("&").append("brand=")
        .append(_elcWebUtility.getBrand());*/

    sb.append("");

    return sb.toString();
  }

}
