## Module 03 — Real-time Joins with Streaming SQL

So far, we have taken one table, `customers`, in the source Postgres database and replicated it to OpenSearch. To take things one step further, let’s assume we’d like to enable full-text search on customers and their addresses. For each customer record, there’s an address record which is stored in a separate table `addresses` in the source database.

!["Customers and Addresses Data Model in Database"](./images/m03/01-customer-address-model.png)

In a relational database such as Postgres, you’d write a `JOIN` query which links the two tables together, allowing you to filter the result set based on the columns of both tables. In contrast, document stores like OpenSearch typically don’t support this kind of query-time join.

This means that we need to join the customer and address data when ingesting the data. That way, the entire data of a customer, including their address data, will be written to one single document in an OpenSearch index, allowing to query it efficiently, without the need for joins at query-time.

To implement the required logic Flink SQL comes in handy as well, since it's allowing you to conveniently filter and map, join, group and aggregate your data. The following steps are required:

* Adding another table using the Postgres CDC source connector for also ingesting changes from the `addresses` table

* Setting up a new OpenSearch backed sink table for propagating the joined data to an index in OpenSearch

* Creating a Flink SQL job for joining the two tables with `customers` and `addresses` data and inserting the result into the sink table

![""Flink SQL 1-to-1 JOIN for Customers and Addresses""](./images/m03/02-flink-sql-1-to-1-join-customer-address.png)

### Setting Up a Postgres Source Connector

In the Flink CLI do the following, create a flink table using the Postgres CDC connector:

```sql
CREATE TABLE addresses (
   id INT,
   customer_id INT,
   line_1 STRING,
   line_2 STRING,
   city STRING,
   state STRING,
   zip_code STRING,
   country STRING,
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
   'table-name' = 'addresses',
   'decoding.plugin.name' = 'pgoutput',
   'debezium.publication.name' = 'addresses_publication',
   'slot.name' = 'addresses_slot'
);
```

Query this Flink table `addresses` to check the existing records:

```sql
SELECT * FROM addresses;
```

which should give a result set as follows:

```bash
         id customer_id                         line_1                         line_2                           city                          state                       zip_code                        country
     1000001        1001                366 Hall Street                         <NULL>                      Las Vegas                         Nevada                          89119                             US
     1000002        1002           2263 New York Avenue                         <NULL>                 Woodland Hills                     California                          91303                             US
     1000003        1003             746 Reynolds Alley                         <NULL>                    Los Angeles                     California                          90014                             US
     1000004        1004         1004 School House Road                         <NULL>                        Jackson                    Mississippi                          39201                             US
```

Hit `q` to stop this query job.

### Setting Up an OpenSearch Sink Connector

Create a Flink table using the OpenSearch sink connector:

```sql
CREATE TABLE customers_with_addresses_os (
    id INT,
    first_name STRING,
    last_name STRING,
    email STRING,
    line_1 STRING,
    city STRING,
    state STRING,
    zip_code STRING,
    country STRING,
   PRIMARY KEY (id) NOT ENFORCED
)
WITH (
     'connector' = 'opensearch',
     'hosts' = 'http://opensearch-node1:9200',
     'username' = 'admin',
     'password' = 'admin',
     'index' = 'customers_with_addresses'
);
```

### Creating the SQL `JOIN` Job

Before being able to create an additional Flink SQL job, which also refers to same customer data, we need to create a second `customers` source table in Flink.
This is a peculiarity when directly working with CDC data originating from Postgres tables, and is related to the underlying replication slots being used by source connectors.
Each replication slot is supposed to be exclusively used by a single Flink SQL job, in other words parallel replication slot usage is prohibited by the source connector implementation and will eventually result in job failure.
Later during this lab, you're learning about the concept of a Flink `STATEMENT SET`, which allows for the execution of multiple SQL statements that may reuse common tables as well as intermediate results and are executed as a single Flink job.

For now, you simply work around this by creating the following Flink table `customers_2` with different settings for its publication and slot names (see `WITH(...)` block):

```sql
CREATE TABLE customers_2 (
   id INT,
   first_name STRING,
   last_name STRING,
   email STRING,
   is_test_account BOOLEAN,
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
   'table-name' = 'customers',
   'decoding.plugin.name' = 'pgoutput',
   'debezium.publication.name' = 'customers_2_publication',
   'slot.name' = 'customers_2_slot'
);
```

Next, create a Flink job by running an `INSERT INTO ... SELECT ...` statement to select data from the source table `customers_2`, join it with the source table `addresses`, filter out any test accounts, and insert it into the `customers_with_addresses_os` sink table:

```sql
INSERT INTO customers_with_addresses_os
SELECT
    c.id,
    c.first_name,
    c.last_name,
    c.email,
    a.line_1,
    a.city,
    a.state,
    a.zip_code,
    a.country
FROM customers_2 c
JOIN addresses a
    ON c.id = a.customer_id
WHERE NOT c.is_test_account;
```

_NOTE: This SQL snippet joins the customers with the addresses streams and uses a `WHERE` clause to filter out all test accounts. Since the default `JOIN` semantic is an `INNER JOIN` you will only get a customer record as part of the result set if there is an address record available for the customer in question. Instead you might want to use a `LEFT JOIN` if this behaviour is not what you are after._

You are expected to see a successful job submission to the Flink cluster.

```bash
[INFO] Submitting SQL update statement to the cluster...
[INFO] SQL update statement has been successfully submitted to the cluster:
Job ID: 4f6d48e0fb453f2ca6a97986da81203a
```

### Query Data in OpenSearch

To quickly verify that the data joined by the SQL pipeline made it into your search index, open this URL

* http://admin:admin@localhost:9200/customers_with_addresses/_doc/1001

The REST API request retrieves the document with id `1001` which represents the joined result of the customer and address data for customer id with `1001`:

```json
{
  "_index": "customers_with_addresses",
  "_type": "_doc",
  "_id": "1001",
  "_version": 1,
  "_seq_no": 0,
  "_primary_term": 1,
  "found": true,
  "_source": {
    "id": 1001,
    "first_name": "Sally",
    "last_name": "Thomas",
    "email": "sally.thomas@acme.com",
    "line_1": "366 Hall Street",
    "city": "Las Vegas",
    "state": "Nevada",
    "zip_code": "89119",
    "country": "US"
  }
}
```

Alternatively you can run the Docker command below to do this on the CLI rather than in the browser/any GUI tool:

```bash
docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    bash -c 'http http://opensearch-node1:9200/customers_with_addresses/_doc/1001 -a "admin:admin"' 
```

### What's next?

In this module 3, you learned how to work with Flink SQL to process data originating from two different tables in your source database. By means of a single SQL statement, you were able to express the stream processing logic of a basic `JOIN` operation for a 1:1 entity relationship.

The [next module](module_04.md) of this lab will explain, how you can work with Flink SQL to address 1:N relationships in your data model and thereby build more complex aggregate structures as part of your streaming ETL workloads.
