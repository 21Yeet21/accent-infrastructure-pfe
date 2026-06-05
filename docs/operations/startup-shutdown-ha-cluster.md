
## Fichier 2 : `docs/operations/startup-shutdown-ha-cluster.md`

# Procédures de Démarrage et Arrêt — Cluster Proxmox HA

> **Version** : 2.0  
> **Dernière mise à jour** : 2026-04-28  
> **Configuration** : Cluster Proxmox 3 nœuds (pve1, pve2, pve3) avec Ceph + VM pfSense (HA) + VMs de monitoring  
> **Statut** : Prêt pour démonstration

---

## Arrêt du Cluster

### Arrêt propre de la VM HA (pfSense)

Le HA gère automatiquement la VM pfSense, mais pour un arrêt propre :

```bash
ha-manager set vm:101 --state stopped
qm stop 101
```

### Ordre d'arrêt des nœuds

Arrêter les nœuds dans cet ordre pour éviter les alertes Ceph inutiles :

1. `shutdown -h now` sur **pve2**
2. `shutdown -h now` sur **pve3**
3. `shutdown -h now` sur **pve1** (en dernier — c'est le Ceph MGR master)
4. Arrêter S1, S2 et MonSrv normalement dans VMware

---

## Démarrage Complet + Procédure de Démonstration

### Partie 1 — Démarrage de Proxmox

1. Démarrer pve1, pve2, pve3 dans VMware
2. Attendre environ 2 minutes
3. SSH sur pve1 et exécuter les vérifications :

```bash
# Vérifier Ceph
ceph status
# Attendu : HEALTH_OK, 3 osds up

# Vérifier le cluster + HA
ha-manager status
# Attendu : quorum OK, all 3 lrm active/idle

# Lister les VMs
qm list
pct list
```

4. Si un OSD est down :

```bash
# Exécuter sur le nœud correspondant
systemctl reset-failed ceph-osd@0 && systemctl start ceph-osd@0  # pve1
systemctl reset-failed ceph-osd@1 && systemctl start ceph-osd@1  # pve2
systemctl reset-failed ceph-osd@2 && systemctl start ceph-osd@2  # pve3
```

5. Corriger l'avertissement pg_num si présent :

```bash
ceph osd pool set vm-pool pg_num 32
ceph osd pool set vm-pool pgp_num 32
```

6. Démarrer pfSense :

```bash
ha-manager set vm:101 --state started
```

7. Vérifier que pfSense est actif :

```bash
ha-manager status
# Attendu : service vm:101 (pveX, started)
```

---

### Partie 2 — Démonstration du Basculement HA

> **Important** : pfSense peut ne pas être sur pve1 après un redémarrage — toujours vérifier avant d'éteindre un nœud.

```bash
ha-manager status
# Noter : service vm:101 (pveX, started) — identifier le nœud pveX
```

1. Éteindre **pveX** (le nœud où pfSense tourne) dans VMware
2. Sur un autre nœud, observer le HA :

```bash
watch ha-manager status
```

3. Séquence attendue :
   - `lrm pveX (old timestamp - dead?)`
   - `service vm:101 (pveX, fence)`
   - `service vm:101 (pveY, started)` ✅
4. Rallumer pveX → attendre le rétablissement du quorum
5. Vérifier la récupération :

```bash
ceph status        # HEALTH_OK
ha-manager status  # tous les nœuds de retour
```

---

### Partie 3 — Démarrage des VMs de Monitoring

Démarrer dans VMware dans cet ordre :

1. **MonSrv** (192.168.50.10) — serveur de supervision central
2. **S1** (192.168.50.11) — serveur applicatif
3. **S2** (192.168.50.12) — serveur web

> **Note** : Les IPs sont permanentes via configuration statique — aucune commande manuelle nécessaire après redémarrage.

Vérifier la connectivité depuis la machine hôte :

```bash
ping -c 2 192.168.50.10   # MonSrv
ping -c 2 192.168.50.11   # S1
ping -c 2 192.168.50.12   # S2
```

---

### Partie 4 — Démarrage de la Stack de Monitoring

**MonSrv :**

```bash
ssh root@192.168.50.10
cd ~/monitoring-stack
docker compose up -d
docker compose ps   # vérifier que tous les conteneurs sont running
```

**S1 :**

```bash
ssh ayoub@192.168.50.11
cd ~/s1-monitoring
docker compose up -d
docker compose ps
```

**S2 :**

```bash
ssh ayoub@192.168.50.12
cd ~/s2-monitoring
docker compose up -d
docker compose ps
```

---

### Partie 5 — Vérification du Monitoring

1. **Grafana** → `http://192.168.50.12/grafana/`
   - Overview — Infrastructure ACCENT ✅
   - System Metrics S1 + S2 ✅
   - Logs S1 (Apache/MySQL/SSH) ✅
   - Logs S2 (Nginx/SSH) ✅
   - Traces (Apache/MySQL) ✅
   - Redis Cache & Performance ✅

2. **Prometheus targets** → `http://192.168.50.10:9090/targets`
   - Tous les targets en statut UP ✅

3. **Wazuh Dashboard** → `https://192.168.20.24:443`
   - 3 agents actifs (S1, S2, pve1) ✅
   - Vulnerability Detection opérationnelle ✅

---

### Partie 6 — Accès à pfSense WebGUI

```
https://192.168.20.23
```

Login : `admin` / `<PFSENSE_PASSWORD>`

---

## Dépannage HA

### Ceph HEALTH_WARN après redémarrage

```bash
ceph status
# Si "X pgs degraded" ou "X pgs undersized"
ceph osd pool set vm-pool pg_num 32
ceph osd pool set vm-pool pgp_num 32
ceph osd pool set vm-pool size 3
ceph osd pool set vm-pool min_size 2
```

### VM pfSense bloquée en état "error"

```bash
ha-manager set vm:101 --state stopped
sleep 10
ha-manager set vm:101 --state started
```

### Corosync timeout (faux positifs en VMware imbriqué)

Vérifier que le token timeout est bien à 10000ms :

```bash
grep token /etc/pve/corosync.conf
# Attendu : token: 10000
```

Si ce n'est pas le cas, éditer `/etc/pve/corosync.conf` sur pve1 (synchronisation automatique) et redémarrer corosync sur tous les nœuds :

```bash
systemctl restart corosync
```


