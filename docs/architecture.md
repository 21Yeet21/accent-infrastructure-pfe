

\# Architecture Globale — ACCENT



Document décrivant l'architecture complète de l'infrastructure ACCENT, des couches de virtualisation jusqu'à la haute disponibilité.



\---



\## Vue d'Ensemble



L'infrastructure ACCENT est conçue selon une approche en couches successives. Chaque couche repose sur les fondations posées par la précédente, garantissant une progression logique du déploiement et facilitant le diagnostic en cas de problème.



L'ensemble du projet a été développé en mode lab, dans un environnement EVE-NG virtualisé, ce qui permet de reproduire fidèlement une infrastructure d'entreprise tout en conservant la flexibilité de tests et d'itérations.



\---



\## Couche 1 — Virtualisation



Trois niveaux de virtualisation se superposent pour permettre la simulation complète de l'environnement cible.



| Composant | Rôle |

|-----------|------|

| VMware Workstation | Hyperviseur hôte exécuté sur la machine physique |

| EVE-NG 6.2.0 | Simulateur réseau exploitant la virtualisation imbriquée |

| Proxmox VE 7.4 | Hyperviseur dédié aux VMs critiques du projet |



Le choix d'EVE-NG plutôt que GNS3 ou Packet Tracer s'explique par sa gestion fiable de la virtualisation imbriquée, indispensable pour exécuter une instance Proxmox à l'intérieur du lab.



\---



\## Couche 2 — Réseau



\### Topologie



La topologie repose sur un routeur de bordure (ISP-R1), un switch de cœur (SW1) et trois équipements connectés en aval (pve1, S1, S2). Le trafic sortant transite par ISP-R1 vers Internet via NAT.



\### Plan VLAN (VLSM)



| VLAN | Nom | Sous-réseau | Usage |

|------|-----|-------------|-------|

| 10 | CLIENTS | 192.168.10.0/24 | Postes utilisateurs et clients DHCP |

| 20 | MANAGEMENT | 192.168.20.0/27 | Administration et supervision |

| 50 | DMZ | 192.168.50.0/26 | Services exposés et serveurs applicatifs |

| 70 | VPN | 192.168.70.0/28 | Tunnel OpenVPN pour accès distant |

| 99 | NATIVE | — | Protection anti-VLAN-hopping |



La segmentation Layer 2 constitue la première barrière de sécurité du projet, sur laquelle pfSense viendra ensuite appliquer ses règles Layer 3.



\---



\## Couche 3 — Sécurité



Trois services de sécurité interviennent à des niveaux différents pour assurer une protection multicouche.



| Composant | Rôle | VLAN |

|-----------|------|------|

| pfSense CE 2.7.2 | Pare-feu, routeur inter-VLAN, NAT, DHCP | Toutes |

| Suricata | Détection et prévention d'intrusion réseau | LAN, CLIENTS, DMZ |

| OpenVPN | Accès distant chiffré (split tunnel) | VLAN70 |

| Wazuh 4.11.2 | HIDS et SIEM sur les endpoints | VLAN20 |



Le pare-feu applique une politique deny-by-default : tout trafic est bloqué tant qu'il n'est pas explicitement autorisé. Suricata complète ce dispositif en analysant le contenu du trafic, tandis que Wazuh surveille directement les hôtes.



\---



\## Couche 4 — Observabilité



L'observabilité est structurée selon les trois piliers reconnus du domaine.



\### Métriques



Prometheus interroge périodiquement les exporters déployés sur chaque cible, avec un intervalle de scrape de 15 secondes et une rétention de 15 jours.



| Cible | Exporter | Port |

|-------|----------|------|

| S1 | Node Exporter | 9100 |

| S2 | Node Exporter | 9100 |

| pve1 | Node Exporter | 9100 |

| S2 | Redis Exporter | 9121 |



\### Logs



Grafana Alloy collecte les logs applicatifs et système sur les serveurs S1 et S2, puis les envoie vers Loki avec une labellisation hostname/job/type. La rétention est configurée à 12 heures en lab et 30 jours en production.



\### Traces



Le collecteur OpenTelemetry capture les traces distribuées des applications Apache et MySQL sur S1, sans modification intrusive du code. Les traces sont transmises à Tempo via gRPC sur le port 4317.



\---



\## Couche 5 — Visualisation et Alerting



\### Dashboards Grafana



Sept dashboards couvrent l'ensemble de l'infrastructure :



1\. Overview consolidée (S1, S2, pve1)

2\. Metrics détaillés S1

3\. Metrics détaillés S2

4\. Logs S1 (Apache, MySQL, SSH)

5\. Logs S2 (Nginx, SSH)

6\. Traces Apache et MySQL

7\. Redis Cache et performance



Les datasources Prometheus, Loki et Tempo utilisent des UIDs fixés pour garantir la portabilité des dashboards.



\### Règles d'Alerte



Dix-sept règles évaluées toutes les 60 secondes couvrent quatre périmètres distincts.



| Catégorie | Nombre | Exemples |

|-----------|--------|----------|

| S1 | 4 | CPU > 85%, RAM > 85%, Disk > 90%, Indisponibilité |

| S2 | 5 | Identiques à S1 plus monitoring Redis |

| pve1 | 4 | CPU > 90%, RAM > 90%, Disk > 85%, Indisponibilité |

| Sécurité | 4 | Brute force SSH (x2), Erreurs HTTP 500 (x2) |



\### Intégrations



Les alertes sont envoyées vers le canal Slack `#accent-alerts` via un webhook entrant. Le délai de notification observé est inférieur à 2 minutes, avec résolution automatique lorsque la condition d'alerte disparaît.



\---



\## Couche 6 — Haute Disponibilité



La dernière phase du projet valide une preuve de concept de haute disponibilité reposant sur trois technologies complémentaires.



| Technologie | Rôle |

|-------------|------|

| Corosync | Communication inter-nœuds et gestion du quorum |

| Ceph | Stockage distribué et répliqué (3x) |

| HA Manager | Orchestration du basculement automatique |



\### Tests Validés



Deux scénarios ont été testés et validés sur le cluster pfe-cluster (pve1, pve2, pve3) :



1\. \*\*Migration manuelle\*\* : VM 101 (pfSense) déplacée de pve1 vers pve2 sans interruption de service.

2\. \*\*Basculement automatique\*\* : pve1 mis hors tension brutalement, VM 101 redémarrée automatiquement sur pve3 en moins de 4 minutes, avec reconstruction Ceph en 33 PGs active+clean.



Ces tests confirment la viabilité d'une évolution vers une disponibilité de 99.9% pour l'ensemble de l'infrastructure ACCENT.



\---



\## Flux de Données



L'architecture peut se résumer ainsi en termes de flux :



\- \*\*Trafic réseau\*\* : Clients → SW1 → pfSense → DMZ/Internet (avec inspection Suricata)

\- \*\*Métriques\*\* : Exporters → Prometheus → Grafana

\- \*\*Logs\*\* : Sources → Alloy → Loki → Grafana

\- \*\*Traces\*\* : Applications → OTel Collector → Tempo → Grafana

\- \*\*Alertes\*\* : Grafana → Webhook → Slack #accent-alerts

\- \*\*Sécurité endpoint\*\* : Agents Wazuh → Manager Wazuh → Dashboard et Slack

\- \*\*HA\*\* : Corosync + Ceph + HA Manager → Basculement automatique des VMs

