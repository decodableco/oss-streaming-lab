package co.decodable.examples;

import ai.djl.huggingface.tokenizers.HuggingFaceTokenizer;
import ai.onnxruntime.OnnxTensor;
import ai.onnxruntime.OrtEnvironment;
import ai.onnxruntime.OrtSession;
import io.quarkus.logging.Log;
import jakarta.annotation.PostConstruct;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.nio.file.Paths;
import java.util.Map;
import java.util.Arrays;
import java.util.stream.IntStream;

import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.util.stream.Collectors;

@Path("/local/model")
public class LocalModelResource {

    @ConfigProperty(name = "app.path.to.model")
    String pathToModel;

    @ConfigProperty(name = "app.path.to.tokenizer")
    String pathToTokenizer;

    private OrtEnvironment env;
    private OrtSession session;
    private HuggingFaceTokenizer tokenizer;

    @PostConstruct
    void initModel() throws Exception {
        env = OrtEnvironment.getEnvironment();
        session = env.createSession(pathToModel);
        tokenizer = HuggingFaceTokenizer.newInstance(Paths.get(pathToTokenizer));
    }

    @POST
    @Produces(MediaType.TEXT_PLAIN)
    @Consumes(MediaType.TEXT_PLAIN)
    @Path("/stars_predictor")
    public int predictStarsRating(String text) throws Exception {
        Log.infov("🔮 determine stars rating for -> {0}",text);
        var encoding = tokenizer.encode(text);
        var result = session.run(
                Map.of(
                    "input_ids",
                    OnnxTensor.createTensor(env, new long[][]{encoding.getIds()}),
                    "attention_mask",
                    OnnxTensor.createTensor(env, new long[][]{encoding.getAttentionMask()}),
                    "token_type_ids",
                    OnnxTensor.createTensor(env, new long[][]{encoding.getTypeIds()})
                )
        );
        float[] rawLogits = ((OnnxTensor)result.get(0)).getFloatBuffer().array();
        Log.debugv("🧮 raw logits -> {0}",Arrays.toString(rawLogits));
        int stars = deriveStarsRating(rawLogits);
        Log.infov("🌟 derived stars rating -> {0}: {1}",
            stars,
            IntStream.rangeClosed(1, stars)
                .mapToObj(i -> "⭐️")
                .collect(Collectors.joining())
        );
        return stars;
    }

    private static int deriveStarsRating(float[] logits) {
        int idxMax = 0;
        for (int i = 1; i < logits.length; i++) {
            if (logits[i] > logits[idxMax]) {
                idxMax = i;
            }
        }
        return idxMax + 1;
    }

}
