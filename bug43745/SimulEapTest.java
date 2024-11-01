import org.apache.http.HttpEntity;
import org.apache.http.HttpHeaders;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;

import java.io.IOException;
import java.net.URI;

public class SimulEapTest {

	public static void main(String[] args) throws IOException, InterruptedException {
		
		URI myUri = URI.create("http://mytest.apps.hongli-az.qe.azure.devcluster.openshift.com");
		try (CloseableHttpClient hc = HttpClients.createDefault()) {
			try (CloseableHttpResponse response = hc.execute(new HttpGet(myUri))) {
				String responseString = EntityUtils.toString(response.getEntity()).trim();
				System.out.println(responseString);
			}

			// time to wait the service is updated in route
			System.out.println(">>> please update the route, waiting 240s and try HttPGet again");
			Thread.sleep(240_000L);
			
			try (CloseableHttpResponse response = hc.execute(new HttpGet(myUri))) {
				String responseString = EntityUtils.toString(response.getEntity()).trim();
				System.out.println(responseString);
			}
			
			// wait 6s and retry with same client
			System.out.println(">>> waiting 6s and retry with same HttpClient");
			Thread.sleep(6_000L);
			
			try (CloseableHttpResponse response = hc.execute(new HttpGet(myUri))) {
				String responseString = EntityUtils.toString(response.getEntity()).trim();
				System.out.println(responseString);
			}

			// wait 6s and retry with same client
			System.out.println(">>> waiting 6s and retry with same HttpClient");
			Thread.sleep(6_000L);
			
			try (CloseableHttpResponse response = hc.execute(new HttpGet(myUri))) {
				String responseString = EntityUtils.toString(response.getEntity()).trim();
				System.out.println(responseString);
			}
		}
	}
}
