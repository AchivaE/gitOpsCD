# Promotion OIDC/CORS du Gateway

## Principe

Le Gateway authentifie les JWT à la frontière de la plateforme. Il vérifie la
signature, l'issuer et l'audience. Il applique aussi la liste blanche CORS.
Chaque service aval conserve ses décisions d'autorisation métier.

Un Ingress ne doit jamais être activé avant cette promotion : les probes et les
métriques restent publics, mais toutes les routes API exigent un JWT valide.

## 1. Publier l'artefact avant GitOps

Depuis le dépôt `gateway-ingestor`, après revue et tests :

```powershell
.\mvnw.cmd test
.\publish-ghcr.ps1 -Version 1.0.1
```

Le script demande un jeton GitHub avec `write:packages` et ne le conserve pas.
Noter le digest retourné par Docker, par exemple :

```text
ghcr.io/achivae/gateway-ingestor@sha256:...
```

## 2. Préparer Keycloak

Créer dans le realm cible un client ou une audience de ressource
`spaceup-gateway`. Les jetons destinés au Gateway doivent contenir :

- `iss` égal à l'issuer configuré ;
- `aud` contenant `spaceup-gateway` ;
- les rôles realm Keycloak nécessaires (`realm_access.roles`) ;
- éventuellement les scopes OAuth2 utilisés par les routes.

En staging et production, l'issuer et l'endpoint JWKS doivent être privés et
HTTPS. L'identité elle-même doit disposer de son Ingress/TLS avant que le
Gateway ne soit exposé.

## 3. Promouvoir dans GitOps

Dans l'overlay visé, utiliser l'image immuable et compléter les données réelles
suivantes :

```yaml
image:
  repository: ghcr.io/achivae/gateway-ingestor
  tag: sha256:REPLACE_WITH_PUBLISHED_DIGEST
  requireDigest: true
ingress:
  enabled: true
  controllerVerified: true
  className: REPLACE_WITH_INGRESS_CLASS
  host: REPLACE_WITH_PUBLIC_GATEWAY_HOSTNAME
oidc:
  enabled: true
  applicationSecurityVerified: true
  issuerUri: https://REPLACE_WITH_PRIVATE_KEYCLOAK_ISSUER
  jwkSetUri: https://REPLACE_WITH_PRIVATE_KEYCLOAK_JWKS
  audiences: [spaceup-gateway]
  egressCidrs: [REPLACE_WITH_PRIVATE_KEYCLOAK_CIDR]
cors:
  enabled: true
  applicationSecurityVerified: true
  allowedOrigins: [https://REPLACE_WITH_TRUSTED_FRONTEND_ORIGIN]
```

Les validations Helm refusent les placeholders, HTTP, wildcard CORS, audience
vide, ou contrôleur Ingress non vérifié.

## 4. Tests de réception

Après synchronisation Argo CD :

1. `GET /actuator/health` retourne `200`.
2. Une route API sans Bearer token retourne `401`.
3. Un JWT valide, du bon issuer et de la bonne audience est accepté.
4. Un JWT expiré, d'un autre issuer ou d'une autre audience retourne `401`.
5. Une origine CORS approuvée reçoit les en-têtes attendus ; une autre origine
   ne reçoit aucun en-tête `Access-Control-Allow-Origin`.

Ne passer `applicationSecurityVerified` à `true` qu'après ces cinq résultats.
