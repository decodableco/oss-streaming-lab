## Module 05 - Streaming Sentiment Analysis

This module will demonstrate how you can seamlessly integrate streaming data pipelines written in Flink SQL with a language model for sentiment analysis.
Specifically, you are going to capture product reviews from a database table and derive user sentiment in real-time by means of a custom pre-built application that serves 
a variant of the [BERT](https://en.wikipedia.org/wiki/BERT_(language_model)) model for in-application inference.
The concrete model in use has been [fine-tuned for sentiment analysis](https://huggingface.co/nlptown/bert-base-multilingual-uncased-sentiment) in the context of product reviews across six different languages and can infer user sentiment, expressed as 1..5 stars rating, from raw textual feedback.

!["Flink SQL sentiment analysis with custom UDF"](./images/m05/01-flink-sql-jobs-udf-sentiment-analysis.png)

### Setting Up the Postgres Source Connector

In the Flink CLI, run the following `CREATE TABLE` statement to define a Flink table named `reviews` using the `postgres-cdc` connector.
This table represents all user reviews.

```sql
CREATE TABLE reviews (
   id INT,
   item_id STRING,
   review_text STRING,
   PRIMARY KEY (id) NOT ENFORCED
)
WITH (
   'connector' = 'postgres-cdc',
   'hostname' = 'postgres',
   'port' = '5432',
   'username' = 'postgres',
   'password' = 'postgres',
   'database-name' = 'postgres',
   'schema-name' = 'inventory',
   'table-name' = 'review',
   'decoding.plugin.name' = 'pgoutput',
   'debezium.publication.name' = 'reviews_publication',
   'slot.name' = 'reviews_slot'
);
```

### Preview Data Changes

From within the Flink SQL CLI, write the following basic `SELECT` query to check the records in that table:

```sql
SELECT * FROM reviews;
```

You are expected to see a result set like the one shown below:

```bash
          id                        item_id                    review_text
          18                     B00A7ZJNHO thin and chinsy i could even ~
          19                     B016TZKU54 The filter did not fit in my ~
          20                     B08R9C3F83 This was hard to find out how~
          21                     B076ZRN68C Everything is great, easy to ~
          22                     B07CKYZRXH Used in one cup pod machine. ~
          23                     B0745N964K You can't beat the price! Awe~
          24                     B003AXVADA Good price for coffee filters.
          25                     B001TJ5380 These water filters do the sa~
```

Note, that text columns are truncated by default in the Flink CLI preview.
You can browse any of the records with your `up/down` arrow keys and press the `o` key to open details for the selected row.
For the last record in this preview having `id=25` this shows the following:

```bash
 id (INT NOT NULL):
 25

 item_id (STRING):
 B001TJ5380

 review_text (STRING):
 These water filters do the same job as the name brand from Samsung, but they are less expensive.
```

Pressing the `q` key brings you back to the table preview. Pressing `q` another time stops the query job.

### Sentiment Scoring

Transforming raw product review texts from users to sentiment scores requires custom functionality which is exposed via an HTTP API by the `model-serving-app` that already runs as part of the Docker Compose containers in the background.
This application embeds the pre-trained and fine-tuned BERT model and provides an HTTP POST endpoint taking the raw input text and returning a sentiment score between 1..5 stars.

```java
  @POST
  @Produces(MediaType.TEXT_PLAIN)
  @Consumes(MediaType.TEXT_PLAIN)
  @Path("/stars_predictor")
  public int predictStarsRating(String text) throws Exception {
        Log.infov("🔮 determine stars rating for -> {0}",text);
        var encoding = tokenizer.encode(text);
        var result = session.run(Map.of(/* ... */));
        /* ... */
        return stars;
  }
```

In order to use this HTTP endpoint from Flink SQL there is a pre-built user-defined function ([UDF](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/functions/udfs/)) that can be registered and applied to your SQL queries.
The JAVA source code for this UDF is rather straight-forward, the essence of which is this code snippet:

```java
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
```

This UDF is compiled and packaged into its own JAR file that is made available to Flink so that the actual `SentimentScoring` Java class can be found on Flink's classpath at runtime.

### Register and Apply UDF for Sentiment Scoring

Before you can use this function it needs to be registered.
In your Flink CLI session run the following `CREATE FUNCTION ...` statement to do so:

```sql
CREATE FUNCTION sentiment_score AS 'co.decodable.examples.flink.udf.SentimentScoring' LANGUAGE JAVA;
```

This should succeed as follows:

```bash
[INFO] Execute statement succeed.
```

You can quickly check which user-defined functions are currently available in your Flink SQL session:

```sql
SHOW USER FUNCTIONS;
```

```bash
+-----------------+
|   function name |
+-----------------+
|      array_aggr |
| sentiment_score |
+-----------------+
2 rows in set
```

With this additional user function `SENTIMENT_SCORE` in place, you can quickly experiment to check whether it's working as expected by running the `SELECT ...` query below which is based on static and made-up input data:

```sql
SELECT 
  raw_text,sentiment_score
FROM (
  VALUES
    ('Amazing! I am loving this.',sentiment_score('Amazing! I am loving this.')),
    ('Oh no. Very frustrating. Worst thing I ever had.',sentiment_score('Oh no. Very frustrating. Worst thing I ever had.')),
    ('Not too good but not too bad either.',sentiment_score('Not too good but not too bad either.'))
  ) t1(raw_text,sentiment_score);
```

The output is supposed to be deterministic, hence, your result set should look as follows:

```bash
                      raw_text sentiment_score
     Amazing! I am loving this.               5
 Oh no. Very frustrating. Wors~               1
 Not too good but not too bad ~               3
```

Next, run an interactive query which uses the UDF to derive the sentiment scores for all 25 existing reviews in the underlying database table:

```sql
SELECT
  id,
  item_id,
  review_text,
  SENTIMENT_SCORE(review_text) AS sentiment_score
FROM reviews;
```

The last page of the result set in the Flink SQL CLI looks like so:

```bash
          id                        item_id                    review_text sentiment_score
          18                     B00A7ZJNHO thin and chinsy i could even ~               1
          19                     B016TZKU54 The filter did not fit in my ~               1
          20                     B08R9C3F83 This was hard to find out how~               2
          21                     B076ZRN68C Everything is great, easy to ~               5
          22                     B07CKYZRXH Used in one cup pod machine. ~               5
          23                     B0745N964K You can''t beat the price! Awe~              5
          24                     B003AXVADA Good price for coffee filters.               4
          25                     B001TJ5380 These water filters do the sa~               4
```

### Setting Up an OpenSearch Sink Connector

In the Flink CLI, run the following `CREATE TABLE` statement to define a Flink table named `reviews_with_sentiment_os` using the `opensearch` connector.
This sink table adds an additional field named `sentiment_score` to represent the inferred user sentiment for the `review_text`.

```sql
CREATE TABLE reviews_with_sentiment_os (
  review_id INT,
  item_id STRING,
  review_text STRING,
  sentiment_score INT,
  PRIMARY KEY (review_id) NOT ENFORCED
 )
 WITH (
     'connector' = 'opensearch',
     'hosts' = 'http://opensearch-node1:9200',
     'username' = 'admin',
     'password' = 'admin',
     'index' = 'reviews_with_sentiment'
 );
```

Create another sink table named `items_avg_sentiment` which stores both, the number of reviews and the average sentiment score per `item_id` in the dataset. 

```sql
CREATE TABLE items_avg_sentiment_os (
    item_id STRING,
    num_reviews BIGINT,
    avg_sentiment_score FLOAT,
    PRIMARY KEY (item_id) NOT ENFORCED
)
WITH (
    'connector' = 'opensearch',
    'hosts' = 'http://opensearch-node1:9200',
    'username' = 'admin',
    'password' = 'admin',
    'index' = 'items_avg_sentiment'
);
```

### Using STATEMENT SET to create SQL job

With these new sink tables in place, we can create the Flink jobs by running the necessary `INSERT INTO ... SELECT ...` statements.
Remember, in module 3, we explained that whenever multiple statements need to access the same source tables and/or intermediary results, we should group them into a so-called [`STATEMENT SET`](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/sqlclient/#execute-a-set-of-sql-statements) to avoid potential conflicts related to parallel replication slot usage behind the scences.

That said, create the following `STATEMENT SET` to process both `INSERT INTO ... SELECT ...` statements which are sourced by the same source table `reviews`  within a single Flink SQL job:

* The first query adds a sentiment score to every existing and all new incoming product review texts by means of applying the custom `SENTIMENT_SCORE` UDF which calls out to the external service.

* The second query calculates the number of reviews and the average sentiment score for each unique item in the data set and filters for those that received two or more reviews.

For both queries in this Flink SQL job, the results are continuously written into the respective sink tables `reviews_with_sentiment_os` and `items_avg_sentiment_os` which in turn feed the corresponding OpenSearch indexes named `reviews_with_sentiment` and `items_avg_sentiment`.

```sql
EXECUTE STATEMENT SET 
BEGIN  
  INSERT INTO reviews_with_sentiment_os
    SELECT
      id AS review_id,
      item_id,
      review_text,
      SENTIMENT_SCORE(review_text) AS sentiment_score
    FROM reviews;
  INSERT INTO items_avg_sentiment_os
      SELECT
        item_id,
        COUNT(*) as num_reviews,
        AVG(CAST(SENTIMENT_SCORE(review_text) AS FLOAT)) as avg_sentiment_score
      FROM reviews
      GROUP BY item_id
      HAVING COUNT(*) >= 2;
END;
```

```bash
[INFO] Submitting SQL update statement to the cluster...
[INFO] SQL update statement has been successfully submitted to the cluster:
Job ID: 970c5c62874dc1345603573704affda1
```

With the job is successfully running, it's time to generate some additional data.

### User Reviews Generator

To simulate continuous user activity, there is a data generator which sends user reviews - by default 1/sec - to the `review-app` which stores them into a PostgreSQL database table. This creates a steady stream of new user reviews being processed in real-time by the previously created Flink SQL job.

The data generator can be run as follows:

```bash
docker run -it --rm --name data-generator-user-reviews --network hol-devoxxbe-network docker.io/hpgrahsl/data-generator:1.1.4
```

This should result in terminal output like below:

```bash
...
📤 posting user review via REST API
{"id":28,"itemId":"B007AVZQ1U","reviewText":"If you have reusable single cup maker and cup these liners are a must have for easy clean up. Much easier on the landfill than the plastic cups. Easy to use and the 'lid' on the top is actually a game changer. Keeps the grounds exactly where they are suppose to be - in the making cup - NOT your drinking cup. Love them, feel really comfortable recommending them. I never hesitate to update my reviews should new info seem useful."}
⏱️ delaying for 1.0s
📤 posting user review via REST API
{"id":29,"itemId":"B084L49119","reviewText":"I was a little disappointed that it doesn't quite fit in my single cup maker - I had to really slam the top down - eventually I get it in. Eh. It's like the puncture needle of my maker is a tiny bit off. I do recommend the cup liners. It brews a lighter than the commercial single coffee cups in my opinion - but if you have ground coffee - its worth a try just to keep the single use cups out of the garbage. Just know it doesn't fit ALL single cup makers. The maker I use is not a national brand. All of that said, I never hesitate to update my reviews should new info seem useful."}
⏱️ delaying for 1.0s
📤 posting user review via REST API
{"id":30,"itemId":"B07VSFPBW5","reviewText":"I purchased a single cup brewer that has the option of your own coffee... came with a cup to do that - but it is a pain to clean - so I buy these... it's a taller single cup holder so these taller liners are perfect. I have one cup of coffee a day - and sometimes none at all - so these will last me a good long time. I like that they are non-bleached - the less chemicals the better in my mind."}
⏱️ delaying for 1.0s
...
```

Each of these newly added reviews is captured by the Flink SQL job via CDC from the PostgreSQL table. The `reviewText` field of each record is transformed to a sentiment score (1 .. 5 stars) in real-time using the custom UDF, which calls out to the `model-serving-app` that locally infers the sentiment score using the pre-trained and specifically fine-tuned BERT language model for the task at hand.

### Query data in OpenSearch

#### 1. Query for Individual User Review Sentiment

Here are two exemplary queries, one showing a 👍 pretty positive 🤩 the other a 👎 rather negative 😤 product review entered by users:

* **very positive (⭐️⭐️⭐️⭐️⭐️):** http://admin:admin@localhost:9200/reviews_with_sentiment/_doc/15

```json
{
  "_index": "reviews_with_sentiment",
  "_type": "_doc",
  "_id": "15",
  "_version": 1,
  "_seq_no": 14,
  "_primary_term": 1,
  "found": true,
  "_source": {
    "review_id": 15,
    "item_id": "B072JXR3MW",
    "review_text": "what a great deal and it even had a little coffee scooper !!!!!!!!!  i paid this for 1 in Target  when i first got my Keurig last year !!!",
    "sentiment_score": 5
  }
}
```

* **very negative (⭐️):** http://localhost:9200/reviews_with_sentiment/_doc/19

```json
{
  "_index": "reviews_with_sentiment",
  "_type": "_doc",
  "_id": "19",
  "_version": 1,
  "_seq_no": 18,
  "_primary_term": 1,
  "found": true,
  "_source": {
    "review_id": 19,
    "item_id": "B016TZKU54",
    "review_text": "The filter did not fit in my Keurig K50. When closing the keurig, there was still a small gap that left the keurig slightly open. I had to hold down the keurig in order to get it to register that it was shut and allow me to select my cup size, and still had to hold it down while it was brewing. Then, the water barely flowed through the filter. Tried with a finer grind as described on the instructions. After a minute of holding it there, I had only less than half a cup of coffee. I tried again with a medium grind and still had the same issue. Decided it was not worth my hassle and to return it. Return was easy and was provided with a free return label.",
    "sentiment_score": 1
  }
}
```

#### 2. Query based on Average Item Sentiment

Here are two exemplary queries after letting the data generator run for a few minutes:

* **👍 Top 5 performing items 🤩** according to their average sentiment score and number of reviews received: 

```bash
docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    curl --location --request GET 'http://opensearch-node1:9200/items_avg_sentiment/_search' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Basic YWRtaW46YWRtaW4=' \
    --data '{
      "size": 5,
      "query": {
        "range": {
          "avg_sentiment_score": {
            "gte": 4.0
          }
        }
      },
    "sort": [ { "avg_sentiment_score": "desc" },{ "num_reviews": "desc" } ]
    }' | jq '.'
```

_Note: The actual results for this query will vary and primarily depend on how long the data generator has been running until the point in time you executed the query against this OpenSearch index._

```json
{
  "took": 5,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 6,
      "relation": "eq"
    },
    "max_score": null,
    "hits": [
      {
        "_index": "items_avg_sentiment",
        "_type": "_doc",
        "_id": "B007AVZQ1U",
        "_score": null,
        "_source": {
          "item_id": "B007AVZQ1U",
          "num_reviews": 2,
          "avg_sentiment_score": 5.0
        },
        "sort": [
          5.0,
          2
        ]
      },
      {
        "_index": "items_avg_sentiment",
        "_type": "_doc",
        "_id": "B08ZYJ8CRX",
        "_score": null,
        "_source": {
          "item_id": "B08ZYJ8CRX",
          "num_reviews": 2,
          "avg_sentiment_score": 4.5
        },
        "sort": [
          4.5,
          2
        ]
      },
      {
        "_index": "items_avg_sentiment",
        "_type": "_doc",
        "_id": "B01AML6LT0",
        "_score": null,
        "_source": {
          "item_id": "B01AML6LT0",
          "num_reviews": 3,
          "avg_sentiment_score": 4.3333335
        },
        "sort": [
          4.3333335,
          3
        ]
      },
      {
        "_index": "items_avg_sentiment",
        "_type": "_doc",
        "_id": "B00LGEKOMS",
        "_score": null,
        "_source": {
          "item_id": "B00LGEKOMS",
          "num_reviews": 2,
          "avg_sentiment_score": 4.0
        },
        "sort": [
          4.0,
          2
        ]
      },
      {
        "_index": "items_avg_sentiment",
        "_type": "_doc",
        "_id": "B000LTOCSG",
        "_score": null,
        "_source": {
          "item_id": "B000LTOCSG",
          "num_reviews": 2,
          "avg_sentiment_score": 4.0
        },
        "sort": [
          4.0,
          2
        ]
      }
    ]
  }
}
```

* **👎 Worst 5 performing items 😤** according to their average sentiment score and number of reviews received: 

```bash
docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    curl --location --request GET 'http://opensearch-node1:9200/items_avg_sentiment/_search' \
    --header 'Content-Type: application/json' \
    --header 'Authorization: Basic YWRtaW46YWRtaW4=' \
    --data '{
      "size": 5,
      "query": {
        "range": {
          "avg_sentiment_score": {
            "lte": 2.0
          }
        }
      },
    "sort": [ { "avg_sentiment_score": "asc" },{ "num_reviews": "desc" } ]
    }' | jq '.'
```

_Note: The actual results for this query will vary and primarily depend on how long the data generator has been running until the point in time you executed the query against this OpenSearch index._

```json
{
  "took": 3,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 3,
      "relation": "eq"
    },
    "max_score": null,
    "hits": [
      {
        "_index": "items_avg_sentiment",
        "_type": "_doc",
        "_id": "B01ENXS1C8",
        "_score": null,
        "_source": {
          "item_id": "B01ENXS1C8",
          "num_reviews": 2,
          "avg_sentiment_score": 1.0
        },
        "sort": [
          1.0,
          2
        ]
      },
      {
        "_index": "items_avg_sentiment",
        "_type": "_doc",
        "_id": "B06XR8WZX6",
        "_score": null,
        "_source": {
          "item_id": "B06XR8WZX6",
          "num_reviews": 2,
          "avg_sentiment_score": 1.5
        },
        "sort": [
          1.5,
          2
        ]
      },
      {
        "_index": "items_avg_sentiment",
        "_type": "_doc",
        "_id": "B08YR8KB69",
        "_score": null,
        "_source": {
          "item_id": "B08YR8KB69",
          "num_reviews": 2,
          "avg_sentiment_score": 1.5
        },
        "sort": [
          1.5,
          2
        ]
      }
    ]
  }
}
```

### What's next?

This concludes the hands-on lab. Head over to the [summary section](./summary.md) to recap what you’ve learned and to get some inspiration for further materials.
