# Apply with the Vault administration workflow, never with kubectl or Argo CD.
# The policy is intentionally minimal: read only the two configuration paths
# consumed by gateway-ingestor. It cannot list, write, create policies or mint
# tokens.
path "achiva/data/shared" {
  capabilities = ["read"]
}

path "achiva/data/gateway-ingestor" {
  capabilities = ["read"]
}
