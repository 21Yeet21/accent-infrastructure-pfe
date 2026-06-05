
# Procédures de Démarrage et Arrêt — Environnement EVE-NG

> **Version** : 5.0
> **Dernière mise à jour** : 2026-05-21
> **Configuration** : 1 nœud Proxmox (pve1) + pfSense VM + MonSrv VM + Wazuh VM + S1/S2 nodes EVE-NG
> **Accès EVE-NG** : 192.168.140.160
> **Lab UID** : `2e718c0b-41bf-48c0-a67a-8fac5dbb9e97`

---

## Démarrage Complet

### Étape 1 — EVE-NG UI : Démarrer les nœuds dans l'ordre

1. **SW1** — attendre 30s
2. **ISP-R1** (Cisco 3725) — attendre 30s
3. **pve1** — attendre 1 minute
4. **S1, S2** (nœuds EVE-NG Ubuntu) — uniquement si besoin

---

### Étape 2 — pve1 : Démarrage des VMs

```bash
ssh root@192.168.140.141
systemctl restart pve-cluster
pvecm expected 1
qm start 104   # pfSense
sleep 15
qm start 105   # MonSrv
qm start 108   # Wazuh
```

---

### Étape 3 — ISP-R1 : Vérification

ISP-R1 **sauvegarde sa config** entre sessions — aucune reconfiguration nécessaire. Vérifier simplement que fa0/0 a obtenu une IP DHCP :

```bash
show interface fa0/0 | include Internet
```

Si l'interface n'a pas d'IP (rare) :

```bash
conf t
interface fa0/0
 no shutdown
end
```

---

### Étape 4 — MonSrv : Stack monitoring

```bash
ssh root@192.168.50.10 "cd ~/monitoring-stack && docker compose up -d && docker compose ps"
```

| Conteneur | Port | Rôle |
|-----------|------|------|
| prometheus | 9090 | Collecte métriques |
| grafana | 3000 | Visualisation |
| loki | 3100 | Agrégation logs |
| tempo | 3200, 4317, 4318 | Traces distribuées |

---

### Étape 5 — S1 : Stack monitoring

```bash
ssh ayoub@192.168.50.11 "cd ~/s1-monitoring && docker compose up -d && docker compose ps"
```

Services : alloy, node-exporter, apache, mysql, otel-collector, apache-trace-generator, mysql-trace-generator

---

### Étape 6 — S2 : Stack monitoring

```bash
ssh ayoub@192.168.50.12 "cd ~/s2-monitoring && docker compose up -d && docker compose ps"
```

Services : alloy, node-exporter, redis, redis-exporter, nginx

---

### Étape 7 — Tunnels SSH (depuis Windows)

Ouvrir un terminal par tunnel :

```powershell
ssh -L 3000:192.168.50.10:3000 root@192.168.140.141   # Grafana (accès dev)
ssh -L 9443:192.168.20.23:443 root@192.168.140.141    # pfSense
ssh -L 9006:192.168.20.11:8006 root@192.168.140.141   # Proxmox
ssh -L 9444:192.168.20.24:443 root@192.168.140.141    # Wazuh
ssh -L 9090:192.168.50.10:9090 root@192.168.140.141   # Prometheus
```

| Service | URL | Identifiants |
|---------|-----|-------------|
| Grafana (dev) | http://localhost:3000/grafana/ | admin / `<REDACTED>` |
| Grafana (VLAN20) | http://192.168.50.12/grafana/ | admin / `<REDACTED>` |
| pfSense | https://localhost:9443 | admin / `<REDACTED>` |
| Proxmox | https://localhost:9006 | root / `<REDACTED>` |
| Wazuh | https://localhost:9444 | admin / `<REDACTED>` |
| Prometheus | http://192.168.50.10:9090 | — |

> **Note** : Les mots de passe doivent être fournis séparément (ne jamais les commiter dans le dépôt).

---

## Arrêt Complet

### Étape 1 — Arrêter les stacks monitoring

```bash
ssh ayoub@192.168.50.12 "cd ~/s2-monitoring && docker compose down"
ssh ayoub@192.168.50.11 "cd ~/s1-monitoring && docker compose down"
ssh root@192.168.50.10 "cd ~/monitoring-stack && docker compose down"
```

### Étape 2 — Arrêter les VMs dans pve1

```bash
ssh root@192.168.20.11
qm stop 108   # Wazuh
qm stop 105   # MonSrv
qm stop 104   # pfSense
```

### Étape 3 — Arrêter pve1 dans EVE-NG UI

Arrêter le nœud pve1 depuis l'interface EVE-NG WebUI.

### Étape 4 — Sauvegarder les disques pve1 (sur EVE-NG host)

```bash
LAB="/opt/unetlab/tmp/0/2e718c0b-41bf-48c0-a67a-8fac5dbb9e97"

# pve1 — Proxmox system + toutes les VMs
/opt/qemu-2.12.0/bin/qemu-img commit $LAB/6/virtioa.qcow2
/opt/qemu-2.12.0/bin/qemu-img commit $LAB/6/virtiob.qcow2

# S1 et S2 — nœuds EVE-NG (uniquement si modifiés)
cp $LAB/2/virtioa.qcow2 /opt/unetlab/addons/qemu/ubuntu-s1-1.0-pfe/virtioa.qcow2
cp $LAB/3/virtioa.qcow2 /opt/unetlab/addons/qemu/ubuntu-s2-1.0-pfe/virtioa.qcow2
```

### Étape 5 — Arrêter les nœuds dans EVE-NG UI

Ordre : S2 → S1 → ISP-R1 → SW1

---

## Vérification Rapide

```bash
# Connectivité
ping -c 2 192.168.20.23    # pfSense
ping -c 2 192.168.50.10    # MonSrv
ping -c 2 192.168.50.11    # S1
ping -c 2 192.168.50.12    # S2

# Node Exporter pve1
curl -s http://192.168.20.11:9100/metrics | head -3

# Prometheus targets
curl -s http://192.168.50.10:9090/api/v1/targets | python3 -m json.tool | grep -E '"health"|"job"'

# Loki
curl -s http://192.168.50.10:3100/ready

# Grafana
curl -s http://admin:<REDACTED>@192.168.50.10:3000/api/health

# Logs dans Loki
curl -s "http://192.168.50.10:3100/loki/api/v1/label/job/values" | python3 -m json.tool

# Traces dans Tempo
curl -s "http://192.168.50.10:3200/api/search?limit=3" | python3 -m json.tool | grep "rootServiceName"
```

---

## Dépannage

### DMZ inaccessible (192.168.50.x)

```bash
bridge vlan add dev vmbr0 vid 50 self
bridge vlan add dev tap104i1 vid 50 tagged master
ping -c 3 192.168.50.10
```

### Prometheus targets DOWN

```bash
curl -s http://192.168.50.11:9100/metrics | head -3   # S1
curl -s http://192.168.50.12:9100/metrics | head -3   # S2
curl -s http://192.168.50.12:9121/metrics | head -3   # Redis
curl -s http://192.168.20.11:9100/metrics | head -3   # pve1
```

### Loki — logs non reçus

```bash
# Vérifier timezone MonSrv (doit être UTC)
ssh root@192.168.50.10 "date"

# Redémarrer Alloy
ssh ayoub@192.168.50.11 "cd ~/s1-monitoring && docker compose restart alloy"
ssh ayoub@192.168.50.12 "cd ~/s2-monitoring && docker compose restart alloy"

# Générer du trafic pour forcer un batch flush
ssh ayoub@192.168.50.11 "for i in {1..20}; do curl -s http://localhost:8080/ > /dev/null; done"
```

### Alloy positions bloquées

```bash
ssh ayoub@192.168.50.11 "docker exec alloy find /data-alloy -name 'positions.yml' -exec rm {} \;"
ssh ayoub@192.168.50.11 "cd ~/s1-monitoring && docker compose restart alloy"
```

### MySQL general.log trop volumineux

```bash
ssh ayoub@192.168.50.11 "sudo truncate -s 0 ~/s1-monitoring/mysql-logs/general.log"
ssh ayoub@192.168.50.11 "cd ~/s1-monitoring && docker compose restart alloy"
```

### Traces OTel non reçues

```bash
ssh ayoub@192.168.50.11 "docker logs otel-collector --tail=10 | grep -E 'error|warn'"
curl -s "http://192.168.50.10:3200/api/search?limit=3" | python3 -m json.tool | grep rootServiceName
```

### Grafana dashboards — No data (Loki)

```bash
ssh ayoub@192.168.50.11 "for i in {1..50}; do curl -s http://localhost:8080/ > /dev/null; done"
ssh ayoub@192.168.50.11 "docker exec mysql mysql -uroot -p<REDACTED> -e 'SHOW DATABASES;' 2>/dev/null"
ssh ayoub@192.168.50.12 "for i in {1..20}; do curl -s http://localhost/ > /dev/null; done"
```

### pfSense — Package Manager vide

```bash
# SSH sur pfSense → option 8
pkg update -f
# Puis réessayer via WebGUI
```

### ISP-R1 — Duplex mismatch (performance lente)

```bash
conf t
interface fa0/0
 duplex full
 speed 100
 no shutdown
end
wr
```

---

## Historique

| Version | Date | Changements |
|---------|------|-------------|
| v1.0 | 2026-05-08 | Procédure initiale 3-nœuds Proxmox |
| v2.0 | 2026-05-10 | Migration VLAN20, SW1, pve nodes |
| v2.1 | 2026-05-13 | Single-node EVE-NG, thin pool, commit hda |
| v3.0 | 2026-05-14 | Nouveau EVE-NG 6.x (.140.160), cp au lieu de commit |
| v4.0 | 2026-05-20 | Ajout pve1 Node Exporter, Wazuh VM 108, dépannage Alloy/Loki/Grafana |
| v5.0 | 2026-05-21 | ISP-R1 config persistante, fix duplex |

---

## What I Changed

| Before | After |
|--------|-------|
| `<GRAFANA_PASSWORD>` | `<REDACTED>` (consistent) |
| `<PFSENSE_PASSWORD>` | `<REDACTED>` |
| `<PROXMOX_PASSWORD>` | `<REDACTED>` |
| `<WAZUH_PASSWORD>` | `<REDACTED>` |
| `<MYSQL_PASSWORD>` in dépannage | `<REDACTED>` |
| ntopng in v5.0 changelog | Removed |
