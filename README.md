# 👩‍🔬 Hands-on Stream Processing 🧪 Labs 🥽 

### **👋 Welcome! Great to have you in our hands-on lab. 🤩**

In this lab, you’ll build a real-time data pipeline from Postgres to OpenSearch, enabling use cases such as full-text search, analytics, and dashboarding on the data located and maintained in an operational database.
You are working on top of [Apache Flink](https://flink.apache.org/), in particular, you'll primarily use [Flink SQL](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/sql/overview/) as a convenient way to express your data processing needs in a declarative way.

You’ll learn how to set up E2E streaming data pipelines on top of existing Flink connectors to interact with the respective source (Postgres) and sink (OpenSearch) systems used during this lab.
Flink SQL will be applied for filtering, joining, grouping and transforming your data in-flight.
Specific data processing needs, for instance, the interaction with AI-related building blocks such as (large) language models, transformers, embedding models etc. can be achieved in SQL by extending Flink's built-in capabilities with custom user-defined functions (UDFs).

Under the hood, [Debezium](https://debezium.io) will be used for extracting change events from the source database via change data capture (CDC).

Ready to go? Then let’s get started by checking the [local infrastructure setup](docs/setup.md) for this lab!

## Contents

### [**Local Infra Setup**](docs/setup.md)

### [**Module 01:** Ingesting Data Changes From Postgres](docs/module_01.md)

### [**Module 02:** Writing Data Changes to OpenSearch](docs/module_02.md)

### [**Module 03:** Real-time Joins with Streaming SQL](docs/module_03.md)

### [**Module 04:** Creating Denormalized Data Views](docs/module_04.md)

### [**Module 05:** Streaming Sentiment Analysis](docs/module_05.md)

### [**Summary**](docs/summary.md)

## License

This repository and its resources are licensed under [Creative Commons BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/).
