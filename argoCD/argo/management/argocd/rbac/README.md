# Argo CD controller Kubernetes RBAC

Ce repertoire contient uniquement les permissions Kubernetes actives dont le
controleur Argo CD a besoin pour synchroniser les resources autorisees par les
`AppProject`. Il ne contient ni PodSecurityPolicy ni identite applicative
inactive.

`spaceup-platform-deployer` est lie au controleur Argo CD. Son perimetre doit
etre revu avant tout ajout de nouvelle ressource au catalogue GitOps. Les droits
de gestion des utilisateurs Argo CD, du SSO et des roles Casbin appartiennent
au Management Plane et ne doivent pas etre confondus avec ce RBAC Kubernetes.
