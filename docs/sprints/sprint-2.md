# 

# \# Sprint 2 — Infrastructure EVE-NG

# 

# \## Vue d'Ensemble

# 

# Ce sprint couvre la mise en place de l'environnement de lab EVE-NG. Il inclut la conversion des images disques de S1 et S2 depuis VMware vers le format compatible EVE-NG, la conception de la topologie réseau, l'architecture VLAN, et la configuration des équipements réseau — SW1 (switch de cœur) et ISP-R1 (routeur NAT).

# 

# À ce stade, aucun serveur n'est configuré et aucun pare-feu n'est déployé. Ce sprint établit la couche réseau physique et virtuelle sur laquelle reposent tous les sprints suivants.

# 

# \---

# 

# \## Environnement du Lab

# 

# \*\*Hôte EVE-NG :\*\* 192.168.140.160 \*\*Fichier du lab :\*\* `/opt/unetlab/labs/PFE/Lab-PFE.unl` \*\*UUID du lab :\*\* `2e718c0b-41bf-48c0-a67a-8fac5dbb9e97` \*\*Version EVE-NG :\*\* 6.2.0

# 

# \---

# 

# \## S1 et S2 — Conversion VMware vers EVE-NG

# 

# \### Pourquoi la Conversion

# 

# S1 et S2 ont été préparés dans VMware lors du Sprint 1 avec tous les paquets requis installés. Plutôt que de réinstaller depuis zéro dans EVE-NG, les images disques sont exportées en VMDK puis converties au format qcow2. Cela préserve les paquets installés et évite de répéter le travail d'installation de l'OS dans un environnement de virtualisation imbriquée plus lent.

# 

# \### Configuration Réseau VMware

# 

# Un VMnet personnalisé est créé dans VMware avec un sous-réseau statique de 192.168.140.0/24. Cela évite les conflits DHCP et donne à tous les nœuds EVE-NG et à l'hôte une plage d'adresses prévisible. L'hôte EVE-NG obtient 192.168.140.160.

# 

# \### Images Converties

# 

# |VM|Source VMware|Dossier Image EVE-NG|Disque|Taille|

# |---|---|---|---|---|

# |Ubuntu S1|client.vmdk|ubuntu-s1-1.0-pfe|virtioa.qcow2|13GB|

# |Ubuntu S2|Clien2.vmdk|ubuntu-s2-1.0-pfe|virtioa.qcow2|7GB|

# 

# \### Procédure de Conversion

# 

# ```bash

# \# 1. Upload du VMDK depuis Windows

# scp "C:\\Users\\pfe\\Desktop\\VMs\\<dossier>\\<fichier>.vmdk" root@192.168.140.160:/tmp/<nom>.vmdk

# 

# \# 2. Créer le dossier image

# mkdir -p /opt/unetlab/addons/qemu/<image-name>-pfe/

# 

# \# 3. Convertir le disque

# qemu-img convert -f vmdk -O qcow2 /tmp/<fichier>.vmdk \\

# &#x20; /opt/unetlab/addons/qemu/<image-name>-pfe/virtioa.qcow2

# 

# \# 4. Corriger les permissions

# chown -R www-data:www-data /opt/unetlab/addons/qemu/

# /opt/unetlab/wrappers/unl\_wrapper -a fixpermissions

# 

# \# 5. Nettoyage

# rm /tmp/<fichier>.vmdk

# ```

# 

# \### Exigences des Images EVE-NG 6.x

# 

# EVE-NG 6.x a des exigences spécifiques qui diffèrent des versions plus anciennes :

# 

# \- Les images disques doivent être nommées \*\*virtioa.qcow2\*\*

# \- Le nom du dossier image doit suivre le pattern \*\*template\_name-suffix\*\* (ex : ubuntu-s1-1.0-pfe)

# \- Les templates doivent être en \*\*YAML uniquement\*\* — les fichiers config.xml sont ignorés

# \- Les templates YAML doivent exister dans `/opt/unetlab/html/templates/amd/` et `/opt/unetlab/html/templates/intel/`

# \- L'ordre de boot doit être \*\*-boot order=c\*\* (pas cd) pour éviter une boucle de boot PXE

# 

# \### Création des Templates YAML

# 

# ```bash

# cat > /opt/unetlab/html/templates/amd/ubuntu-s1-1.0.yml << 'EOF'

# \---

# type: qemu

# description: Ubuntu S1

# name: ubuntu-s1-1.0

# cpulimit: 1

# icon: Server-2D-Linux-S.svg

# cpu: 2

# ram: 2048

# ethernet: 2

# console: vnc

# shutdown: 1

# qemu\_arch: x86\_64

# qemu\_nic: virtio-net-pci

# qemu\_version: 2.4.0

# qemu\_options: -machine type=pc,accel=kvm -vga std -usbdevice tablet -boot order=c -cpu host

# EOF

# 

# cp /opt/unetlab/html/templates/amd/ubuntu-s1-1.0.yml \\

# &#x20;  /opt/unetlab/html/templates/intel/ubuntu-s1-1.0.yml

# ```

# 

# Même structure pour ubuntu-s2-1.0.

# 

# \### Sauvegarde des Images Après Chaque Session

# 

# EVE-NG 6.x crée des fichiers d'overlay dans le dossier tmp pendant l'exécution. Les modifications doivent être appliquées à l'image de base après chaque session :

# 

# ```bash

# LAB="/opt/unetlab/tmp/0/2e718c0b-41bf-48c0-a67a-8fac5dbb9e97"

# /opt/qemu-2.12.0/bin/qemu-img commit $LAB/2/virtioa.qcow2

# /opt/qemu-2.12.0/bin/qemu-img commit $LAB/3/virtioa.qcow2

# ```

# 

# \---

# 

# \## Topologie Réseau

# 

# \### Nœuds du Lab

# 

# |Node ID|Nom|Type|Image|Rôle|

# |---|---|---|---|---|

# |6|pve1|QEMU|proxmox-pfe-1.0-pfe|Hyperviseur Proxmox|

# |9|SW1|QEMU|viosl2-tee|Switch L2 de cœur|

# |7|ISP-R1|Dynamips|c3725|Routeur NAT / passerelle internet|

# |2|UbuntuS1|QEMU|ubuntu-s1-1.0-pfe|Serveur applicatif 1|

# |3|UbuntuS2|QEMU|ubuntu-s2-1.0-pfe|Serveur applicatif 2|

# 

# \### Connexions Physiques

# 

# |De|Interface|Vers|Interface|Type|

# |---|---|---|---|---|

# |ISP-R1|fa0/0|Cloud0 (NAT)|—|WAN/internet|

# |ISP-R1|fa1/0|pve1|ens4/vmbr1|WAN link (10.0.0.0/30)|

# |SW1|Gi0/0|pve1|ens3/vmbr0|Trunk 802.1Q|

# |SW1|Gi1/0|UbuntuS1|ens3|Access VLAN50|

# |SW1|Gi1/1|UbuntuS2|ens3|Access VLAN50|

# |SW1|Gi1/2|Clients|—|Access VLAN10|

# 

# \---

# 

# \## Plan VLAN (VLSM)

# 

# |VLAN|Nom|Réseau|Masque|Hôtes|Rôle|

# |---|---|---|---|---|---|

# |10|CLIENTS|192.168.10.0|/24|254|Appareils WiFi/clients|

# |20|MANAGEMENT|192.168.20.0|/27|30|LAN de management|

# |50|DMZ|192.168.50.0|/26|62|Serveurs (S1, S2, MonSrv)|

# |70|VPN|192.168.70.0|/28|14|Tunnel OpenVPN|

# |99|NATIVE|—|—|—|VLAN natif du trunk (sécurité)|

# 

# VLAN99 est utilisé comme VLAN natif sur tous les ports trunk. Aucun hôte n'y est assigné. Cela empêche les attaques VLAN hopping où un attaquant forge des trames double-taguées pour atteindre un autre VLAN — toute trame de ce type atterrit dans VLAN99 qui n'a ni hôte ni routage.

# 

# \---

# 

# \## Configuration ISP-R1 (Cisco 3725)

# 

# ISP-R1 fournit le NAT et l'accès internet pour l'ensemble du lab. Les configurations Dynamips ne persistent pas après reboot — il faut reconfigurer à chaque session.

# 

# ```

# conf t

# interface fa0/0

# &#x20;ip address dhcp

# &#x20;no shutdown

# interface fa1/0

# &#x20;ip address 10.0.0.1 255.255.255.252

# &#x20;no shutdown

# ip route 0.0.0.0 0.0.0.0 192.168.140.2

# access-list 1 permit 10.0.0.0 0.0.0.3

# ip nat inside source list 1 interface fa0/0 overload

# interface fa0/0

# &#x20;ip nat outside

# interface fa1/0

# &#x20;ip nat inside

# end

# wr

# 

# conf t

# ip nat inside source static udp 10.0.0.2 1194 interface FastEthernet0/0 1194

# end

# wr

# ```

# 

# Vérification :

# 

# ```

# ping 8.8.8.8

# show ip interface brief

# show ip nat translations

# ```

# 

# \---

# 

# \## Configuration SW1 (vIOS L2)

# 

# SW1 est le switch Layer 2 de cœur connectant tous les nœuds du lab. Les configurations persistent via l'overlay EVE-NG.

# 

# ```

# conf t

# vlan 10

# &#x20;name CLIENTS

# vlan 20

# &#x20;name MANAGEMENT

# vlan 50

# &#x20;name DMZ

# vlan 70

# &#x20;name VPN

# vlan 99

# &#x20;name NATIVE

# exit

# interface Gi0/0

# &#x20;switchport trunk encapsulation dot1q

# &#x20;switchport mode trunk

# &#x20;switchport trunk native vlan 99

# &#x20;switchport trunk allowed vlan 10,20,50,70

# &#x20;no shutdown

# interface Gi0/1

# &#x20;switchport trunk encapsulation dot1q

# &#x20;switchport mode trunk

# &#x20;switchport trunk native vlan 99

# &#x20;switchport trunk allowed vlan 10,20,50,70

# &#x20;no shutdown

# interface Gi0/2

# &#x20;switchport trunk encapsulation dot1q

# &#x20;switchport mode trunk

# &#x20;switchport trunk native vlan 99

# &#x20;switchport trunk allowed vlan 10,20,50,70

# &#x20;no shutdown

# interface Gi0/3

# &#x20;switchport mode access

# &#x20;switchport access vlan 50

# &#x20;no shutdown

# interface Gi1/0

# &#x20;switchport mode access

# &#x20;switchport access vlan 50

# &#x20;no shutdown

# interface Gi1/1

# &#x20;switchport mode access

# &#x20;switchport access vlan 50

# &#x20;no shutdown

# interface Gi1/2

# &#x20;switchport mode access

# &#x20;switchport access vlan 10

# &#x20;no shutdown

# end

# wr

# ```

# 

# Vérification :

# 

# ```

# show vlan brief

# show interfaces trunk

# ```

# 

# \---

# 

# \## Fix NAT EVE-NG (Persistant)

# 

# Après reboot, EVE-NG perd ses règles NAT iptables. Correction permanente via crontab :

# 

# ```bash

# crontab -e

# ```

# 

# Ajouter :

# 

# ```

# @reboot iptables -t nat -A POSTROUTING -o pnet0 -j MASQUERADE \&\& echo 1 > /proc/sys/net/ipv4/ip\_forward \&\& iptables -I FORWARD -i pnet0 -j ACCEPT \&\& iptables -I FORWARD -o pnet0 -j ACCEPT

# ```

# 

# Appliquer immédiatement :

# 

# ```bash

# iptables -t nat -A POSTROUTING -o pnet0 -j MASQUERADE

# echo 1 > /proc/sys/net/ipv4/ip\_forward

# iptables -I FORWARD -i pnet0 -j ACCEPT

# iptables -I FORWARD -o pnet0 -j ACCEPT

# ```

# 

# \---

# 

# \## Procédure de Démarrage

# 

# Démarrer les nœuds dans cet ordre depuis l'interface WebUI EVE-NG :

# 

# 1\. SW1 — attendre 30s

# 2\. ISP-R1 — attendre 30s

# 3\. pve1 — attendre 1 minute

# 4\. UbuntuS1, UbuntuS2

# 

# \---

# 

# \## Problèmes Connus et Corrections

# 

# |Problème|Cause|Correction|

# |---|---|---|

# |Nœud grisé dans WebUI|qemu\_version manquant dans YAML|Ajouter qemu\_version: 2.4.0 au template|

# |Boucle de boot PXE|-boot order=cd dans qemu\_options|Changer en -boot order=c|

# |S1 ne démarre pas|Pas de virtioa.qcow2 dans le dossier tmp|Créer manuellement l'overlay après wipe|

# |NAT EVE-NG ne fonctionne pas après reboot|Règles iptables perdues|Ajouter l'entrée @reboot crontab|

# |Pas de DHCP ISP-R1|Règles iptables FORWARD manquantes|Appliquer le fix NAT ci-dessus|

# 

# \---

# 

# \## Captures d'Écran

# 

# \### 1. Topologie du Lab EVE-NG

# 

# !\[Topologie EVE-NG — ISP-R1, SW1, pve1, S1, S2](https://claude.ai/chat/images/Pasted%20image%2020260522142958.png)

# 

# \### 2. Templates de Nœuds Personnalisés — ubuntu-s1

# 

# !\[Template ubuntu-s1 dans la liste QEMU](https://claude.ai/chat/images/Pasted%20image%2020260522142750.png)

# 

# \### 3. Templates de Nœuds Personnalisés — ubuntu-s2

# 

# !\[Template ubuntu-s2 dans la liste QEMU](https://claude.ai/chat/images/Pasted%20image%2020260522142800.png)

# 

# \### 4. Dossier Image S1 sur l'Hôte EVE-NG

# 

# !\[Dossier ubuntu-s1-1.0-pfe avec virtioa.qcow2](https://claude.ai/chat/images/Pasted%20image%2020260522140137.png)

# 

# \### 5. Dossier Image S2 sur l'Hôte EVE-NG

# 

# !\[Dossier ubuntu-s2-1.0-pfe avec virtioa.qcow2](https://claude.ai/chat/images/Pasted%20image%2020260522140228.png)

# 

# \### 6. Configuration VLAN sur SW1

# 

# !\[show vlan brief — VLANs configurés](https://claude.ai/chat/images/Pasted%20image%2020260522134759.png)

# 

# \### 7. Interfaces Trunk SW1

# 

# !\[show interfaces trunk — Gi0/0, Gi0/1, Gi0/2 en mode trunk](https://claude.ai/chat/images/Pasted%20image%2020260522134825.png)

# 

# \### 8. Connectivité Internet ISP-R1

# 

# !\[show ip interface brief et ping 8.8.8.8](https://claude.ai/chat/images/Pasted%20image%2020260522134900.png)

# 

# \---

# 

