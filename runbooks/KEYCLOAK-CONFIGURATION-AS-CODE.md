# Configuration Keycloak versionnée

Le module Keycloak utilise `keycloak-config-cli` pour rendre la configuration
du realm rejouable par Argo CD. Son fichier d'import respecte le format d'export
Keycloak et est appliqué par l'API d'administration une fois Keycloak prêt.

Le profil local gère :

- le realm `spaceup-local` ;
- le resource server `spaceup-gateway` ;
- l'audience JWT `spaceup-gateway` ;
- les rôles `spaceup-user` et `spaceup-admin` ;
- un client de test local, limité au flux Direct Grant.

Le Job est idempotent. Il ne doit contenir ni utilisateur, ni mot de passe, ni
secret de client. Les identifiants administrateur utilisés par le Job viennent
du Secret Kubernetes existant, lui-même fourni par Vault/External Secrets hors
du profil local.

Après une synchronisation Argo CD locale, vérifier :

```powershell
minikube kubectl -- get jobs -n platform-identity
minikube kubectl -- logs -n platform-identity job/platform-keycloak-local-keycloak-config-cli
```

En staging et production, remplacer le client de test par des clients
confidentiels ou publics adaptés, avec Authorization Code + PKCE, redirect URI
HTTPS exacte et secrets livrés exclusivement par External Secrets.
