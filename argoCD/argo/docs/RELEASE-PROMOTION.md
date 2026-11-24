# Promotion staging et production

Les Applications `local` peuvent suivre `main` avec synchronisation
automatique. Les Applications `staging` et `prod` n'ont volontairement pas
`syncPolicy.automated` : une branche mutable ne peut pas etre une source de
deploiement non supervisee.

Pour promouvoir une version :

1. Creer et proteger un tag de release, ou recuperer le SHA Git complet de la
   revision revue.
2. Modifier `spec.source.targetRevision` de la seule Application concernee vers
   ce tag ou ce SHA. Ne pas modifier plusieurs produits dans le meme changement.
3. Verifier le rendu Helm correspondant et les changements de donnees,
   certificats ou CRD.
4. Synchroniser manuellement l'Application dans Argo CD et attendre `Healthy`.
5. Conserver la revision precedente dans la revue de changement : elle est le
   rollback Git immediat.

Le passage de `main` a un SHA/tag ne se fait pas automatiquement ici : aucun
identifiant de release reel ne doit etre invente dans un manifeste Argo CD.
Une fois une revision immuable choisie, elle doit rester la seule modification
de promotion avec les valeurs d'environnement necessaires.
