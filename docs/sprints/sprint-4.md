# \# Sprint 4 — pfSense : Firewall, Sécurité et VPN

# donedonedonedone

# \## Objectif

# 

# Ce sprint couvre le déploiement complet de \*\*pfSense CE 2.7.2\*\* comme passerelle de sécurité centrale du lab. pfSense tourne comme VM 104 dans Proxmox (pve1) et assure le routage inter-VLAN, l'application des règles de pare-feu, le NAT, la détection d'intrusions via \*\*Suricata\*\*, et l'accès distant sécurisé via \*\*OpenVPN\*\*.

# 

# \---

# 

# \## 1. Création de la VM pfSense

# 

# pfSense est créée comme VM 104 sur pve1 en utilisant le stockage `vmdata` configuré au Sprint 3.

# 

# Upload de l'ISO depuis Windows :

# 

# ```powershell

# scp "C:\\Users\\pfe\\Downloads\\pfSense-CE-2.7.2-RELEASE-amd64.iso" root@192.168.140.141:/mnt/vmdata/template/iso/

# ```

# 

# Création de la VM :

# 

# ```bash

# qm create 104 --name pfsense --memory 2048 --cores 2 \\

# &#x20; --net0 e1000,bridge=vmbr1 \\

# &#x20; --net1 e1000,bridge=vmbr0 \\

# &#x20; --ide2 vmdata:iso/pfSense-CE-2.7.2-RELEASE-amd64.iso,media=cdrom \\

# &#x20; --boot order=ide2 --ostype other

# qm set 104 --ide0 vmdata:20

# qm start 104

# ```

# 

# Deux interfaces réseau sont assignées :

# 

# |Interface|Bridge|Rôle|

# |---|---|---|

# |net0 (em0)|vmbr1|WAN — connecté à ISP-R1 fa1/0|

# |net1 (em1)|vmbr0|Trunk LAN — porte tous les VLANs|

# 

# \---

# 

# \## 2. Installation

# 

# Dans la console VNC de Proxmox WebUI :

# 

# \- Pas de VLANs pendant l'installation

# \- WAN : em0

# \- LAN : em1

# \- Disque cible : ada0

# \- Auto reboot : OFF

# 

# !\[Installation pfSense — étape 1](https://claude.ai/chat/images/Pasted%20image%2020260515194507.png) !\[Installation pfSense — étape 2](https://claude.ai/chat/images/Pasted%20image%2020260515194818.png)

# 

# Après l'installation, détacher l'ISO et redémarrer :

# 

# ```bash

# qm set 104 --ide2 none,media=cdrom --boot order=ide0

# qm set 104 --hookscript local:snippets/pfsense-vlan.sh

# qm stop 104

# qm start 104

# ```

# 

# \---

# 

# \## 3. Configuration initiale des interfaces

# 

# \### IP LAN

# 

# Console pfSense → option 2 → LAN :

# 

# \- IP : 192.168.20.23/27

# \- Pas de passerelle, pas d'IPv6, pas de DHCP

# 

# \### IP WAN

# 

# Console pfSense → option 2 → WAN :

# 

# \- IP : 10.0.0.2/30

# \- Passerelle : 10.0.0.1

# 

# \---

# 

# \## 4. Script hook VLAN

# 

# Lorsque pfSense démarre, Proxmox crée `tap104i1` mais ne l'ajoute pas automatiquement au bridge ni ne configure ses VLANs. Le script hook s'exécute après le démarrage de pfSense et gère cela automatiquement.

# 

# ```bash

# mkdir -p /var/lib/vz/snippets

# cat > /var/lib/vz/snippets/pfsense-vlan.sh << 'EOF'

# \#!/bin/bash

# if \[ "$2" = "post-start" ]; then

# &#x20;   TAP="tap${1}i1"

# &#x20;   for i in $(seq 1 10); do

# &#x20;       ip link show "$TAP" >/dev/null 2>\&1 \&\& break

# &#x20;       sleep 1

# &#x20;   done

# &#x20;   if ! ip link show "$TAP" >/dev/null 2>\&1; then

# &#x20;       echo "\[ERROR] $TAP not found" >\&2

# &#x20;       exit 1

# &#x20;   fi

# &#x20;   ip link set "$TAP" master vmbr0 2>/dev/null || true

# &#x20;   bridge vlan del dev "$TAP" vid 1 2>/dev/null || true

# &#x20;   bridge vlan add dev "$TAP" vid 20 pvid untagged master

# &#x20;   bridge vlan add dev "$TAP" vid 10 tagged master

# &#x20;   bridge vlan add dev "$TAP" vid 50 tagged master

# fi

# EOF

# chmod 755 /var/lib/vz/snippets/pfsense-vlan.sh

# qm set 104 --hookscript local:snippets/pfsense-vlan.sh

# ```

# 

# \### Pourquoi VLAN20 est natif/untagged

# 

# pfSense em1 est une interface standard sans conscience VLAN native. En définissant VLAN20 comme PVID sur tap104i1, le trafic VLAN20 arrive sur em1 sans tag. pfSense crée ensuite des sous-interfaces (em1.10, em1.50) pour les autres VLANs qui arrivent taggés.

# 

# \### Correction manuelle si le hook ne s'est pas exécuté

# 

# ```bash

# ip link set tap104i1 master vmbr0

# bridge vlan del dev tap104i1 vid 1 2>/dev/null || true

# bridge vlan add dev tap104i1 vid 20 pvid untagged master

# bridge vlan add dev tap104i1 vid 10 tagged master

# bridge vlan add dev tap104i1 vid 50 tagged master

# ```

# 

# \---

# 

# \## 5. Accès WebGUI

# 

# ```powershell

# ssh -L 9443:192.168.20.23:443 root@192.168.20.11

# ```

# 

# Ouvrir https://localhost:9443 avec les identifiants par défaut.

# 

# !\[Login pfSense](https://claude.ai/chat/images/Pasted%20image%2020260511211114.png)

# 

# \---

# 

# \## 6. Sous-interfaces VLAN

# 

# Interfaces → VLANs → Add :

# 

# |Parent|Tag VLAN|Description|

# |---|---|---|

# |em1|10|CLIENTS|

# |em1|50|DMZ|

# 

# !\[Configuration des VLANs](https://claude.ai/chat/images/Pasted%20image%2020260522134249.png)

# 

# Interfaces → Assignments :

# 

# \- em1.10 → Activer → CLIENTS → IP : 192.168.10.1/24

# \- em1.50 → Activer → DMZ → IP : 192.168.50.1/26

# 

# !\[Assignments des interfaces](https://claude.ai/chat/images/Pasted%20image%2020260522134235.png)

# 

# \---

# 

# \## 7. Serveur DHCP

# 

# Services → DHCP Server → CLIENTS :

# 

# \- Enable : ✅

# \- Range : 192.168.10.100 → 192.168.10.200

# 

# !\[Configuration DHCP CLIENTS](https://claude.ai/chat/images/Pasted%20image%2020260511220953.png)

# 

# \---

# 

# \## 8. Règles de pare-feu

# 

# \### Politique de sécurité

# 

# Le pare-feu suit une approche \*\*deny-by-default\*\*.

# 

# |Source|Destination|Port|Action|Justification|

# |---|---|---|---|---|

# |CLIENTS net|192.168.20.24|TCP 1514|Allow|Wazuh agent events|

# |CLIENTS net|192.168.20.24|TCP 1515|Allow|Wazuh agent enrollment|

# |CLIENTS net|any|any|Allow|Outbound général|

# |DMZ net|192.168.20.24|TCP 1514|Allow|Wazuh agent events|

# |DMZ net|192.168.20.24|TCP 1515|Allow|Wazuh agent enrollment|

# |DMZ net|192.168.50.10|TCP 3100|Allow|Loki|

# |DMZ net|192.168.50.10|TCP 4317|Allow|OTel gRPC|

# |DMZ net|192.168.50.10|TCP 4318|Allow|OTel HTTP|

# |DMZ net|192.168.50.10|TCP 3200|Allow|Tempo|

# |DMZ net|192.168.50.10|TCP 9090|Allow|Prometheus|

# |DMZ net|192.168.20.0/27|ICMP|Allow|Ping management|

# |DMZ net|any|any|Allow|Outbound général|

# |LAN net|192.168.50.10|TCP 9090|Allow|Prometheus|

# |LAN net|192.168.50.12|TCP 80|Allow|Grafana via Nginx|

# |LAN net|DMZ net|any|Block|Isolation DMZ|

# |any|any|any|Block|Default deny-all|

# 

# \### Règles CLIENTS

# 

# !\[Règles firewall CLIENTS](https://claude.ai/chat/images/Pasted%20image%2020260522134112.png)

# 

# \### Règles DMZ

# 

# !\[Règles firewall DMZ](https://claude.ai/chat/images/Pasted%20image%2020260522134057.png)

# 

# \### Règles LAN

# 

# !\[Règles firewall LAN](https://claude.ai/chat/images/Pasted%20image%2020260522134033.png)

# 

# \---

# 

# \## 9. NAT Outbound

# 

# Firewall → NAT → Outbound → Mode : Automatic → Save.

# 

# \---

# 

# \## 10. Connectivité internet

# 

# !\[Test connectivité internet](https://claude.ai/chat/images/Pasted%20image%2020260512195227.png)

# 

# \---

# 

# \## 11. Désactivation du hardware offloading

# 

# Avant d'installer Suricata, le hardware offloading doit être désactivé. Lorsque pfSense tourne comme VM, les tâches d'offloading sont gérées par le commutateur virtuel de l'hyperviseur, ce qui crée un décalage où Suricata voit des paquets déjà partiellement traités — le rendant aveugle au contenu des paquets.

# 

# System → Advanced → Networking :

# 

# \- ✅ Disable hardware checksum offloading

# \- ✅ Disable hardware TCP segmentation offloading

# \- ✅ Disable hardware large receive offloading

# 

# !\[Désactivation hardware offloading](https://claude.ai/chat/images/Pasted%20image%2020260520175909.png)

# 

# \---

# 

# \## 12. Suricata IDS/IPS

# 

# \### Installation

# 

# System → Package Manager → Available Packages → suricata → Install.

# 

# !\[Installation Suricata](https://claude.ai/chat/images/Pasted%20image%2020260520054204.png)

# 

# \### Règles ETOpen

# 

# Services → Suricata → Global Settings → ETOpen Emerging Threats rules → Enable ✅ → Update interval : 12 heures → Save.

# 

# Onglet Updates → Update → confirmation verte.

# 

# !\[Configuration ETOpen](https://claude.ai/chat/images/Pasted%20image%2020260520181138.png) !\[Mise à jour des règles](https://claude.ai/chat/images/Pasted%20image%2020260520181551.png)

# 

# \### Assignment des interfaces

# 

# |Interface|Enable|Objectif|

# |---|---|---|

# |LAN|✅|Réseau management (VLAN20)|

# |CLIENTS|✅|Réseau client (VLAN10)|

# |DMZ|✅|Réseau serveurs (VLAN50)|

# 

# !\[Assignment des interfaces Suricata](https://claude.ai/chat/images/Pasted%20image%2020260520182335.png)

# 

# \### Catégories de règles

# 

# Pour chaque interface, onglet Categories :

# 

# \- ✅ emerging-malware.rules

# \- ✅ emerging-scan.rules

# \- ✅ emerging-exploit.rules

# \- ✅ emerging-web-server.rules

# \- ✅ emerging-trojan.rules

# \- ✅ emerging-botcc.rules

# 

# Pour l'interface CLIENTS, la catégorie `emerging-mobile-malware` est également activée — le réseau CLIENTS est susceptible d'accueillir des appareils mobiles des employés d'ACCENT.

# 

# !\[Catégories de règles Suricata](https://claude.ai/chat/images/Pasted%20image%2020260520181852.png)

# 

# \### Vérification des alertes

# 

# Pour valider le fonctionnement de Suricata, des scans de test sont générés depuis S1 :

# 

# ```bash

# sudo nmap -sS -T5 -p 1-1000 192.168.20.23

# sudo nmap --script vuln 192.168.20.23

# ```

# 

# !\[Scan nmap depuis S1](https://claude.ai/chat/images/Pasted%20image%2020260520190137.png)

# 

# Les alertes apparaissent dans Services → Suricata → Alerts :

# 

# !\[Alertes Suricata détectées](https://claude.ai/chat/images/Pasted%20image%2020260520190506.png)

# 

# \---

# 

# \## 13. OpenVPN — Accès distant sécurisé

# 

# \### Architecture

# 

# Un nœud Ubuntu (\*\*Node4\*\*) est ajouté à la topologie comme client VPN distant, connecté à un routeur Cisco dédié (\*\*VPN-Router\*\*) qui simule un employé en télétravail derrière un routeur NAT.

# 

# ```

# Node4 (10.1.1.10) → VPN-Router NAT → NAT Cloud → ISP-Router → pfSense WAN (10.0.0.2)

# &#x20;                                                 port forward UDP 1194

# ```

# 

# \### Création du CA — ACCENT-CA

# 

# VPN → OpenVPN → Wizards → Create CA :

# 

# |Champ|Valeur|

# |---|---|

# |Descriptive name|`ACCENT-CA`|

# |Key length|2048 bit|

# |Lifetime|3650 jours|

# |Country Code|`TN`|

# |Organization|`ACCENT`|

# 

# !\[Création du CA ACCENT-CA](https://claude.ai/chat/images/Pasted%20image%2020260522112624.png)

# 

# \### Création du certificat serveur — ACCENT-VPN-Server

# 

# |Champ|Valeur|

# |---|---|

# |Descriptive name|`ACCENT-VPN-Server`|

# |Key length|2048 bit|

# |Lifetime|398 jours|

# |Country Code|`TN`|

# |Organization|`ACCENT`|

# 

# !\[Création du certificat serveur](https://claude.ai/chat/images/Pasted%20image%2020260522112724.png)

# 

# \### Configuration du serveur OpenVPN

# 

# \*\*Endpoint :\*\*

# 

# |Champ|Valeur|

# |---|---|

# |Description|`ACCENT-VPN`|

# |Protocol|UDP on IPv4 only|

# |Interface|WAN|

# |Local Port|1194|

# 

# \*\*Cryptographie :\*\*

# 

# |Champ|Valeur|

# |---|---|

# |TLS Authentication|✅|

# |DH Parameters|2048 bit|

# |Data Encryption|AES-256-GCM, AES-128-GCM, CHACHA20-POLY1305|

# |Fallback|AES-256-CBC|

# |Auth Digest|SHA256|

# 

# \*\*Tunnel (split tunnel) :\*\*

# 

# |Champ|Valeur|

# |---|---|

# |IPv4 Tunnel Network|`10.8.0.0/24`|

# |Redirect IPv4 Gateway|❌ (split tunnel)|

# |IPv4 Local Networks|`192.168.20.0/27, 192.168.50.0/26, 192.168.60.0/25`|

# |Topology|Subnet|

# |DNS Server 1|`192.168.20.23`|

# 

# > \*\*Split tunnel\*\* : seul le trafic vers les réseaux internes passe par le VPN. Le trafic internet du client reste sur sa connexion locale.

# 

# !\[Configuration serveur OpenVPN](https://claude.ai/chat/images/Pasted%20image%2020260522133053.png)

# 

# \### Règles firewall auto-créées

# 

# Le wizard crée automatiquement :

# 

# \- Règle WAN : Pass UDP 1194

# \- Règle OpenVPN : Pass all

# 

# !\[Règles firewall créées par le wizard](https://claude.ai/chat/images/Pasted%20image%2020260522113152.png)

# 

# Serveur OpenVPN créé et actif :

# 

# !\[Serveur OpenVPN actif](https://claude.ai/chat/images/Pasted%20image%2020260522132917.png)

# 

# Règles OpenVPN tab :

# 

# !\[Règles OpenVPN](https://claude.ai/chat/images/Pasted%20image%2020260522134153.png)

# 

# Règles WAN — UDP 1194 :

# 

# !\[Règle WAN UDP 1194](https://claude.ai/chat/images/Pasted%20image%2020260522123903.png)

# 

# \### Création de l'utilisateur VPN

# 

# System → User Manager → Add :

# 

# |Champ|Valeur|

# |---|---|

# |Username|`vpn-client`|

# |Password|`<REDACTED>`|

# |Certificate|`vpn-client-cert` (ACCENT-CA, 2048 bit, 398j)|

# 

# !\[Création utilisateur VPN](https://claude.ai/chat/images/Pasted%20image%2020260522113428.png)

# 

# \### Export de la configuration client

# 

# Installation du package `openvpn-client-export` :

# 

# !\[Installation openvpn-client-export](https://claude.ai/chat/images/Pasted%20image%2020260522114903.png)

# 

# Export du fichier `.ovpn` avec Host Name Resolution pointant vers `192.168.140.179` (IP publique ISP-Router) :

# 

# !\[Export configuration client .ovpn](https://claude.ai/chat/images/Pasted%20image%2020260522115105.png)

# 

# \### Connexion depuis Node4

# 

# ```bash

# sudo apt install -y openvpn

# sudo openvpn --config /tmp/vpn-client-conf.ovpn

# ```

# 

# Connexion établie — `Initialization Sequence Completed` :

# 

# !\[Connexion VPN établie depuis Node4](https://claude.ai/chat/images/Pasted%20image%2020260522120934.png)

# 

# Node4 obtient l'IP `192.168.70.2/24` sur tun0 :

# 

# !\[Node4 connecté avec IP 192.168.70.2](https://claude.ai/chat/images/Pasted%20image%2020260522140832.png)

# 

# \### Validation de la connectivité

# 

# Ping depuis vpnclient vers les ressources internes :

# 

# !\[Ping depuis vpnclient vers ressources internes](https://claude.ai/chat/images/Pasted%20image%2020260522132732.png)

# 

# Statut OpenVPN côté pfSense — client connecté :

# 

# !\[Statut OpenVPN — client connecté](https://claude.ai/chat/images/Pasted%20image%2020260522140620.png)

# 

# \---

# 

# \## 14. Transition vers la configuration réseau finale

# 

# Avec pfSense déployé et VLAN20 opérationnel, l'IP temporaire cloud0 sur pve1 n'est plus nécessaire. Tous les tunnels SSH utilisent désormais 192.168.20.11 comme point de saut :

# 

# ```powershell

# ssh -L 9443:192.168.20.23:443 root@192.168.20.11

# ssh -L 9006:192.168.20.11:8006 root@192.168.20.11

# ```

# 

# \---



