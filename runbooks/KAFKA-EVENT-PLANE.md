# Kafka event-plane governance and recovery

## Provider decision gate

Before creating topics, record the selected provider and evidence that it
supports every required Kafka feature: transactions, idempotent producer,
consumer groups, compression, Kafka Connect, Streams, schema registry and
cross-region recovery where applicable. Kafka protocol compatibility alone is
not enough evidence.

For Azure Event Hubs, use a private endpoint and an approved tier. Its Kafka
endpoint is a managed compatibility layer, not a self-operated broker cluster.
The team must specifically validate any Kafka feature it depends on.

## Topic contract

Every topic is reviewed as a product interface and records:

| Field | Required rule |
| --- | --- |
| Owner | One business domain is accountable. |
| Name | `<domain>.<entity>.<event>.v<major>`, for example `ingestion.document.received.v1`. |
| Partitions | Sized from throughput and consumer parallelism; increasing is possible, shrinking is not. |
| Replication | Production RF 3, `min.insync.replicas=2`. |
| Retention | Explicit duration/size and data-classification approval. |
| Schema | Versioned Avro, Protobuf or JSON Schema with compatibility policy. |
| Authorization | Separate producer and consumer identities, limited to this topic and consumer group. |
| Replay | Idempotency key and replay/reprocessing procedure documented. |
| Failure | Retry topic/DLQ policy and owner alert defined. |

## Application delivery contract

Producers use TLS and workload-specific authentication, `acks=all`, idempotence
and bounded retries. Consumers are idempotent because duplicate delivery is
normal during retry/rebalance/recovery. They commit an offset only after their
business side effect is durable. Cross-service database writes and Kafka
publishes use an outbox pattern when atomicity is required.

## Operational evidence before production

1. Prove private DNS and TLS connectivity from a workload namespace.
2. Prove ACL denial for an unauthorized producer and consumer.
3. Measure producer failure behavior, consumer lag alerting and rebalance.
4. Execute one replay and one poison-message/DLQ exercise.
5. Execute provider failover/region recovery according to the approved RPO/RTO.
6. Record topic configurations, client versions, test evidence and owners.

## Kafka client activation gate

A microservice may be connected only after its source code contains a supported
Kafka client dependency and automated tests for idempotent duplicate delivery.
The implementation Pull Request must include its topic contract, producer or
consumer identity, expected consumer group, retry/DLQ behavior and NetworkPolicy
egress. Do not add generic `KAFKA_*` environment variables to a chart before
the service actually has a Kafka client.
