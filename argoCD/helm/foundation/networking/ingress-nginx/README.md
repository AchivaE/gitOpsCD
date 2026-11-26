# Ingress Controller local

This module installs the `nginx` IngressClass only in the local Minikube
overlay. It is a Foundation capability, separate from the API Gateway release.

The upstream ingress-nginx project is archived; it is retained here solely for
local development compatibility. Staging and production use provider-managed
controllers: Application Gateway Ingress Controller on AKS and AWS Load
Balancer Controller on EKS. Do not add this Application to cloud overlays.

The local controller is exposed through a NodePort. Retrieve its address with:

```powershell
minikube service -n ingress-nginx ingress-nginx-controller --url
```

No local Gateway Ingress is enabled by default. Enable it only alongside an
explicit local hostname and certificate strategy; `kubectl port-forward` stays
the default local access method.
