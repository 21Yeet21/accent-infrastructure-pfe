
# ACCENT — Infrastructure Observabilité & Sécurité

> Projet de Fin d'Études — Infrastructure complète d'observabilité et de sécurité déployée en environnement virtualisé (EVE-NG, Proxmox VE) avec une stack Grafana, Wazuh HIDS et haute disponibilité.

[![Status](https://img.shields.io/badge/status-completed-brightgreen)](https://github.com/21Yeet21/accent-infrastructure)
[![Sprints](https://img.shields.io/badge/sprints-9%2F9-blue)](https://github.com/21Yeet21/accent-infrastructure)
[![Story Points](https://img.shields.io/badge/story_points-56-orange)](https://github.com/21Yeet21/accent-infrastructure)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

---

## Vue d'Ensemble

**ACCENT** est une infrastructure d'entreprise miniature conçue pour démontrer le déploiement complet d'une stack moderne combinant virtualisation, sécurité réseau, monitoring distribué (les 3 piliers : métriques, logs, traces) et haute disponibilité. 

Ce dépôt contient l'intégralité du code d'infrastructure (Infrastructure as Code), des configurations, des scripts d'automatisation et de la documentation détaillée, permettant une reproduction fidèle et sécurisée de l'environnement de lab.

---

## Architecture

L'infrastructure repose sur six couches successives :
1. **Virtualisation** : VMware Workstation (hôte), EVE-NG 6.2.0 (simulation réseau), Proxmox VE 8.4 (hyperviseur des VMs critiques).
2. **Réseau** : Topologie complète avec 5 VLANs segmentés (Clients, Management, DMZ, VPN, Native) et routage NAT.
3. **Sécurité** : pfSense CE 2.7.2 (Pare-feu, IDS/IPS Suricata, OpenVPN) et Wazuh 4.11.2 (HIDS/SIEM).
4. **Observabilité** : Prometheus (métriques), Grafana Loki (logs), Grafana Tempo (traces), Grafana Alloy & OpenTelemetry Collector.
5. **Visualisation & Alerting** : 7 dashboards Grafana, 17 règles d'alerte, intégration Slack en temps réel.
6. **Haute Disponibilité** : Cluster Proxmox 3 nœuds avec stockage Ceph distribué (PoC validé).

---

## Structure du Dépôt

Ce dépôt est organisé pour faciliter le déploiement, la maintenance et la compréhension de l'infrastructure :

```text
accent-infrastructure/
├── .gitignore                          # Exclusions de sécurité (secrets, données, binaires)
├── LICENSE                             # Licence MIT (Copyright 2026 21Yeet21)
├── README.md                           # Documentation principale du projet (ce fichier)
│
├── configs/                            # Fichiers de configuration de tous les services
│   ├── README.md                       # Guide de déploiement et règles de sécurité
│   ├── alloy/                          # Configs Grafana Alloy (collecte de logs S1/S2)
│   ├── docker-compose/                 # Stacks Docker (Monitoring, Agents S1/S2)
│   ├── eve-ng/                         # Templates QEMU et configs Cisco (ISP-R1, SW1)
│   ├── grafana/                        # Dashboards JSON et provisioning (datasources, alerting)
│   ├── loki/                           # Configuration du serveur d'agrégation de logs
│   ├── otel/                           # Configuration OpenTelemetry Collector (traces S1)
│   ├── pfsense/                        # Configuration pfSense (sanitisée, sans secrets)
│   ├── prometheus/                     # prometheus.yml et règles d'alerte
│   ├── proxmox/                        # Configuration réseau de l'hyperviseur pve1
│   ├── tempo/                          # Configuration du backend de traces distribuées
│   └── wazuh/                          # Configurations des agents et du manager Wazuh
│
├── docs/                               # Documentation détaillée du projet
│   ├── architecture.md                 # Architecture globale et flux de données
│   ├── webography.md                   # Références bibliographiques et liens utiles
│   ├── operations/                     # Procédures opérationnelles (démarrage, tests, dépannage)
│   │   ├── startup-shutdown-eve-ng.md
│   │   ├── startup-shutdown-ha-cluster.md
│   │   └── monitoring-tests.md
│   └── sprints/                        # Documentation technique étape par étape (Sprint 0 à 9)
│
└── scripts/                            # Scripts d'automatisation et d'installation
    ├── install-docker.sh               # Installation Docker (MonSrv)
    ├── install-node-exporter.sh        # Installation Node Exporter (pve1)
    ├── install-wazuh-agent.sh          # Installation de l'agent Wazuh (S1, S2, pve1)
    ├── pfsense-vlan.sh                 # Hook Proxmox pour la configuration VLAN de pfSense
    ├── setup-volumes.sh                # Préparation des permissions de volumes Docker
    └── test-brute-force.sh             # Simulation d'attaque pour valider les alertes Wazuh/Slack
```

---

## Démarrage Rapide

1. **Cloner le dépôt** :
   ```bash
   git clone https://github.com/21Yeet21/accent-infrastructure.git
   cd accent-infrastructure
   ```
2. **Consulter les règles de sécurité** : Lire `configs/README.md` pour comprendre comment appliquer les configurations sans exposer de secrets.
3. **Explorer la documentation** : La progression du projet est détaillée dans le dossier `docs/sprints/`, du déploiement réseau (Sprint 1) à la haute disponibilité (Sprint 9).
4. **Automatiser le déploiement** : Utiliser les scripts du dossier `scripts/` (après les avoir rendus exécutables avec `chmod +x`) pour installer les composants requis sur les cibles respectives.

> **Important** : Ce dépôt est un modèle d'infrastructure. Les mots de passe, clés API, certificats et webhooks ont été remplacés par `<REDACTED>`. Vous devez fournir vos propres valeurs sécurisées avant tout déploiement en production.

---

## Procédures Opérationnelles

Le dossier `docs/operations/` contient les guides pratiques pour démarrer, arrêter et tester l'infrastructure :

| Procédure | Description |
|-----------|-------------|
| [`startup-shutdown-eve-ng.md`](docs/operations/startup-shutdown-eve-ng.md) | Démarrage et arrêt de l'environnement EVE-NG (SW1, ISP-R1, pve1, S1, S2, MonSrv, Wazuh) |
| [`startup-shutdown-ha-cluster.md`](docs/operations/startup-shutdown-ha-cluster.md) | Démarrage du cluster Proxmox HA, démonstration de basculement et vérifications Ceph |
| [`monitoring-tests.md`](docs/operations/monitoring-tests.md) | Tests de validation de la stack de monitoring (stress CPU/RAM, trafic Apache/Nginx, activité MySQL/Redis, génération d'erreurs) |

Ces procédures incluent également des sections de **dépannage** pour les problèmes courants (Ceph degraded, Alloy bloqué, targets Prometheus DOWN, etc.).

---

## Progression des Sprints

| # | Sprint | Points | Documentation |
|---|--------|--------|---------------|
| 0 | Préparation des serveurs S1/S2 (VMware) | 3 | `docs/sprints/sprint-0.md` |
| 1 | Mise en Place de l'Environnement Virtualisé EVE-NG | 5 | `docs/sprints/sprint-1.md` |
| 2 | Déploiement de l'Infrastructure Réseau | 10 | `docs/sprints/sprint-2.md` |
| 3 | Mise en Place de l'Infrastructure Proxmox VE | 7 | `docs/sprints/sprint-3.md` |
| 4 | pfSense — Firewall, Sécurité (Suricata) et VPN | 14 | `docs/sprints/sprint-4.md` |
| 5 | Déploiement de Prometheus et Exporters | 8 | `docs/sprints/sprint-5.md` |
| 6 | Logs et Traces — Loki, Tempo, Alloy, OpenTelemetry | 8 | `docs/sprints/sprint-6.md` |
| 7 | Grafana — Dashboards, Alerting et Slack | 12 | `docs/sprints/sprint-7.md` |
| 8 | Wazuh HIDS — Détection d'Intrusion et Sécurité | 15 | `docs/sprints/sprint-8.md` |
| 9 | Proxmox HA — Cluster Haute Disponibilité (PoC) | 16 | `docs/sprints/sprint-9.md` |
| **Total** | | **56** | |

---

## Auteur & Encadrement

- **Réalisé par** : [21Yeet21](https://github.com/21Yeet21) & Abdelhamid (2026)
- **Encadré par** : M. Sofiane El Mahroug 

---

## Licence

Ce projet est distribué sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

