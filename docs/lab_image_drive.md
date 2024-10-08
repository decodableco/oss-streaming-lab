# Using the Lab Container Image USB Drive:

We provide the multi-arch container images for this lab also offline on a USB/Flash-Drive.
Ask the instructor to hand you the USB/Flash-Drive if applicable.

Then, proceed as follows to load the container images into your local Docker image registry.

## 1. Copy the TAR files to your Local Machine

You find two folders on the USB/Flash-Drive, either `/container_images/aarch64` or `/container_images/amd64`.

**! Depending on your CPU architecture !** copy the proper folder onto your local machine somewhere, for instance, into your user's home or downloads folder.

## 2. Load Container Images into your Local Docker Registry

Open a terminal window and make sure to go into the image folder you just copied which is supposed to contain the following seven TAR files, one for each container image:

```text
data-generator.tar
dbz-tooling.tar
flink.tar
model-serving-app.tar
opensearch.tar
postgres.tar
review-app.tar
```

From within this folder run the following Docker CLI commands:

```bash
docker load --input ./flink.tar
docker load --input ./opensearch.tar
docker load --input ./postgres.tar
docker load --input ./dbz-tooling.tar
docker load --input ./model-serving-app.tar
docker load --input ./review-app.tar
docker load --input ./data-generator.tar
```

The images should be loaded successfully into your local Docker Registry.

```bash
# expected terminal cli output
Loaded image: flink:1.19.1-scala_2.12-java17
Loaded image: opensearchproject/opensearch:1.3.19
Loaded image: quay.io/debezium/example-postgres:2.7.3.Final
Loaded image: quay.io/debezium/tooling:latest
Loaded image: hpgrahsl/hol-devoxxbe-model-serving-app:1.0.0
Loaded image: hpgrahsl/hol-devoxxbe-review-app:1.0.1
Loaded image: hpgrahsl/data-generator:1.1.4
```

Once this is finished, you're all set and ready to proceed with the lab!
