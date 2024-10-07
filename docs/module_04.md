## Module 04 - Creating Denormalized Data Views

In this module, you are going to work with additional tables in your Postgres database to learn how you can create and maintain continuously updated denormalized views in an OpenSearch index.

So far you have been working with just two tables from your Postgres database. Additionally, the idea is to start capturing data from three more tables, namely `purchase_orders`, `order_lines`, and `products`.
There's a many-to-one relationship between purchase orders and order lines, as well as a many-to-one relationship between order lines and products.

!["Purchase Order Data Model in Database"](./images/m04/01-order-related-data-model.png)

The following main steps are necessary to create a streaming SQL Pipeline that creates a complex aggregate structure holding all details for one specific order:

* Setting up Postgres CDC source connectors for ingesting changes from the additional tables (`purchase_orders`, `order_lines`, and `products`)
* Setting up a new OpenSearch sink connector for propagating the denormalized order aggregate structures to another OpenSearch index
* Creating a SQL job which does a three-way JOIN across both many-to-one relationships and writing the results to OpenSearch

!["Flink SQL three-way JOIN with custom aggregation function"](./images/m04/02-flink-sql-3way-join-custom-aggregation.png)

### Building your Custom User-Defined Function

In order for the Flink SQL job to perform the three-way join and generate type-safe purchase order aggregates, you are implementing a custom user-defined function [(UDF)](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/functions/udfs/) for Flink.
This custom function will be named `ARRAY_AGGR()` and registered in your Flink environment later.
It takes a set of values, like the order lines of a purchase order in a 1:n join, and emits them as an array. 
Unlike alternatives such as Flink's built-in `JSON_ARRAYAGG()` function, this `ARRAY_AGGR()` function emits a strongly typed data representation. 
This means that any downstream processors and consumers can operate on the data in a type-safe way.

The UDF project skeleton is already contained in the repository in the folder [`array-agg-udf`](../array-agg-udf).
Open this Java Maven project in your code editor or IDE of choice to provide the missing bits of the UDF implementation.

> A user-defined [aggregate function](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/functions/udfs/#aggregate-functions
) (UDAGG) maps scalar values of multiple rows to a new scalar value.
> The behavior of an aggregate function is centered around the concept of an accumulator. The accumulator is an intermediate data structure that stores the aggregated values until a final aggregation result is computed.

#### Accumulator

In the Java UDF project, open the file [`ArrayAccumulator.java`](../array-agg-udf/src/main/java/co/decodable/demos/arrayagg/ArrayAccumulator.java) and add the following implementation to it by replacing the `// TODO: ...` comment section in the file:

```java
	public ListView<T> values = new ListView<T>();

	@Override
	public int hashCode() {
		return Objects.hash(values);
	}

	@Override
	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		ArrayAccumulator<?> other = (ArrayAccumulator<?>) obj;
		return Objects.equals(values, other.values);
	}
```

#### Aggregate Function

In the Java UDF project, open the file [`ArrayAgg.java`](../array-agg-udf/src/main/java/co/decodable/demos/arrayagg/ArrayAgg.java)

1. Add the following method body for `getValue(...)` by replacing the `// TODO-1: ...` comment section in this file:

```java
		if (acc.values.getList().isEmpty()) {
			return null;
		}
		else {
			List<T> values = new ArrayList<T>(acc.values.getList());
			return values.toArray((T[]) Array.newInstance(elementType.getConversionClass(), values.size()));
		}
```

2. Add the additional missing methods by replacing the `//TODO-2: ...` comment section in the file:

```java
	public void accumulate(ArrayAccumulator<T> acc, T o) throws Exception {
		if (o != null) {
			acc.values.add(o);
		}
	}

	public void retract(ArrayAccumulator<T> acc, T o) throws Exception {
		if (o != null) {
			acc.values.remove(o);
		}
	}

	public void resetAccumulator(ArrayAccumulator<T> acc) {
		acc.values.clear();
	}

	@Override
	public TypeInference getTypeInference(DataTypeFactory typeFactory) {
		return TypeInference.newBuilder()
				.inputTypeStrategy(InputTypeStrategies.sequence(InputTypeStrategies.ANY))
				.accumulatorTypeStrategy(ctx -> {
					return Optional.of(
							DataTypes.STRUCTURED(
									ArrayAccumulator.class,
									DataTypes.FIELD("values",ListView.newListViewDataType(ctx.getArgumentDataTypes().get(0)))//,
							));
				})
				.outputTypeStrategy(ctx -> {
					this.elementType = ctx.getArgumentDataTypes().get(0);
					return Optional.of(DataTypes.ARRAY(elementType));
				}).build();
	}
```

#### Build Java UDF Project

Either build this project by means of the Maven support in your code editor / IDE or open a terminal window, go into the folder `array-agg-udf` and run:

```bash
./mvnw clean verify
```

You should see a successfull build and the JAR artefact [`array-agg-0.1.jar`](../array-agg-udf/target/array-agg-0.1.jar) being produced in the `/target` folder of the `array-agg-udf` project.

### Recreate Flink Containers

Before you can make use of this custom UDF in Flink, you have to adapt the `compose.yaml` file and mount the UDF JAR [`array-agg-0.1.jar`](../array-agg-udf/target/array-agg-0.1.jar) such that all Flink-related containers have access to the JAR file at runtime.

#### Adapt `compose.yaml`

Open [`compose.yaml`](../compose.yaml) in your editor of choice and uncomment the three prepared volume mount definitions for the `jobmanager`, `taskmanager`, and `sql-client` container services in that file.

They all look the same:

```yaml
      # - ./array-agg-udf/target/array-agg-0.1.jar:/opt/flink/lib/array-agg-0.1.jar
```

Make sure to **SAVE the file** after uncommenting these three lines i.e. line 56, line 74, and line 91.

#### Restart Flink-related Services

Open a terminal window and make sure you are in the root folder of this hands-on lab repository, where the `compose.yaml` file resides.
Then run the following Docker Compose command which will re-create the three Flink-related containers, namely, `jobmanager`, `taskmanager`, and `sql-client`.

```bash
docker-compose up -d --force-recreate jobmanager taskmanager sql-client
```

After a few moments, these three container services should be up and running again.
In order to proceed with the lab module's instructions, start a Flink SQL CLI session

```bash
docker compose exec -it sql-client bin/sql-client.sh
```

### Setting Up the Postgres Source Connector

Create a table in Flink SQL for ingesting the data from the `purchase_orders` table in Postgres:

```sql
CREATE TABLE purchase_orders (
   id INT,
   order_date DATE,
   purchaser_id INT,
   db_name STRING METADATA FROM 'database_name' VIRTUAL,
   operation_ts TIMESTAMP_LTZ(3) METADATA FROM 'op_ts' VIRTUAL,
   PRIMARY KEY (id) NOT ENFORCED
) WITH (
   'connector' = 'postgres-cdc',
   'hostname' = 'postgres',
   'port' = '5432',
   'username' = 'postgres',
   'password' = 'postgres',
   'database-name' = 'postgres',
   'schema-name' = 'inventory',
   'table-name' = 'purchase_orders',
   'decoding.plugin.name' = 'pgoutput',
   'debezium.publication.name' = 'purchase_orders_publication',
   'slot.name' = 'purchase_orders_slot'
);
```

Create a table for `order_lines`:

```sql
CREATE TABLE order_lines (
   id INT,
   order_id INT,
   product_id INT,
   quantity INT,
   price DOUBLE,
   PRIMARY KEY (id) NOT ENFORCED
) WITH (
   'connector' = 'postgres-cdc',
   'hostname' = 'postgres',
   'port' = '5432',
   'username' = 'postgres',
   'password' = 'postgres',
   'database-name' = 'postgres',
   'schema-name' = 'inventory',
   'table-name' = 'order_lines',
   'decoding.plugin.name' = 'pgoutput',
   'debezium.publication.name' = 'order_lines_publication',
   'slot.name' = 'order_lines_slot'
);
```

And create a table for `products`:

```sql
CREATE TABLE products (
   id INT,
   name STRING,
   description STRING,
   weight DOUBLE,
   category STRING,
   PRIMARY KEY (id) NOT ENFORCED
) WITH (
   'connector' = 'postgres-cdc',
   'hostname' = 'postgres',
   'port' = '5432',
   'username' = 'postgres',
   'password' = 'postgres',
   'database-name' = 'postgres',
   'schema-name' = 'inventory',
   'table-name' = 'products',
   'decoding.plugin.name' = 'pgoutput',
   'debezium.publication.name' = 'products_publication',
   'slot.name' = 'products_slot'
);
```

### Setting Up the OpenSearch Connector

Create a sink table for writing the results to OpenSearch:

```sql
CREATE TABLE orders_with_lines_os (
  order_id INT,
  order_date DATE,
  purchaser_id INT,
  lines ARRAY<row<id INT, product_id INT, quantity INT, price DOUBLE, name VARCHAR, description VARCHAR, weight DOUBLE, category VARCHAR>>,
  PRIMARY KEY (order_id) NOT ENFORCED
 )
 WITH (
     'connector' = 'opensearch',
     'hosts' = 'http://opensearch-node1:9200',
     'username' = 'admin',
     'password' = 'admin',
     'index' = 'orders_with_lines_and_products'
 );
```

### Creating the SQL `JOIN` Job

With all the source and sink tables being set up, it's time to issue a SQL job which joins the three source tables and writes the results to the sink table.

Start by registering the pre-built custom UDF:

```sql
CREATE FUNCTION ARRAY_AGGR AS 'co.decodable.demos.arrayagg.ArrayAgg' LANGUAGE JAVA;
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
+-----------------+
1 row in set
```

Let's see the `ARRAY_AGGR()` function in action by applying it in an interactive `SELECT` statement to `JOIN` the 3 tables in the Flink SQL CLI:

```sql
SELECT
    po.id,
    po.order_date,
    po.purchaser_id,
    ARRAY_AGGR(ROW(ol.id, ol.product_id, ol.quantity, ol.price, p.name, p.description, p.weight, p.category)) AS lines
  FROM
    purchase_orders po
  LEFT JOIN order_lines ol ON ol.order_id = po.id
  LEFT JOIN products p ON ol.product_id = p.id
  GROUP BY po.id, po.order_date, po.purchaser_id;
```

This SQL query performs a `LEFT JOIN` between the `purchase_orders`, the `order_lines`, and the `products`.
The `LEFT JOIN` semantic means that if there's a purchase order without any order lines, only the order's attributes would be emitted.
The results are grouped by the purchase order attributes, so as to emit one result row per order.
For each order line, a `SQL ROW` is created with the line and product attributes, and all the lines of one purchase order are emitted as an array by calling the custom user-defined function (UDF) `ARRAY_AGGR()`.

The result set should looks as follows:

```text
         id order_date purchaser_id                          lines
       10001 2024-01-16         1001 [(100001, 102, 1, 39.99, car ~
       10002 2024-01-17         1002 [(100003, 106, 1, 29.49, hamm~
       10004 2024-02-11         1004 [(NULL, NULL, NULL, NULL, NUL~
       10003 2024-02-19         1002 [(100006, 101, 4, 219.99, sco~
       10005 2024-01-13         1005 [(NULL, NULL, NULL, NULL, NUL~
       10006 2024-03-17         1006 [(NULL, NULL, NULL, NULL, NUL~
```

Note that for three of these orders (`IDs 1004,1005,1006`), the lines column shows an array containing a `ROW` entry with `NULL` fields only.
This is because the query uses `LEFT JOIN` semantics to keep orders without order lines and the `ARRAY_AGGR()` function, unlike other aggregation functions, doesn’t explicitly filter out `NULL` values by default.

Typically, you might not want to ship the records like this into an OpenSearch index, but instead just set the `lines` field to a single `NULL` value. This can be achieved by using the `FILTER` clause when applying the `ARRAY_AGGR()` function like so:

```sql
...
ARRAY_AGGR(ROW(ol.id, ol.product_id, ol.quantity, ol.price, p.name, p.description, p.weight, p.category)) FILTER (WHERE ol.id IS NOT NULL) AS lines
...
```

With the `FILTER` clause in place, you'd see the result set in the anticipated form:

```text
         id order_date purchaser_id                          lines
       10001 2024-01-16         1001 [(100001, 102, 1, 39.99, car ~
       10004 2024-02-11         1004                         <NULL>
       10005 2024-01-13         1005                         <NULL>
       10006 2024-03-17         1006                         <NULL>
       10002 2024-01-17         1002 [(100003, 106, 1, 29.49, hamm~
       10003 2024-02-19         1002 [(100006, 101, 4, 219.99, sco~
```

If applicable, hit `q` to quit your running `SELECT` query before proceeding.

The Flink SQL job you submit next with the `INSERT INTO ... SELECT ...` statement contains this `FILTER` clause already:

```sql
INSERT INTO orders_with_lines_os
  SELECT
    po.id,
    po.order_date,
    po.purchaser_id,
    ARRAY_AGGR(ROW(ol.id, ol.product_id, ol.quantity, ol.price, p.name, p.description, p.weight, p.category)) FILTER (WHERE ol.id IS NOT NULL) AS lines
  FROM
    purchase_orders po
  LEFT JOIN order_lines ol ON ol.order_id = po.id
  LEFT JOIN products p ON ol.product_id = p.id
  GROUP BY po.id, po.order_date, po.purchaser_id;
```

You are expected to see a successful job submission to the Flink cluster.

```bash
[INFO] Submitting SQL update statement to the cluster...
[INFO] SQL update statement has been successfully submitted to the cluster:
Job ID: 0b62f4cbfe82ca1349adbe9186384a58
```

Once the job is running, you can query the data in OpenSearch.

### Query Data in OpenSearch

To quickly verify that the data joined by the SQL pipeline made it into your search index, open this URL: 

* http://admin:admin@localhost:9200/orders_with_lines_and_products/_doc/10001

The REST API request retrieves the document with id `10001` which represents the denormalized i.e. pre-joined result of the purchase order `10001` together with all of its order lines and product information:

```json
{
  "_index": "orders_with_lines_and_products",
  "_type": "_doc",
  "_id": "10001",
  "_version": 3,
  "_seq_no": 2,
  "_primary_term": 1,
  "found": true,
  "_source": {
    "order_id": 10001,
    "order_date": "2024-01-16",
    "purchaser_id": 1001,
    "lines": [
      {
        "id": 100001,
        "product_id": 102,
        "quantity": 1,
        "price": 39.99,
        "name": "car battery",
        "description": "12V car battery",
        "weight": 8.1,
        "category": "mobility"
      },
      {
        "id": 100002,
        "product_id": 105,
        "quantity": 2,
        "price": 129.99,
        "name": "hammer",
        "description": "14oz carpenter's hammer",
        "weight": 0.875,
        "category": "home improvement"
      }
    ]
  }
}
```

Let's check one of the orders without any order lines e.g. the order having `ID=10005`

* http://admin:admin@localhost:9200/orders_with_lines_and_products/_doc/10005

```json
{
  "_index": "orders_with_lines_and_products",
  "_type": "_doc",
  "_id": "10005",
  "_version": 2,
  "_seq_no": 24,
  "_primary_term": 1,
  "found": true,
  "_source": {
    "order_id": 10005,
    "order_date": "2024-01-13",
    "purchaser_id": 1005,
    "lines": null
  }
}
```

As expected, the lines field for this specific order is a single `null` value which resulted from the `ARRAY_AGG()` function in combination with the applied `FILTER` clause.

You can alternatively use httpie on the command line to retrieve the document from the index:

```bash
docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    bash -c 'http http://opensearch-node1:9200/orders_with_lines_and_products/_doc/10001 -a "admin:admin"'

docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    bash -c 'http http://opensearch-node1:9200/orders_with_lines_and_products/_doc/10005 -a "admin:admin"' 
```

Just being able to retrieve such a denormalized data view by means of a simple key-based `GET` request—without incurring the cost of a query-time join—can be very useful for many applications, for instance helping to reduce load on the primary database.
Note that if the same product is referenced by several order lines, that product data would be duplicated to all the lines.
That's the trade-off when using a document store like OpenSearch in comparison to a relational database with a highly normalized data model.
The advantage is the higher query performance, and thanks to the streaming query, this denormalized data view gets updated continuously, ensuring it is in sync with the data in the primary data store.

You could also take advantage of the powerful querying capabilities of OpenSearch, for instance fuzzy and proximity search and geo-spatial queries, pagination, query string completion, results scoring and highlighting, and much more.

### Analysing Jobs in the Flink Web UI

Flink comes with a built-in web dashboard,
which you can use to monitor the system, for instance by examining log files, tracking the progress of checkpoints, analyse backpressure in jobs, and more.
To go to the Flink dashboard, open up http://localhost:8081 in your browser.
You'll see a list of all currently and previously running jobs:

!["Flink Web Dashboard"](./images/m04/03-flink-web-dashboard-overview.png)

Click on the job `insert-into_default_catalog.default_database.orders_with_lines_os` and you'll see the topology of this job:

!["Streaming Job Topology In The Flink Web Dashboard"](./images/m04/04-flink-web-dashboard-topology.png)

Select the "Checkpoints" tab.
Uh oh, there are no [checkpoints](https://nightlies.apache.org/flink/flink-docs-master/docs/ops/state/checkpoints/) to see,
i.e. if the job gets restared (for instance after a failure),
it would not have kept record of how far it has processed the incoming data streams and woud have to start all over:

!["Checkpoints View In The Flink Web Dashboard"](./images/m04/05-flink-web-dashboard-checkpoints.png)

Furthermore, without checkpointing, the Flink CDC connector for Postgres will never confirm processed offsets from the source transaction log with the database server,
causing the slot to [retain more and more data](https://www.morling.dev/blog/insatiable-postgres-replication-slot/).
No bueno!

Let's fix this by enabling checkpointing.
In the Flink web UI,
stop the job by clicking "Cancel Job" in the upper right corner of the screen.
Next, go to the Flink SQL client again,
and issue this command:

```sql
Flink SQL> SET execution.checkpointing.interval = 10s;
```

```bash
[INFO] Execute statement succeed.
```

This sets the checkpointing interval to ten seconds for all jobs started thereafter.
For the sake of the example, we are using on-heap checkpoint storage here,
i.e. state still is volatile.
For a production scenario, checkpoint data would be persisted on the file system,
allowing to safely recover after a restart.

Issue the `INSERT INTO orders_with_lines_os ...` Flink SQL job again,
you can find it in the command history by clicking the Arrow Up key a few times.
Once the job is running,
open it in the Flink web UI,
where you should see the checkpoint data now on the job's "Checkpoints" tab, including the checkpoint history:

!["Checkpoint History In The Flink Web Dashboard"](./images/m04/06-flink-web-dashboard-checkpoint-history.png)

### Enabling Mini-Batching

Let's explore in some more detail how the updates of this join query are computed and transmitted to OpenSearch and how we can make this process a bit more efficient.
To do so, change the [result mode](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/sqlclient/#sql-client-result-modes) in the Flink SQL client to visualize the result stream.

```sql
SET 'sql-client.execution.result-mode' = 'changelog';
```

While at it, also adjust the maximum column width so we can take a better look at the results:

```sql
SET 'sql-client.display.max-column-width' = '180';
```

Also cancel the job `insert-into_default_catalog.default_database.orders_with_lines_os` in the Flink web UI.
In the Flink SQL client,
issue this query to retrieve the data for a purchase order which we are going to create in Postgres next (i.e. no results will be returned just yet):

```sql
SELECT
  po.id,
  po.order_date,
  po.purchaser_id,
  ARRAY_AGGR(ROW(ol.id, ol.product_id, ol.quantity, ol.price, p.name, p.description, p.weight, p.category)) FILTER (WHERE ol.id IS NOT NULL) AS lines
FROM
  purchase_orders po
LEFT JOIN order_lines ol ON ol.order_id = po.id
LEFT JOIN products p ON ol.product_id = p.id
WHERE po.id = 10007
GROUP BY po.id, po.order_date, po.purchaser_id;
```

**Important: Please leave this interactive query running - do NOT quit it!**

Switch to a different terminal tab/window and open a `pgcli` session for the Postgres database.

```bash
docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    bash -c 'pgcli postgresql://postgres:postgres@postgres:5432/postgres'
```

Run the two `INSERT INTO ...` statements below to create a new purchase order with three order lines:

```sql
INSERT INTO inventory.purchase_orders
VALUES (default, '2024-10-04', 1001);
INSERT INTO inventory.order_lines
VALUES (default, 10007, 102, 1, 39.99),
       (default, 10007, 105, 2, 129.99),
       (default, 10007, 107, 3, 49.49);
```

Back in the Flink SQL client, you'll see a result stream as follows:

```sql
 op          id order_date purchaser_id                                                                                                                                                                                lines
 +I       10007 2024-10-04         1001                                                                                                               [(100007, 102, 1, 39.99, car battery, 12V car battery, 8.1, mobility)]
 -U       10007 2024-10-04         1001                                                                                                               [(100007, 102, 1, 39.99, car battery, 12V car battery, 8.1, mobility)]
 +U       10007 2024-10-04         1001                           [(100007, 102, 1, 39.99, car battery, 12V car battery, 8.1, mobility), (100008, 105, 2, 129.99, hammer, 14oz carpenter's hammer, 0.875, home improvement)]
 -U       10007 2024-10-04         1001                           [(100007, 102, 1, 39.99, car battery, 12V car battery, 8.1, mobility), (100008, 105, 2, 129.99, hammer, 14oz carpenter's hammer, 0.875, home improvement)]
 +U       10007 2024-10-04         1001 [(100007, 102, 1, 39.99, car battery, 12V car battery, 8.1, mobility), (100008, 105, 2, 129.99, hammer, 14oz carpenter's hammer, 0.875, home improvement), (100010, 107, 3, 49.49, ~
```

As Flink processes the group aggregation operator for the `ArrayAggr` UDF for each input record one by one by default,
a new result set row is emitted upon processing each order line,
with a retraction event (`-U`) before.
We are not really interested in these intermediary join results with just a subset of the rows,
yet they will all be transmitted to the index in OpenSearch,
yielding to potentially incomplete query results and a fair amount of write amplification.

To mitigate this situation, you can enable Flink's [mini-batching](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/tuning/#minibatch-aggregation) feature.
Cancel the query in the SQL client by typing `q`,
then run the following configuration commands:

* enable mini-batching

```sql
SET 'table.exec.mini-batch.enabled' = 'true';
```

* define allowed mini-batching latency

```sql
SET 'table.exec.mini-batch.allow-latency' = '500 ms';
```

* define maximum mini-batching size

```sql
SET 'table.exec.mini-batch.size' = '1000';
```

Flink will now buffer and batch the results of the aggregation,
waiting at most for 500 milliseconds and processing at most 1000 records at once.
Re-run the query from before,
and you'll see much less intermediary results than before, or none at all
(specifics depend on the exact timing; in particular, mini-batching does _not_ ensure that all events from one transaction in the source database are processed atomically).

### What's next?

In this module 4, you learned how to use Flink SQL to create denormalized views for your relational data residing in an operational database and feed a dedicated full text search index.

The [next module](module_05.md) of this lab will explain how to go beyond the built-in capabilities of Flink SQL by means of user-defined functions (UDFs). Thanks to UDFs, you can effectively incorporate arbitrary functionality and processing logic. For instance, you can integrate with AI-related services exposed by external applications and seamlessly make use of these in your streaming data pipelines without giving up on the power and convenience of SQL.
