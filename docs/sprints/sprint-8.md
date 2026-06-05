Voici le Sprint 8 nettoyé, avec les références aux fichiers du dépôt et les diagrammes (activity + deployment) intégrés :

```markdown
# Sprint 8 — Wazuh HIDS : Détection d'Intrusion et Sécurité des Endpoints

## Objectif

Déployer **Wazuh 4.11.2** comme système de détection d'intrusion basé sur les hôtes (HIDS). Wazuh surveille en temps réel les serveurs S1, S2 et l'hyperviseur pve1, détecte les menaces de sécurité, assure la conformité réglementaire et envoie des alertes vers Slack pour une notification immédiate.

---

## Architecture Wazuh

```
┌─────────────────────────────────┐
│       Wazuh Server (VM 108)     │
│  192.168.20.24 — VLAN20         │
│                                 │
│  wazuh-manager  (port 1514/1515)│
│  wazuh-indexer  (OpenSearch)    │
│  wazuh-dashboard (HTTPS :443)   │
└────────────┬────────────────────┘
             │
    ┌────────┼────────────┐
    │        │            │
┌───▼──┐ ┌──▼───┐ ┌──────▼──┐
│  S1  │ │  S2  │ │  pve1   │
│agent │ │agent │ │  agent  │
│:1514 │ │:1514 │ │  :1514  │
└──────┘ └────── └─────────┘
```

| Composant | Rôle | IP |
|-----------|------|-----|
| Wazuh Server (VM 108) | Manager + Indexer + Dashboard | 192.168.20.24 |
| S1 Agent | Surveillance serveur applicatif | 192.168.50.11 |
| S2 Agent | Surveillance serveur web | 192.168.50.12 |
| pve1 Agent | Surveillance hyperviseur Proxmox | 192.168.20.11 |

---

## 1. Installation Wazuh All-in-One

Wazuh est installé comme solution **all-in-one** sur la VM 108 — le manager, l'indexer (OpenSearch) et le dashboard sont tous sur la même machine. Cette architecture convient parfaitement à un environnement de lab et de taille moyenne comme ACCENT.

### Prérequis

La VM Wazuh dispose de :

- **6 Go de RAM** — OpenSearch (basé sur Elasticsearch) est gourmand en mémoire
- **Debian 13**
- IP : **192.168.20.24/27** sur VLAN20

### Procédure d'installation

Wazuh fournit un script d'installation automatisé :

```bash
curl -sO https://packages.wazuh.com/4.11/wazuh-install.sh
bash wazuh-install.sh --all-in-one
```

> **Note :** Debian 13 n'est pas officiellement supporté par le script d'installation Wazuh. Une dépendance manquante (`software-properties-common`) cause l'échec du script. La solution est de créer un package factice via `equivs` :

```bash
apt install -y equivs
equivs-build software-properties-common-dummy.conf
dpkg -i software-properties-common_1.0_all.deb
bash wazuh-install.sh --all-in-one
```

![Installation Wazuh All-in-One](./images/Pasted%20image%2020260521060602.png)

---

## 2. Gestion des mots de passe

Après installation, les mots de passe Wazuh sont régénérés pour assurer la sécurité. Wazuh fournit un outil dédié à cet effet :

```bash
/usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh --change-all
```

![Regénération des mots de passe Wazuh](./images/Pasted%20image%2020260521062326.png)

L'outil génère de nouveaux mots de passe aléatoires pour tous les utilisateurs internes (admin, kibanaserver, logstash, etc.) et met à jour automatiquement la configuration Filebeat. Un backup des anciens utilisateurs est sauvegardé dans `/etc/wazuh-indexer/internalusers-backup/`.

> Cette procédure est également utile en cas d'oubli du mot de passe administrateur — elle permet de regénérer l'accès sans réinstallation.

---

## 3. Accès au dashboard

Le dashboard Wazuh est accessible via tunnel SSH :

```powershell
ssh -L 9444:192.168.20.24:443 root@192.168.140.141
```

Puis ouvrir https://localhost:9444 — Login : **admin / [mot de passe généré]**

![Accès au dashboard Wazuh](./images/Pasted%20image%2020260521062835.png)

---

## 4. Installation des agents Wazuh

### Agent sur S1 et S2

Les agents Wazuh sont installés sur S1 et S2 via le package Debian officiel. Le script d'installation automatisé est disponible dans le dépôt :

- **Script** : [`scripts/install-wazuh-agent.sh`](../../scripts/install-wazuh-agent.sh)

```bash
curl -so wazuh-agent.deb \
  https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.11.2-1_amd64.deb
dpkg -i wazuh-agent.deb
```

Configuration de l'agent (`/var/ossec/etc/ossec.conf`) :

La configuration de référence est disponible dans le dépôt :

- **Fichier** : [`configs/wazuh/agent-ossec.conf`](../../configs/wazuh/agent-ossec.conf)

```xml
<client>
  <server>
    <address>192.168.20.24</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
  <enrollment>
    <enabled>yes</enabled>
    <manager_address>192.168.20.24</manager_address>
    <port>1515</port>
    <agent_name>server1</agent_name>
  </enrollment>
</client>
```

```bash
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent
```

![Statut de l'agent Wazuh sur S1](./images/Pasted%20image%2020260521060848.png)

### Agent sur pve1 (Hyperviseur)

L'hyperviseur Proxmox est également surveillé par un agent Wazuh. Cela permet de monitorer l'intégrité des fichiers de configuration Proxmox, les connexions SSH sur l'hyperviseur et les vulnérabilités des packages système.

```bash
apt install -y lsb-release
curl -so wazuh-agent.deb \
  https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.11.2-1_amd64.deb
dpkg -i wazuh-agent.deb
```

---

## 5. Agents actifs dans le dashboard

Les trois agents apparaissent dans le dashboard Wazuh avec le statut **Active** :

![Liste des agents Wazuh actifs](./images/Pasted%20image%2020260521070316.png)

| ID | Nom | IP | OS | Statut |
|----|-----|----|----|--------|
| 001 | server1 | 192.168.50.11 | Ubuntu 24.04.4 LTS | ✅ Active |
| 002 | server2 | 192.168.50.12 | Ubuntu 25.10 | ✅ Active |
| 003 | pve1 | 192.168.20.11 | Debian 11 | ✅ Active |

---

## 6. Détail des agents

### Server1 — Détection de vulnérabilités

![Vulnérabilités Server1](./images/Pasted%20image%2020260521062908.png)

Wazuh effectue un inventaire complet des packages installés sur S1 et les confronte aux bases de données CVE. Les résultats révèlent :

- **4 Critical** — vulnérabilités critiques nécessitant une action immédiate
- **528 High** — vulnérabilités à traiter en priorité
- **1182 Medium** — vulnérabilités à surveiller
- **27 Low** — vulnérabilités de faible impact

Les packages les plus exposés sont les images kernel Linux (`linux-image-6.8.0-110-generic`, `linux-image-6.8.0-117-generic`) qui concentrent la majorité des CVEs.

### Server2

![Vulnérabilités Server2](./images/Pasted%20image%2020260521062931.png)

S2 présente un profil de vulnérabilités plus faible avec **1 Medium** — ce serveur dispose de moins de packages installés et d'une version OS plus récente (Ubuntu 25.10).

---

## 7. Vue d'ensemble — Dashboard principal

![Dashboard Principal](./images/Pasted%20image%2020260521073707.png)

Le dashboard principal Wazuh affiche :

- **3 agents actifs**, 0 déconnecté
- **56 alertes Medium** (niveau 7-11) sur les dernières 24h
- **196 alertes Low** (niveau 0-6) sur les dernières 24h

---

## 8. Threat Hunting — Analyse des événements S1

![Threat Hunting](./images/Pasted%20image%2020260521073745.png)

Le module Threat Hunting de Wazuh offre une vue détaillée des événements de sécurité par agent. Pour server1 sur les dernières 24h :

| Métrique | Valeur |
|----------|--------|
| Total événements | 127 |
| Alertes niveau 12+ | 0 |
| Échecs d'authentification | 45 |
| Succès d'authentification | 27 |

**Top 5 alertes :** SSH brute force, PAM login session, sudo, accès non autorisé, démarrage agent Wazuh.

**Conformité PCI DSS :** Les événements sont automatiquement mappés aux exigences PCI DSS (10.2.4, 10.2.5, 10.6.1, 10.2.2) — utile pour les audits de conformité chez ACCENT.

---

## 9. Intégration Slack — Alertes en temps réel

### Pourquoi Slack

Pour garantir une réponse rapide aux incidents de sécurité, Wazuh est configuré pour envoyer des alertes en temps réel vers un canal Slack dédié (`#accent-alerts`). Cette intégration permet aux équipes de sécurité d'être notifiées immédiatement sans avoir à consulter le dashboard manuellement.

### Configuration du webhook

Un webhook Incoming est créé dans l'application Slack `Accent-Monitoring`. Un premier test permet de valider la connectivité :

```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test from PFE Lab - Wazuh Alert System"}' \
  <REDACTED>
```

### Configuration native Wazuh

Wazuh 4.11 supporte **nativement** l'intégration Slack — aucun script custom n'est nécessaire. La configuration se fait directement dans `/var/ossec/etc/ossec.conf` :

La configuration de référence est disponible dans le dépôt :

- **Fichier** : [`configs/wazuh/manager-ossec.conf`](../../configs/wazuh/manager-ossec.conf)

```xml
<ossec_config>
  <integration>
    <name>slack</name>
    <hook_url><REDACTED></hook_url>
    <level>7</level>
    <alert_format>json</alert_format>
  </integration>
</ossec_config>
```

Le seuil est fixé à **niveau 7** — seules les alertes de sévérité moyenne et haute sont envoyées sur Slack, évitant le bruit des alertes informatives. Après modification, le manager est redémarré :

```bash
systemctl restart wazuh-manager
```

### Alertes reçues

![Alerte Slack 1](./images/Pasted%20image%2020260521072516.png)

![Alerte Slack 2](./images/Pasted%20image%2020260521072909.png)

Les alertes Slack affichent :

- **Agent source** — quel serveur a généré l'alerte
- **Règle déclenchée** — description de la menace détectée
- **Niveau de sévérité** — 1 à 15
- **Timestamp** — heure exacte de l'événement

### Test de détection — Brute Force SSH

Pour valider l'intégration, une attaque brute force SSH simulée est lancée depuis S1 vers S2. Le script de test est disponible dans le dépôt :

- **Script** : [`scripts/test-brute-force.sh`](../../scripts/test-brute-force.sh)

```bash
for i in {1..10}; do ssh wronguser@192.168.50.12 exit 2>/dev/null; done
```

Wazuh détecte immédiatement l'attaque (règle niveau 10 — **sshd: brute force**) et envoie l'alerte sur Slack en moins de 30 secondes.

---

## 10. Capacités Wazuh disponibles

Le dashboard Wazuh offre de nombreuses fonctionnalités exploitables chez ACCENT :

| Fonctionnalité | Description |
|----------------|-------------|
| **File Integrity Monitoring (FIM)** | Détecte toute modification de fichiers critiques (/etc, /bin, /sbin) |
| **Vulnerability Detection** | Inventaire CVE de tous les packages installés |
| **Rootcheck** | Détection de rootkits, anomalies système et processus cachés |
| **Threat Hunting** | Recherche avancée dans les événements de sécurité |
| **MITRE ATT&CK** | Mapping des alertes aux techniques d'attaque MITRE |
| **PCI DSS / HIPAA / GDPR / NIST** | Conformité multi-réglementaire |
| **Malware Detection** | Détection d'indicateurs de compromission |
| **Active Response** | Réponse automatique aux menaces (blocage IP, kill processus) |
| **Docker/Watermark Listener** | Surveillance des conteneurs et conteneurs |
| **SCA (Security Configuration Assessment)** | Audit de configuration selon des benchmarks CIS |

---

## Résultat

À l'issue de ce sprint, la plateforme HIDS est opérationnelle :

- **3 agents actifs** — S1, S2, pve1 — surveillés en temps réel
- **Détection de vulnérabilités** — inventaire CVE complet sur tous les agents
- **Alertes Slack** — notification immédiate pour toute alerte de niveau 7+
- **Threat Hunting** — visibilité complète sur les événements de sécurité
- **Conformité** — mapping automatique PCI DSS, HIPAA, GDPR, NIST
- **Latence de détection** — inférieure à 30 secondes entre l'événement et la notification Slack

---

## Diagrammes

### Diagramme d'Activité

![Diagramme d'activité — Sprint 8](../diagrams/activity/sprint8.png)

### Diagramme de Déploiement

![Diagramme de déploiement — Sprint 8](../diagrams/deployment/sprint8.png)

---

## Captures d'Écran de Validation

### Liste des agents actifs

![Liste des agents Wazuh actifs](./images/Pasted%20image%2020260521070316.png)

### Dashboard Principal

![Dashboard Principal](./images/Pasted%20image%2020260521073707.png)

### Détection de Vulnérabilités — Server1

![Vulnérabilités Server1](./images/Pasted%20image%2020260521062908.png)

### Détection de Vulnérabilités — Server2

![Vulnérabilités Server2](./images/Pasted%20image%2020260521062931.png)

### Threat Hunting

![Threat Hunting](./images/Pasted%20image%2020260521073745.png)

### Alertes Slack

![Alerte Slack 1](./images/Pasted%20image%2020260521072516.png)

![Alerte Slack 2](./images/Pasted%20image%2020260521072909.png)

### Règles Firewall Wazuh

Les règles pfSense autorisent les agents Wazuh à communiquer avec le serveur Wazuh via les ports TCP 1514 et TCP 1515.

![Règles Firewall Wazuh](./images/Pasted%20image%2020260522113906.png)

### Installation Wazuh All-in-One

![Installation Wazuh All-in-One](./images/Pasted%20image%2020260521060602.png)

### Regénération des mots de passe

![Regénération des mots de passe Wazuh](./images/Pasted%20image%2020260521062326.png)

### Statut de l'agent Wazuh sur S1

![Statut de l'agent Wazuh sur S1](./images/Pasted%20image%2020260521060848.png)
```

---

## Résumé des corrections

| Correction | Détail |
|------------|--------|
| 🧹 Préfixes `#` supprimés | Toutes les lignes commençaient par `# ` |
| 🔙 Backslashes retirés | `\*\*`, `\_`, `\[`, `\]`, `\#` nettoyés |
| 📐 Espaces HTML nettoyés | `&#x20;` → espaces normaux |
| 📁 Références aux fichiers du dépôt | Scripts install-wazuh-agent.sh, test-brute-force.sh, configs/wazuh/ |
| 📊 Diagrammes ajoutés | activity/sprint8.png + **deployment/sprint8.png** (au lieu de components) |
| 🔐 Secrets mentionnés | Webhook Slack = `<REDACTED>` |

Tu peux maintenant copier-coller ce contenu dans `docs/sprints/sprint-8.md`. Dis-moi "done" et on passe au Sprint 9 (le dernier) !
# Sprint 8 — Wazuh HIDS : Détection d'Intrusion et Sécurité des Endpoints

## Objectif

Déployer **Wazuh 4.11.2** comme système de détection d'intrusion basé sur les hôtes (HIDS). Wazuh surveille en temps réel les serveurs S1, S2 et l'hyperviseur pve1, détecte les menaces de sécurité, assure la conformité réglementaire et envoie des alertes vers Slack pour une notification immédiate.

---

## Architecture Wazuh

```
┌─────────────────────────────────┐
│       Wazuh Server (VM 108)     │
│  192.168.20.24 — VLAN20         │
│                                 │
│  wazuh-manager  (port 1514/1515)│
│  wazuh-indexer  (OpenSearch)    │
│  wazuh-dashboard (HTTPS :443)   │
└────────────┬────────────────────┘
             │
    ┌────────┼────────────┐
    │        │            │
┌───▼──┐ ┌──▼───┐ ┌──────▼──┐
│  S1  │ │  S2  │ │  pve1   │
│agent │ │agent │ │  agent  │
│:1514 │ │:1514 │ │  :1514  │
└──────┘ └────── └─────────┘
```

| Composant | Rôle | IP |
|-----------|------|-----|
| Wazuh Server (VM 108) | Manager + Indexer + Dashboard | 192.168.20.24 |
| S1 Agent | Surveillance serveur applicatif | 192.168.50.11 |
| S2 Agent | Surveillance serveur web | 192.168.50.12 |
| pve1 Agent | Surveillance hyperviseur Proxmox | 192.168.20.11 |

---

## 1. Installation Wazuh All-in-One

Wazuh est installé comme solution **all-in-one** sur la VM 108 — le manager, l'indexer (OpenSearch) et le dashboard sont tous sur la même machine. Cette architecture convient parfaitement à un environnement de lab et de taille moyenne comme ACCENT.

### Prérequis

La VM Wazuh dispose de :

- **6 Go de RAM** — OpenSearch (basé sur Elasticsearch) est gourmand en mémoire
- **Debian 13**
- IP : **192.168.20.24/27** sur VLAN20

### Procédure d'installation

Wazuh fournit un script d'installation automatisé :

```bash
curl -sO https://packages.wazuh.com/4.11/wazuh-install.sh
bash wazuh-install.sh --all-in-one
```

> **Note :** Debian 13 n'est pas officiellement supporté par le script d'installation Wazuh. Une dépendance manquante (`software-properties-common`) cause l'échec du script. La solution est de créer un package factice via `equivs` :

```bash
apt install -y equivs
equivs-build software-properties-common-dummy.conf
dpkg -i software-properties-common_1.0_all.deb
bash wazuh-install.sh --all-in-one
```

![Installation Wazuh All-in-One](./images/Pasted%20image%2020260521060602.png)

---

## 2. Gestion des mots de passe

Après installation, les mots de passe Wazuh sont régénérés pour assurer la sécurité. Wazuh fournit un outil dédié à cet effet :

```bash
/usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh --change-all
```

![Regénération des mots de passe Wazuh](./images/Pasted%20image%2020260521062326.png)

L'outil génère de nouveaux mots de passe aléatoires pour tous les utilisateurs internes (admin, kibanaserver, logstash, etc.) et met à jour automatiquement la configuration Filebeat. Un backup des anciens utilisateurs est sauvegardé dans `/etc/wazuh-indexer/internalusers-backup/`.

> Cette procédure est également utile en cas d'oubli du mot de passe administrateur — elle permet de regénérer l'accès sans réinstallation.

---

## 3. Accès au dashboard

Le dashboard Wazuh est accessible via tunnel SSH :

```powershell
ssh -L 9444:192.168.20.24:443 root@192.168.140.141
```

Puis ouvrir https://localhost:9444 — Login : **admin / [mot de passe généré]**

![Accès au dashboard Wazuh](./images/Pasted%20image%2020260521062835.png)

---

## 4. Installation des agents Wazuh

### Agent sur S1 et S2

Les agents Wazuh sont installés sur S1 et S2 via le package Debian officiel. Le script d'installation automatisé est disponible dans le dépôt :

- **Script** : [`scripts/install-wazuh-agent.sh`](../../scripts/install-wazuh-agent.sh)

```bash
curl -so wazuh-agent.deb \
  https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.11.2-1_amd64.deb
dpkg -i wazuh-agent.deb
```

Configuration de l'agent (`/var/ossec/etc/ossec.conf`) :

La configuration de référence est disponible dans le dépôt :

- **Fichier** : [`configs/wazuh/agent-ossec.conf`](../../configs/wazuh/agent-ossec.conf)

```xml
<client>
  <server>
    <address>192.168.20.24</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
  <enrollment>
    <enabled>yes</enabled>
    <manager_address>192.168.20.24</manager_address>
    <port>1515</port>
    <agent_name>server1</agent_name>
  </enrollment>
</client>
```

```bash
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent
```

![Statut de l'agent Wazuh sur S1](./images/Pasted%20image%2020260521060848.png)

### Agent sur pve1 (Hyperviseur)

L'hyperviseur Proxmox est également surveillé par un agent Wazuh. Cela permet de monitorer l'intégrité des fichiers de configuration Proxmox, les connexions SSH sur l'hyperviseur et les vulnérabilités des packages système.

```bash
apt install -y lsb-release
curl -so wazuh-agent.deb \
  https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.11.2-1_amd64.deb
dpkg -i wazuh-agent.deb
```

---

## 5. Agents actifs dans le dashboard

Les trois agents apparaissent dans le dashboard Wazuh avec le statut **Active** :

![Liste des agents Wazuh actifs](./images/Pasted%20image%2020260521070316.png)

| ID | Nom | IP | OS | Statut |
|----|-----|----|----|--------|
| 001 | server1 | 192.168.50.11 | Ubuntu 24.04.4 LTS | ✅ Active |
| 002 | server2 | 192.168.50.12 | Ubuntu 25.10 | ✅ Active |
| 003 | pve1 | 192.168.20.11 | Debian 11 | ✅ Active |

---

## 6. Détail des agents

### Server1 — Détection de vulnérabilités

![Vulnérabilités Server1](./images/Pasted%20image%2020260521062908.png)

Wazuh effectue un inventaire complet des packages installés sur S1 et les confronte aux bases de données CVE. Les résultats révèlent :

- **4 Critical** — vulnérabilités critiques nécessitant une action immédiate
- **528 High** — vulnérabilités à traiter en priorité
- **1182 Medium** — vulnérabilités à surveiller
- **27 Low** — vulnérabilités de faible impact

Les packages les plus exposés sont les images kernel Linux (`linux-image-6.8.0-110-generic`, `linux-image-6.8.0-117-generic`) qui concentrent la majorité des CVEs.

### Server2

![Vulnérabilités Server2](./images/Pasted%20image%2020260521062931.png)

S2 présente un profil de vulnérabilités plus faible avec **1 Medium** — ce serveur dispose de moins de packages installés et d'une version OS plus récente (Ubuntu 25.10).

---

## 7. Vue d'ensemble — Dashboard principal

![Dashboard Principal](./images/Pasted%20image%2020260521073707.png)

Le dashboard principal Wazuh affiche :

- **3 agents actifs**, 0 déconnecté
- **56 alertes Medium** (niveau 7-11) sur les dernières 24h
- **196 alertes Low** (niveau 0-6) sur les dernières 24h

---

## 8. Threat Hunting — Analyse des événements S1

![Threat Hunting](./images/Pasted%20image%2020260521073745.png)

Le module Threat Hunting de Wazuh offre une vue détaillée des événements de sécurité par agent. Pour server1 sur les dernières 24h :

| Métrique | Valeur |
|----------|--------|
| Total événements | 127 |
| Alertes niveau 12+ | 0 |
| Échecs d'authentification | 45 |
| Succès d'authentification | 27 |

**Top 5 alertes :** SSH brute force, PAM login session, sudo, accès non autorisé, démarrage agent Wazuh.

**Conformité PCI DSS :** Les événements sont automatiquement mappés aux exigences PCI DSS (10.2.4, 10.2.5, 10.6.1, 10.2.2) — utile pour les audits de conformité chez ACCENT.

---

## 9. Intégration Slack — Alertes en temps réel

### Pourquoi Slack

Pour garantir une réponse rapide aux incidents de sécurité, Wazuh est configuré pour envoyer des alertes en temps réel vers un canal Slack dédié (`#accent-alerts`). Cette intégration permet aux équipes de sécurité d'être notifiées immédiatement sans avoir à consulter le dashboard manuellement.

### Configuration du webhook

Un webhook Incoming est créé dans l'application Slack `Accent-Monitoring`. Un premier test permet de valider la connectivité :

```bash
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test from PFE Lab - Wazuh Alert System"}' \
  <REDACTED>
```

### Configuration native Wazuh

Wazuh 4.11 supporte **nativement** l'intégration Slack — aucun script custom n'est nécessaire. La configuration se fait directement dans `/var/ossec/etc/ossec.conf` :

La configuration de référence est disponible dans le dépôt :

- **Fichier** : [`configs/wazuh/manager-ossec.conf`](../../configs/wazuh/manager-ossec.conf)

```xml
<ossec_config>
  <integration>
    <name>slack</name>
    <hook_url><REDACTED></hook_url>
    <level>7</level>
    <alert_format>json</alert_format>
  </integration>
</ossec_config>
```

Le seuil est fixé à **niveau 7** — seules les alertes de sévérité moyenne et haute sont envoyées sur Slack, évitant le bruit des alertes informatives. Après modification, le manager est redémarré :

```bash
systemctl restart wazuh-manager
```

### Alertes reçues

![Alerte Slack 1](./images/Pasted%20image%2020260521072516.png)

![Alerte Slack 2](./images/Pasted%20image%2020260521072909.png)

Les alertes Slack affichent :

- **Agent source** — quel serveur a généré l'alerte
- **Règle déclenchée** — description de la menace détectée
- **Niveau de sévérité** — 1 à 15
- **Timestamp** — heure exacte de l'événement

### Test de détection — Brute Force SSH

Pour valider l'intégration, une attaque brute force SSH simulée est lancée depuis S1 vers S2. Le script de test est disponible dans le dépôt :

- **Script** : [`scripts/test-brute-force.sh`](../../scripts/test-brute-force.sh)

```bash
for i in {1..10}; do ssh wronguser@192.168.50.12 exit 2>/dev/null; done
```

Wazuh détecte immédiatement l'attaque (règle niveau 10 — **sshd: brute force**) et envoie l'alerte sur Slack en moins de 30 secondes.

---

## 10. Capacités Wazuh disponibles

Le dashboard Wazuh offre de nombreuses fonctionnalités exploitables chez ACCENT :

| Fonctionnalité | Description |
|----------------|-------------|
| **File Integrity Monitoring (FIM)** | Détecte toute modification de fichiers critiques (/etc, /bin, /sbin) |
| **Vulnerability Detection** | Inventaire CVE de tous les packages installés |
| **Rootcheck** | Détection de rootkits, anomalies système et processus cachés |
| **Threat Hunting** | Recherche avancée dans les événements de sécurité |
| **MITRE ATT&CK** | Mapping des alertes aux techniques d'attaque MITRE |
| **PCI DSS / HIPAA / GDPR / NIST** | Conformité multi-réglementaire |
| **Malware Detection** | Détection d'indicateurs de compromission |
| **Active Response** | Réponse automatique aux menaces (blocage IP, kill processus) |
| **Docker/Watermark Listener** | Surveillance des conteneurs et conteneurs |
| **SCA (Security Configuration Assessment)** | Audit de configuration selon des benchmarks CIS |

---

## Résultat

À l'issue de ce sprint, la plateforme HIDS est opérationnelle :

- **3 agents actifs** — S1, S2, pve1 — surveillés en temps réel
- **Détection de vulnérabilités** — inventaire CVE complet sur tous les agents
- **Alertes Slack** — notification immédiate pour toute alerte de niveau 7+
- **Threat Hunting** — visibilité complète sur les événements de sécurité
- **Conformité** — mapping automatique PCI DSS, HIPAA, GDPR, NIST
- **Latence de détection** — inférieure à 30 secondes entre l'événement et la notification Slack

---

## Diagrammes

### Diagramme d'Activité

![Diagramme d'activité — Sprint 8](../diagrams/activity/sprint8.png)

### Diagramme de Déploiement

![Diagramme de déploiement — Sprint 8](../diagrams/deployment/sprint8.png)

---

## Captures d'Écran de Validation

### Liste des agents actifs

![Liste des agents Wazuh actifs](./images/Pasted%20image%2020260521070316.png)

### Dashboard Principal

![Dashboard Principal](./images/Pasted%20image%2020260521073707.png)

### Détection de Vulnérabilités — Server1

![Vulnérabilités Server1](./images/Pasted%20image%2020260521062908.png)

### Détection de Vulnérabilités — Server2

![Vulnérabilités Server2](./images/Pasted%20image%2020260521062931.png)

### Threat Hunting

![Threat Hunting](./images/Pasted%20image%2020260521073745.png)

### Alertes Slack

![Alerte Slack 1](./images/Pasted%20image%2020260521072516.png)

![Alerte Slack 2](./images/Pasted%20image%2020260521072909.png)

### Règles Firewall Wazuh

Les règles pfSense autorisent les agents Wazuh à communiquer avec le serveur Wazuh via les ports TCP 1514 et TCP 1515.

![Règles Firewall Wazuh](./images/Pasted%20image%2020260522113906.png)

### Installation Wazuh All-in-One

![Installation Wazuh All-in-One](./images/Pasted%20image%2020260521060602.png)

### Regénération des mots de passe

![Regénération des mots de passe Wazuh](./images/Pasted%20image%2020260521062326.png)

### Statut de l'agent Wazuh sur S1

![Statut de l'agent Wazuh sur S1](./images/Pasted%20image%2020260521060848.png)

