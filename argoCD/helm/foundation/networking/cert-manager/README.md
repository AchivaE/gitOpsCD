# cert-manager foundation module

This release owns cert-manager, its CRDs and approved `ClusterIssuer` objects.
It must be upgraded and rolled back independently from observability, runtime
services and workloads. In production, pin the Argo Application to a reviewed
Git revision before changing this chart.
