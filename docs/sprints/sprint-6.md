# \# Sprint 6 — Logs et Traces : Loki, Tempo, Alloy, OpenTelemetry

# 

# \## Objectif

# 

# Mettre en place la collecte centralisée des \*\*journaux (logs)\*\* et des \*\*traces distribuées\*\* pour les serveurs S1 et S2. Ce sprint complète la stack d'observabilité en ajoutant les deux piliers manquants : \*\*logs\*\* via Grafana Loki + Grafana Alloy, et \*\*traces\*\* via Grafana Tempo + OpenTelemetry Collector.

# 

# \---

# 

# \## Architecture d'observabilité complète

# 

# ```

# &#x20;                   ┌─────────────────────────────────┐

# &#x20;                   │           MonSrv                │

# &#x20;                   │  Prometheus  Loki  Tempo  Grafana│

# &#x20;                   └────────────────┬────────────────┘

# &#x20;                                    │

# &#x20;             ┌──────────────────────┼──────────────────────┐

# &#x20;             │                                             │

# &#x20;   ┌─────────▼──────────┐                      ┌──────────▼──────────┐

# &#x20;   │        S1          │                      │        S2           │

# &#x20;   │  Alloy (logs)      │                      │  Alloy (logs)       │

# &#x20;   │  Node Exporter     │                      │  Node Exporter      │

# &#x20;   │  OTel Collector    │                      │  Redis Exporter     │

# &#x20;   │  Apache + MySQL    │                      │  Nginx              │

# &#x20;   │  Trace Generators  │                      │                     │

# &#x20;   └────────────────────┘                      └─────────────────────┘

# ```

# 

# Les trois piliers de l'observabilité sont désormais couverts :

# 

# | Pilier | Outil | Source |

# |--------|-------|--------|

# | Métriques | Prometheus + Node Exporter | S1, S2, pve1 |

# | Logs | Loki + Grafana Alloy | S1, S2 |

# | Traces | Tempo + OpenTelemetry | S1 |

# 

# \---

# 

# \## 1. Grafana Loki — Collecte des logs

# 

# \### Présentation

# 

# \*\*Grafana Loki\*\* est un système d'agrégation de logs conçu pour être économique en ressources. Contrairement à Elasticsearch, Loki n'indexe pas le contenu des logs mais uniquement leurs \*\*labels\*\* (métadonnées), ce qui réduit considérablement la consommation mémoire et disque.

# 

# Loki stocke les logs en blocs compressés sur le système de fichiers local (`/loki/chunks`). Ce stockage est monté comme volume Docker persistant sur MonSrv, garantissant que les logs survivent aux redémarrages des conteneurs.

# 

# \### Configuration Loki (`loki-config.yaml`)

# 

# ```yaml

# auth\_enabled: false

# 

# server:

# &#x20; http\_listen\_port: 3100

# 

# common:

# &#x20; path\_prefix: /loki

# &#x20; storage:

# &#x20;   filesystem:

# &#x20;     chunks\_directory: /loki/chunks

# &#x20;     rules\_directory: /loki/rules

# &#x20; replication\_factor: 1

# &#x20; ring:

# &#x20;   instance\_addr: 127.0.0.1

# &#x20;   kvstore:

# &#x20;     store: inmemory

# 

# schema\_config:

# &#x20; configs:

# &#x20;   - from: 2020-10-24

# &#x20;     store: tsdb

# &#x20;     object\_store: filesystem

# &#x20;     schema: v13

# &#x20;     index:

# &#x20;       prefix: index\_

# &#x20;       period: 24h

# 

# limits\_config:

# &#x20; allow\_structured\_metadata: false

# &#x20; reject\_old\_samples: false

# &#x20; creation\_grace\_period: 3h

# ```

# 

# > \*\*Note :\*\* Le paramètre `creation\_grace\_period: 3h` tolère un léger décalage horaire entre les agents Alloy et le serveur Loki, évitant le rejet des logs dont le timestamp est légèrement en avance par rapport à l'horloge de Loki.

# 

# \### Rétention des logs — Choix de configuration

# 

# Dans ce lab, la rétention des logs est gérée par la durée de vie des blocs Loki. Deux paramètres clés sont configurés selon le contexte :

# 

# \*\*En environnement de lab :\*\* les logs sont conservés \*\*12 heures\*\*. Ce choix est délibéré — le lab génère un volume de logs continu (Apache, MySQL, Nginx, SSH, système) qui s'accumule rapidement. Une rétention courte évite de saturer le disque de MonSrv qui dispose d'un espace limité dans l'environnement virtualisé.

# 

# \*\*En production chez ACCENT :\*\* la rétention serait configurée à \*\*7 jours minimum\*\*, voire 30 jours pour les logs de sécurité (SSH, système). Loki supporte nativement cette configuration via son compacteur :

# 

# ```yaml

# limits\_config:

# &#x20; retention\_period: 720h   # 30 jours

# 

# compactor:

# &#x20; working\_directory: /loki/compactor

# &#x20; retention\_enabled: true

# &#x20; retention\_delete\_delay: 2h

# &#x20; delete\_request\_store: filesystem

# ```

# 

# Avec un stockage objet (S3, MinIO), Loki peut conserver des mois ou des années de logs sans contrainte de disque local — c'est l'architecture recommandée pour ACCENT.

# 

# \---

# 

# \## 2. Grafana Tempo — Collecte des traces

# 

# \### Présentation

# 

# \*\*Grafana Tempo\*\* est un backend de traces distribué compatible avec les protocoles \*\*OpenTelemetry\*\*, Jaeger et Zipkin. Il stocke les traces sous forme de blocs compressés sur le système de fichiers local ou dans un stockage objet.

# 

# \### Configuration Tempo (`tempo.yaml`)

# 

# ```yaml

# server:

# &#x20; http\_listen\_port: 3200

# 

# distributor:

# &#x20; receivers:

# &#x20;   otlp:

# &#x20;     protocols:

# &#x20;       grpc:

# &#x20;         endpoint: 0.0.0.0:4317

# &#x20;       http:

# &#x20;         endpoint: 0.0.0.0:4318

# 

# storage:

# &#x20; trace:

# &#x20;   backend: local

# &#x20;   local:

# &#x20;     path: /tmp/tempo/blocks

# 

# compactor:

# &#x20; compaction:

# &#x20;   block\_retention: 12h

# ```

# 

# Tempo écoute sur deux protocoles OTLP :

# 

# \- \*\*gRPC\*\* sur le port \*\*4317\*\* — utilisé par l'OTel Collector de S1

# \- \*\*HTTP\*\* sur le port \*\*4318\*\* — alternative HTTP/protobuf

# 

# > \*\*Rétention :\*\* La rétention des traces est fixée à \*\*12 heures\*\* dans ce lab pour les mêmes raisons que Loki — économie d'espace disque. En production, une rétention de \*\*7 jours\*\* minimum serait appliquée, avec un stockage objet pour les traces long terme.

# 

# > \*\*Note technique :\*\* La version `grafana/tempo:2.3.0` est utilisée à la place de `latest`. Les versions récentes de Tempo requièrent une architecture AMD64 v2 (AVX2), incompatible avec l'environnement de virtualisation imbriquée (EVE-NG → Proxmox → VM). La version 2.3.0 est la dernière compatible avec ce contexte.

# 

# \---

# 

# \## 3. Grafana Alloy — Agent de collecte des logs

# 

# \### Présentation

# 

# \*\*Grafana Alloy\*\* est l'agent de collecte de logs et de métriques de nouvelle génération de Grafana Labs. Il remplace Promtail et Grafana Agent avec une configuration unifiée en langage \*\*River\*\* (`.alloy`).

# 

# Alloy est déployé sur \*\*S1 et S2\*\* pour collecter :

# 

# \- Les journaux \*\*systemd\*\* (SSH, système)

# \- Les fichiers de logs des services (Apache, MySQL sur S1 ; Nginx sur S2)

# 

# \### Configuration Alloy S1 (`config.alloy`)

# 

# ```hcl

# loki.write "default" {

# &#x20; endpoint {

# &#x20;   url = "http://192.168.50.10:3100/loki/api/v1/push"

# &#x20; }

# &#x20; external\_labels = {}

# }

# 

# loki.source.journal "ssh\_logs" {

# &#x20; max\_age = "168h"

# &#x20; matches = "\_SYSTEMD\_UNIT=ssh.service"

# &#x20; labels = {

# &#x20;   job      = "ssh",

# &#x20;   hostname = "server1",

# &#x20; }

# &#x20; forward\_to = \[loki.write.default.receiver]

# }

# 

# loki.source.journal "system\_logs" {

# &#x20; max\_age = "168h"

# &#x20; labels = {

# &#x20;   job      = "system",

# &#x20;   hostname = "server1",

# &#x20; }

# &#x20; forward\_to = \[loki.write.default.receiver]

# }

# 

# loki.source.file "apache\_logs" {

# &#x20; targets = \[

# &#x20;   {\_\_path\_\_ = "/var/log/apache2/access\_log", job = "apache", hostname = "server1", type = "access"},

# &#x20;   {\_\_path\_\_ = "/var/log/apache2/error\_log",  job = "apache", hostname = "server1", type = "error"},

# &#x20; ]

# &#x20; forward\_to = \[loki.write.default.receiver]

# }

# 

# loki.source.file "mysql\_logs" {

# &#x20; targets = \[

# &#x20;   {\_\_path\_\_ = "/var/log/mysql/general.log", job = "mysql", hostname = "server1", type = "general"},

# &#x20;   {\_\_path\_\_ = "/var/log/mysql/error.log",   job = "mysql", hostname = "server1", type = "error"},

# &#x20; ]

# &#x20; forward\_to = \[loki.write.default.receiver]

# }

# ```

# 

# \### Configuration Alloy S2 (`config.alloy`)

# 

# ```hcl

# loki.write "default" {

# &#x20; endpoint {

# &#x20;   url = "http://192.168.50.10:3100/loki/api/v1/push"

# &#x20; }

# &#x20; external\_labels = {}

# }

# 

# loki.source.journal "ssh\_logs" {

# &#x20; max\_age = "168h"

# &#x20; matches = "\_SYSTEMD\_UNIT=ssh.service"

# &#x20; labels = {

# &#x20;   job      = "ssh",

# &#x20;   hostname = "server2",

# &#x20; }

# &#x20; forward\_to = \[loki.write.default.receiver]

# }

# 

# loki.source.journal "system\_logs" {

# &#x20; max\_age = "168h"

# &#x20; labels = {

# &#x20;   job      = "system",

# &#x20;   hostname = "server2",

# &#x20; }

# &#x20; forward\_to = \[loki.write.default.receiver]

# }

# 

# loki.source.file "nginx\_logs" {

# &#x20; targets = \[

# &#x20;   {\_\_path\_\_ = "/var/log/nginx/access.log", job = "nginx", hostname = "server2", type = "access"},

# &#x20;   {\_\_path\_\_ = "/var/log/nginx/error.log",  job = "nginx", hostname = "server2", type = "error"},

# &#x20; ]

# &#x20; forward\_to = \[loki.write.default.receiver]

# }

# ```

# 

# \### Labels utilisés

# 

# Chaque stream de logs dans Loki est identifié par ses labels :

# 

# | Label | Valeurs possibles | Description |

# |-------|-------------------|-------------|

# | `job` | apache, mysql, nginx, ssh, system | Type de service |

# | `hostname` | server1, server2 | Serveur source |

# | `type` | access, error, general | Type de log |

# 

# \---

# 

# \## 4. Persistance des logs — Conception de la résilience

# 

# \### Persistance sur MonSrv

# 

# Les données Loki sont stockées dans un répertoire local monté comme volume Docker :

# 

# ```yaml

# loki:

# &#x20; volumes:

# &#x20;   - ./loki-data:/loki

# ```

# 

# Ce répertoire survit aux redémarrages du conteneur Loki et aux redémarrages de MonSrv. Les logs ingérés restent disponibles dans Grafana même après un arrêt complet du lab.

# 

# Les permissions sont définies explicitement pour garantir l'écriture sans droits root :

# 

# ```bash

# chown -R 10001:10001 \~/monitoring-stack/loki-data

# ```

# 

# \### Résilience côté agents — Le rôle du paramètre `max\_age`

# 

# Le paramètre `max\_age = "168h"` configuré sur les sources journal d'Alloy est le mécanisme clé de résilience. Il définit jusqu'où dans le passé Alloy doit relire les journaux systemd au démarrage.

# 

# \*\*Scénario typique sans `max\_age` :\*\* Si S1 s'arrête pendant 6 heures (maintenance, panne), au redémarrage Alloy ne renvoie que les nouvelles entrées. Les 6 heures de logs SSH et système pendant la panne sont perdues dans Loki.

# 

# \*\*Avec `max\_age = "168h"` :\*\* Au redémarrage d'Alloy, le système relit les journaux systemd des 7 derniers jours et renvoie tout ce qui n'a pas encore été ingéré par Loki. La continuité des logs est garantie même après une interruption prolongée d'un serveur.

# 

# Ce mécanisme couvre également le cas où \*\*MonSrv lui-même redémarre\*\* : Alloy continue de stocker les logs localement dans son buffer et les renvoie dès que Loki est de nouveau disponible.

# 

# \### Positions files — Suivi de lecture des fichiers

# 

# Pour les sources fichiers (Apache, MySQL, Nginx), Alloy maintient des \*\*fichiers de positions\*\* (`positions.yml`) qui enregistrent la dernière position de lecture dans chaque fichier log. Ces fichiers sont stockés dans un volume persistant :

# 

# ```yaml

# alloy:

# &#x20; volumes:

# &#x20;   - alloy\_data:/data-alloy

# ```

# 

# Grâce à ces positions files, Alloy reprend exactement là où il s'était arrêté après un redémarrage — aucun log n'est envoyé deux fois, et aucun n'est manqué.

# 

# \---

# 

# \## 5. OpenTelemetry Collector — Collecte des traces sur S1

# 

# \### Présentation

# 

# L'\*\*OpenTelemetry Collector\*\* est déployé sur S1 pour recevoir les traces générées par les services applicatifs et les transmettre à Tempo sur MonSrv.

# 

# \### Configuration OTel Collector (`otel-collector.yml`)

# 

# ```yaml

# receivers:

# &#x20; otlp:

# &#x20;   protocols:

# &#x20;     grpc:

# &#x20;       endpoint: 0.0.0.0:4317

# &#x20;     http:

# &#x20;       endpoint: 0.0.0.0:4318

# 

# processors:

# &#x20; batch:

# 

# exporters:

# &#x20; otlp\_grpc/tempo:

# &#x20;   endpoint: "192.168.50.10:4317"

# &#x20;   tls:

# &#x20;     insecure: true

# &#x20; otlp\_http/loki:

# &#x20;   endpoint: "http://192.168.50.10:3100/otlp"

# 

# service:

# &#x20; pipelines:

# &#x20;   traces:

# &#x20;     receivers: \[otlp]

# &#x20;     processors: \[batch]

# &#x20;     exporters: \[otlp\_grpc/tempo]

# &#x20;   logs:

# &#x20;     receivers: \[otlp]

# &#x20;     processors: \[batch]

# &#x20;     exporters: \[otlp\_http/loki]

# ```

# 

# \---

# 

# \## 6. Générateurs de traces

# 

# Pour simuler une activité applicative réaliste et démontrer les capacités de tracing, deux \*\*générateurs de traces\*\* sont déployés sur S1 :

# 

# \### Apache Trace Generator

# 

# Ce générateur surveille les logs d'accès Apache en temps réel et crée une trace OpenTelemetry pour chaque requête HTTP détectée. La trace inclut :

# 

# \- La méthode HTTP (GET, POST...)

# \- L'URL demandée

# \- Le code de réponse HTTP

# \- La durée de traitement

# 

# \### MySQL Trace Generator

# 

# Ce générateur intercepte les requêtes MySQL dans le general log et crée des traces pour chaque opération de base de données, permettant de visualiser les requêtes SQL dans Grafana Tempo.

# 

# Les traces sont envoyées au format \*\*OTLP gRPC\*\* vers l'OTel Collector local, qui les relaie ensuite à Tempo.

# 

# \---

# 

# \## 7. Stack Docker Compose sur S1

# 

# ```yaml

# services:

# &#x20; alloy:

# &#x20;   image: grafana/alloy:latest

# &#x20;   container\_name: alloy

# &#x20;   volumes:

# &#x20;     - ./config.alloy:/etc/alloy/config.alloy

# &#x20;     - /var/log:/var/log:ro

# &#x20;     - /run/log/journal:/run/log/journal:ro

# &#x20;     - /etc/machine-id:/etc/machine-id:ro

# &#x20;     - alloy\_data:/data-alloy

# &#x20;   command: run /etc/alloy/config.alloy

# &#x20;   restart: unless-stopped

# 

# &#x20; node-exporter:

# &#x20;   image: prom/node-exporter:latest

# &#x20;   container\_name: node-exporter

# &#x20;   network\_mode: host

# &#x20;   pid: host

# &#x20;   volumes:

# &#x20;     - /proc:/host/proc:ro

# &#x20;     - /sys:/host/sys:ro

# &#x20;     - /:/rootfs:ro

# &#x20;   command:

# &#x20;     - '--path.procfs=/host/proc'

# &#x20;     - '--path.sysfs=/host/sys'

# &#x20;     - '--path.rootfs=/rootfs'

# &#x20;   restart: unless-stopped

# 

# &#x20; apache:

# &#x20;   image: httpd:latest

# &#x20;   container\_name: apache

# &#x20;   ports:

# &#x20;     - "8080:80"

# &#x20;   volumes:

# &#x20;     - ./apache-logs:/usr/local/apache2/logs

# &#x20;   restart: unless-stopped

# 

# &#x20; mysql:

# &#x20;   image: mysql:8

# &#x20;   container\_name: mysql

# &#x20;   environment:

# &#x20;     MYSQL\_ROOT\_PASSWORD: <REDACTED>

# &#x20;     MYSQL\_DATABASE: testdb

# &#x20;   volumes:

# &#x20;     - ./mysql-logs:/var/log/mysql

# &#x20;     - ./mysql.conf:/etc/mysql/conf.d/logging.conf

# &#x20;   restart: unless-stopped

# 

# &#x20; otel-collector:

# &#x20;   image: otel/opentelemetry-collector-contrib:latest

# &#x20;   container\_name: otel-collector

# &#x20;   volumes:

# &#x20;     - ./otel-collector.yml:/etc/otel-collector.yml

# &#x20;   command: --config=/etc/otel-collector.yml

# &#x20;   restart: unless-stopped

# 

# &#x20; apache-trace-generator:

# &#x20;   image: pfe/trace-generator:latest

# &#x20;   container\_name: apache-trace-generator

# &#x20;   command: python -u /app/apache\_generator.py

# &#x20;   volumes:

# &#x20;     - ./apache-logs:/var/log/apache2:ro

# &#x20;   restart: unless-stopped

# 

# &#x20; mysql-trace-generator:

# &#x20;   image: pfe/trace-generator:latest

# &#x20;   container\_name: mysql-trace-generator

# &#x20;   command: python -u /app/mysql\_generator.py

# &#x20;   volumes:

# &#x20;     - ./mysql-logs:/var/log/mysql:ro

# &#x20;   restart: unless-stopped

# 

# volumes:

# &#x20; alloy\_data:

# ```

# 

# \---

# 

# \## 8. Vérification de la collecte

# 

# \### Vérification des labels Loki

# 

# ```bash

# curl -s "http://192.168.50.10:3100/loki/api/v1/labels" | python3 -m json.tool

# ```

# 

# Résultat attendu :

# 

# ```json

# {

# &#x20; "status": "success",

# &#x20; "data": \["filename", "hostname", "job", "service\_name", "type"]

# }

# ```

# 

# \### Vérification des jobs actifs

# 

# ```bash

# curl -s "http://192.168.50.10:3100/loki/api/v1/label/job/values" | python3 -m json.tool

# ```

# 

# Résultat attendu :

# 

# ```json

# {

# &#x20; "status": "success",

# &#x20; "data": \["apache", "mysql", "nginx", "ssh", "system"]

# }

# ```

# 

# \### Vérification des traces dans Tempo

# 

# ```bash

# curl -s "http://192.168.50.10:3200/api/search?limit=5" | python3 -m json.tool | grep "rootServiceName"

# ```

# 

# Résultat attendu :

# 

# ```

# "rootServiceName": "apache"

# "rootServiceName": "mysql"

# ```

# 

# \---

# 

# \## Résultat

# 

# À l'issue de ce sprint, la collecte des logs et des traces est opérationnelle :

# 

# | Source | Logs collectés | Statut |

# |--------|----------------|--------|

# | S1 | Apache access/error, MySQL, SSH, System | ✅ |

# | S2 | Nginx access/error, SSH, System | ✅ |

# | S1 | Traces Apache (HTTP requests) | ✅ |

# | S1 | Traces MySQL (SQL queries) | ✅ |

# 

# La stack d'observabilité complète (\*\*métriques + logs + traces\*\*) est fonctionnelle et accessible via Grafana sur MonSrv.

# 

# \---

# 

# \## Captures d'Écran

# 

# Les captures d'écran pour ce sprint sont à compléter ultérieurement avec :

# 

# \- Loki Labels disponibles

# \- Loki Jobs actifs

# \- Grafana Explore — Logs Apache S1

# \- Grafana Explore — Logs SSH S2

# \- Dashboard Logs S1 et S2

# \- Tempo Traces disponibles

# \- Dashboard Traces

# \- Trace détaillée dans Grafana Explore

# \- Alloy logs de démarrage S1

# \- Volumes persistants MonSrv

# 

# \---

# 

# 

