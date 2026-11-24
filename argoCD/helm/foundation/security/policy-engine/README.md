# Policy Engine Foundation

Cette release installe Kyverno et quatre politiques de baseline SpaceUP :
ressources, probes, image `latest` et privileges de conteneur. Kyverno est
deploye seul dans le namespace `kyverno`; il n'est pas co-localise avec les
applications ou les composants systeme.

L'Application est synchronisee en vague `-17`, apres le monitoring (`-18`) et
avant les services de plateforme (`-10`). Les quatre `ServiceMonitor` Kyverno
sont donc crees seulement apres les CRD Prometheus et sont selectionnes par le
Prometheus de plateforme.

Les politiques ciblent uniquement les namespaces portant le label
`platform.spaceup.io/policy-tier: baseline`. Elles sont initialement en `Audit`:
elles produisent des PolicyReports sans refuser de workload. Cela permet de
mesurer les ecarts avant toute interruption de service.

## Passage controle en enforcement

1. Consulter les rapports sur au moins un cycle de deploiement et corriger les
   violations attendues.
2. Tester la politique et son rollback sur le cluster local.
3. Passer une seule politique a `Enforce` dans une revue distincte, d'abord en
   staging, avec une revision Git immuable.
4. Conserver le rollback : revenir a `Audit` dans la revision precedente.

Ne jamais cibler `kube-system`, `argocd`, `platform-system`, `kyverno` ou un
namespace tiers sans une analyse d'impact dediee. Les politiques ne remplacent
ni les NetworkPolicies, ni les controles d'image du registre.
