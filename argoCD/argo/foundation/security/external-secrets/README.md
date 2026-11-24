# Cloud secret-store contracts

`azure/` and `aws/` are provider-specific, gated configuration. Include one
and only one in a matching cloud overlay after Terraform has created the
workload identity and granted least-privilege access. Neither directory creates
the External Secrets Operator; that is the independent Foundation Application.
