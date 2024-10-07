package co.decodable.examples.flink.udf;

import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse.BodyHandlers;

public class SentimentScoring extends AbstractHttpFetcher {

    public static final String MODEL_API_ENDPOINT = "http://model-serving-app:8080/local/model/stars_predictor";

    public Integer eval(String text) {
        try {
            var postRequest = 
                HttpRequest.newBuilder()
                    .uri(URI.create(MODEL_API_ENDPOINT))
                    .header("Content-Type", "text/plain; charset=utf-8")
                    .POST(HttpRequest.BodyPublishers.ofString(text))
                    .build();
                var response = doRequest(postRequest, BodyHandlers.ofString());
            return response.statusCode() == 200 ? Integer.valueOf(response.body()) : null;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

}
