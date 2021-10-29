//$Id$
package ksr.pos.web;

import static javax.ws.rs.core.MediaType.APPLICATION_JSON;
import static org.glassfish.jersey.client.ClientProperties.CONNECT_TIMEOUT;
import static org.glassfish.jersey.client.ClientProperties.READ_TIMEOUT;

import javax.ws.rs.client.Client;
import javax.ws.rs.client.ClientBuilder;
import javax.ws.rs.client.Invocation.Builder;

import org.glassfish.jersey.client.ClientConfig;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.jaxrs.json.JacksonJsonProvider;

import dtv.util.StringUtils;

public class KsrWebMethodHelper {

  public Builder buildWebmethodPostRequestHeader(String argUrl) {

    ClientConfig config = new ClientConfig();
    Client client = ClientBuilder.newClient(config).register(JacksonJsonProvider.class);
    client.property(CONNECT_TIMEOUT, 300000);
    client.property(READ_TIMEOUT, 300000);
    Builder webResourceBuilder = client.target(argUrl).request(APPLICATION_JSON);
    return webResourceBuilder;
  }

  public String getStringFromJson(Object argObject) {
    ObjectMapper mapper = new ObjectMapper();
    String jsonInString = StringUtils.EMPTY;
    try {
      jsonInString = mapper.writeValueAsString(argObject);
    }
    catch (JsonProcessingException ex) {
    }
    return jsonInString;
  }

}
