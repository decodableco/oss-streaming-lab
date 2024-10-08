# Using the Lab Image Registry

NOTE: Make sure to follow the right instructions based on your platform (Arm vs. x64)!

# Using the Lab Image Registry With Arm Mac M1 etc.

1. Allow access to insecure registries.
Go to Docker Desktop -> "Settings" -> "Docker Engine".

```json
"insecure-registries": [
    "10.126.14.18:15101"
],
```

2. Pull the images:

```
docker image pull 10.126.14.18:15101/debezium/example-postgres:2.7.3.Final
docker image pull 10.126.14.18:15101/debezium/tooling:latest
docker image pull 10.126.14.18:15101/opensearchproject/opensearch:1.3.19
docker image pull 10.126.14.18:15101/flink:1.19.1-scala_2.12-java17
docker image pull 10.126.14.18:15101/hpgrahsl/hol-devoxxbe-model-serving-app:1.0.0
docker image pull 10.126.14.18:15101/hpgrahsl/hol-devoxxbe-review-app:1.0.1
docker image pull 10.126.14.18:15101/hpgrahsl/data-generator:1.1.4
```

3. Re-tag the images:

```
docker tag 10.126.14.18:15101/debezium/example-postgres:2.7.3.Final quay.io/debezium/example-postgres:2.7.3.Final
docker tag 10.126.14.18:15101/debezium/tooling:latest quay.io/debezium/tooling:latest
docker tag 10.126.14.18:15101/opensearchproject/opensearch:1.3.19 docker.io/opensearchproject/opensearch:1.3.19
docker tag 10.126.14.18:15101/flink:1.19.1-scala_2.12-java17 docker.io/flink:1.19.1-scala_2.12-java17
docker tag 10.126.14.18:15101/hpgrahsl/hol-devoxxbe-model-serving-app:1.0.0 docker.io/hpgrahsl/hol-devoxxbe-model-serving-app:1.0.0
docker tag 10.126.14.18:15101/hpgrahsl/hol-devoxxbe-review-app:1.0.1 docker.io/hpgrahsl/hol-devoxxbe-review-app:1.0.1
docker tag 10.126.14.18:15101/hpgrahsl/data-generator:1.1.4 docker.io/hpgrahsl/data-generator:1.1.4
```

# Using the Lab Image Registry With x64

1. Allow access to insecure registries.
Go to Docker Desktop -> "Settings" -> "Docker Engine".

```json
"insecure-registries": [
    "10.126.14.18:15102"
],
```

2. Pull the images:

```
docker image pull 10.126.14.18:15102/debezium/example-postgres:2.7.3.Final
docker image pull 10.126.14.18:15102/debezium/tooling:latest
docker image pull 10.126.14.18:15102/opensearchproject/opensearch:1.3.19
docker image pull 10.126.14.18:15102/flink:1.19.1-scala_2.12-java17
docker image pull 10.126.14.18:15102/hpgrahsl/hol-devoxxbe-model-serving-app:1.0.0
docker image pull 10.126.14.18:15102/hpgrahsl/hol-devoxxbe-review-app:1.0.1
docker image pull 10.126.14.18:15102/hpgrahsl/data-generator:1.1.4
```

3. Re-tag the images:

```
docker tag 10.126.14.18:15102/debezium/example-postgres:2.7.3.Final quay.io/debezium/example-postgres:2.7.3.Final
docker tag 10.126.14.18:15102/debezium/tooling:latest quay.io/debezium/tooling:latest
docker tag 10.126.14.18:15102/opensearchproject/opensearch:1.3.19 docker.io/opensearchproject/opensearch:1.3.19
docker tag 10.126.14.18:15102/flink:1.19.1-scala_2.12-java17 docker.io/flink:1.19.1-scala_2.12-java17
docker tag 10.126.14.18:15102/hpgrahsl/hol-devoxxbe-model-serving-app:1.0.0 docker.io/hpgrahsl/hol-devoxxbe-model-serving-app:1.0.0
docker tag 10.126.14.18:15102/hpgrahsl/hol-devoxxbe-review-app:1.0.1 docker.io/hpgrahsl/hol-devoxxbe-review-app:1.0.1
docker tag 10.126.14.18:15102/hpgrahsl/data-generator:1.1.4 docker.io/hpgrahsl/data-generator:1.1.4
```
