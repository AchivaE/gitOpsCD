# Activation contrôlée d'un environnement Azure

Les overlays `azure-staging` et `azure-prod` installent uniquement le socle
GitOps sans configuration sensible ni workload applicatif non prêt. Cela garde
la Root Application saine tant que Terraform, les identités et les contrats de
service ne sont pas prouvés.

## Ordre obligatoire

1. Terraform crée le réseau privé, les DNS privés, l'identité fédérée External
   Secrets, les rôles Key Vault et le contrôleur Ingress Azure. Tester la
   classe `azure-application-gateway` et le routage TLS.
2. Dans une revue dédiée, remplacer les valeurs publiques `REPLACE_WITH_*` du
   `ClusterSecretStore` Azure : tenant, client ID et URL Key Vault. Aucun mot
   de passe, token ou clé ne va dans Git.
3. Ajouter à l'overlay de l'environnement, puis synchroniser dans cet ordre :

   ```yaml
   - ../../applications/foundation/security/external-secrets
   - ../../foundation/security/external-secrets/azure
   - ../../management/argocd/repository-access
   ```

   Attendre que l'opérateur et `azure-keyvault` soient prêts avant tout
   consommateur d'External Secrets.
4. Ajouter puis synchroniser `foundation-policy-engine-*` après validation des
   règles d'audit et de leurs rapports.
5. Ajouter puis synchroniser `foundation-cert-manager-*` et
   `platform-monitoring-*` seulement après leurs prérequis de stockage,
   certificats et sauvegarde.
6. Ajouter `config-server` puis `api-gateway` seulement quand les profils
   staging/prod rendent avec une image digérée, les endpoints privés, Git de
   configuration immuable, métriques réelles, OIDC, CORS et CIDR egress réels.
   Remplacer `targetRevision: main` par un SHA Git complet ou un tag protégé.
7. Activer Keycloak séparément selon `IDENTITY-ACTIVATION.md`.

Chaque étape est un changement Git distinct et une synchronisation manuelle
vérifiée. Ne jamais ajouter toutes les ressources à l'overlay dans une unique
promotion.
