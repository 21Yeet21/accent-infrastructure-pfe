
# Sprint 1 — Préparation des Serveurs S1 et S2 dans VMware

## Vue d'Ensemble

Avant la migration vers EVE-NG, S1 et S2 sont préparés dans VMware. L'approche choisie consiste à installer uniquement les paquets nécessaires dans VMware et à différer toute la configuration après la migration. Cette méthode est plus rapide à déployer car VMware fournit un environnement stable pour l'installation de l'OS et des paquets, tandis qu'EVE-NG fournit la topologie réseau finale où la configuration prend tout son sens.

Aucun serveur de monitoring n'existe à ce stade — les agents sont installés mais ne sont pas encore configurés pour envoyer des données vers une destination.

---

## Pourquoi Cette Approche

L'installation d'un OS complet et de tous les paquets requis directement dans EVE-NG est lente et sujette aux erreurs en raison de l'environnement de virtualisation imbriquée. En préparant les serveurs dans VMware d'abord, puis en convertissant les images disques, on obtient des VMs propres et pré-packagées prêtes à être configurées dès leur arrivée dans EVE-NG.

---

## Spécifications des Serveurs

| Serveur | OS | Rôle | IP |
|---------|-----|------|----|
| S1 | Ubuntu 22.04 LTS | Serveur Applicatif 1 | 192.168.50.11/26 |
| S2 | Ubuntu 22.04 LTS | Serveur Applicatif 2 | 192.168.50.12/26 |

---

## S1 — Paquets Installés

S1 est le serveur applicatif principal exécutant une stack web et base de données avec des agents de monitoring.

```bash
# Mise à jour système
apt update && apt upgrade -y

# Serveur web Apache
apt install -y apache2

# Base de données MySQL
apt install -y mysql-server

# Node Exporter (métriques Prometheus)
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

# OpenTelemetry Collector
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.96.0/otelcol-contrib_0.96.0_linux_amd64.tar.gz

# Grafana Alloy (collecteur de logs)
apt install -y alloy

# Wazuh Agent
apt install -y wazuh-agent
```

### Services installés sur S1

| Service | Port | Objectif |
|---------|------|----------|
| Apache | 80 | Serveur web |
| MySQL | 3306 | Base de données |
| Node Exporter | 9100 | Métriques système |
| OTel Collector | 4317, 4318 | Traces et logs |
| Alloy | — | Acheminement des logs vers Loki |
| Wazuh Agent | — | Événements HIDS vers Wazuh Manager |

---

## S2 — Paquets Installés

S2 est le serveur applicatif secondaire exécutant un reverse proxy et une stack de cache avec des agents de monitoring.

```bash
# Mise à jour système
apt update && apt upgrade -y

# Reverse proxy Nginx
apt install -y nginx

# Cache Redis
apt install -y redis-server

# Redis Exporter (métriques Prometheus pour Redis)
wget https://github.com/oliver006/redis_exporter/releases/download/v1.58.0/redis_exporter-v1.58.0.linux-amd64.tar.gz
tar xvf redis_exporter-v1.58.0.linux-amd64.tar.gz
cp redis_exporter-v1.58.0.linux-amd64/redis_exporter /usr/local/bin/

# Node Exporter — identique à S1
# OpenTelemetry Collector — identique à S1
# Grafana Alloy — identique à S1
# Wazuh Agent — identique à S1
```

### Services installés sur S2

| Service | Port | Objectif |
|---------|------|----------|
| Nginx | 80 | Reverse proxy |
| Redis | 6379 | Cache |
| Redis Exporter | 9121 | Métriques Redis |
| Node Exporter | 9100 | Métriques système |
| OTel Collector | 4317, 4318 | Traces et logs |
| Alloy | — | Acheminement des logs vers Loki |
| Wazuh Agent | — | Événements HIDS vers Wazuh Manager |

---

## Ce Qui n'Est PAS Configuré

La configuration suivante est intentionnellement différée aux sprints suivants :

- Endpoints de l'OTel Collector (pas encore d'adresse MonSrv)
- Cibles Loki pour Alloy (pas encore d'adresse Loki)
- Adresse du manager Wazuh (pas encore de Wazuh Manager)
- Règles de reverse proxy Nginx (pas encore de Grafana)
- Bases de données et utilisateurs MySQL (configuration spécifique à l'application)
- Configuration des interfaces réseau (effectuée après migration EVE-NG)

---

## Résultat de Ce Sprint

À l'issue du Sprint 1, S1 et S2 sont des VMs VMware avec :

- Ubuntu 22.04 installé
- Tous les paquets et binaires requis présents
- Services installés mais pas encore configurés
- Images disques prêtes à être exportées en VMDK pour conversion

Ces images disques sont ensuite exportées et converties au format qcow2 compatible EVE-NG lors du Sprint 2.

---

## Notes Importantes

| Note | Détail |
|------|--------|
| Pas encore de serveur de monitoring | Les agents sont installés mais n'ont pas de destination configurée |
| Configuration réseau différée | Les IPs finales (192.168.50.11, 192.168.50.12) seront définies après la migration EVE-NG |
| Services non démarrés | La plupart des services sont installés mais pas activés tant que la configuration n'est pas terminée |

