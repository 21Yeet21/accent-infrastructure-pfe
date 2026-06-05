# 

# \# Sprint 3 — Proxmox Single Node (pve1)

# 

# \## Vue d'Ensemble

# 

# Ce sprint couvre l'installation et la configuration de Proxmox VE 7.4 comme hyperviseur single-node tournant à l'intérieur d'EVE-NG. Proxmox est installé proprement depuis l'ISO directement sur le nœud pve1 — aucune conversion n'est impliquée.

# 

# Il inclut la décision d'architecture de stockage, remplaçant le pool LVM-thin par défaut par un répertoire ext4 simple pour éviter la corruption sous virtualisation imbriquée, ainsi que la configuration complète des bridges réseau qui permet tous les déploiements de VMs ultérieurs. Ce sprint doit être complété avant tout déploiement de VM.

# 

# \---

# 

# \## Installation de Proxmox

# 

# \### Préparation de l'ISO

# 

# L'ISO Proxmox 7.4 est téléchargée sur l'hôte EVE-NG et attachée au nœud pve1 comme cdrom virtuel :

# 

# ```bash

# wget --no-check-certificate -O /tmp/proxmox.iso \\

# &#x20; https://download.proxmox.com/iso/proxmox-ve\_7.4-1.iso

# 

# cp /tmp/proxmox.iso /opt/unetlab/addons/qemu/proxmox-pfe-1.0-pfe/cdrom.iso

# chown www-data:www-data /opt/unetlab/addons/qemu/proxmox-pfe-1.0-pfe/cdrom.iso

# ```

# 

# Wipe et démarrage de pve1 depuis l'interface WebUI EVE-NG. L'installeur démarre automatiquement.

# 

# !\[Installeur Proxmox](https://claude.ai/chat/images/Pasted%20image%2020260515184418.png)

# 

# \### Paramètres d'Installation

# 

# |Paramètre|Valeur|

# |---|---|

# |Disque cible|vda (20G) — système uniquement|

# |Système de fichiers|ext4|

# |Hostname|pve1.pfe.local|

# |Interface de management|ens5 (temporaire — cloud0)|

# |IP|192.168.140.141/24 (temporaire)|

# |Passerelle|192.168.140.2 (temporaire)|

# |DNS|8.8.8.8|

# 

# > vdb (80G) est laissé intact pendant l'installation. Il est configuré séparément comme stockage VM après le boot. L'IP de management assignée pendant l'installation est temporaire — à ce stade, pfSense n'est pas encore déployé, donc il n'y a pas de passerelle VLAN20 disponible. Une fois pfSense opérationnel au Sprint 4, cette configuration temporaire est remplacée par la configuration finale de management basée sur VLAN20.

# 

# Désactiver l'auto reboot AVANT de cliquer sur Install — le cdrom doit être retiré avant le premier reboot pour éviter de redémarrer dans l'installeur.

# 

# !\[Configuration réseau installation](https://claude.ai/chat/images/Pasted%20image%2020260515184732.png) !\[Écran de résumé avant installation](https://claude.ai/chat/images/Pasted%20image%2020260515184902.png)

# 

# \### Commit Post-Installation

# 

# Après la fin de l'installation, commit du disque sur l'hôte EVE-NG avant d'arrêter pve1 :

# 

# ```bash

# /opt/qemu-2.12.0/bin/qemu-img commit \\

# &#x20; /opt/unetlab/tmp/0/2e718c0b-41bf-48c0-a67a-8fac5dbb9e97/6/virtioa.qcow2

# rm /opt/unetlab/addons/qemu/proxmox-pfe-1.0-pfe/cdrom.iso

# ```

# 

# Arrêter pve1 dans WebUI puis redémarrer sans wipe.

# 

# !\[Premier boot Proxmox — WebUI](https://claude.ai/chat/images/Pasted%20image%2020260515185119.png)

# 

# \### Configuration du Cluster Single Node

# 

# Proxmox nécessite un quorum de cluster pour écrire dans son système de fichiers de configuration (/etc/pve). Sur un nœud unique, cela fait échouer pve-cluster car il s'attend à plus de nœuds. La solution est de créer un cluster single-node :

# 

# ```bash

# systemctl stop corosync

# systemctl disable corosync

# rm /var/lib/pve-cluster/config.db

# systemctl start pve-cluster

# pvecm create pfe-cluster

# ```

# 

# \---

# 

# \## Architecture de Stockage

# 

# \### Pourquoi Pas LVM-Thin

# 

# Proxmox s'installe avec LVM-thin comme pool de stockage VM par défaut. LVM-thin utilise un arbre B de métadonnées pour suivre les blocs alloués, ce qui nécessite des I/O à faible latence pour les opérations de métadonnées. Sous quatre niveaux de virtualisation imbriquée (VMware → EVE-NG → Proxmox → VM), la latence I/O est trop élevée pour ces opérations, causant une corruption des métadonnées et des défaillances du pool pendant les écritures lourdes telles que les installations d'OS ou les pulls d'images Docker.

# 

# Pour cette raison, le pool LVM-thin est supprimé et remplacé par un répertoire ext4 simple sur le disque de stockage dédié vdb. Cette approche échange une certaine efficacité d'espace pour une fiabilité complète sous virtualisation imbriquée.

# 

# \### Configuration du Stockage

# 

# ```bash

# lvremove -f pve/data 2>/dev/null || true

# vgreduce pve /dev/vdb 2>/dev/null || true

# pvremove -ff --yes /dev/vdb

# wipefs -a /dev/vdb

# mkfs.ext4 /dev/vdb

# mkdir -p /mnt/vmdata

# mount /dev/vdb /mnt/vmdata

# echo "/dev/vdb /mnt/vmdata ext4 defaults 0 0" >> /etc/fstab

# pvesm add dir vmdata --path /mnt/vmdata --content images,iso,snippets,rootdir

# pvesm status

# ```

# 

# Déplacer les templates ISO vers le nouveau stockage :

# 

# ```bash

# mkdir -p /mnt/vmdata/template/iso

# mv /var/lib/vz/template/iso/\*.iso /mnt/vmdata/template/iso/ 2>/dev/null || true

# ```

# 

# \### Résumé du Stockage

# 

# |Stockage|Type|Chemin|Disque|Taille|Objectif|

# |---|---|---|---|---|---|

# |local|Directory|/var/lib/vz|vda|8.5G|Snippets, backups|

# |vmdata|Directory|/mnt/vmdata|vdb|79G|Disques VM, ISOs|

# 

# \---

# 

# \## Architecture Réseau

# 

# \### Assignation des Interfaces Physiques

# 

# pve1 a 6 interfaces réseau virtuelles. Seulement deux sont utilisées dans la configuration de production finale :

# 

# |Interface|Connecté à|Rôle|

# |---|---|---|

# |ens3|SW1 Gi0/0|Trunk 802.1Q — VLANs 10, 20, 50, 70|

# |ens4|ISP-R1 fa1/0|Uplink WAN (10.0.0.0/30)|

# 

# > ens5 (cloud0) est utilisé temporairement pendant ce sprint pour l'accès initial. Il est retiré de la configuration réseau de production au Sprint 4 après le déploiement de pfSense.

# 

# \### Design des Bridges

# 

# Deux bridges Linux sont créés sur pve1 :

# 

# \*\*vmbr0\*\* est le bridge VLAN-aware central. Il transporte tout le trafic interne entre les VMs, les nœuds EVE-NG, et pfSense. Il se connecte à SW1 via ens3 (trunk) et est configuré avec la conscience VLAN pour pouvoir tagger et détagger les trames pour chaque VLAN. Il n'a pas d'IP propre — c'est purement un tissu de commutation.

# 

# \*\*vmbr1\*\* est un bridge simple connecté à ens4 (WAN). Il relie le WAN pfSense directement à ISP-R1. Aucune conscience VLAN n'est nécessaire ici car le trafic WAN n'est pas taggé.

# 

# \### Entrées VLAN Self

# 

# vmbr0 forwarde les trames taggées entre ses ports. Pour que pve1 lui-même puisse envoyer et recevoir du trafic sur un VLAN spécifique — et pas seulement le forwarder — le bridge doit être explicitement ajouté comme membre de chaque VLAN en utilisant le flag `self`. Sans cela, pve1 est invisible sur ces VLANs même si le bridge transporte le trafic entre les autres équipements.

# 

# ```bash

# bridge vlan add dev vmbr0 vid 10 self

# bridge vlan add dev vmbr0 vid 20 self

# bridge vlan add dev vmbr0 vid 50 self

# bridge vlan add dev vmbr0 vid 70 self

# ```

# 

# Ces entrées sont ajoutées de manière permanente via les règles post-up dans le fichier interfaces.

# 

# \### vmbr0.20 — Sous-interface de Management

# 

# pve1 participe au VLAN20 (réseau de management) via une sous-interface VLAN sur vmbr0 :

# 

# \- IP : 192.168.20.11/27

# \- C'est l'identité permanente de pve1 sur le réseau de management

# \- Les routes inter-VLAN (vers VLAN50, VLAN10, VLAN70) utilisent pfSense (192.168.20.23) comme passerelle

# 

# Sans vmbr0.20, pve1 n'a pas de présence sur VLAN20 et ne peut pas communiquer avec pfSense ou tout serveur via le routage approprié.

# 

# \### Flux de Trafic

# 

# Quand pve1 doit atteindre un serveur dans la DMZ (par ex. MonSrv à 192.168.50.10) :

# 

# ```

# pve1 vmbr0.20 (src 192.168.20.11)

# &#x20; → vmbr0 (VLAN20 taggé)

# &#x20; → tap104i1 — pfSense LAN (VLAN20 natif/untaggé)

# &#x20; → pfSense route vers em1.50

# &#x20; → tap104i1 (VLAN50 taggé)

# &#x20; → vmbr0 → ens3 → SW1 → MonSrv

# ```

# 

# Quand S1 (192.168.50.11) envoie du trafic vers internet :

# 

# ```

# S1 ens3

# &#x20; → SW1 Gi1/0 (access VLAN50)

# &#x20; → SW1 Gi0/0 (trunk, VLAN50 taggé)

# &#x20; → ens3 → vmbr0

# &#x20; → tap104i1 — pfSense em1.50

# &#x20; → pfSense NAT → em0

# &#x20; → tap104i0 → vmbr1 → ens4

# &#x20; → ISP-R1 → internet

# ```

# 

# \### /etc/network/interfaces — Configuration Production Finale

# 

# C'est la configuration réseau finale qui s'applique après le déploiement de pfSense au Sprint 4. Elle est présentée ici parce que l'architecture des bridges est conçue et implémentée dans ce sprint :

# 

# ```bash

# cat > /etc/network/interfaces << 'EOF'

# auto lo

# iface lo inet loopback

# 

# iface ens3 inet manual

# 

# auto vmbr0

# iface vmbr0 inet manual

# &#x20;       bridge-ports ens3

# &#x20;       bridge-stp off

# &#x20;       bridge-fd 0

# &#x20;       bridge-vlan-aware yes

# &#x20;       bridge-vids 10 20 50 70 99

# &#x20;       post-up bridge vlan add dev vmbr0 vid 10 self

# &#x20;       post-up bridge vlan add dev vmbr0 vid 20 self

# &#x20;       post-up bridge vlan add dev vmbr0 vid 50 self

# &#x20;       post-up bridge vlan add dev vmbr0 vid 70 self

# 

# auto vmbr0.20

# iface vmbr0.20 inet static

# &#x20;       address 192.168.20.11/27

# &#x20;       gateway 192.168.20.23

# &#x20;       post-up ip route add 192.168.50.0/26 via 192.168.20.23 dev vmbr0.20

# &#x20;       post-up ip route add 192.168.10.0/24 via 192.168.20.23 dev vmbr0.20

# &#x20;       post-up ip route add 192.168.70.0/28 via 192.168.20.23 dev vmbr0.20

# 

# auto vmbr1

# iface vmbr1 inet manual

# &#x20;       bridge-ports ens4

# &#x20;       bridge-stp off

# &#x20;       bridge-fd 0

# 

# iface ens4 inet manual

# iface ens5 inet manual

# iface ens6 inet manual

# iface ens7 inet manual

# iface ens8 inet manual

# EOF

# 

# systemctl restart networking

# ```

# 

# \### Fix du VLAN Natif sur ens3

# 

# Quand ens3 est ajouté à vmbr0, Linux assigne VLAN1 comme son VLAN natif par défaut. Le trunk SW1 utilise VLAN99 comme natif. Ils doivent correspondre :

# 

# ```bash

# bridge vlan del dev ens3 vid 1

# bridge vlan add dev ens3 vid 99 pvid untagged

# ```

# 

# \---

# 

# \## Accès Temporaire Pendant Ce Sprint

# 

# Puisque pfSense n'est pas encore déployé, VLAN20 n'a pas de passerelle et vmbr0.20 (192.168.20.11) n'est pas encore joignable depuis l'extérieur. Pendant le Sprint 3, l'accès temporaire à Proxmox est fourni via l'interface cloud0 (ens5) avec l'IP statique assignée pendant l'installation :

# 

# \- Proxmox WebUI : https://192.168.140.141:8006

# \- SSH : ssh root@192.168.140.141

# 

# Depuis une machine Windows, une route statique est ajoutée pour atteindre le sous-réseau VLAN20 via pve1 :

# 

# ```cmd

# route add 192.168.20.0 mask 255.255.255.224 192.168.140.141

# ```

# 

# \### Transition vers l'Accès Production (Sprint 4)

# 

# Après le déploiement de pfSense et la mise en service de VLAN20, le management cloud0 temporaire est retiré. ens5 devient inutilisé et tout l'accès de management passe vers vmbr0.20 (192.168.20.11) à travers pfSense :

# 

# ```bash

# systemctl restart networking

# ping -c 3 192.168.20.23

# ssh root@192.168.20.11

# ```

# 

# \---

# 

# \## Vérification

# 

# ```bash

# bridge vlan show dev vmbr0

# bridge vlan show dev ens3

# bridge link show vmbr0

# pvesm status

# df -h /mnt/vmdata

# ```

# 

# \---

# 

# \## Problèmes Connus et Corrections

# 

# |Problème|Cause|Correction|

# |---|---|---|

# |pve-cluster échoue au démarrage|config.db corrompue|rm /var/lib/pve-cluster/config.db puis restart|

# |Corruption du pool LVM-thin|Latence I/O de la virtualisation imbriquée|Remplacer par stockage répertoire ext4 sur vdb|

# |ens3 mauvais VLAN natif|VLAN1 par défaut Linux|bridge vlan del vid 1, add vid 99 pvid untagged|

# |Routes vmbr0.20 manquantes après reboot|post-up non déclenché|Vérifier les entrées post-up dans le fichier interfaces|

# 

# \---

# 

# \## Captures d'Écran

# 

# \### 1. Installation Proxmox — Écran de l'Installeur

# 

# !\[Installeur graphique Proxmox dans pve1 VNC](https://claude.ai/chat/images/Pasted%20image%2020260515184418.png)

# 

# \### 2. Installation Proxmox — Configuration Réseau

# 

# !\[Configuration réseau — ens5, IP 192.168.140.141, hostname pve1.pfe.local](https://claude.ai/chat/images/Pasted%20image%2020260515184732.png)

# 

# \### 3. Installation Proxmox — Écran Résumé

# 

# !\[Paramètres confirmés, auto reboot OFF](https://claude.ai/chat/images/Pasted%20image%2020260515184902.png)

# 

# \### 4. Premier Boot Proxmox — WebUI

# 

# !\[Dashboard Proxmox à https://192.168.140.141:8006](https://claude.ai/chat/images/Pasted%20image%2020260515185119.png)

# 

# \### 5. Statut du Stockage

# 

# !\[pvesm status — local et vmdata actifs, \~79G disponibles](https://claude.ai/chat/images/Pasted%20image%2020260522114401.png)

# 

# \### 6. Bridges Réseau — bridge link show vmbr0

# 

# !\[vmbr0 avec ens3, ens5 et tap104i1 comme ports](https://claude.ai/chat/images/Pasted%20image%2020260522114430.png)

# 

# \### 7. VLANs sur vmbr0

# 

# !\[vmbr0 avec VLANs 10, 20, 50, 70 configurés](https://claude.ai/chat/images/Pasted%20image%2020260522114450.png)

# 

# \### 8. VLANs sur ens3

# 

# !\[ens3 avec VLAN99 comme natif et VLANs 10, 20, 50, 70 taggés](https://claude.ai/chat/images/Pasted%20image%2020260522114512.png)

# 

# \### 9. WebUI Proxmox — Vue Stockage et Cluster

# 

# !\[Datacenter pfe-cluster avec stockage local et vmdata actifs](https://claude.ai/chat/images/Pasted%20image%2020260522114821.png)

# 

# \---

