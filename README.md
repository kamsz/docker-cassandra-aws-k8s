# Cassandra on AWS and Kubernetes

This image is based on official Cassandra image (https://github.com/docker-library/cassandra).

It adds:
* JNA.
* Automatic rack detection (based on availability zone) using metadata server.
* Ability to provide cassandra.yaml via ConfigMap (https://github.com/docker-library/cassandra/pull/129).
* Ability to provide
