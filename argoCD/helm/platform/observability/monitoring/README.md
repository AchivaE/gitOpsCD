# Monitoring platform module

This release owns Prometheus, Alertmanager, Grafana and platform alert rules.
It is deliberately independent from cert-manager. Persistent Prometheus and
Grafana data require a tested storage backup/restore procedure before an
upgrade, downgrade or recreation.
