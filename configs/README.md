# 

# \# Configurations ACCENT

# 

# Ce répertoire centralise l'ensemble des fichiers de configuration des composants déployés dans l'infrastructure ACCENT. Chaque sous-dossier correspond à un service ou une couche spécifique, facilitant ainsi le déploiement, la maintenance et la reproductibilité de l'environnement.

# 

# \*\*Avertissement de sécurité\*\* : Ce dépôt ne doit contenir aucune donnée sensible (mots de passe, clés privées, certificats, webhooks, tokens). Consultez le fichier `.gitignore` à la racine pour la liste exhaustive des exclusions.

# 

# \---

# 

# \## Structure du répertoire

# 

# | Dossier | Contenu |

# |---------|---------|

# | `eve-ng/` | Templates QEMU YAML et configurations Cisco (ISP-R1, SW1) |

# | `proxmox/` | Configuration réseau de l'hyperviseur pve1 (`/etc/network/interfaces`) |

# | `pfsense/` | Configuration pfSense : règles firewall, NAT, VLANs, OpenVPN |

# | `prometheus/` | `prometheus.yml` et règles d'alerte infrastructure (`alert-rules.yml`) |

# | `grafana/` | Dashboards JSON et provisioning (datasources, alerting) |

# | `loki/` | `loki-config.yaml` — serveur d'agrégation de logs |

# | `tempo/` | `tempo.yaml` — backend de traces distribuées |

# | `alloy/` | Configurations Grafana Alloy pour S1 et S2 (collecte de logs) |

# | `otel/` | Configuration OpenTelemetry Collector (traces applicatives S1) |

# | `wazuh/` | Configurations agents et manager (intégration Slack) |

# | `docker-compose/` | Fichiers `docker-compose.yml` organisés par hôte ou service |

# 

# \---

# 

# \## Déploiement des configurations

# 

# \### EVE-NG (Simulation réseau)

# 

# Les templates YAML personnalisés pour S1 et S2 doivent être placés dans :

# 

# ```

# /opt/unetlab/html/templates/amd/

# /opt/unetlab/html/templates/intel/

# ```

# 

# Les configurations Cisco (ISP-R1, SW1) sont appliquées manuellement via la console de chaque nœud au démarrage du lab.

# 

# \### Proxmox VE (Hyperviseur pve1)

# 

# Appliquer la configuration réseau :

# 

# ```bash

# cp configs/proxmox/interfaces /etc/network/interfaces

# systemctl restart networking

# ```

# 

# \### pfSense (Hook VLAN Proxmox)

# 

# Le script `scripts/pfsense-vlan.sh` est un hook Proxmox qui configure automatiquement les VLANs sur l'interface LAN de pfSense après le démarrage de la VM.

# 

# \*\*Installation sur pve1 :\*\*

# 

# ```bash

# cp scripts/pfsense-vlan.sh /var/lib/vz/snippets/

# chmod 755 /var/lib/vz/snippets/pfsense-vlan.sh

# qm set 104 --hookscript local:snippets/pfsense-vlan.sh

# ```

# 

# \### Stack de supervision (MonSrv — 192.168.50.10)

# 

# Les fichiers `prometheus.yml`, `loki-config.yaml`, `tempo.yaml` ainsi que les dossiers de provisioning Grafana sont montés automatiquement via les volumes définis dans :

# 

# ```

# configs/docker-compose/monitoring-stack/docker-compose.yml

# ```

# 

# \### Agents de monitoring (S1, S2)

# 

# Les configurations Alloy et OpenTelemetry Collector sont montées en lecture seule (`:ro`) via les fichiers `docker-compose.yml` respectifs :

# 

# ```

# configs/docker-compose/s1-agents/docker-compose.yml

# configs/docker-compose/s2-agents/docker-compose.yml

# ```

# 

# \### Wazuh Agent (S1, S2, pve1)

# 

# Appliquer `configs/wazuh/agent-ossec.conf` sur chaque agent :

# 

# ```bash

# cp configs/wazuh/agent-ossec.conf /var/ossec/etc/ossec.conf

# systemctl restart wazuh-agent

# ```

# 

# \### Wazuh Manager (VM 108 — 192.168.20.24)

# 

# Ajouter le contenu de `configs/wazuh/manager-ossec.conf` à la fin du fichier `/var/ossec/etc/ossec.conf` du manager, puis redémarrer :

# 

# ```bash

# systemctl restart wazuh-manager

# ```

# 

# \*\*Note\*\* : Le webhook Slack doit être renseigné manuellement avant déploiement (remplacer `<REDACTED>` par l'URL réelle). Ne jamais commiter le webhook en clair.

# 

# \---

# 

# \## Règles de sécurité avant commit

# 

# Avant toute modification ou ajout dans ce répertoire, vérifier systématiquement :

# 

# 1\. \*\*Absence de secrets\*\* : Aucun mot de passe, clé SSH, certificat ou token d'API en clair.

# 2\. \*\*Anonymisation\*\* : Remplacer les IPs publiques, noms de domaine sensibles ou identifiants par des valeurs fictives.

# 3\. \*\*Placeholders\*\* : Utiliser `<REDACTED>` ou des variables d'environnement (ex: `${SLACK\_WEBHOOK\_URL}`) pour les valeurs sensibles.

# 

# \---

# 

