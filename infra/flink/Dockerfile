FROM flink:1.19.1-scala_2.12-java17

#adding connectors used during the lab
RUN wget -P /opt/flink/lib https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-opensearch/1.2.0-1.19/flink-sql-connector-opensearch-1.2.0-1.19.jar

# Using 2.3.0 here as later versions have an issue where not all replication slots
# are started eagerly
RUN wget -P /opt/flink/lib https://repo1.maven.org/maven2/com/ververica/flink-sql-connector-postgres-cdc/2.3.0/flink-sql-connector-postgres-cdc-2.3.0.jar
