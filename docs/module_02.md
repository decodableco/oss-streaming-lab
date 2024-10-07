## Module 02 — Writing Data Changes to OpenSearch

It’s now time switch focus towards the sink of this E2E data pipeline. In order to push the data into OpenSearch, an additional Flink table is defined.

### Setting Up an OpenSearch Sink Connector

In the Flink CLI, run the following `CREATE TABLE` statement to define a Flink table named `customers_os` using the `opensearch` connector. This table represents the sink side of the E2E streaming data pipeline.

```sql
CREATE TABLE customers_os (
   id INT,
   first_name STRING,
   last_name STRING,
   email STRING,
   is_test_account BOOLEAN,
   PRIMARY KEY (id) NOT ENFORCED
)
WITH (
     'connector' = 'opensearch',
     'hosts' = 'http://opensearch-node1:9200',
     'username' = 'admin',
     'password' = 'admin',
     'index' = 'customers'
);
```

With this sink table in place, create a Flink job by running the `INSERT INTO ... SELECT ...` statement shown below. All it does is select the data from the source table `customers` and insert it into `customers_os` sink table as is: 

```sql
INSERT INTO customers_os
  SELECT
    id,
    first_name,
    last_name,
    email,
    is_test_account
  FROM
    customers;
```

As a result, you're expected to see a successful job submission similar to:

```bash
[INFO] Submitting SQL update statement to the cluster...
[INFO] SQL update statement has been successfully submitted to the cluster:
Job ID: cc37feb002a2a00c90b4acb56e5675fa
```

### Query Data in OpenSearch

To query the OpenSearch index `customers`, any of these three exemplary REST API calls can be made directly from within a web browser:

1. retrieve the document for the customer with the id `1001`

http://admin:admin@localhost:9200/customers/_doc/1001

```json
{
  "_index": "customers",
  "_type": "_doc",
  "_id": "1001",
  "_version": 3,
  "_seq_no": 2,
  "_primary_term": 1,
  "found": true,
  "_source": {
    "id": 1001,
    "first_name": "Sally",
    "last_name": "Green",
    "email": "sally.thomas@acme.com",
    "is_test_account": false
  }
}
```

2. A query for documents where `last_name` equals `"barrett"` OR `first_name` equals `"sally"` (case-insensitve) is supposed to give you a result that matched two documents, namely, that of customers having IDs `1001` and `1004`

http://admin:admin@localhost:9200/customers/_search?q=last_name%3Abarrett%20OR%20first_name%3Asally

```json
{
  "took": 12,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 2,
      "relation": "eq"
    },
    "max_score": 2.0794415,
    "hits": [
      {
        "_index": "customers",
        "_type": "_doc",
        "_id": "1004",
        "_score": 2.0794415,
        "_source": {
          "id": 1004,
          "first_name": "Aidan",
          "last_name": "Barrett",
          "email": "aidan@example.com",
          "is_test_account": true
        }
      },
      {
        "_index": "customers",
        "_type": "_doc",
        "_id": "1001",
        "_score": 1.2321435,
        "_source": {
          "id": 1001,
          "first_name": "Sally",
          "last_name": "Green",
          "email": "sally.thomas@acme.com",
          "is_test_account": false
        }
      }
    ]
  }
}
```

3. A query for documents with an email field ending in "*.org" is supposed to give you a result that matched 1 document, namely, that of customer having ID 1005:

http://admin:admin@localhost:9200/customers/_search?q=email%3A*.org

```json
{
  "took": 12,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 1,
      "relation": "eq"
    },
    "max_score": 1,
    "hits": [
      {
        "_index": "customers",
        "_type": "_doc",
        "_id": "1005",
        "_score": 1,
        "_source": {
          "id": 1005,
          "first_name": "Anne",
          "last_name": "Kretchmar",
          "email": "annek@noanswer.org",
          "is_test_account": true
        }
      }
    ]
  }
}
```

If you prefer to run these queries on the command line, you can alternatively run these Docker commands to query against the REST API of OpenSearch:

```bash
docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    bash -c 'http http://opensearch-node1:9200/customers/_doc/1001 -a "admin:admin"' 

docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    bash -c 'http http://opensearch-node1:9200/customers/_search?q=last_name%3Abarrett%20OR%20first_name%3Asally -a "admin:admin"' 

docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    bash -c 'http http://opensearch-node1:9200/customers/_search?q=email%3A*.org -a "admin:admin"' 
```

### What's next?

At this point, you have a running end-to-end data pipeline, which propagates changes from one table in a Postgres database to a corresponding search index in OpenSearch. Any inserts, updates, and deletes will be propagated from the source to the sink with a low latency, enabling use cases such as full-text search, analytics, or dashboarding.

In the [next module](./module_03.md) of this lab we’ll take things to the next level by joining and preprocessing the data from multiple source tables before writing it to the search index, using just a few lines of (streaming) SQL.
