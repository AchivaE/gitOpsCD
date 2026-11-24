# Contrat Tracing Platform

Tempo (ou un backend gere equivalent) est un produit de donnees partage. Son
activation exige du stockage objet prive, une retention approuvee,
l'authentification des collecteurs OpenTelemetry et une politique de
confidentialite sur les attributs de traces.

Avant de creer le chart, definir les quotas d'ingestion, l'echantillonnage, les
regles de masquage des donnees sensibles, les alertes de collecte, le RPO/RTO
et une restauration testee. Chaque service conserve son propre choix
d'instrumentation ; il ne depend pas du chart Tempo comme sous-chart.
