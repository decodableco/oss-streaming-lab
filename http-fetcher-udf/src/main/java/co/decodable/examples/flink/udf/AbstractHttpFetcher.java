package co.decodable.examples.flink.udf;

import java.io.IOException;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpResponse.BodyHandler;

import org.apache.flink.table.functions.FunctionContext;
import org.apache.flink.table.functions.ScalarFunction;

public class AbstractHttpFetcher extends ScalarFunction {

    private transient HttpClient httpClient;

    @Override
    public void open(FunctionContext context) throws Exception {
        super.open(context); 
        httpClient = HttpClient.newHttpClient();
    }

    protected <T> HttpResponse<T> doRequest(HttpRequest httpRequest, BodyHandler<T> responseHandler) throws IOException, InterruptedException {
        return httpClient.send(httpRequest, responseHandler);
    }

}
