# Achiva deployable services

These charts deploy images only. They never build source code and must never use a mutable `latest` tag.

## Promotion contract

1. CI builds outside the cluster, runs tests and security scans, then pushes a signed image to the selected OCI registry.
2. CI submits a reviewed Git change with the verified image digest. Production accepts only `sha256` digests and Helm renders them as `repository@sha256:...`.
3. Argo CD synchronizes the reviewed change. It does not run Maven, Docker build, or arbitrary scripts.

## Config Ingestor

`config-ingestor` is internal-only. In Kubernetes it uses Spring Cloud Config's Git backend, not the Docker-only local `/config-repo` mount.

Before an environment can sync, configure:

- `configRepository.uri` with the protected configuration-repository URL;
- the selected `ClusterSecretStore` with `config-ingestor-git-username` and `config-ingestor-git-token`;
- network access from AKS to that repository (private endpoint or controlled egress).
- a reviewed immutable configuration Git revision: full commit SHA or protected
  `v*` release tag for staging and production; `main` is local-only.
- a verified `/actuator/prometheus` endpoint backed by
  `micrometer-registry-prometheus` before enabling the ServiceMonitor.

## Gateway Ingestor

`gateway-ingestor` is the only public entry point. Its ingress class and
annotations are supplied by the Azure or AWS profile; it authenticates to Vault
with its Kubernetes service account.

Before its public Ingress can render in staging or production, the chart
requires a verified Foundation IngressClass, a HTTPS OIDC issuer and JWKS URI,
an expected JWT audience, private endpoint egress CIDRs, and an explicit CORS
allow-list of HTTPS web origins. The Gateway binary must include and verify
Spring OAuth2 Resource Server support; values alone do not authenticate a
request. The code must consume `SPACEUP_GATEWAY_CORS_ALLOWED_ORIGINS` and
`SPACEUP_GATEWAY_OIDC_PUBLIC_PATHS`, with no public API path by default.

Before production sync, configure the private Consul and Vault endpoints, their TLS material, least-privilege Consul tokens, and the Vault Kubernetes auth role. The full contract is in [RUNTIME-DEPENDENCIES.md](RUNTIME-DEPENDENCIES.md). Application metric scraping remains disabled until the services include `micrometer-registry-prometheus`.

## Application hardening still required

The existing gateway configuration permits `allowedOriginPatterns: "*"` together with credentialed CORS. That is unsafe for a public gateway and must be replaced in the configuration repository with the explicit allow-list promoted in the chart. This source is outside `gitOpsCD`, so it has not been changed here.

## Provider and local portability

Use the local, Azure, or AWS values layer rather than modifying templates. The
full layer order and local-cluster commands are in [PORTABILITY.md](PORTABILITY.md).

## GitOps bootstrap secret

The Argo CD repository token is stored as `argocd-repository-token` in Azure Key Vault. It is injected once from a protected administration pipeline, then maintained by External Secrets Operator. See `../../argo/bootstrap/README.md`; no token belongs in this repository.
