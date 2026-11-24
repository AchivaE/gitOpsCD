# Kafka event-plane contract

Kafka is a shared event plane, not a Helm dependency embedded in a business
service. This dedicated module vendors the Bitnami Kafka chart `32.4.3`
(Apache Kafka `4.0.0`) for an explicit **local-only** KRaft validation target.
It is never part of the standard Root Application overlay and cannot render
for staging or production.

Staging and production use a managed, private Kafka-compatible service. Argo
CD therefore does not deploy production Kafka brokers, KRaft controllers,
disks or public listeners.

## Standard topology

```text
producer / consumer workloads
          │ TLS + SASL/OAuth, private network
          ▼
 managed Kafka service (three availability zones)
          ├── brokers / controllers operated by the provider
          ├── topic ACLs and quotas
          ├── schema registry when required
          └── backup / cross-region recovery policy
```

The service must provide genuine Kafka semantics required by the product. Azure
Event Hubs' Kafka endpoint is acceptable only after feature-compatibility is
validated for the intended clients and patterns. For Kafka transactions,
connectors, Streams, exactly-once behavior or features not supported by that
endpoint, use a managed Apache Kafka provider instead.

## Mandatory production baseline

- private endpoint/PrivateLink only; no public broker listener;
- three-zone availability, replication factor `3`, and `min.insync.replicas=2`;
- TLS plus workload-specific SASL/OAuth identity and topic ACLs;
- producer `acks=all`, idempotence enabled, bounded retries and delivery
  timeout; consumers must be idempotent and commit offsets only after durable
  processing;
- topic owner, retention, partition count, classification and schema/version
  policy declared before the topic is created;
- monitoring for under-replicated partitions, consumer lag, failed produces,
  quota throttling and authentication failures;
- a tested regional recovery design and documented RPO/RTO.

## Local development

A single local Kafka broker is permitted only for producer/consumer tests. It
uses a persistent 8Gi PVC and a NetworkPolicy, but plaintext listeners and one
node mean it does not prove replication, partition reassignment, TLS/SASL,
ACLs, private networking or disaster recovery. It is intentionally not part of
the standard Argo overlay.

After ensuring that the local cluster has at least 4 CPUs and 8GiB memory,
create its Application explicitly:

```powershell
minikube kubectl -- apply -n argocd -k argoCD/argo/applications/platform/eventing/kafka-local
```

Then review and manually synchronize `platform-kafka-local` in Argo CD. A test
client must carry the label `kafka-client: "true"`; the NetworkPolicy
intentionally rejects other client pods.

The activation and topic-governance process is in
[`../../../../runbooks/KAFKA-EVENT-PLANE.md`](../../../../runbooks/KAFKA-EVENT-PLANE.md).

## Workload integration gate

There is currently no Kafka client dependency in `config-ingestor` or
`gateway-ingestor`. Kafka must not be enabled merely by adding bootstrap-server
environment variables. Before an application becomes a producer or consumer it
must add its Kafka client dependency, TLS/SASL authentication implementation,
idempotency tests and an explicit event/topic contract. This is enforced as a
review gate, not hidden inside a generic service chart.
