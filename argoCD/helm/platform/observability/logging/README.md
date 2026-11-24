# Contrat Logging Platform

Loki (ou une solution geree equivalente) ne doit etre active qu'avec un
backend durable, chiffre et une politique de retention validee. Un chart sans
ces choix donnerait une impression trompeuse de tracabilite tout en perdant les
logs a la premiere panne ou rotation de volume.

Prerequis d'activation : stockage objet prive, cle de chiffrement, retention
par niveau de donnees, limites d'ingestion et de requetes, authentification,
alertes sur perte de collecte et procedure de restauration testee. Les agents
de collecte doivent etre deploies separement du backend de stockage.
