## Module 01 — Ingesting Data Changes From Postgres

In this module you are going to set up a Postgres CDC connector for ingesting change events from a Postgres database into Apache Flink. This connector is based on Debezium, a popular open-source platform for log-based change data capture (CDC). Whenever an `INSERT`, `UPDATE`, or `DELETE` is issued in the source Postgres database, the connector will capture that data change and emit a corresponding event.

The captured data change events are propagated directly into a Flink table. From there, you can either consume the events and send it further to an external system such as a data warehouse, a search index, or object storage. Alternatively, you can process the change events within Flink, for instance using SQL to create denormalized data views.

### Setting Up the Postgres Source Connector

Start a containerized Flink SQL CLI using the Docker command below:

```bash
docker compose exec -it sql-client bin/sql-client.sh
```

**IMPORTANT: Keep this Flink CLI session open at all times during the lab!** It's the primary way to interact with the Flink cluster throughout this hands-on lab. Usually, there is no need to stop/(re-)start the Flink CLI nor run multiple sessions in parallel.

In the Flink CLI, run the following `CREATE TABLE` statement to define a Flink table named `customers` using the `postgres-cdc` connector. This table represents the source of the E2E streaming data pipeline.

```sql
CREATE TABLE customers (
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
   'debezium.publication.name' = 'customers_publication',
   'slot.name' = 'customers_slot'
);
```

### Preview Data Changes

From within the Flink SQL CLI, write the following basic `SELECT` query to check the records in that table:

```sql
SELECT * FROM customers;
```

As you executed this query, this is the very first time that the Postgres CDC connector is being run based on the specified configuration. Hence, it will take an initial snapshot of all the existing data in the Postgres `customers` table. For each existing record, a snapshot record will be emitted and stored in this Flink table.

You should see a result set as follows:

```bash
          id                     first_name                      last_name                          email is_test_account
        1001                          Sally                         Thomas          sally.thomas@acme.com           FALSE
        1002                         George                         Bailey             gbailey@foobar.com           FALSE
        1003                         Edward                         Walker                  ed@walker.com           FALSE
        1004                          Aidan                        Barrett              aidan@example.com            TRUE
        1005                           Anne                      Kretchmar             annek@noanswer.org            TRUE
        1006                        Melissa                           Cole            melissa@example.com           FALSE
        1007                        Rosalie                        Stewart            rosalie@example.com           FALSE
```

### Perform Data Changes

Next, let’s do a few changes in the source database. For that purpose, open a new terminal window/tab and create a containerized pgcli session by means of the Docker command below:

```bash
docker run --tty --rm -i \
    --network hol-devoxxbe-network \
    quay.io/debezium/tooling:latest \
    bash -c 'pgcli postgresql://postgres:postgres@postgres:5432/postgres'
```

In pgcli, run these SQL statements to `INSERT` two new customers, `UPDATE` one existing customer twice (`id=1001`), and finally delete one customer (`id=1007`):

```sql
INSERT INTO inventory.customers VALUES
    (default, 'Issac', 'Fletcher', 'ifletcher@example.com',false),
    (default, 'Belle', 'Read', 'belle.read@example.com',true);

UPDATE inventory.customers set last_name = 'Brooks' where id = 1001;
UPDATE inventory.customers set last_name = 'Green' where id = 1001;

DELETE FROM inventory.customers WHERE id = 1007;
```

You may get a question about a destructive command like so:

```bash
You're about to run a destructive command.
Do you want to proceed? [y/N]: y
```

Press `y` to proceed.

Switch back to your still running Flink SQL CLI. In case you kept the previously started query active, you should see the database changes already being reflected in the automatically updated result set. If you quit the previous query, re-run the `SELECT` statment to inspect the updated flink table:

```sql
SELECT * FROM customers;
```

You should see a result set as follows:

```bash
         id                     first_name                      last_name                          email is_test_account
        1002                         George                         Bailey             gbailey@foobar.com           FALSE
        1003                         Edward                         Walker                  ed@walker.com           FALSE
        1004                          Aidan                        Barrett              aidan@example.com            TRUE
        1005                           Anne                      Kretchmar             annek@noanswer.org            TRUE
        1006                        Melissa                           Cole            melissa@example.com           FALSE
        1008                          Issac                       Fletcher          ifletcher@example.com           FALSE
        1009                          Belle                           Read         belle.read@example.com            TRUE
        1001                          Sally                          Green          sally.thomas@acme.com           FALSE
```

_NOTE:_ Change events are ingested asynchronously. If you don’t see your changes being reflected immediately, wait a little and if applicable, quit and re-run this query.

### What's next?

At this point, you have successfully defined a Flink table backed by data residing in Postgres. After performing a snapshot, the CDC connector will react to any inserts, updates, and deletes happening in the configured Postgres table.

In the [next module](./module_02.md) of this lab, you’ll learn how to start a permanently running Flink job so that the CDC connector will continuously propagate any data changes into an OpenSearch index, enabling use cases such as full-text search, analytics, or dashboarding.
